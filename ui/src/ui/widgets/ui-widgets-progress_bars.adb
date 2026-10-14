package body UI.Widgets.Progress_Bars is

   procedure Set_Value (Item : in out Progress_Bar; To : Float) is
   begin
      if To /= Item.Fraction then
         Item.Fraction := To;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Value;

   function Value (Item : Progress_Bar) return Float is (Item.Fraction);

   overriding procedure Draw
     (Item   : in out Progress_Bar;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme) is
   begin
      SDL3.Windows.Renderers.Fill_Rect
        (Target, Themes.Mix (Colors.Background, Colors.Foreground, 0.2),
         Left_Of (Item), Top_Of (Item), Width_Of (Item), Height_Of (Item));
      SDL3.Windows.Renderers.Fill_Rect
        (Target, Colors.Accent,
         Left_Of (Item), Top_Of (Item),
         Float'Rounding (Width_Of (Item) * Item.Fraction), Height_Of (Item));
   end Draw;

end UI.Widgets.Progress_Bars;
