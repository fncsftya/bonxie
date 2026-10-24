with Ada.Command_Line;
with Ada.Real_Time;
with Ada.Text_IO;
with Projects;
with SDL3;
with Pomarine.Events;
with Viewer;
with Viewer.Home_Screen;
with Viewer.Project_Screen;

--  Measures opening a project that is already kept, as a click on it does:
--  open_bench database [project [times]].
procedure Open_Bench is
   package Home renames Viewer.Home_Screen;
   package Proj renames Viewer.Project_Screen;
   use Ada.Real_Time;
   use Ada.Text_IO;

   Path : constant String := Ada.Command_Line.Argument (1);
   Key  : constant Projects.Id :=
     (if Ada.Command_Line.Argument_Count > 1
      then Projects.Id'Value (Ada.Command_Line.Argument (2)) else 1);
   Runs : constant Positive :=
     (if Ada.Command_Line.Argument_Count > 2
      then Positive'Value (Ada.Command_Line.Argument (3)) else 5);

   Session : Viewer.Session;
   Start   : Time;
begin
   SDL3.Initialize;
   Viewer.Open_Window
     (Session, "", Hidden => True, Store => Path, VSync => False);
   Viewer.Paint_Frame (Session);
   for Run in 1 .. Runs loop
      Start := Clock;
      Home.Open_Project (Session, Key);
      Put_Line
        ("open" & Run'Image & ":"
         & Duration'Image (To_Duration (Clock - Start) * 1000.0) & " ms");
      Start := Clock;
      Viewer.Paint_Frame (Session);
      Put_Line
        ("  first frame:"
         & Duration'Image (To_Duration (Clock - Start) * 1000.0) & " ms");
      --  As the event loop would: tick, and draw what that damaged. The
      --  longest frame is the pictures being put on the GPU.
      declare
         Worst : Duration := 0.0;
         Began : constant Time := Clock;
      begin
         while Clock - Began < Milliseconds (400) loop
            Start := Clock;
            Viewer.Tick (Session, Pomarine.Events.Ticks);
            Viewer.Paint_Frame (Session);
            Worst := Duration'Max (Worst, To_Duration (Clock - Start));
            delay 0.005;
         end loop;
         Put_Line
           ("  slowest frame after:"
            & Duration'Image (Worst * 1000.0) & " ms");
      end;
      Proj.Close_Project (Session);
   end loop;
   SDL3.Shutdown;
end Open_Bench;
