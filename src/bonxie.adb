with Ada.Command_Line;
with Files;
with SDL3;
with Speech.Jobs;
with Viewer;

procedure Bonxie is
begin
   SDL3.Initialize;

   --  The file named on the command line, or an empty document.
   if Ada.Command_Line.Argument_Count > 0 then
      Viewer.Run
        (Files.Read (Ada.Command_Line.Argument (1)),
         File_Name => Ada.Command_Line.Argument (1));
   else
      Viewer.Run ("");
   end if;

   SDL3.Shutdown;
   Speech.Jobs.Shutdown;  --  or the tasks that listen would keep it from ending
exception
   when others =>
      Speech.Jobs.Shutdown;
      raise;
end Bonxie;
