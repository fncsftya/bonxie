package body UI.Widgets.Panels is

   use type Themes.Color;
   use type UI.Boxes.Look;

   procedure Restyle (Item : in out Panel; To : UI.Boxes.Look);
   --  Look like To, drawn again if that is not how it looks.

   procedure Restyle (Item : in out Panel; To : UI.Boxes.Look) is
   begin
      if To /= Item.Look then
         Item.Look := To;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Restyle;

   procedure Set_Fill (Item : in out Panel; Value : Themes.Color) is
   begin
      Restyle (Item, (Item.Look with delta Filled => True, Fill => Value));
   end Set_Fill;

   procedure Clear_Fill (Item : in out Panel) is
   begin
      Restyle (Item, (Item.Look with delta Filled => False));
   end Clear_Fill;

   function Has_Fill (Item : Panel) return Boolean is (Item.Look.Filled);

   function Fill (Item : Panel) return Themes.Color is (Item.Look.Fill);

   procedure Set_Border
     (Item : in out Panel; Value : Themes.Color; Dashed : Boolean := False)
   is
   begin
      Restyle
        (Item,
         (Item.Look with delta
            Bordered => True, Border => Value, Dashed => Dashed));
   end Set_Border;

   procedure Set_Shadow (Item : in out Panel; Value : Themes.Color) is
   begin
      Restyle
        (Item, (Item.Look with delta Shadowed => True, Shadow => Value));
   end Set_Shadow;

   procedure Set_Ring (Item : in out Panel; Value : Themes.Color) is
   begin
      if not Item.Ringed or else Item.Ring /= Value then
         Item.Ringed := True;
         Item.Ring := Value;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Ring;

   procedure Clear_Ring (Item : in out Panel) is
   begin
      if Item.Ringed then
         Item.Ringed := False;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Clear_Ring;

   overriding procedure Draw
     (Item   : in out Panel;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme)
   is
      pragma Unreferenced (Colors);
   begin
      UI.Boxes.Draw
        (Target, Item.Look, Left_Of (Item), Top_Of (Item), Width_Of (Item),
         Height_Of (Item), Density (Item));
   end Draw;

   overriding procedure Draw_Over
     (Item   : in out Panel;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme)
   is
      pragma Unreferenced (Colors);
      Off : constant Float := UI.Boxes.Inset (Item.Look, Density (Item));
   begin
      if Item.Ringed then
         UI.Boxes.Outline
           (Target, Item.Ring, Left_Of (Item), Top_Of (Item),
            Width_Of (Item) - Off, Height_Of (Item) - Off,
            Float'Max (1.0, Float'Rounding (Ring_Width * Density (Item))));
      end if;
   end Draw_Over;

end UI.Widgets.Panels;
