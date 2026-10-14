package body UI.Widgets.Grips is

   use type Themes.Slot;

   use type SDL3.Events.Event_Kind;
   use SDL3.Windows.Renderers;

   Dot_Size : constant Float := 2.0;
   --  A dot's side, in points, and the space between dots.

   procedure Set_Shape (Item : in out Grip; To : Shape) is
   begin
      if To /= Item.Form then
         Item.Form := To;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Shape;

   procedure Refresh (Item : in out Grip);
   --  Draw Item again, if it is on the screen.

   procedure Refresh (Item : in out Grip) is
   begin
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Refresh;

   procedure Set_Fill (Item : in out Grip; Value : Themes.Slot) is
   begin
      if not Item.Look.Filled or else Item.Fill_Slot /= Value then
         Item.Look.Filled := True;
         Item.Fill_Slot := Value;
         Refresh (Item);
      end if;
   end Set_Fill;

   procedure Clear_Fill (Item : in out Grip) is
   begin
      if Item.Look.Filled then
         Item.Look.Filled := False;
         Refresh (Item);
      end if;
   end Clear_Fill;

   procedure Set_Border
     (Item : in out Grip; Value : Themes.Slot; Dashed : Boolean := False)
   is
   begin
      if not Item.Look.Bordered or else Item.Border_Slot /= Value
        or else Item.Look.Dashed /= Dashed
      then
         Item.Look.Bordered := True;
         Item.Look.Dashed := Dashed;
         Item.Border_Slot := Value;
         Refresh (Item);
      end if;
   end Set_Border;

   procedure Clear_Border (Item : in out Grip) is
   begin
      if Item.Look.Bordered then
         Item.Look.Bordered := False;
         Refresh (Item);
      end if;
   end Clear_Border;

   procedure Set_Shadow (Item : in out Grip; Value : Themes.Slot) is
   begin
      if not Item.Look.Shadowed or else Item.Shadow_Slot /= Value then
         Item.Look.Shadowed := True;
         Item.Shadow_Slot := Value;
         Refresh (Item);
      end if;
   end Set_Shadow;

   procedure Clear_Shadow (Item : in out Grip) is
   begin
      if Item.Look.Shadowed then
         Item.Look.Shadowed := False;
         Refresh (Item);
      end if;
   end Clear_Shadow;

   procedure Set_Hover_Outline (Item : in out Grip; Value : Themes.Slot) is
   begin
      Item.Outlined := True;
      Item.Outline_Color := Value;
      Refresh (Item);
   end Set_Hover_Outline;

   procedure Set_Hover_Fill (Item : in out Grip; Value : Themes.Slot) is
   begin
      if not Item.Hover_Filled or else Item.Hover_Fill /= Value then
         Item.Hover_Filled := True;
         Item.Hover_Fill := Value;
         if Is_Attached (Item) and then Is_Hovered (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Hover_Fill;

   procedure Clear_Hover_Fill (Item : in out Grip) is
   begin
      if Item.Hover_Filled then
         Item.Hover_Filled := False;
         if Is_Attached (Item) and then Is_Hovered (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Clear_Hover_Fill;

   procedure Take_Click (Item : in out Grip; Clicked : out Boolean) is
   begin
      Clicked := Item.Clicked;
      Item.Clicked := False;
   end Take_Click;

   procedure Take_Double_Click (Item : in out Grip; Doubled : out Boolean) is
   begin
      Doubled := Item.Doubled;
      Item.Doubled := False;
   end Take_Double_Click;

   overriding procedure Hover_Changed
     (Item : in out Grip; Hovered : Boolean)
   is
      pragma Unreferenced (Hovered);
   begin
      if Item.Outlined or else Item.Hover_Filled then
         Invalidate (Item);
      end if;
   end Hover_Changed;

   procedure Set_Wanted_Cursor (Item : in out Grip; To : SDL3.Cursors.Kind) is
   begin
      Item.Wanted := To;
   end Set_Wanted_Cursor;

   procedure Take_Drag (Item : in out Grip; Across, Down : out Float) is
   begin
      Across := Item.Across;
      Down := Item.Down;
      Item.Across := 0.0;
      Item.Down := 0.0;
   end Take_Drag;

   function Is_Dragging (Item : Grip) return Boolean is (Item.Held);

   procedure Pointer (Item : Grip; X, Y : out Float) is
   begin
      X := Item.Last_X;
      Y := Item.Last_Y;
   end Pointer;

   procedure Cancel_Drag (Item : in out Grip) is
   begin
      Item.Held := False;
      Item.Across := 0.0;
      Item.Down := 0.0;
   end Cancel_Drag;

   overriding procedure Handle
     (Item    : in out Grip;
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
               Item.Doubled := Item.Doubled or else Event.Clicks >= 2;
               Item.Last_X := Event.Mouse_X;
               Item.Last_Y := Event.Mouse_Y;
               Handled := True;
            end if;
         when SDL3.Events.Mouse_Move =>
            if Item.Held then
               Item.Across := Item.Across + Event.Mouse_X - Item.Last_X;
               Item.Down := Item.Down + Event.Mouse_Y - Item.Last_Y;
               Item.Last_X := Event.Mouse_X;
               Item.Last_Y := Event.Mouse_Y;
               Handled := True;
            end if;
         when SDL3.Events.Mouse_Up =>
            if Item.Held and then Event.Button = 1 then
               Item.Held := False;
               Item.Clicked :=
                 Contains
                   (Item, Event.Mouse_X * Density (Item),
                    Event.Mouse_Y * Density (Item));
               Handled := True;
            end if;
         when others =>
            null;
      end case;
   end Handle;

   overriding procedure Draw
     (Item   : in out Grip;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme)
   is
      Side : constant Float := Float'Rounding (Dot_Size * Density (Item));
      Ink  : constant Themes.Color :=
        Themes.Mix (Colors.Background, Colors.Foreground, 0.55);
      Edge : constant Float := Left_Of (Item) + Width_Of (Item) - 2.0 * Side;
      Base : constant Float := Top_Of (Item) + Height_Of (Item) - 2.0 * Side;
      Look : UI.Boxes.Look := Item.Look;
   begin
      Look.Fill := Themes.Resolve (Colors, Item.Fill_Slot);
      Look.Border := Themes.Resolve (Colors, Item.Border_Slot);
      Look.Shadow := Themes.Resolve (Colors, Item.Shadow_Slot);
      if Item.Hover_Filled and then Is_Hovered (Item) then
         Look.Fill := Themes.Resolve (Colors, Item.Hover_Fill);
      end if;
      UI.Boxes.Draw
        (Target, Look, Left_Of (Item), Top_Of (Item), Width_Of (Item),
         Height_Of (Item), Density (Item));
      if Item.Outlined and then Is_Hovered (Item) then
         declare
            Off : constant Float :=
              UI.Boxes.Inset (Item.Look, Density (Item));
         begin
            UI.Boxes.Outline
              (Target, Themes.Resolve (Colors, Item.Outline_Color),
               Left_Of (Item), Top_Of (Item),
               Width_Of (Item) - Off, Height_Of (Item) - Off,
               UI.Boxes.Edge (Density (Item)));
         end;
      end if;
      if Item.Form = Corner then
         --  Dots a step apart, three along the bottom, two above, one
         --  at the top.
         for Row in 0 .. 2 loop
            for Column in 0 .. 2 - Row loop
               Fill_Rect
                 (Target, Ink,
                  Edge - Float (Column) * 2.0 * Side,
                  Base - Float (Row) * 2.0 * Side, Side, Side);
            end loop;
         end loop;
      end if;
   end Draw;

   overriding function Cursor (Item : Grip) return SDL3.Cursors.Kind is
     (Item.Wanted);

end UI.Widgets.Grips;
