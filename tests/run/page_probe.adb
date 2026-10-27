--  Takes the picture of a page, as finding sources does, and says how tall it is and how
--  many words are read from it: page_probe <address> [look]. The picture is /tmp/probe.png
--  (and the look at the top, /tmp/probe-look.png).
with Ada.Command_Line;
with Ada.Text_IO;
with Vision;
with Webshot;

procedure Page_Probe is
   use Ada.Text_IO;
   use type Webshot.States;
   Found   : Vision.Result;
   Ok      : Boolean;
   Message : String (1 .. 200);
   Last    : Natural;
   Waited  : Natural := 0;
   Look    : constant Boolean := Ada.Command_Line.Argument_Count > 1;
begin
   Webshot.Start
     (1,
      Ada.Command_Line.Argument (1),
      "/tmp/probe.png",
      Look_File       => (if Look then "/tmp/probe-look.png" else ""),
      Dismiss_Banners => False);
   while Webshot.State (1) = Webshot.Working and then Waited < 90_000 loop
      Webshot.Pump (50);
      Waited := Waited + 50;
   end loop;
   if Webshot.State (1) = Webshot.Looked then
      Vision.Recognize ("/tmp/probe-look.png", Found, Ok, Message, Last);
      Put_Line ("look: words" & Found.Count'Image);
      Webshot.Continue (1);
      Waited := 0;
      while Webshot.State (1) = Webshot.Working and then Waited < 90_000 loop
         Webshot.Pump (50);
         Waited := Waited + 50;
      end loop;
   end if;
   if Webshot.State (1) = Webshot.Done then
      Put_Line ("height" & Webshot.Height (1)'Image & " title " & Webshot.Page_Title (1));
      Vision.Recognize ("/tmp/probe.png", Found, Ok, Message, Last);
      Put_Line ("ok " & Ok'Image & " words" & Found.Count'Image);
   else
      Put_Line ("state " & Webshot.State (1)'Image);
   end if;
end Page_Probe;
