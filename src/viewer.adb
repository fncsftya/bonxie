with Ada.Exceptions;
with Ada.Numerics.Elementary_Functions;
with Ada.Text_IO;
with SDL3.Events.Redraws;
with SDL3.Windows.Renderers;
with UI.Themes;

package body Viewer is

   package Text_Areas renames UI.Text_Areas;

   use Ada.Strings.Unbounded;
   use type SDL3.Events.Event_Kind;
   use type SDL3.Events.Key_Code;
   use type SDL3.Events.Milliseconds;
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
   --  Around the text area.

   Colors  : constant UI.Themes.Theme := UI.Themes.Light;
   Toolbar : constant Color := (52, 54, 66, 255);

   --  Zooming

   Min_Zoom       : constant Float := 0.25;
   Max_Zoom       : constant Float := 8.0;
   Zoom_Per_Notch : constant Float := 1.1;
   Settle_MS      : constant := 120;
   --  How long the zoom must hold still to count as settled.

   --  Drawing

   procedure Lay_Out_Window (Item : in out Session);
   --  Lay out the window's parts to fit its size now.

   procedure Lay_Out_Window (Item : in out Session) is
      package Nodes renames Yoga.Nodes;
      Width  : Natural;
      Height : Natural;
   begin
      Output_Size (Item.Target, Width, Height);
      Nodes.Calculate_Layout (Item.Layout, Float (Width), Float (Height));
      Text_Areas.Place
        (Item.Area,
         Left    => Nodes.Left (Item.Content_Node)
                    + Nodes.Left (Item.Area_Node),
         Top     => Nodes.Top (Item.Content_Node)
                    + Nodes.Top (Item.Area_Node),
         Width   => Nodes.Width (Item.Area_Node),
         Height  => Nodes.Height (Item.Area_Node),
         Density => Item.Density,
         Zoom    => Item.Zoom);
   end Lay_Out_Window;

   procedure Paint (Item : in out Session);
   --  Draw what is shown, but do not present it.

   procedure Paint (Item : in out Session) is
   begin
      Lay_Out_Window (Item);
      Clear (Item.Target, Colors.Background);
      Text_Areas.Draw (Item.Area, Item.Target, Colors, Item.Settled);
      Fill_Rect
        (Item.Target, Toolbar,
         Yoga.Nodes.Left (Item.Toolbar_Node),
         Yoga.Nodes.Top (Item.Toolbar_Node),
         Yoga.Nodes.Width (Item.Toolbar_Node),
         Yoga.Nodes.Height (Item.Toolbar_Node));
      Item.Dirty := False;
   end Paint;

   procedure Tell_Input_Method (Item : in out Session);
   --  Where the caret is, so that an input method can show its choices
   --  beside it.

   procedure Tell_Input_Method (Item : in out Session) is
      X, Y, Width, Height : Float;
   begin
      if Text_Areas.Is_Focused (Item.Area) then
         Text_Areas.Caret_Box (Item.Area, X, Y, Width, Height);
         declare
            Across : constant Integer := Integer (X / Item.Density);
         begin
            --  Once a line, not once a character: the input method's
            --  choices would jump about as it is typed into.
            if Across /= Item.Input_Area then
               Item.Input_Area := Across;
               SDL3.Windows.Set_Text_Input_Area
                 (Item.Win, Across, Integer (Y / Item.Density),
                  Integer (Float'Ceiling (Width / Item.Density)),
                  Integer (Float'Ceiling (Height / Item.Density)));
            end if;
         end;
      end if;
   end Tell_Input_Method;

   procedure Draw (Item : in out Session) is
   begin
      Paint (Item);
      Present (Item.Target);
      Tell_Input_Method (Item);
   end Draw;

   package Redraws is new SDL3.Events.Redraws (Session, Draw);

   --  Zooming

   procedure Zoom_By (Item : in out Session; Factor : Float) is
      Zoom : constant Float :=
        Float'Min (Max_Zoom, Float'Max (Min_Zoom, Item.Zoom * Factor));
   begin
      if Zoom /= Item.Zoom then
         Item.Zoom := Zoom;
         Item.Settled := False;
         Item.Dirty := True;
         --  Before the next event, which may be over the text.
         Lay_Out_Window (Item);
      end if;
   end Zoom_By;

   --  Events

   procedure Handle_Zoom
     (Item : in out Session; Event : SDL3.Events.Event; Handled : out Boolean);
   --  Command with the wheel, =, - or 0.

   procedure Handle_Zoom
     (Item : in out Session; Event : SDL3.Events.Event; Handled : out Boolean)
   is
   begin
      Handled := True;
      Item.Zoomed_At := Event.Time;
      if Event.Kind = SDL3.Events.Mouse_Wheel and then Event.Command then
         Zoom_By
           (Item,
            Ada.Numerics.Elementary_Functions."**"
              (Zoom_Per_Notch, Event.Wheel_Y));
      elsif Event.Kind /= SDL3.Events.Key_Down or else not Event.Command then
         Handled := False;
      elsif Event.Key = SDL3.Events.Key_Equals then
         Zoom_By (Item, Zoom_Per_Notch);
      elsif Event.Key = SDL3.Events.Key_Minus then
         Zoom_By (Item, 1.0 / Zoom_Per_Notch);
      elsif Event.Key = SDL3.Events.Key_0 then
         Zoom_By (Item, 1.0 / Item.Zoom);
      else
         Handled := False;
      end if;
   end Handle_Zoom;

   procedure Handle (Item : in out Session; Event : SDL3.Events.Event) is
      Handled : Boolean;
   begin
      case Event.Kind is
         when SDL3.Events.Quit =>
            Item.Done := True;
         when SDL3.Events.Redraw =>
            Item.Dirty := True;
         when others =>
            Handle_Zoom (Item, Event, Handled);
            if not Handled and then Event.Kind = SDL3.Events.Key_Down
              and then Event.Command and then Event.Key = SDL3.Events.Key_S
            then
               Save (Item);
               Handled := True;
            end if;
            if Handled then
               null;
            elsif Item.Windowed then
               Text_Areas.Handle
                 (Item.Area, Event, Item.System_Board, Handled);
            else
               Text_Areas.Handle (Item.Area, Event, Item.Own_Board, Handled);
            end if;
            --  A click elsewhere takes the focus away.
            if not Handled and then Event.Kind = SDL3.Events.Mouse_Down
              and then Text_Areas.Is_Focused (Item.Area)
            then
               Text_Areas.Set_Focus (Item.Area, False);
               Handled := True;
            end if;
            if Handled then
               Item.Dirty := True;
            end if;
      end case;
   end Handle;

   --  The file

   function Title (Item : Session) return String is
     (Scripts.Title (Item.Script));

   procedure Save (Item : in out Session) is
   begin
      if Scripts.File_Name (Item.Script) /= "" then
         Scripts.Save (Item.Script);
      end if;
   exception
      when Problem : others =>
         --  Keep the text, to save another time.
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "Could not save " & Scripts.File_Name (Item.Script) & ": "
            & Ada.Exceptions.Exception_Message (Problem));
   end Save;

   procedure Show_Title (Item : in out Session);
   --  In the window's title bar, if it has changed.

   procedure Show_Title (Item : in out Session) is
      Now : constant String := Title (Item);
   begin
      if Now /= To_String (Item.Shown_Title) then
         SDL3.Windows.Set_Title (Item.Win, Now);
         Item.Shown_Title := To_Unbounded_String (Now);
      end if;
   end Show_Title;

   --  Running

   procedure Set_Up
     (Item : in out Session; Source : String; File_Name : String);
   --  Lay out the window and the script in it, once there is a target.

   procedure Set_Up
     (Item : in out Session; Source : String; File_Name : String)
   is
      use Yoga.Nodes;
      Window_Node : constant Node := Root (Item.Layout);
   begin
      Scripts.Load (Item.Script, Source, File_Name);
      Text_Areas.Configure
        (Item.Area, Family, Font_Size, Page_Width, Para_Gap);
      Text_Areas.Attach (Item.Area, Scripts.Document (Item.Script));
      Text_Areas.Set_Focus (Item.Area, True);

      Item.Content_Node := New_Child (Window_Node);
      Item.Area_Node := New_Child (Item.Content_Node);
      Item.Toolbar_Node := New_Child (Window_Node);
      Set_Flex_Direction (Window_Node, Yoga.Column);
      Set_Flex_Grow (Item.Content_Node, 1.0);
      Set_Flex_Direction (Item.Content_Node, Yoga.Column);
      Set_Padding (Item.Content_Node, Yoga.All_Edges, Margin * Item.Density);
      Set_Flex_Grow (Item.Area_Node, 1.0);
      Set_Height (Item.Toolbar_Node, Toolbar_Size * Item.Density);
      --  Before any event: the text area must know where it is.
      Lay_Out_Window (Item);
   end Set_Up;

   procedure Open
     (Item : in out Session; Source : String; File_Name : String) is
   begin
      Item.Windowed := True;
      SDL3.Windows.Create
        (Item.Win, "bonxie", Window_Width, Window_Height,
         Resizable => True, High_Density => True);
      Item.Density := SDL3.Windows.Pixel_Density (Item.Win);
      Create (Item.Target, Item.Win);
      Set_Up (Item, Source, File_Name);
      SDL3.Windows.Start_Text_Input (Item.Win);
   end Open;

   procedure Wait_And_Handle (Item : in out Session) is
      Event   : SDL3.Events.Event;
      Timeout : Integer := -1;  --  none

      procedure Wake_In (Milliseconds : Integer) is
      begin
         Timeout :=
           (if Timeout < 0 then Integer'Max (0, Milliseconds)
            else Integer'Min (Timeout, Integer'Max (0, Milliseconds)));
      end Wake_In;
   begin
      --  Nothing to do until something happens, except to settle the
      --  zoom once it has held still, and to blink the caret.
      Tick (Item, SDL3.Events.Ticks);
      if not Item.Settled then
         Wake_In
           (Settle_MS - Integer (SDL3.Events.Ticks - Item.Zoomed_At));
      end if;
      if Text_Areas.Is_Focused (Item.Area) then
         Wake_In (Integer (Text_Areas.Until_Blink (Item.Area)));
      end if;

      if SDL3.Events.Wait (Event, Timeout_MS => Timeout) then
         Handle (Item, Event);
         while SDL3.Events.Poll (Event) loop
            Handle (Item, Event);
         end loop;
      end if;

      if not Item.Settled
        and then SDL3.Events.Ticks - Item.Zoomed_At >= Settle_MS
      then
         Settle (Item);
      end if;
      Tick (Item, SDL3.Events.Ticks);
   end Wait_And_Handle;

   --  Without a window

   function Pixels (Points : Positive; Density : Float) return Positive is
     (Positive (Float (Points) * Density));

   procedure Open
     (Item      : in out Session;
      Source    : String;
      Width     : Positive;
      Height    : Positive;
      Density   : Float := 2.0;
      File_Name : String := "") is
   begin
      Item.Density := Density;
      Create_Offscreen
        (Item.Target, Pixels (Width, Density), Pixels (Height, Density));
      Set_Up (Item, Source, File_Name);
   end Open;

   function Is_Open (Item : Session) return Boolean is
     (Text_Areas.Is_Attached (Item.Area));

   function Text (Item : Session) return String is
     (Scripts.Text (Item.Script));

   procedure Tick (Item : in out Session; Now : SDL3.Events.Milliseconds) is
      Changed : Boolean;
   begin
      Text_Areas.Tick (Item.Area, Now, Changed);
      if Changed then
         Item.Dirty := True;
      end if;
   end Tick;

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

   procedure Run (Source : String; File_Name : String := "") is
      Item    : aliased Session;
      Watcher : Redraws.Watch;  --  ends before Item does
   begin
      Open (Item, Source, File_Name);

      --  The redraw watch also draws: the OS blocks the event loop
      --  during a live resize, and only repainting from inside the event
      --  watch avoids a stretched frame.
      Redraws.Install (Watcher, Item);

      while not Item.Done loop
         Show_Title (Item);
         if Item.Dirty then
            Draw (Item);
         end if;
         Wait_And_Handle (Item);
      end loop;
   end Run;

end Viewer;
