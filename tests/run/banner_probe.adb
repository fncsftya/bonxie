--  Tries the step that clears what covers a page, on one page, with the real model:
--  banner_probe <model folder> <address>. It looks at the top, reads the words from
--  the picture, asks the model what covers it, and presses the button the model names,
--  saying what it did and what the page's title was before and after.
with Ada.Command_Line;
with Ada.Directories;
with Ada.Text_IO;
with MLX.Jobs;
with Source_Finding;
with Vision;
with Webshot;

procedure Banner_Probe is
   use Ada.Text_IO;
   use type Webshot.States;
   use type MLX.Jobs.States;

   Found   : Vision.Result;
   Ok      : Boolean;
   Message : String (1 .. 200);
   Last    : Natural;
   Job     : MLX.Jobs.Job;

   procedure Wait_Looked is
      Waited : Natural := 0;
   begin
      while Webshot.State (1) = Webshot.Working and then Waited < 90_000 loop
         Webshot.Pump (50);
         Waited := Waited + 50;
      end loop;
   end Wait_Looked;

   function Words_Of (Result : Vision.Result) return String is
      Text : String (1 .. 20_000);
      Used : Natural := 0;
      Line : Natural := 0;
   begin
      for Each in 1 .. Result.Count loop
         declare
            Word : constant String := Vision.Image (Result.Words (Each), Result);
         begin
            exit when Used + Word'Length + 1 > Text'Length;
            if Used > 0 then
               Used := Used + 1;
               Text (Used) := (if Result.Words (Each).Line /= Line then ASCII.LF else ' ');
            end if;
            Line := Result.Words (Each).Line;
            Text (Used + 1 .. Used + Word'Length) := Word;
            Used := Used + Word'Length;
         end;
      end loop;
      return Text (1 .. Used);
   end Words_Of;
begin
   Webshot.Start
     (1, Ada.Command_Line.Argument (2), "/tmp/probe.png", Look_File => "/tmp/probe-look.png",
      Dismiss_Banners => False);
   Wait_Looked;
   if Webshot.State (1) /= Webshot.Looked then
      Put_Line ("not looked at: " & Webshot.State (1)'Image);
      return;
   end if;
   Put_Line ("title before: " & Webshot.Page_Title (1));
   Vision.Recognize ("/tmp/probe-look.png", Found, Ok, Message, Last);
   declare
      Words : constant String := Words_Of (Found);
   begin
      Put_Line ("words read:" & Found.Count'Image & "; first of them: " & Words (1 .. Natural'Min (300, Words'Length)));
      MLX.Jobs.Start
        (Job, Ada.Command_Line.Argument (1), Source_Finding.Banner_Prompt (Words),
         Source_Finding.Banner_System_Prompt,
         Tuning => (Max_Tokens => Source_Finding.Banner_Tokens, Temperature => 0.1, Thinking => MLX.Off,
                    others => <>));
   end;
   while MLX.Jobs.State (Job) = MLX.Jobs.Running loop
      Webshot.Pump (50);
   end loop;
   declare
      Reply   : constant String := MLX.Jobs.Text (Job);
      Covered : Boolean;
      Button  : Source_Finding.Button_Texts.Bounded_String;
      Valid   : Boolean;
   begin
      Put_Line ("the model said: " & Reply);
      Source_Finding.Parse_Banner (Reply, Covered, Button, Valid);
      Put_Line ("valid " & Valid'Image & " covered " & Covered'Image & " button '"
                & Source_Finding.Button_Texts.To_String (Button) & "'");
      if Covered then
         Ada.Directories.Copy_File ("/tmp/probe-look.png", "/tmp/probe-look-before.png", "mode=overwrite");
         Webshot.Press (1, Source_Finding.Button_Texts.To_String (Button));
         Wait_Looked;
         Put_Line ("pressed " & Webshot.Pressed (1)'Image & "; title after: " & Webshot.Page_Title (1));
      end if;
   end;
   MLX.Jobs.Reset (Job);
   MLX.Jobs.Shutdown;
end Banner_Probe;
