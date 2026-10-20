--  What a page says about its own PDF: links_probe <address>. It loads the page, looks
--  at it, and prints the PDF address Webshot finds (meta tags and links) and what the
--  address is made of; for finding out why a page's PDF was not seen.
with Ada.Command_Line;
with Ada.Text_IO;
with Source_Links;
with Webshot;

procedure Links_Probe is
   use Ada.Text_IO;
   use type Webshot.States;
   Waited : Natural := 0;
begin
   Webshot.Start
     (1, Ada.Command_Line.Argument (1), "/tmp/links-probe.png", Look_File => "/tmp/links-probe-look.png",
      Dismiss_Banners => False);
   while Webshot.State (1) = Webshot.Working and then Waited < 90_000 loop
      Webshot.Pump (50);
      Waited := Waited + 50;
   end loop;
   if Webshot.State (1) = Webshot.Looked then
      Put_Line ("document link: '" & Webshot.Document_Link (1) & "'");
   else
      Put_Line ("state " & Webshot.State (1)'Image);
   end if;
   Put_Line ("direct: '" & Source_Links.Direct_Document (Ada.Command_Line.Argument (1)) & "'");
end Links_Probe;
