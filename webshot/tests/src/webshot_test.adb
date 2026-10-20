--  Tests of Webshot, on pages written to /tmp: the whole of a very long page
--  is in its picture, and a cookie banner is clicked away before the picture is
--  taken (a page says that its button was pressed by changing its title).
--  Needs WebKit, not a network.
with Ada.Command_Line;
with Ada.Directories;
with Ada.Text_IO;
with Webshot;

procedure Webshot_Test is
   use Ada.Text_IO;
   use type Webshot.States;
   use type Ada.Directories.File_Size;

   Folder   : constant String := "/tmp/bonxie-webshot-test";
   Which    : constant Webshot.Slot := 1;
   Failures : Natural := 0;

   procedure Check (Ok : Boolean; What : String) is
   begin
      if not Ok then
         Put_Line ("FAIL: " & What);
         Failures := Failures + 1;
      end if;
   end Check;

   procedure Remove (Name : String) is
   begin
      if Ada.Directories.Exists (Name) then
         Ada.Directories.Delete_File (Name);
      end if;
   end Remove;

   procedure Write_Page (Name, Html : String) is
      File : File_Type;
   begin
      --  What an earlier run made is not what this makes.
      Remove (Folder & "/" & Name & ".png");
      Remove (Folder & "/" & Name & ".look.png");
      Create (File, Out_File, Folder & "/" & Name & ".html");
      Put_Line (File, Html);
      Close (File);
   end Write_Page;

   --  Takes the picture of the page, and says the title it had.
   function Take (Name : String) return String is
      Waited : Natural := 0;
   begin
      Webshot.Reset (Which);
      Webshot.Start (Which, "file://" & Folder & "/" & Name & ".html", Folder & "/" & Name & ".png");
      while Webshot.State (Which) = Webshot.Working and then Waited < 60_000 loop
         Webshot.Pump (50);
         Waited := Waited + 50;
      end loop;
      Check (Webshot.State (Which) = Webshot.Done, Name & ": the picture was taken");
      return (if Webshot.State (Which) = Webshot.Done then Webshot.Page_Title (Which) else "(none)");
   end Take;

   --  Takes a look at the top of the page, with no banner pressed by the page's own
   --  way, and waits for it. True if it was looked at.
   function Look (Name : String) return Boolean is
      Waited : Natural := 0;
   begin
      Webshot.Reset (Which);
      Webshot.Start
        (Which, "file://" & Folder & "/" & Name & ".html", Folder & "/" & Name & ".png",
         Look_File => Folder & "/" & Name & ".look.png", Dismiss_Banners => False);
      while Webshot.State (Which) = Webshot.Working and then Waited < 60_000 loop
         Webshot.Pump (50);
         Waited := Waited + 50;
      end loop;
      Check (Webshot.State (Which) = Webshot.Looked, Name & ": the top was looked at");
      return Webshot.State (Which) = Webshot.Looked;
   end Look;

   --  Presses the button that says Label, and waits for the next look.
   function Press (Label : String) return Boolean is
      Waited : Natural := 0;
   begin
      Webshot.Press (Which, Label);
      while Webshot.State (Which) = Webshot.Working and then Waited < 60_000 loop
         Webshot.Pump (50);
         Waited := Waited + 50;
      end loop;
      Check (Webshot.State (Which) = Webshot.Looked, "pressed " & Label & ": looked again");
      return Webshot.Pressed (Which);
   end Press;

   Banner_Style : constant String :=
     "position:fixed;left:0;right:0;bottom:0;background:#222;color:#fff;padding:24px;z-index:99";
