with Ada.Command_Line;
with Ada.Numerics.Elementary_Functions;
with Ada.Streams.Stream_IO;
with Typeset.Documents;
with SDL3.Events;
with SDL3.Windows.Renderers;
with Typeset.Views;
with Yoga.Nodes;

procedure Bonxie is
   package Documents renames Typeset.Documents;
   package Views renames Typeset.Views;

   use type SDL3.Events.Event_Kind;
   use type SDL3.Events.Key_Code;
   use SDL3.Windows.Renderers;

   Family       : constant String := "Georgia";
   Font_Size    : constant Float := 18.0;
   Page_Width   : constant Float := 640.0;  --  layout units
   Para_Gap     : constant Float := 8.0;
   Toolbar_Size : constant Float := 32.0;
   Margin       : constant Float := 16.0;

   Min_Zoom : constant Float := 0.25;
   Max_Zoom : constant Float := 8.0;
   Zoom_Per_Notch : constant Float := 1.1;
   Settle_MS : constant := 120;
   --  How long the zoom must hold still to count as settled.

   Background : constant Color := (30, 30, 36, 255);
   Toolbar    : constant Color := (52, 54, 66, 255);
   Ink        : constant Color := (230, 230, 235, 255);

   function Read_File (File_Name : String) return String is
      use Ada.Streams.Stream_IO;
      File : File_Type;
   begin
      Open (File, In_File, File_Name);
      declare
         Data : String (1 .. Natural (Size (File)));
      begin
         String'Read (Stream (File), Data);
         Close (File);
         return Data;
      end;
   end Read_File;

   Source : constant String :=
     (if Ada.Command_Line.Argument_Count > 0
      then Read_File (Ada.Command_Line.Argument (1))
      else "");
   --  The text of the file named on the command line.
