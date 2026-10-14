with Ada.Command_Line;
with Ada.Float_Text_IO;
with Ada.Real_Time;
with Ada.Text_IO;
with Projects;
with SDL3;
with SDL3.Events;
with SDL3.Windows.Renderers.Images;
with Typeset.Samples;
with Viewer;
with Viewer.Canvas_Windows;
with Viewer.Home_Screen;

--  Measures what dragging and sizing an item on the canvas costs, offscreen
--  in software: item_bench [items [frames [paragraphs [gpu]]]]. Each is the
--  time per frame of
--  handling the pointer's move (which lays the item out again), and of
--  drawing what it damaged. Reading the image back is in the drawing, so
--  compare with a frame where nothing has changed.
procedure Item_Bench is
   package Events renames SDL3.Events;
   package Windows renames Viewer.Canvas_Windows;
   package Home renames Viewer.Home_Screen;
   package Images renames SDL3.Windows.Renderers.Images;

   use Ada.Real_Time;
   use Ada.Text_IO;

   Items  : constant Positive :=
     (if Ada.Command_Line.Argument_Count > 0
      then Positive'Value (Ada.Command_Line.Argument (1)) else 1);
   Frames : constant Positive :=
     (if Ada.Command_Line.Argument_Count > 1
      then Positive'Value (Ada.Command_Line.Argument (2)) else 200);

   Paragraphs : constant Natural :=
     (if Ada.Command_Line.Argument_Count > 2
      then Natural'Value (Ada.Command_Line.Argument (3)) else 0);
   --  Of text, besides a line, in each item.

   Session : Viewer.Session;
   Drawn   : Images.Image;

   procedure Report (What : String; Handling, Drawing : Duration) is
      Shown : String (1 .. 9);
      Other : String (1 .. 9);
   begin
      Ada.Float_Text_IO.Put
        (Shown, Float (Handling) * 1000.0 / Float (Frames),
         Aft => 3, Exp => 0);
      Ada.Float_Text_IO.Put
        (Other, Float (Drawing) * 1000.0 / Float (Frames),
         Aft => 3, Exp => 0);
      Put_Line ("  " & What & (1 .. Integer'Max (1, 28 - What'Length) => ' ')
                & "handle" & Shown & " ms   draw" & Other & " ms");
   end Report;

   function Move (X, Y : Float; Held : Boolean) return Events.Event is
     ((Kind => Events.Mouse_Move, Mouse_X => X, Mouse_Y => Y,
       Left_Held => Held, others => <>));

   function Button (Kind : Events.Event_Kind; X, Y : Float)
      return Events.Event is
     ((Kind => Kind, Button => 1, Clicks => 1, Mouse_X => X, Mouse_Y => Y,
       others => <>));

   Windowed : Boolean := False;
   --  Drawing is on the GPU, in a hidden window, not offscreen in software.

   procedure Draw is
   begin
      if Windowed then
         --  Not presenting: that waits for the display, even without vsync.
         Viewer.Paint_Frame (Session);
      else
         Viewer.Render (Session, Drawn);
      end if;
   end Draw;

   procedure Measure
     (What : String; From_X, From_Y : Float; Step_X, Step_Y : Float)
   is
      Start : Time;
      Handling, Drawing : Duration := 0.0;
      X : Float := From_X;
      Y : Float := From_Y;
   begin
      Viewer.Handle (Session, Move (X, Y, False));
      Viewer.Handle (Session, Button (Events.Mouse_Down, X, Y));
      for K in 1 .. Frames loop
         --  Back and forth, to stay on the screen.
         if K mod 40 < 20 then
            X := X + Step_X;
            Y := Y + Step_Y;
         else
            X := X - Step_X;
            Y := Y - Step_Y;
         end if;
         Start := Clock;
         Viewer.Handle (Session, Move (X, Y, True));
         Handling := Handling + To_Duration (Clock - Start);
         Start := Clock;
         Draw;
         Drawing := Drawing + To_Duration (Clock - Start);
      end loop;
      Viewer.Handle (Session, Button (Events.Mouse_Up, X, Y));
      Report (What, Handling, Drawing);
   end Measure;

   procedure Idle is
      Start : Time;
      Drawing : Duration := 0.0;
   begin
      for K in 1 .. Frames loop
         Start := Clock;
         Draw;
         Drawing := Drawing + To_Duration (Clock - Start);
      end loop;
      Report ("nothing changed", 0.0, Drawing);
   end Idle;
   procedure Everything is
      Start : Time;
      Drawing : Duration := 0.0;
   begin
      for K in 1 .. Frames loop
         Viewer.Handle (Session, (Kind => Events.Redraw, others => <>));
         Start := Clock;
         Draw;
         Drawing := Drawing + To_Duration (Clock - Start);
      end loop;
      Report ("everything redrawn", 0.0, Drawing);
   end Everything;
begin
   Put_Line
     (Items'Image & " items," & Frames'Image & " frames,"
      & Paragraphs'Image & " paragraphs:");
   Windowed := Ada.Command_Line.Argument_Count > 3
     and then Ada.Command_Line.Argument (4) = "gpu";
   if Windowed then
      SDL3.Initialize;
      Viewer.Open_Window
        (Session, "", Hidden => True, Store => Projects.Memory,
         VSync => False);
   else
      Viewer.Open (Session, "", 720, 480, 2.0);
   end if;
   Home.New_Project (Session);
   for I in 1 .. Items loop
      Windows.Add_Item (Session, "Item" & I'Image);
      if Paragraphs > 0 then
         declare
            Text : constant String := Typeset.Samples.Document (Paragraphs);
            Next : Positive := Text'First;
         begin
            while Next <= Text'Last loop
               declare
                  Last : Positive := Positive'Min (Text'Last, Next + 199);
               begin
                  --  Not in the middle of a character.
                  while Last < Text'Last and then Last > Next
                    and then Character'Pos (Text (Last + 1))
                               in 16#80# .. 16#BF#
                  loop
                     Last := Last - 1;
                  end loop;
                  Viewer.Handle
                    (Session, Events.Text_Event (Text (Next .. Last)));
                  Next := Last + 1;
               end;
            end loop;
         end;
      end if;
      Viewer.Handle
        (Session,
         Events.Text_Event
           ("The quick brown fox jumps over the lazy dog, and then some "
            & "more words follow so that the item has a few lines of text "
            & "to wrap when it is made smaller or larger."));
   end loop;
   Viewer.Handle (Session, Move (650.0, 60.0, False));
   Draw;

   Idle;
   Everything;
   --  The last item added is the top one: its title bar, and its corner.
   --  The window is larger, and has a header, so the item is lower and
   --  to the right.
   declare
      Across : constant Float := (if Windowed then 140.0 else 0.0);
      Down   : constant Float := (if Windowed then 174.0 else 0.0);
   begin
      Measure ("dragging by the title bar", 420.0 + Across, 125.0 + Down,
               3.0, 2.0);
      Measure ("sizing by the corner", 490.0 + Across, 296.0 + Down,
               3.0, 2.0);
   end;
   if Windowed then
      SDL3.Shutdown;
   end if;
end Item_Bench;
