with Adaptive_Themes;
with Pomarine.Boxes;
with Pomarine.Widgets;

package body Section_Colour_Pickers is
   use Pomarine.Widgets;
   use all type SDL3.Painters.Painter;
   use type Pomarine.Events.Event_Kind;
   use type Pomarine.Themes.Color;

   function Clamp (Value : Float) return Unit is
     (Float'Max (0.0, Float'Min (1.0, Value)));

   function RGB (Hue, Brightness, Purity : Unit) return Pomarine.Themes.Color is
      Chroma : constant Float := Brightness * Purity;
   begin
      return Adaptive_Themes.From_Chroma (Hue, Chroma, Brightness - Chroma);
   end RGB;

   function Colour (Item : Picker) return Projects.Sections.Colour_Value is
     (Projects.Sections.Palette_Size + Natural (Item.Selected.Red) * 65536
      + Natural (Item.Selected.Green) * 256 + Natural (Item.Selected.Blue));

   function Changed (Item : Picker) return Boolean is (Item.Selected /= Item.Original);

   procedure Set_Colour (Item : in out Picker; To : Pomarine.Themes.Color) is
      R : constant Float := Float (To.Red) / 255.0;
      G : constant Float := Float (To.Green) / 255.0;
      B : constant Float := Float (To.Blue) / 255.0;
      Most : constant Float := Float'Max (R, Float'Max (G, B));
      Least : constant Float := Float'Min (R, Float'Min (G, B));
      Delta_C : constant Float := Most - Least;
      H : Float := 0.0;
   begin
      Item.Selected := To;
      Item.Original := To;
      Item.Brightness := Most;
      Item.Purity := (if Most = 0.0 then 0.0 else Delta_C / Most);
      if Delta_C > 0.0 then
         if Most = R then
            H := (G - B) / Delta_C;
         elsif Most = G then
            H := 2.0 + (B - R) / Delta_C;
         else
            H := 4.0 + (R - G) / Delta_C;
         end if;
      end if;
      Item.Hue := (H - 6.0 * Float'Floor (H / 6.0)) / 6.0;
      Item.Held := None;
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Set_Colour;

   overriding procedure Handle
     (Item : in out Picker; Event : Pomarine.Events.Event; Handled : out Boolean)
   is
      Pixels : constant Float := Density (Item);
      Wide : constant Float := Width_Of (Item) - 32.0 * Pixels;
      High : constant Float := Height_Of (Item);
      X, Y : Float;
   begin
      Pomarine.Widgets.Grips.Handle (Pomarine.Widgets.Grips.Grip (Item), Event, Handled);
      if Wide <= 2.0 or else High <= 2.0 then
         return;
      end if;
      if Event.Kind = Pomarine.Events.Mouse_Down and then Event.Button = 1 then
         X := Event.Mouse_X * Pixels - Left_Of (Item);
         Item.Held := (if X <= Wide then Plane
                       elsif X >= Wide + 12.0 * Pixels then Saturation else None);
      end if;
      if Item.Held /= None
        and then (Event.Kind = Pomarine.Events.Mouse_Down or else Event.Kind = Pomarine.Events.Mouse_Move
                  or else Event.Kind = Pomarine.Events.Mouse_Up)
      then
         X := Event.Mouse_X * Pixels - Left_Of (Item);
         Y := Event.Mouse_Y * Pixels - Top_Of (Item);
         if Item.Held = Plane then
            Item.Hue := Clamp ((X - Pixels) / (Wide - 2.0 * Pixels));
            Item.Brightness := 1.0 - Clamp ((Y - Pixels) / (High - 2.0 * Pixels));
         else
            Item.Purity := 1.0 - Clamp ((Y - Pixels) / (High - 2.0 * Pixels));
         end if;
         Item.Selected := RGB (Item.Hue, Item.Brightness, Item.Purity);
         Invalidate (Item);
      end if;
      if Event.Kind = Pomarine.Events.Mouse_Up then
         Item.Held := None;
      end if;
   end Handle;

   overriding procedure Draw
     (Item : in out Picker; Target : SDL3.Painters.Painter'Class; Colors : Pomarine.Themes.Theme)
   is
      Pixels : constant Float := Density (Item);
      Wide : constant Float := Width_Of (Item) - 32.0 * Pixels;
      High : constant Float := Height_Of (Item);
      Left : constant Float := Left_Of (Item);
      Top : constant Float := Top_Of (Item);
      Step : constant Float := Float'Max (1.0, Pixels);
      X, Y : Float;
      Mark_X, Mark_Y : Float;
   begin
      if Wide <= 2.0 * Pixels or else High <= 2.0 * Pixels then
         return;
      end if;
      Y := Pixels;
      while Y < High - Pixels loop
         X := Pixels;
         while X < Wide - Pixels loop
            Fill_Rect (Target, RGB (Clamp ((X - Pixels) / (Wide - 2.0 * Pixels)),
                       1.0 - Clamp ((Y - Pixels) / (High - 2.0 * Pixels)), Item.Purity),
                       Left + X, Top + Y, Step, Step);
            X := X + Step;
         end loop;
         Fill_Rect (Target, RGB (Item.Hue, Item.Brightness,
                    1.0 - Clamp ((Y - Pixels) / (High - 2.0 * Pixels))),
                    Left + Wide + 13.0 * Pixels, Top + Y, 18.0 * Pixels, Step);
         Y := Y + Step;
      end loop;
      Pomarine.Boxes.Outline (Target, Colors (Pomarine.Themes.Border), Left, Top, Wide, High, Pixels);
      Pomarine.Boxes.Outline (Target, Colors (Pomarine.Themes.Border), Left + Wide + 12.0 * Pixels,
                             Top, 20.0 * Pixels, High, Pixels);
      Mark_X := Left + Pixels + Item.Hue * (Wide - 2.0 * Pixels);
      Mark_Y := Top + Pixels + (1.0 - Item.Brightness) * (High - 2.0 * Pixels);
      Pomarine.Boxes.Outline (Target, Pomarine.Themes.White,
                             Mark_X - 4.0 * Pixels, Mark_Y - 4.0 * Pixels,
                             8.0 * Pixels, 8.0 * Pixels, Pixels, Radius => 4.0 * Pixels);
      Mark_Y := Top + Pixels + (1.0 - Item.Purity) * (High - 2.0 * Pixels);
      Fill_Rect (Target, Colors (Pomarine.Themes.Foreground), Left + Wide + 9.0 * Pixels,
                 Mark_Y - Pixels, 26.0 * Pixels, 2.0 * Pixels);
   end Draw;
end Section_Colour_Pickers;
