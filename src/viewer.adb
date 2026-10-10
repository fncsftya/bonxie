with Ada.Numerics.Elementary_Functions;
with SDL3.Events.Redraws;
with SDL3.Windows.Renderers;

package body Viewer is

   package Documents renames Typeset.Documents;
   package Views renames Typeset.Views;

   use type SDL3.Events.Event_Kind;
   use type SDL3.Events.Key_Code;
   use SDL3.Windows.Renderers;

   --  The page

   Family     : constant String := "Georgia";
   Font_Size  : constant Float := 18.0;
   Page_Width : constant Float := 640.0;  --  layout units
   Para_Gap   : constant Float := 8.0;

   --  The window

   Window_Width  : constant := 1000;
   Window_Height : constant := 800;
   Toolbar_Size  : constant Float := 32.0;
   Margin        : constant Float := 16.0;
   --  Beside the page when it fills the window's width.

   Background : constant Color := (30, 30, 36, 255);
   Toolbar    : constant Color := (52, 54, 66, 255);
   Ink        : constant Color := (230, 230, 235, 255);

   --  Moving about

   Min_Zoom       : constant Float := 0.25;
   Max_Zoom       : constant Float := 8.0;
   Zoom_Per_Notch : constant Float := 1.1;
   Settle_MS      : constant := 120;
   --  How long the zoom must hold still to count as settled.

   Lines_Per_Notch : constant Float := 3.0;
   Page_Fraction   : constant Float := 0.9;
   --  How much of a view Page Up and Page Down move.

   --  The page area's height, in layout units.
   function Extent (Item : Session) return Float is
     (Yoga.Nodes.Height (Item.Page_Node) / (Item.Density * Item.Zoom));

   --  Drawing

   procedure Lay_Out_Window (Item : in out Session);
   --  Lay out the window's parts to fit its size now.

   procedure Lay_Out_Window (Item : in out Session) is
      Width  : Natural;
      Height : Natural;
   begin
      Output_Size (Item.Target, Width, Height);
      Yoga.Nodes.Calculate_Layout (Item.UI, Float (Width), Float (Height));
   end Lay_Out_Window;

   procedure Paint (Item : in out Session);
   --  Draw what is shown, but do not present it.

   procedure Paint (Item : in out Session) is
      Scale  : constant Float := Item.Density * Item.Zoom;
      Width  : Natural;
      Height : Natural;
   begin
      Lay_Out_Window (Item);
      Output_Size (Item.Target, Width, Height);

      Clear (Item.Target, Background);
      Views.Draw
        (Item.Page, Item.Doc, Item.Target, Ink, Item.Anchor, Item.Offset,
         Left    => Float'Max
                      (Margin * Item.Density,
                       (Float (Width) - Page_Width * Scale) / 2.0),
         Top     => Yoga.Nodes.Top (Item.Page_Node),
         Width   => Natural (Yoga.Nodes.Width (Item.Page_Node)),
         Height  => Natural (Yoga.Nodes.Height (Item.Page_Node)),
         Scale   => Scale,
         Settled => Item.Settled);

      --  Over the text, which is flushed.
      Fill_Rect
        (Item.Target, Toolbar,
         Yoga.Nodes.Left (Item.Toolbar_Node),
         Yoga.Nodes.Top (Item.Toolbar_Node),
         Yoga.Nodes.Width (Item.Toolbar_Node),
         Yoga.Nodes.Height (Item.Toolbar_Node));
      Item.Dirty := False;
   end Paint;

   procedure Draw (Item : in out Session) is
   begin
      Paint (Item);
      Present (Item.Target);
   end Draw;

   package Redraws is new SDL3.Events.Redraws (Session, Draw);

   --  Moving about

   procedure Scroll (Item : in out Session; By : Float) is
   begin
      Documents.Scroll
        (Item.Doc, Item.Anchor, Item.Offset, By, Extent (Item));
      Item.Dirty := True;
   end Scroll;

   procedure Zoom_By (Item : in out Session; Factor : Float) is
      Zoom : constant Float :=
        Float'Min (Max_Zoom, Float'Max (Min_Zoom, Item.Zoom * Factor));
   begin
      if Zoom /= Item.Zoom then
         Item.Zoom := Zoom;
         Item.Settled := False;
         Item.Dirty := True;
      end if;
   end Zoom_By;

   procedure Go_To_Start (Item : in out Session) is
   begin
      Item.Anchor := 1;
      Item.Offset := 0.0;
      Item.Dirty := True;
   end Go_To_Start;

   --  Events

   procedure Handle_Wheel (Item : in out Session; Notches : Float) is
   begin
      if SDL3.Events.Command_Held then
         Zoom_By
           (Item,
            Ada.Numerics.Elementary_Functions."**" (Zoom_Per_Notch, Notches));
      else
         Scroll
           (Item,
            -Notches * Lines_Per_Notch * Documents.Line_Height (Item.Doc));
      end if;
   end Handle_Wheel;

   procedure Handle_Key (Item : in out Session; Event : SDL3.Events.Event) is
      Line : constant Float := Documents.Line_Height (Item.Doc);
   begin
      if Event.Key = SDL3.Events.Key_Down_Arrow then
         Scroll (Item, Line);
      elsif Event.Key = SDL3.Events.Key_Up_Arrow then
         Scroll (Item, -Line);
      elsif Event.Key = SDL3.Events.Key_Page_Down then
         Scroll (Item, Page_Fraction * Extent (Item));
      elsif Event.Key = SDL3.Events.Key_Page_Up then
         Scroll (Item, -Page_Fraction * Extent (Item));
      elsif Event.Key = SDL3.Events.Key_Home then
         Go_To_Start (Item);
      elsif Event.Key = SDL3.Events.Key_End then
         Scroll (Item, Documents.Total_Height (Item.Doc));
      elsif Event.Command and then Event.Key = SDL3.Events.Key_Equals then
         Zoom_By (Item, Zoom_Per_Notch);
      elsif Event.Command and then Event.Key = SDL3.Events.Key_Minus then
         Zoom_By (Item, 1.0 / Zoom_Per_Notch);
      elsif Event.Command and then Event.Key = SDL3.Events.Key_0 then
         Zoom_By (Item, 1.0 / Item.Zoom);
      end if;
   end Handle_Key;

   procedure Handle (Item : in out Session; Event : SDL3.Events.Event) is
   begin
      case Event.Kind is
         when SDL3.Events.Quit =>
            Item.Done := True;
         when SDL3.Events.Redraw =>
            Item.Dirty := True;
         when SDL3.Events.Mouse_Wheel =>
            Handle_Wheel (Item, Event.Wheel_Y);
         when SDL3.Events.Key_Down =>
            Handle_Key (Item, Event);
         when SDL3.Events.Other =>
            null;
      end case;
   end Handle;

   --  Running

   procedure Set_Up (Item : in out Session; Source : String);
   --  Lay out the window and the document in it, once there is a target.

   procedure Set_Up (Item : in out Session; Source : String) is
   begin
      Documents.Configure
        (Item.Doc, Family, Font_Size, Page_Width, Para_Gap);
      Documents.Load (Item.Doc, Source);

      Item.Page_Node := Yoga.Nodes.New_Child (Yoga.Nodes.Root (Item.UI));
      Item.Toolbar_Node := Yoga.Nodes.New_Child (Yoga.Nodes.Root (Item.UI));
      Yoga.Nodes.Set_Flex_Direction (Yoga.Nodes.Root (Item.UI), Yoga.Column);
      Yoga.Nodes.Set_Flex_Grow (Item.Page_Node, 1.0);
      Yoga.Nodes.Set_Height (Item.Toolbar_Node, Toolbar_Size * Item.Density);
      --  Before any event: moving about needs the page area's size.
      Lay_Out_Window (Item);
   end Set_Up;

   procedure Open (Item : in out Session; Source : String) is
   begin
      SDL3.Windows.Create
        (Item.Win, "bonxie", Window_Width, Window_Height,
         Resizable => True, High_Density => True);
      Item.Density := SDL3.Windows.Pixel_Density (Item.Win);
      Create (Item.Target, Item.Win);
      Set_Up (Item, Source);
   end Open;

   procedure Wait_And_Handle (Item : in out Session) is
      Event : SDL3.Events.Event;
   begin
      --  Nothing to do until something happens, except to settle the
      --  zoom once it has held still.
      if SDL3.Events.Wait
           (Event, Timeout_MS => (if Item.Settled then -1 else Settle_MS))
      then
         Handle (Item, Event);
         while SDL3.Events.Poll (Event) loop
            Handle (Item, Event);
         end loop;
      elsif not Item.Settled then
         Item.Settled := True;
         Item.Dirty := True;
      end if;
   end Wait_And_Handle;

   --  Without a window

   function Pixels (Points : Positive; Density : Float) return Positive is
     (Positive (Float (Points) * Density));

   procedure Open
     (Item    : in out Session;
      Source  : String;
      Width   : Positive;
      Height  : Positive;
      Density : Float := 2.0) is
   begin
      Item.Density := Density;
      Create_Offscreen
        (Item.Target, Pixels (Width, Density), Pixels (Height, Density));
      Set_Up (Item, Source);
   end Open;

   function Is_Open (Item : Session) return Boolean is
     (Documents.Is_Configured (Item.Doc));

   procedure Settle (Item : in out Session) is
   begin
      if not Item.Settled then
         Item.Settled := True;
         Item.Dirty := True;
      end if;
   end Settle;

   procedure Resize (Item : in out Session; Width, Height : Positive) is
   begin
      SDL3.Windows.Renderers.Resize
        (Item.Target,
         Pixels (Width, Item.Density), Pixels (Height, Item.Density));
      Lay_Out_Window (Item);
      Item.Dirty := True;
   end Resize;

   procedure Render
     (Item   : in out Session;
      Result : in out SDL3.Windows.Renderers.Images.Image) is
   begin
      --  Offscreen there is nothing to present to.
      Paint (Item);
      SDL3.Windows.Renderers.Images.Read (Result, Item.Target);
   end Render;

   procedure Run (Source : String) is
      Item    : aliased Session;
      Watcher : Redraws.Watch;  --  ends before Item does
   begin
      Open (Item, Source);

      --  The redraw watch also draws: the OS blocks the event loop
      --  during a live resize, and only repainting from inside the event
      --  watch avoids a stretched frame.
      Redraws.Install (Watcher, Item);

      while not Item.Done loop
         if Item.Dirty then
            Draw (Item);
         end if;
         Wait_And_Handle (Item);
      end loop;
   end Run;

end Viewer;
