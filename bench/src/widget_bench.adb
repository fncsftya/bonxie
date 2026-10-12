with Ada.Command_Line;
with Ada.Float_Text_IO;
with Ada.Real_Time;
with Ada.Text_IO;
with SDL3;
with SDL3.Events;
with SDL3.Windows;
with SDL3.Windows.Renderers;
with Texts.Documents;
with Typeset.Samples;
with UI.Clipboards;
with UI.Themes;
with UI.Widgets.Buttons;
with UI.Widgets.Editors;
with UI.Widgets.Panels;
with Yoga.Nodes;

--  Measures what a frame costs through the widget tree, in a hidden window
--  on the GPU, with the frame kept (so that only what changed is drawn)
--  and without: widget_bench [paragraphs [frames]]. Each is the time to
--  draw one frame, averaged over many, not counting presenting it: that
--  waits for the display, even without vsync.
procedure Widget_Bench is
   package Events renames SDL3.Events;
   package Renderers renames SDL3.Windows.Renderers;
   package Widgets renames UI.Widgets;
   package Docs renames Texts.Documents;
   package Nodes renames Yoga.Nodes;

   use Ada.Real_Time;
   use type SDL3.Events.Milliseconds;
   use Ada.Text_IO;

   Colors  : constant UI.Themes.Theme := UI.Themes.Light;
   Density : constant Float := 2.0;
   Frames  : constant Positive :=
     (if Ada.Command_Line.Argument_Count > 1
      then Positive'Value (Ada.Command_Line.Argument (2)) else 300);
   --  Of each kind to measure.
   Blink   : constant := 500;  --  milliseconds, as the caret's

   procedure Report (What : String; Millis : Float) is
      Shown : String (1 .. 10);
   begin
      Ada.Float_Text_IO.Put (Shown, Millis, Aft => 3, Exp => 0);
      Put_Line ("  " & What & (1 .. Integer'Max (1, 44 - What'Length) => ' ')
                & Shown & " ms");
   end Report;

   Spent : Duration := 0.0;
   --  Of the frames of this run, not counting presenting them: that waits
   --  for the display, even without vsync.

   function Average return Float is
     (Float (Spent) * 1000.0 / Float (Frames));

   Win    : SDL3.Windows.Window;
   Target : Renderers.Renderer;

   procedure Measure (Source : String; Keep : Boolean) is
      Tree   : Widgets.Tree;
      Root   : aliased Widgets.Panels.Panel;
      Bar    : aliased Widgets.Panels.Panel;
      Button : aliased Widgets.Buttons.Button;
      Text_Box : aliased Widgets.Editors.Editor;
      Doc    : aliased Docs.Document;
      Board  : UI.Clipboards.Memory_Clipboard;
      Handled : Boolean;
      Start   : Time;
      Now     : SDL3.Events.Milliseconds := 0;

      procedure Frame is
         Resized : Boolean;
      begin
         Renderers.Fit (Target, Resized);
         Widgets.Paint
           (Tree, Target, Colors, Retained => Renderers.Keeps_Frame (Target));
      end Frame;

      procedure Finish (Started : Time) is
      begin
         Spent := Spent + To_Duration (Clock - Started);
         Renderers.Present (Target);
      end Finish;

      function Move (X : Float) return Events.Event is
        ((Kind => Events.Mouse_Move, Mouse_X => X, Mouse_Y => 16.0,
          others => <>));
   begin
      Renderers.Create (Target, Win, VSync => False, Keep_Frame => Keep);
      Docs.Load (Doc, Source);
      Widgets.Set_Density (Tree, Density);
      Widgets.Set_Clipboard (Tree, Board);
      Widgets.Set_Root (Tree, Root);
      Widgets.Add (Root, Bar);
      Widgets.Add (Bar, Button);
      Widgets.Add (Root, Text_Box);
      Widgets.Panels.Set_Fill (Bar, (52, 54, 66, 255));
      Widgets.Buttons.Set_Label (Button, "Save");
      Widgets.Editors.Configure (Text_Box, "Georgia", 18.0, 640.0, 8.0);
      Widgets.Editors.Attach (Text_Box, Doc'Unchecked_Access);
      Widgets.Focus (Text_Box);
      Nodes.Set_Flex_Direction (Widgets.Node (Root), Yoga.Column);
      Nodes.Set_Height (Widgets.Node (Bar), 32.0 * Density);
      Nodes.Set_Padding (Widgets.Node (Bar), Yoga.All_Edges, 4.0 * Density);
      Nodes.Set_Width (Widgets.Node (Button), 80.0 * Density);
      Nodes.Set_Flex_Grow (Widgets.Node (Text_Box), 1.0);
      Nodes.Set_Margin
        (Widgets.Node (Text_Box), Yoga.All_Edges, 16.0 * Density);
      Frame;
      Renderers.Present (Target);
      Frame;
      Renderers.Present (Target);

      Put_Line (if Keep then " frame kept (draw what changed):"
                else " frame not kept (draw all):");

      Spent := 0.0;
      for K in 1 .. Frames loop
         Start := Clock;
         Now := Now + 1;
         Widgets.Update (Tree, Now);
         if Widgets.Needs_Paint (Tree) then
            Frame;
         end if;
         Spent := Spent + To_Duration (Clock - Start);
      end loop;
      Report ("nothing changed", Average);

      Spent := 0.0;
      for K in 1 .. Frames loop
         Start := Clock;
         Widgets.Invalidate_All (Tree);
         Frame;
         Finish (Start);
      end loop;
      Report ("everything redrawn", Average);

      --  The caret hides and shows, a period apart.
      Spent := 0.0;
      for K in 1 .. Frames loop
         Start := Clock;
         Now := Now + Blink;
         Widgets.Update (Tree, Now);
         Frame;
         Finish (Start);
      end loop;
      Report ("caret blinking", Average);

      Spent := 0.0;
      for K in 1 .. Frames loop
         Start := Clock;
         Widgets.Dispatch (Tree, Events.Text_Event ("x"), Handled);
         Frame;
         Finish (Start);
      end loop;
      Report ("typing a character", Average);

      Spent := 0.0;
      for K in 1 .. Frames loop
         Start := Clock;
         Widgets.Dispatch
           (Tree, Move (if K mod 2 = 0 then 20.0 else 600.0), Handled);
         Frame;
         Finish (Start);
      end loop;
      Report ("pointer on and off a button", Average);

      Spent := 0.0;
      for K in 1 .. Frames loop
         Start := Clock;
         Widgets.Dispatch (Tree, Move (300.0 + Float (K mod 50)), Handled);
         Spent := Spent + To_Duration (Clock - Start);
      end loop;
      Report ("pointer moving, over nothing (no frame)", Average);
   end Measure;

begin
   SDL3.Initialize;
   SDL3.Windows.Create
     (Win, "bench", 1000, 800, High_Density => True, Hidden => True);
   declare
      Paragraphs : constant Positive :=
        (if Ada.Command_Line.Argument_Count > 0
         then Positive'Value (Ada.Command_Line.Argument (1)) else 1_000);
      Source : constant String := Typeset.Samples.Document (Paragraphs);
   begin
      Put_Line (Paragraphs'Image & " paragraphs," & Source'Length'Image
                & " bytes:");
      Measure (Source, Keep => True);
      Measure (Source, Keep => False);
   end;
   SDL3.Shutdown;
end Widget_Bench;
