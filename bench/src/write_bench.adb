with Ada.Command_Line;
with Ada.Float_Text_IO;
with Ada.Real_Time;
with Ada.Text_IO;
with Projects;
with SDL3;
with Pomarine.Events;
with SDL3.Windows.Renderers.Images;
with Typeset.Samples;
with Viewer;
with Viewer.Canvas_Windows;
with Viewer.Home_Screen;
with Viewer.Project_Screen;

procedure Write_Bench is
   package Events renames Pomarine.Events;
   package Windows renames Viewer.Canvas_Windows;
   package Home renames Viewer.Home_Screen;
   package Proj renames Viewer.Project_Screen;
   package Images renames SDL3.Windows.Renderers.Images;

   use Ada.Real_Time;
   use Ada.Text_IO;

   Items_Count : constant Positive :=
     (if Ada.Command_Line.Argument_Count > 0
      then Positive'Value (Ada.Command_Line.Argument (1)) else 3);

   Paragraphs  : constant Natural :=
     (if Ada.Command_Line.Argument_Count > 1
      then Natural'Value (Ada.Command_Line.Argument (2)) else 2);

   Runs        : constant Positive :=
     (if Ada.Command_Line.Argument_Count > 2
      then Positive'Value (Ada.Command_Line.Argument (3)) else 3);

   Use_GPU     : constant Boolean :=
     Ada.Command_Line.Argument_Count > 3
     and then Ada.Command_Line.Argument (4) = "gpu";

   Session     : Viewer.Session;
   Drawn       : Images.Image;

   procedure Print_Ms (Label : String; D : Duration) is
      Buf : String (1 .. 10);
   begin
      Ada.Float_Text_IO.Put (Buf, Float (D) * 1000.0, Aft => 3, Exp => 0);
      Put_Line
        ("  " & Label
         & (1 .. Integer'Max (1, 35 - Label'Length) => ' ') & Buf & " ms");
   end Print_Ms;

   procedure Draw is
   begin
      if Use_GPU then
         Viewer.Paint_Frame (Session);
      else
         Viewer.Render (Session, Drawn);
      end if;
   end Draw;

   procedure Run_Once (Iteration : Positive) is
      T0, T1 : Time;
      D_Switch_1, D_Paint_1, D_Paint_Idle, D_Switch_Back : Duration;
      D_Paint_Canvas, D_Switch_2, D_Paint_2 : Duration;
   begin
      Put_Line ("--- Run" & Iteration'Image & " ---");

      --  1. Switch to Write mode (first time)
      T0 := Clock;
      Proj.Set_Mode (Session, Viewer.Write);
      T1 := Clock;
      D_Switch_1 := To_Duration (T1 - T0);
      Print_Ms ("Set_Mode (Write) #1", D_Switch_1);

      --  2. First paint in Write mode
      T0 := Clock;
      Draw;
      T1 := Clock;
      D_Paint_1 := To_Duration (T1 - T0);
      Print_Ms ("First Paint in Write mode", D_Paint_1);

      --  3. Second paint in Write mode (idle / settled)
      T0 := Clock;
      Draw;
      T1 := Clock;
      D_Paint_Idle := To_Duration (T1 - T0);
      Print_Ms ("Idle Paint in Write mode", D_Paint_Idle);

      --  4. Switch back to Canvas mode
      T0 := Clock;
      Proj.Set_Mode (Session, Viewer.Canvas);
      T1 := Clock;
      D_Switch_Back := To_Duration (T1 - T0);
      Print_Ms ("Set_Mode (Canvas)", D_Switch_Back);

      T0 := Clock;
      Draw;
      T1 := Clock;
      D_Paint_Canvas := To_Duration (T1 - T0);
      Print_Ms ("Paint in Canvas mode", D_Paint_Canvas);

      --  5. Switch to Write mode (second time)
      T0 := Clock;
      Proj.Set_Mode (Session, Viewer.Write);
      T1 := Clock;
      D_Switch_2 := To_Duration (T1 - T0);
      Print_Ms ("Set_Mode (Write) #2", D_Switch_2);

      --  6. Paint in Write mode after second switch
      T0 := Clock;
      Draw;
      T1 := Clock;
      D_Paint_2 := To_Duration (T1 - T0);
      Print_Ms ("Paint in Write mode #2", D_Paint_2);

      --  Switch back to Canvas mode for next iteration
      Proj.Set_Mode (Session, Viewer.Canvas);
      Draw;
   end Run_Once;

begin
   Put_Line ("Write mode profiling:");
   Put_Line ("  Items:      " & Items_Count'Image);
   Put_Line ("  Paragraphs: " & Paragraphs'Image);
   Put_Line ("  Runs:       " & Runs'Image);
   Put_Line ("  Backend:    " & (if Use_GPU then "GPU" else "Software"));

   if Use_GPU then
      SDL3.Initialize;
      Viewer.Open_Window
        (Session, "", Hidden => True, Store => Projects.Memory,
         VSync => False);
   else
      Viewer.Open (Session, "", 720, 480, 2.0);
   end if;

   Home.New_Project (Session);

   for I in 1 .. Items_Count loop
      Windows.Add_Item (Session, "Document" & I'Image);
      if Paragraphs > 0 then
         declare
            Text : constant String := Typeset.Samples.Document (Paragraphs);
            Next : Positive := Text'First;
         begin
            while Next <= Text'Last loop
               declare
                  Last : Positive := Positive'Min (Text'Last, Next + 199);
               begin
                  while Last < Text'Last and then Last > Next
                    and then Character'Pos (Text (Last + 1))
                               in 16#80# .. 16#BF#
                  loop
                     Last := Last - 1;
                  end loop;
                  Viewer.Handle
                    (Session,
                     Events.Text_Event (Text (Next .. Last)));
                  Next := Last + 1;
               end;
            end loop;
         end;
      end if;
   end loop;

   --  Settle in canvas mode
   Draw;

   for R in 1 .. Runs loop
      Run_Once (R);
   end loop;

   if Use_GPU then
      SDL3.Shutdown;
   end if;
end Write_Bench;
