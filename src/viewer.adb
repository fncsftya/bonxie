with Ada.Exceptions;
with Ada.Numerics.Elementary_Functions;
with Ada.Text_IO;
with SDL3.Events.Redraws;
with SDL3.Windows.Renderers;
with UI.Themes;
with UI.Widgets;
with Yoga.Nodes;

package body Viewer is

   package Widgets renames UI.Widgets;
   package Editors renames UI.Widgets.Editors;
   package Panels renames UI.Widgets.Panels;

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

   procedure Paint (Item : in out Session);
   --  Draw what is shown, but do not present it.

   procedure Paint (Item : in out Session) is
   begin
      --  The target keeps what is drawn on it, offscreen and in a window,
      --  so that only what has changed need be drawn again.
      Widgets.Paint
        (Item.Widgets, Item.Target, Colors,
         Retained => Keeps_Frame (Item.Target));
   end Paint;

   procedure Tell_Input_Method (Item : in out Session);
   --  Where the caret is, so that an input method can show its choices
   --  beside it.

   procedure Tell_Input_Method (Item : in out Session) is
      X, Y, Width, Height : Float;
   begin
      if Editors.Is_Focused (Item.Area) then
         Editors.Caret_Box (Item.Area, X, Y, Width, Height);
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
      Resized : Boolean;
   begin
      --  A window that has changed size has a new image to draw to.
      Fit (Item.Target, Resized);
      if Resized then
         Widgets.Invalidate_All (Item.Widgets);
      end if;
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
         Widgets.Set_Settled (Item.Widgets, False);
         Editors.Set_Zoom (Item.Area, Zoom);
         --  Before the next event, which may be over the text.
         Widgets.Layout (Item.Widgets, Item.Target);
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
            Widgets.Invalidate_All (Item.Widgets);
         when others =>
            Handle_Zoom (Item, Event, Handled);
            if not Handled and then Event.Kind = SDL3.Events.Key_Down
              and then Event.Command and then Event.Key = SDL3.Events.Key_S
            then
               Save (Item);
               Handled := True;
            end if;
            if not Handled then
               Widgets.Dispatch (Item.Widgets, Event, Handled);
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
   begin
      Scripts.Load (Item.Script, Source, File_Name);
      Widgets.Set_Density (Item.Widgets, Item.Density);
      if Item.Windowed then
         Widgets.Set_Clipboard (Item.Widgets, Item.System_Board);
      else
         Widgets.Set_Clipboard (Item.Widgets, Item.Own_Board);
      end if;

      Widgets.Set_Root (Item.Widgets, Item.Window_Panel);
      Widgets.Add (Item.Window_Panel, Item.Content_Panel);
      Widgets.Add (Item.Content_Panel, Item.Area);
      Widgets.Add (Item.Window_Panel, Item.Toolbar_Panel);
      Panels.Set_Fill (Item.Toolbar_Panel, Toolbar);

      Editors.Configure (Item.Area, Family, Font_Size, Page_Width, Para_Gap);
      Editors.Attach (Item.Area, Scripts.Document (Item.Script));
      Widgets.Focus (Item.Area);

      Set_Flex_Direction (Widgets.Node (Item.Window_Panel), Yoga.Column);
      Set_Flex_Grow (Widgets.Node (Item.Content_Panel), 1.0);
      Set_Flex_Direction (Widgets.Node (Item.Content_Panel), Yoga.Column);
      Set_Padding
        (Widgets.Node (Item.Content_Panel), Yoga.All_Edges,
         Margin * Item.Density);
      Set_Flex_Grow (Widgets.Node (Item.Area), 1.0);
      Set_Height
        (Widgets.Node (Item.Toolbar_Panel), Toolbar_Size * Item.Density);
      --  Before any event: the text area must know where it is.
      Widgets.Layout (Item.Widgets, Item.Target);
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
      if Widgets.Until_Update (Item.Widgets) >= 0 then
         Wake_In (Widgets.Until_Update (Item.Widgets));
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
     (Editors.Has_Document (Item.Area));

   function Text (Item : Session) return String is
     (Scripts.Text (Item.Script));

   procedure Tick (Item : in out Session; Now : SDL3.Events.Milliseconds) is
   begin
      Widgets.Update (Item.Widgets, Now);
   end Tick;

   procedure Settle (Item : in out Session) is
   begin
      if not Item.Settled then
         Item.Settled := True;
         Widgets.Set_Settled (Item.Widgets, True);
      end if;
   end Settle;

   procedure Resize (Item : in out Session; Width, Height : Positive) is
   begin
      SDL3.Windows.Renderers.Resize
        (Item.Target,
         Pixels (Width, Item.Density), Pixels (Height, Item.Density));
      --  Which loses what was drawn.
      Widgets.Invalidate_All (Item.Widgets);
      Widgets.Layout (Item.Widgets, Item.Target);
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
         if Widgets.Needs_Paint (Item.Widgets) then
            Draw (Item);
         end if;
         Wait_And_Handle (Item);
      end loop;
   end Run;

end Viewer;
