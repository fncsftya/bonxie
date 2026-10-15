with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with Ebook;
with Pomarine.Pages;
with Pomarine.Words;

--  Usage: ebook_test FILE OUT_FOLDER. Draws the file's first page, and its
--  last, and checks what Ebook says of links.
procedure Ebook_Test is
   use type Pomarine.Pages.Page_Access;
   Found   : Ebook.Information;
   Message : String (1 .. Ebook.Max_Message);
   Last    : Natural;
   Height  : Natural;
   type Pair is array (1 .. 2) of Positive;
begin
   pragma Assert (Ebook.Extension_Of ("https://a.b/c/Book.PDF?x=1.epub#y") = "pdf");
   pragma Assert (Ebook.Extension_Of ("https://a.b/c.d/book") = "");
   pragma Assert (Ebook.Extension_Of ("https://a.b") = "b");
   pragma Assert (Ebook.Is_Document ("http://x.org/files/a.pdf"));
   pragma Assert (not Ebook.Is_Document ("http://x.org/files/a.html"));
   pragma Assert (Ebook.Is_Document ("http://x.org/files/a.EPUB?x=1"));
   pragma Assert (not Ebook.Is_Document ("http://x.org/files/a.mobi"));
   pragma Assert (not Ebook.Is_Document ("http://x.org/a.pdf/index"));

   Ebook.Open ("/no/such.pdf", Found, Message, Last);
   pragma Assert (Found.Pages = 0 and then Last >= Message'First);
   Ada.Text_IO.Put_Line ("missing: " & Message (1 .. Last));
   Ebook.Open ("/no/such.epub", Found, Message, Last);
   pragma Assert (Found.Pages = 0 and then Last >= Message'First);
   Ada.Text_IO.Put_Line ("missing e-book: " & Message (1 .. Last));

   declare
      File : constant String := Ada.Command_Line.Argument (1);
      Out_Folder : constant String := Ada.Command_Line.Argument (2);
   begin
      Ada.Directories.Create_Path (Out_Folder);
      Ebook.Open (File, Found, Message, Last);
      pragma Assert (Found.Pages > 0, Message (1 .. Last));
      Ada.Text_IO.Put_Line
        ("pages:" & Found.Pages'Image & " title: " & Found.Title (1 .. Found.Last));
      for Page of Pair'[1, Found.Pages] when Ebook.File_Extension (File) /= "epub" loop
         Ebook.Render
           (File, Page, Out_Folder & "/" & Ada.Strings.Fixed.Trim (Page'Image, Ada.Strings.Both) & ".png",
            Height, Message, Last);
         pragma Assert (Height > 0, Message (1 .. Last));
         Ada.Text_IO.Put_Line ("page" & Page'Image & " height" & Height'Image);
      end loop;
      declare
         Words   : Pomarine.Words.Result;
         Content : Pomarine.Pages.Page_Access;
      begin
         Ebook.Build_Page (File, 1, Content, Words, Message, Last);
         pragma Assert (Content /= null, Message (1 .. Last));
         Ada.Text_IO.Put_Line
           ("vector page" & Content.Width'Image & " x" & Content.Height'Image
            & ": ops" & Content.Operations'Image & " points" & Content.Points'Image
            & " characters" & Content.Characters'Image & " faces" & Content.Faces'Image
            & " pictures" & Content.Images'Image & " words" & Words.Count'Image);
         for Face of Content.Fonts loop
            Ada.Text_IO.Put_Line ("  face " & Face.Name (1 .. Face.Last));
         end loop;
         for Each in 1 .. Natural'Min (Words.Count, 12) loop
            Ada.Text_IO.Put_Line
              ("  word " & Pomarine.Words.Image (Words.Words (Each), Words)
               & Words.Words (Each).Line'Image
               & Words.Words (Each).Left'Image & Words.Words (Each).Top'Image);
         end loop;
         Pomarine.Pages.Free (Content);
      end;
      Ebook.Render (File, Found.Pages + 1, Out_Folder & "/none.png", Height, Message, Last);
      pragma Assert (Height = 0 and then Last >= Message'First);
      Ada.Text_IO.Put_Line ("past the end: " & Message (1 .. Last));
      declare
         Words   : Pomarine.Words.Result;
         Content : Pomarine.Pages.Page_Access;
      begin
         Ebook.Build_Page (File, Found.Pages + 1, Content, Words, Message, Last);
         pragma Assert (Content = null and then Last >= Message'First);
      end;
   end;
end Ebook_Test;
