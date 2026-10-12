package body UI.Widgets.Panels is

   use type Themes.Color;

   procedure Set_Fill (Item : in out Panel; Value : Themes.Color) is
   begin
      if not Item.Filled or else Item.Color /= Value then
         Item.Filled := True;
         Item.Color := Value;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Fill;

   procedure Clear_Fill (Item : in out Panel) is
   begin
      if Item.Filled then
         Item.Filled := False;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Clear_Fill;

   function Has_Fill (Item : Panel) return Boolean is (Item.Filled);

   function Fill (Item : Panel) return Themes.Color is (Item.Color);

   overriding procedure Draw
     (Item   : in out Panel;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme)
   is
      pragma Unreferenced (Colors);
   begin
      if Item.Filled then
         SDL3.Windows.Renderers.Fill_Rect
           (Target, Item.Color,
            Left_Of (Item), Top_Of (Item), Width_Of (Item),
            Height_Of (Item));
      end if;
   end Draw;

end UI.Widgets.Panels;
