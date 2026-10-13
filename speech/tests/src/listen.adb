--  Listen to the microphone with a model for some seconds, showing the
--  words as they come, then the whole: `listen model.gguf seconds`.
with Ada.Command_Line;
with Ada.Text_IO;
with Speech.Jobs;

procedure Listen is
   use Ada.Text_IO;
   use type Speech.Jobs.States;

   Which : constant Speech.Jobs.Slot := 1;
   Heard : Speech.Transcript;
   Ticks : constant Natural :=
     Natural'Value (Ada.Command_Line.Argument (2)) * 5;
begin
   Speech.Jobs.Start
     (Which, Speech.Jobs.Model, Ada.Command_Line.Argument (1));
   for Tick in 1 .. Ticks loop
      delay 0.2;
      Speech.Jobs.Heard_So_Far (Which, Heard);
      if Tick mod 5 = 0 then
         Put_Line
           (Speech.Jobs.States'Image (Speech.Jobs.State (Which))
            & " level" & Speech.Jobs.Loudness (Which)'Image & " : "
            & Speech.Image (Heard));
      end if;
   end loop;
   Speech.Jobs.Stop (Which);
   while Speech.Jobs.State (Which) = Speech.Jobs.Finishing loop
      delay 0.1;
   end loop;
   if Speech.Jobs.State (Which) = Speech.Jobs.Done then
      Speech.Jobs.Take (Which, Heard);
      Put_Line ("FINAL: " & Speech.Image (Heard));
   else
      Put_Line (Speech.Jobs.States'Image (Speech.Jobs.State (Which)) & ": "
                & Speech.Jobs.Message (Which));
   end if;
end Listen;