begin
   Ada.Directories.Create_Path (Folder);

   --  Its whole length, however long: scaled to fit a picture, not cut off.
   Write_Page ("tall", "<title>tall</title><body style='margin:0'><div style='height:40000px;background:#cde'>x</div>");
   declare
      Title : constant String := Take ("tall");
   begin
      Check (Title = "tall", "tall: its title, " & Title);
      if Webshot.State (Which) = Webshot.Done then
         Check (Webshot.Height (Which) in 16_000 .. Webshot.Max_Pixels,
                "tall: all of it is in a picture that fits, " & Webshot.Height (Which)'Image & " pixels");
      end if;
   end;

   --  The first screens of a long page are also written at the full scale, for words
   --  to be read from, as the picture of all of it is shrunk to fit.
   declare
      Waited : Natural := 0;
   begin
      Webshot.Reset (Which);
      Webshot.Start
        (Which, "file://" & Folder & "/tall.html", Folder & "/tiled.png", Tile_Prefix => Folder & "/tiled-tile");
      while Webshot.State (Which) = Webshot.Working and then Waited < 60_000 loop
         Webshot.Pump (50);
         Waited := Waited + 50;
      end loop;
      Check (Webshot.State (Which) = Webshot.Done, "tiled: the picture was taken");
      if Webshot.State (Which) = Webshot.Done then
         Check (Webshot.Tile_Count (Which) = Webshot.Max_Tiles,
                "tiled: four screens," & Webshot.Tile_Count (Which)'Image);
         for Tile in 1 .. Webshot.Max_Tiles loop
            Check (Ada.Directories.Exists (Folder & "/tiled-tile-" & Tile'Image (2 .. 2) & ".png"),
                   "tiled: the screen" & Tile'Image & " is there");
         end loop;
         Check (not Ada.Directories.Exists (Folder & "/tiled-tile-5.png"), "tiled: and no more");
      end if;
   end;
   Write_Page ("short", "<title>short</title><body style='margin:0'><p>Not much here.</p>");
   declare
      Waited : Natural := 0;
   begin
      Webshot.Reset (Which);
      Webshot.Start
        (Which, "file://" & Folder & "/short.html", Folder & "/short.png", Tile_Prefix => Folder & "/short-tile");
      while Webshot.State (Which) = Webshot.Working and then Waited < 60_000 loop
         Webshot.Pump (50);
         Waited := Waited + 50;
      end loop;
      Check (Webshot.State (Which) = Webshot.Done and then Webshot.Tile_Count (Which) = 1,
             "short: one screen is enough");
   end;

   --  A banner with a button to accept: pressed.
   Write_Page
     ("accept",
      "<title>waiting</title><div id=b style='" & Banner_Style & "'>We use cookies to improve your experience."
      & "<button onclick=""document.title='accepted';b.remove()"">Accept all</button>"
      & "<button>Manage preferences</button></div>");
   Check (Take ("accept") = "accepted", "accept: the banner's button was pressed");

   --  One that offers to reject too: cookies are accepted, which is what the page is read for.
   Write_Page
     ("reject",
      "<title>waiting</title><div id=b role=dialog style='" & Banner_Style & "'>Your privacy: we and our partners"
      & " use cookies."
      & "<button onclick=""document.title='rejected';b.remove()"">Reject all</button>"
      & "<button onclick=""document.title='accepted';b.remove()"">Accept all cookies</button></div>");
   Check (Take ("reject") = "accepted", "reject: the one that accepts is pressed");

   --  The reject button is pressed if there is no other: and not one that is a purchase.
   Write_Page
     ("rejectonly",
      "<title>waiting</title><div id=b role=dialog style='" & Banner_Style & "'>We use cookies on this site."
      & "<button onclick=""document.title='rejected';b.remove()"">Reject all</button></div>");
   Check (Take ("rejectonly") = "rejected", "rejectonly: with nothing to accept, the one that rejects");

   --  A notice that leads to another: both are pressed.
   Write_Page
     ("second",
      "<title>waiting</title><script>function more () { b.innerHTML = 'Cookie settings saved <button id=two>OK"
      & "</button>'; two.onclick = function () { document.title = 'second'; b.remove (); }; }</script>"
      & "<div id=b style='" & Banner_Style & "'>This site uses cookies."
      & "<button onclick='more ()'>Accept</button></div>");
   Check (Take ("second") = "second", "second: a second notice is pressed too");

   --  A banner kept in a shadow root, as some are.
   Write_Page
     ("shadow",
      "<title>waiting</title><div id=host></div><script>"
      & "var root = host.attachShadow({mode:'open'});"
      & "root.innerHTML = ""<div style='" & Banner_Style & "'>Cookie consent for this site"
      & "<button id=ok>Accept all</button></div>"";"
      & "root.getElementById('ok').onclick = function () { document.title = 'accepted'; };</script>");
   Check (Take ("shadow") = "accepted", "shadow: a banner in a shadow root");

   --  A banner in a frame of the page (which says so by a message: the origins differ).
   Write_Page
     ("frame",
      "<title>waiting</title><script>window.addEventListener('message', function (e) { document.title = e.data; });"
      & "</script><iframe style='position:fixed;left:0;right:0;bottom:0;width:100%;height:120px' srcdoc=""<div>"
      & "We use cookies on this site.<button onclick=&quot;parent.postMessage('accepted','*')&quot;>Accept all"
      & "</button></div>""></iframe>");
   Check (Take ("frame") = "accepted", "frame: a banner in a frame");

   --  A button that says Accept, but is not in a notice about cookies: left alone.
   Write_Page
     ("terms",
      "<title>untouched</title><form><p>Please read the terms of the competition before you enter.</p>"
      & "<button type=button onclick=""document.title='pressed'"">Accept</button></form>");
   Check (Take ("terms") = "untouched", "terms: a button that is not a cookie banner's is left alone");

   --  The top first: nothing is pressed by the page's own way, and the picture of it is
   --  made, while the page is kept open for what is said to be pressed.
   Write_Page
     ("choice",
      "<title>waiting</title><div id=b style='" & Banner_Style & "'>We use cookies to improve your experience."
      & "<button onclick=""document.title='accepted';b.remove()"">Accept all cookies</button>"
      & "<button onclick=""document.title='rejected';b.remove()"">Reject all</button>"
      & "<button onclick=""document.title='settings'"">Manage preferences</button></div>");
   if Look ("choice") then
      Check (Ada.Directories.Exists (Folder & "/choice.look.png"), "choice: there is a picture of the top");
      Check (not Ada.Directories.Exists (Folder & "/choice.png"), "choice: not of the whole page yet");
      Check (Webshot.Page_Title (Which) = "waiting", "choice: the page's own way pressed nothing");
      Check (Webshot.Document_Link (Which) = "", "choice: no PDF");
      Check (not Press ("Nonexistent button"), "choice: nothing to press, said so");
      --  What a picture's words give may be a letter wrong, and the case and marks of it not the page's.
      Check (Press ("Rejact All."), "choice: a button is found by words a little wrong");
      Check (Webshot.Page_Title (Which) = "rejected", "choice: the one that rejects was pressed");
      Webshot.Continue (Which);
      declare
         Waited : Natural := 0;
      begin
         while Webshot.State (Which) = Webshot.Working and then Waited < 60_000 loop
            Webshot.Pump (50);
            Waited := Waited + 50;
         end loop;
      end;
      Check (Webshot.State (Which) = Webshot.Done, "choice: the whole page is then taken");
      Check (Ada.Directories.Exists (Folder & "/choice.png"), "choice: and its picture is there");
   end if;

   --  A button that costs something is never pressed, even when it is the one asked for
   --  (a notice of this kind has "Reject all and subscribe" for a price).
   Write_Page
     ("purchase",
      "<title>waiting</title><div id=b role=dialog style='" & Banner_Style & "'>Personalised advertising: cookies."
      & "<button onclick=""document.title='accepted';b.remove()"">Accept all</button>"
      & "<button onclick=""document.title='bought'"">Reject all and subscribe for &pound;5 per month</button></div>");
   if Look ("purchase") then
      Check (not Press ("Reject all"), "purchase: a button that costs something is not pressed, as asked for");
      Check (not Press ("Reject all and subscribe for 5 per month"), "purchase: nor by its words in full");
      Check (Webshot.Page_Title (Which) = "waiting", "purchase: and nothing was bought");
      Check (Press ("Accept all"), "purchase: the one that accepts is");
      Check (Webshot.Page_Title (Which) = "accepted", "purchase: and it was pressed");
   end if;

   --  A button whose words are only part of what is read.
   Write_Page
     ("part",
      "<title>waiting</title><div id=b style='" & Banner_Style & "'>This site uses cookies."
      & "<a href=# onclick=""document.title='closed';b.remove()"">No thanks, continue without accepting</a></div>");
   if Look ("part") then
      Check (Press ("continue without accepting"), "part: a button is found by part of its words");
      Check (Webshot.Page_Title (Which) = "closed", "part: and it was the one pressed");
   end if;

   --  A page that says which PDF it is the page of.
   Write_Page
     ("front",
      "<title>front</title><meta name=citation_pdf_url content='paper.pdf'><p>Abstract of a paper.</p>");
   if Look ("front") then
      Check (Webshot.Document_Link (Which) = "file://" & Folder & "/paper.pdf",
             "front: its PDF is " & Webshot.Document_Link (Which));
   end if;

   --  A page with no meta tag, but a button for its PDF (as the front of a paper has, twice, one
   --  of them for a viewer): the one PDF.
   Write_Page
     ("front2",
      "<title>front2</title><a href='doc/epdf/10.1/x'>PDF/eReader</a><p>Abstract.</p>"
      & "<a href='doc/pdf/10.1/x?download=true'>Download PDF</a>");
   if Look ("front2") then
      Check (Webshot.Document_Link (Which) = "file://" & Folder & "/doc/pdf/10.1/x?download=true",
             "front2: its PDF is found by its buttons, " & Webshot.Document_Link (Which));
   end if;

   --  A page that lists many PDFs is no front of one, nor are words that are no PDF's link.
   Write_Page
     ("listing",
      "<title>listing</title><a href='a.pdf'>PDF</a> <a href='b.pdf'>PDF</a> <a href='c.pdf'>[PDF]</a>");
   if Look ("listing") then
      Check (Webshot.Document_Link (Which) = "", "listing: many PDFs are no front's");
   end if;
   Write_Page ("about", "<title>about</title><a href='about-pdfs.html'>PDF</a><a href='report.pdf'>The report</a>");
   if Look ("about") then
      Check (Webshot.Document_Link (Which) = "", "about: a PDF's name, or a PDF not called so, is not taken");
   end if;

   --  A notice that is put up a good while after the page has loaded, as consent tools do: it is
   --  seen when the whole page is to be taken, which is looked at again, and then it is pressed.
   Write_Page
     ("late",
      "<title>waiting</title><p>Text of a page.</p><script>setTimeout(function () {"
      & "var d = document.createElement('div'); d.id = 'b';"
      & "d.style.cssText = 'position:fixed;left:0;right:0;bottom:0;background:#222;color:#fff;padding:24px';"
      & "d.innerHTML = 'We use cookies on this site.<button onclick=""document.title=&quot;accepted&quot;;"
      & "b.remove()"">Accept all</button>';"
      & "document.body.appendChild(d); }, 2500);</script>");
   if Look ("late") then
      Check (Webshot.Page_Title (Which) = "waiting", "late: nothing yet at the first look");
      Webshot.Pump (3_000);
      Webshot.Continue (Which);
      declare
         Waited : Natural := 0;
      begin
         while Webshot.State (Which) = Webshot.Working and then Waited < 60_000 loop
            Webshot.Pump (50);
            Waited := Waited + 50;
         end loop;
      end;
      Check (Webshot.State (Which) = Webshot.Looked, "late: a notice that came late is looked at, not photographed");
      if Webshot.State (Which) = Webshot.Looked then
         Check (Press ("Accept all"), "late: and pressed");
         Check (Webshot.Page_Title (Which) = "accepted", "late: it was the notice's button");
         Webshot.Continue (Which);
         declare
            Waited : Natural := 0;
         begin
            while Webshot.State (Which) = Webshot.Working and then Waited < 60_000 loop
               Webshot.Pump (50);
               Waited := Waited + 50;
            end loop;
         end;
         Check (Webshot.State (Which) = Webshot.Done, "late: and then the page is taken");
      end if;
   end if;

   --  A file is fetched as a browser would download it: a PDF is saved as it is; a page is no file.
   declare
      Paper : constant String := Folder & "/paper.pdf";
      Waited : Natural := 0;
      File  : File_Type;
   begin
      Create (File, Out_File, Paper);
      Put_Line (File, "%PDF-1.4");
      Put_Line (File, "1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj");
      Put_Line (File, "2 0 obj<</Type/Pages/Count 1/Kids[3 0 R]>>endobj");
      Put_Line (File, "3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 200 200]>>endobj");
      Put_Line (File, "trailer<</Root 1 0 R/Size 4>>");
      Put_Line (File, "%%EOF");
      Close (File);
      Remove (Folder & "/fetched.pdf");
      Webshot.Reset (Which);
      Webshot.Start_Download (Which, "file://" & Paper, Folder & "/fetched.pdf");
      while Webshot.State (Which) = Webshot.Working and then Waited < 60_000 loop
         Webshot.Pump (50);
         Waited := Waited + 50;
      end loop;
      Check (Webshot.State (Which) = Webshot.Done,
             "fetch: a PDF is fetched" & (if Webshot.State (Which) = Webshot.Failed
                                          then ", " & Webshot.Message (Which) else ""));
      Check (Ada.Directories.Exists (Folder & "/fetched.pdf"), "fetch: and its file is there");
      if Ada.Directories.Exists (Folder & "/fetched.pdf") then
         Check (Ada.Directories.Size (Folder & "/fetched.pdf") = Ada.Directories.Size (Paper),
                "fetch: all of it, as it is");
      end if;

      Waited := 0;
      Remove (Folder & "/notfile.pdf");
      Webshot.Reset (Which);
      Webshot.Start_Download (Which, "file://" & Folder & "/terms.html", Folder & "/notfile.pdf");
      while Webshot.State (Which) = Webshot.Working and then Waited < 60_000 loop
         Webshot.Pump (50);
         Waited := Waited + 50;
      end loop;
      Check (Webshot.State (Which) = Webshot.Failed, "fetch: a page is no file");
      Check (not Ada.Directories.Exists (Folder & "/notfile.pdf"), "fetch: and nothing is left of it");
   end;

   Webshot.Reset (Which);
   if Failures > 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   else
      Put_Line ("checks passed");
   end if;
end Webshot_Test;
