with Ada.Command_Line;
with Files;
with SDL3;
with Viewer;

procedure Bonxie is
begin
   SDL3.Initialize;

   --  The file named on the command line, or an empty document.
   Viewer.Run
     (if Ada.Command_Line.Argument_Count > 0
      then Files.Read (Ada.Command_Line.Argument (1))
      else "");

   SDL3.Shutdown;
end Bonxie;
