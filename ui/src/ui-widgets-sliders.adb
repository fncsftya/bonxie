with UI.Boxes;

package body UI.Widgets.Sliders is

   use type SDL3.Events.Event_Kind;
   use SDL3.Windows.Renderers;

   Knob_Points  : constant Float := 9.0;
   Track_Points : constant Float := 4.0;
   --  The knob's width, and the track's thickness, in points.

   function Knob_Width (Item : Slider) return Float is
     (Float'Min
        (Width_Of (Item), Float'Rounding (Knob_Points * Density (Item))));

   function Travel (Item : Slider) return Float is
     (Width_Of (Item) - Knob_Width (Item));
   --  How far the knob's left edge goes, in pixels.

   function Fraction_At (Item : Slider; X : Float) return Float is
     (if Travel (Item) <= 0.0 then 0.0
      else Float'Min
        (1.0,
         Float'Max
           (0.0,
            (X * Density (Item) - Left_Of (Item) - Knob_Width (Item) / 2.0)
            / Travel (Item))));
   --  Of the pointer at X, in points.

   function Value (Item : Slider) return Float is (Item.Fraction);

   procedure Set_Value (Item : in out Slider; To : Float) is
   begin
      if not Item.Held and then To /= Item.Fraction then
         Item.Fraction := To;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Value;

   procedure Take_Change (Item : in out Slider; Changed : out Boolean) is
   begin
      Changed := Item.Moved;
      Item.Moved := False;
   end Take_Change;

   function Is_Dragging (Item : Slider) return Boolean is (Item.Held);

   procedure Move_To (Item : in out Slider; X : Float);
   --  Put the knob under the pointer at X, in points.

   procedure Move_To (Item : in out Slider; X : Float) is
      To : constant Float := Fraction_At (Item, X);
   begin
      if To /= Item.Fraction then
         Item.Fraction := To;
         Item.Moved := True;
         Invalidate (Item);
      end if;
   end Move_To;

   overriding procedure Handle
     (Item    : in out Slider;
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
               Move_To (Item, Event.Mouse_X);
               Handled := True;
            end if;
         when SDL3.Events.Mouse_Move =>
            if Item.Held then
               Move_To (Item, Event.Mouse_X);
               Handled := True;
            end if;
         when SDL3.Events.Mouse_Up =>
            if Item.Held and then Event.Button = 1 then
               Item.Held := False;
               Invalidate (Item);
               Handled := True;
            end if;
         when others =>
            null;
      end case;
   end Handle;

   overriding procedure Hover_Changed
     (Item : in out Slider; Hovered : Boolean)
   is
      pragma Unreferenced (Hovered);
   begin
      Invalidate (Item);
   end Hover_Changed;

   overriding function Cursor (Item : Slider) return SDL3.Cursors.Kind is
     (SDL3.Cursors.Pointer);

   overriding procedure Draw
     (Item   : in out Slider;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme)
   is
      Pixels : constant Float := Density (Item);
      Left   : constant Float := Left_Of (Item);
      High   : constant Float := Height_Of (Item);
      Thick  : constant Float :=
        Float'Max (2.0, Float'Rounding (Track_Points * Pixels));
      Wide   : constant Float := Knob_Width (Item);
      Knob   : constant Float :=
        Float'Rounding (Left + Item.Fraction * Travel (Item));
      Groove : constant Themes.Color :=
        Themes.Mix (Colors.Background, Colors.Foreground, 0.12);
      Groove_Top : constant Float :=
        Top_Of (Item) + Float'Rounding ((High - Thick) / 2.0);
   begin
      --  The groove, the light falling into it from the top left.
      Fill_Rect (Target, Groove, Left, Groove_Top, Width_Of (Item), Thick);
      UI.Boxes.Bevel
        (Target, Groove, Left, Groove_Top, Width_Of (Item), Thick, Pixels,
         Sunken => True);
      UI.Boxes.Draw_Raised
        (Target,
         (Face    =>
            (if Is_Hovered (Item) and then not Item.Held
             then Themes.Mix (Colors.Face, Themes.White, 0.22)
             else Colors.Face),
          Border  => Colors.Border,
          Drop    => Themes.Drop (Colors),
          Pressed => Item.Held,
          Flat    => False),
         Knob, Top_Of (Item), Wide, High, Pixels);
   end Draw;

end UI.Widgets.Sliders;