begin
   SDL3.Initialize;

   declare
      Win  : SDL3.Windows.Window;
      Ev   : SDL3.Events.Event;
      Done : Boolean := False;

      UI : Yoga.Nodes.Tree;
      --  Frame: a column holding the page area above the toolbar.
      Page_Node    : constant Yoga.Nodes.Node :=
        Yoga.Nodes.New_Child (Yoga.Nodes.Root (UI));
      Toolbar_Node : constant Yoga.Nodes.Node :=
        Yoga.Nodes.New_Child (Yoga.Nodes.Root (UI));

      Doc : Documents.Document;
   begin
      SDL3.Windows.Create
        (Win, "bonxie", 1000, 800, Resizable => True, High_Density => True);

      declare
         R       : Renderer;
         Page    : Views.View;  --  after R: it is destroyed first
         Density : constant Float := SDL3.Windows.Pixel_Density (Win);
         W, H    : Natural;

         Anchor  : Documents.Paragraph_Number := 1;
         Offset  : Float := 0.0;
         Zoom    : Float := 1.0;
         Settled : Boolean := True;
         Dirty   : Boolean := True;

         procedure Draw is
            Scale : constant Float := Density * Zoom;
            Left  : Float;
         begin
            Output_Size (R, W, H);
            Yoga.Nodes.Calculate_Layout (UI, Float (W), Float (H));
            Left := Float'Max
              (Margin * Density,
               (Float (W) - Page_Width * Scale) / 2.0);

            Clear (R, Background);
            Views.Draw
              (Page, Doc, R, Ink, Anchor, Offset,
               Left   => Left,
               Top    => Yoga.Nodes.Top (Page_Node),
               Width  => Natural (Yoga.Nodes.Width (Page_Node)),
               Height => Natural (Yoga.Nodes.Height (Page_Node)),
               Scale  => Scale,
               Settled => Settled);

            --  Over the text, which is flushed.
            Fill_Rect
              (R, Toolbar,
               Yoga.Nodes.Left (Toolbar_Node), Yoga.Nodes.Top (Toolbar_Node),
               Yoga.Nodes.Width (Toolbar_Node),
               Yoga.Nodes.Height (Toolbar_Node));
            Present (R);
            Dirty := False;
         end Draw;

         function Extent return Float is
           (Yoga.Nodes.Height (Page_Node) / (Density * Zoom));
         --  How high the view is, in layout units.

         procedure Scroll (By : Float) is
         begin
            Documents.Scroll (Doc, Anchor, Offset, By, Extent);
            Dirty := True;
         end Scroll;

         procedure Zoom_By (Factor : Float) is
            New_Zoom : constant Float :=
              Float'Min (Max_Zoom, Float'Max (Min_Zoom, Zoom * Factor));
         begin
            if New_Zoom /= Zoom then
               Zoom := New_Zoom;
               Settled := False;
               Dirty := True;
            end if;
         end Zoom_By;

         procedure Handle (Item : SDL3.Events.Event) is
            Lines : constant Float := Documents.Line_Height (Doc);
         begin
            case Item.Kind is
               when SDL3.Events.Quit =>
                  Done := True;
               when SDL3.Events.Redraw =>
                  Dirty := True;
               when SDL3.Events.Mouse_Wheel =>
                  if SDL3.Events.Command_Held then
                     Zoom_By
                       (Ada.Numerics.Elementary_Functions."**"
                          (Zoom_Per_Notch, Item.Wheel_Y));
                  else
                     Scroll (-Item.Wheel_Y * 3.0 * Lines);
                  end if;
               when SDL3.Events.Key_Down =>
                  if Item.Key = SDL3.Events.Key_Down_Arrow then
                     Scroll (Lines);
                  elsif Item.Key = SDL3.Events.Key_Up_Arrow then
                     Scroll (-Lines);
                  elsif Item.Key = SDL3.Events.Key_Page_Down then
                     Scroll (0.9 * Extent);
                  elsif Item.Key = SDL3.Events.Key_Page_Up then
                     Scroll (-0.9 * Extent);
                  elsif Item.Key = SDL3.Events.Key_Home then
                     Anchor := 1;
                     Offset := 0.0;
                     Dirty := True;
                  elsif Item.Key = SDL3.Events.Key_End then
                     Scroll (Documents.Total_Height (Doc));
                  elsif Item.Command
                    and then Item.Key = SDL3.Events.Key_Equals
                  then
                     Zoom_By (Zoom_Per_Notch);
                  elsif Item.Command
                    and then Item.Key = SDL3.Events.Key_Minus
                  then
                     Zoom_By (1.0 / Zoom_Per_Notch);
                  elsif Item.Command and then Item.Key = SDL3.Events.Key_0
                  then
                     Zoom_By (1.0 / Zoom);
                  end if;
               when SDL3.Events.Other =>
                  null;
            end case;
         end Handle;
      begin
         Create (R, Win);

         Documents.Configure (Doc, Family, Font_Size, Page_Width, Para_Gap);
         Documents.Load (Doc, Source);

         Yoga.Nodes.Set_Flex_Direction (Yoga.Nodes.Root (UI), Yoga.Column);
         Yoga.Nodes.Set_Flex_Grow (Page_Node, 1.0);
         Yoga.Nodes.Set_Height (Toolbar_Node, Toolbar_Size * Density);

         --  Also the redraw handler: the OS blocks the event loop during
         --  a live resize, and only repainting from inside the event
         --  watch avoids a stretched frame.
         SDL3.Events.Set_Redraw_Handler (Draw'Unrestricted_Access);

         while not Done loop
            if Dirty then
               Draw;
            end if;

            --  Nothing to do until something happens, except to settle
            --  the zoom once it has held still.
            if not Done then
               if SDL3.Events.Wait
                    (Ev, Timeout_MS => (if Settled then -1 else Settle_MS))
               then
                  Handle (Ev);
                  while SDL3.Events.Poll (Ev) loop
                     Handle (Ev);
                  end loop;
               elsif not Settled then
                  Settled := True;
                  Dirty := True;
               end if;
            end if;
         end loop;
      end;
   end;  --  Page and Renderer, then Win and UI, are destroyed here

   SDL3.Shutdown;
end Bonxie;
