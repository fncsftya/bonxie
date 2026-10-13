package body UI.Widgets.Pins is

   use type SDL3.Events.Event_Kind;
   use SDL3.Windows.Renderers;

   Edge        : constant Float := 1.0;
   Target_Edge : constant Float := 2.5;
   --  The width of its border, in points, and when a line may end on it
   --  and the pointer is over it.

   procedure Set_Accepting (Item : in out Pin; To : Boolean) is
   begin
      if To /= Item.Accepting then
         Item.Accepting := To;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Accepting;

   function Is_Accepting (Item : Pin) return Boolean is (Item.Accepting);

   procedure Take_Press (Item : in out Pin; Pressed : out Boolean) is
   begin
      Pressed := Item.Pressed;
      Item.Pressed := False;
   end Take_Press;

   procedure Take_Release (Item : in out Pin; Released : out Boolean) is
   begin
      Released := Item.Released;
      Item.Released := False;
   end Take_Release;

   function Is_Held (Item : Pin) return Boolean is (Item.Held);

   procedure Cancel (Item : in out Pin) is
   begin
      Item.Held := False;
      Item.Pressed := False;
      Item.Released := False;
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Cancel;

   function Pointer_X (Item : Pin) return Float is (Item.Pointer_At_X);

   function Pointer_Y (Item : Pin) return Float is (Item.Pointer_At_Y);

   overriding procedure Hover_Changed (Item : in out Pin; Hovered : Boolean)
   is
      pragma Unreferenced (Hovered);
   begin
      Invalidate (Item);
   end Hover_Changed;

   overriding procedure Handle
     (Item    : in out Pin;
      Event   : SDL3.Events.Event;
      Handled : out Boolean) is
   begin
      Handled := False;
      case Event.Kind is
         when SDL3.Events.Mouse_Down =>
            if Event.Button = 1
              and then Contains
                         (Item, Event.Mouse_X * Density (Item),
                          Event.Mouse_Y * Density (Item))
            then
               Item.Held := True;
               Item.Pressed := True;
               Item.Pointer_At_X := Event.Mouse_X;
               Item.Pointer_At_Y := Event.Mouse_Y;
               Handled := True;
               Invalidate (Item);
            end if;
         when SDL3.Events.Mouse_Move =>
            if Item.Held then
               Item.Pointer_At_X := Event.Mouse_X;
               Item.Pointer_At_Y := Event.Mouse_Y;
               Handled := True;
            end if;
         when SDL3.Events.Mouse_Up =>
            if Item.Held and then Event.Button = 1 then
               Item.Held := False;
               Item.Released := True;
               Item.Pointer_At_X := Event.Mouse_X;
               Item.Pointer_At_Y := Event.Mouse_Y;
               Handled := True;
               Invalidate (Item);
            end if;
         when others =>
            null;
      end case;
   end Handle;

   overriding procedure Draw
     (Item   : in out Pin;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme)
   is
      Pixels : constant Float := Density (Item);
      Radius : constant Float :=
        Float'Min (Width_Of (Item), Height_Of (Item)) / 2.0;
      Aimed  : constant Boolean :=
        Item.Accepting and then Is_Hovered (Item);
      Border : constant Float :=
        Float'Max (1.0, Float'Rounding
                          ((if Aimed then Target_Edge else Edge) * Pixels));
      Ring   : constant Themes.Color :=
        (if Aimed or else Item.Held or else Is_Hovered (Item)
         then Colors.Accent else Colors.Bar);
      Face   : constant Themes.Color :=
        (if Item.Held then Colors.Accent else (255, 255, 255, 255));
   begin
      --  Square, as every box is.
      Fill_Rect (Target, Ring, Left_Of (Item), Top_Of (Item),
                 2.0 * Radius, 2.0 * Radius);
      Fill_Rect (Target, Face, Left_Of (Item) + Border, Top_Of (Item) + Border,
                 2.0 * (Radius - Border), 2.0 * (Radius - Border));
   end Draw;

   overriding function Cursor (Item : Pin) return SDL3.Cursors.Kind is
     (if Item.Held then SDL3.Cursors.Crosshair else SDL3.Cursors.Pointer);

end UI.Widgets.Pins;
