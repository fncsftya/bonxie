with Pomarine.Boxes;

package body Previews is

   use SDL3.Windows.Renderers;
   use type Items.Kinds;

   --  In points

   Dot_Step  : constant Float := 15.0;
   Dot_Side  : constant Float := 1.5;
   Margin    : constant Float := 18.0;
   --  Round the cards, within the box.
   Most      : constant Float := 0.45;
   --  The largest the cards are drawn, of their size on the canvas.
   Line_High : constant Float := 2.0;
   Card_Pad  : constant Float := 8.0;

   procedure Set_Cards (Item : in out Preview; To : Card_Array) is
   begin
      Item.Count := To'Length;
      Item.Cards (1 .. To'Length) := To;
      if Pomarine.Widgets.Is_Attached (Item) then
         Pomarine.Widgets.Invalidate (Item);
      end if;
   end Set_Cards;

   procedure Clear (Item : in out Preview) is
   begin
      Set_Cards (Item, [1 .. 0 => <>]);
   end Clear;

   overriding procedure Draw
     (Item   : in out Preview;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Pomarine.Themes.Theme)
   is
      Pixels : constant Float := Pomarine.Widgets.Density (Item);
      Left   : constant Float := Pomarine.Widgets.Left_Of (Item);
      Top    : constant Float := Pomarine.Widgets.Top_Of (Item);
      Wide   : constant Float := Pomarine.Widgets.Width_Of (Item);
      High   : constant Float := Pomarine.Widgets.Height_Of (Item);
      Side   : constant Float :=
        Float'Max (1.0, Float'Rounding (Dot_Side * Pixels));
      Step   : constant Float := Dot_Step * Pixels;
      Ink    : constant Pomarine.Themes.Color :=
        Pomarine.Themes.Mix (Colors.Background, Colors.Border, 0.8);
      Rule   : constant Pomarine.Themes.Color :=
        Pomarine.Themes.Mix (Colors.Bar, Pomarine.Themes.White, 0.25);
      Text   : constant Pomarine.Themes.Color :=
        Pomarine.Themes.Mix (Colors.Face, Pomarine.Themes.White, 0.35);
      X, Y   : Float;
   begin
      Fill_Rect (Target, Colors.Background, Left, Top, Wide, High);
      Y := Step / 2.0;
      while Y < High loop
         X := Step / 2.0;
         while X < Wide loop
            Fill_Rect (Target, Ink, Float'Rounding (Left + X),
                       Float'Rounding (Top + Y), Side, Side);
            X := X + Step;
         end loop;
         Y := Y + Step;
      end loop;
      if Item.Count = 0 then
         return;
      end if;

      --  All of the cards, as large as fits, in the middle.
      declare
         Least_X, Least_Y : Float := Float'Last;
         Most_X, Most_Y   : Float := Float'First;
      begin
         for Each of Item.Cards (1 .. Item.Count) loop
            Least_X := Float'Min (Least_X, Each.Where.Left);
            Least_Y := Float'Min (Least_Y, Each.Where.Top);
            Most_X := Float'Max (Most_X, Each.Where.Left + Each.Where.Width);
            Most_Y := Float'Max (Most_Y, Each.Where.Top + Each.Where.Height);
         end loop;
         declare
            Room_X : constant Float := Wide - 2.0 * Margin * Pixels;
            Room_Y : constant Float := High - 2.0 * Margin * Pixels;
            Scale  : constant Float :=
              Float'Min
                (Most * Pixels,
                 Float'Min (Room_X / Float'Max (1.0, Most_X - Least_X),
                            Room_Y / Float'Max (1.0, Most_Y - Least_Y)));
            From_X : constant Float :=
              Left + (Wide - (Most_X - Least_X) * Scale) / 2.0;
            From_Y : constant Float :=
              Top + (High - (Most_Y - Least_Y) * Scale) / 2.0;
            Pad    : constant Float := Float'Rounding (Card_Pad * Pixels);
            Line   : constant Float :=
              Float'Max (1.0, Float'Rounding (Line_High * Pixels));
         begin
            for Each of Item.Cards (1 .. Item.Count) loop
               declare
                  L : constant Float :=
                    Float'Rounding
                      (From_X + (Each.Where.Left - Least_X) * Scale);
                  T : constant Float :=
                    Float'Rounding
                      (From_Y + (Each.Where.Top - Least_Y) * Scale);
                  W : constant Float :=
                    Float'Rounding (Each.Where.Width * Scale);
                  H : constant Float :=
                    Float'Rounding (Each.Where.Height * Scale);
                  Inner : constant Float := W - 2.0 * Pad;
                  Mark  : constant Float := Float'Rounding (5.0 * Pixels);
                  Title_Left : Float := L + Pad;
                  Row   : Float := T + Pad + Mark + Pad / 2.0;
                  Part  : Natural := 0;
               begin
                  Pomarine.Boxes.Draw
                    (Target,
                     (Filled => True, Fill => Pomarine.Themes.White,
                      Bordered => True, Border => Colors.Border,
                      Shadowed => True, Shadow => Colors.Shadow,
                      Dashed => False),
                     L, T, W + Pomarine.Boxes.Offset (Pixels / 2.0),
                     H + Pomarine.Boxes.Offset (Pixels / 2.0), Pixels / 2.0);
                  if Inner > 0.0 then
                     if Each.Kind = Items.Source then
                        Fill_Rect
                          (Target, Pomarine.Themes.Resolve (Colors, Each.Ink),
                           Title_Left, T + Pad, Mark, Mark);
                        Title_Left := Title_Left + Mark + Pad / 2.0;
                     end if;
                     Fill_Rect
                       (Target, Rule, Title_Left,
                        T + Pad + Float'Rounding ((Mark - Line) / 2.0),
                        Float'Rounding (Inner * 0.45), Line);
                     --  Lines of text, as far as there is room.
                     while Row + Line < T + H - Pad and then Part < 6 loop
                        Fill_Rect
                          (Target, Text, L + Pad, Row,
                           Float'Rounding
                             (Inner * (if Part mod 3 = 2 then 0.55 else 0.9)),
                           Line);
                        Row := Row + 3.0 * Line;
                        Part := Part + 1;
                     end loop;
                  end if;
               end;
            end loop;
         end;
      end;
   end Draw;

end Previews;
