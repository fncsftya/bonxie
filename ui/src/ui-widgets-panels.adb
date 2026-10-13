package body UI.Widgets.Panels is

   use type Themes.Color;
   use type Themes.Slot;

   procedure Refresh (Item : in out Panel);
   --  Draw Item again, if it is on the screen.

   procedure Refresh (Item : in out Panel) is
   begin
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Refresh;

   procedure Set_Fill (Item : in out Panel; Value : Themes.Slot) is
   begin
      if not Item.Look.Filled or else Item.Fill_Fixed
        or else Item.Fill_Slot /= Value
      then
         Item.Look.Filled := True;
         Item.Fill_Fixed := False;
         Item.Fill_Slot := Value;
         Refresh (Item);
      end if;
   end Set_Fill;

   procedure Set_Fill_Color (Item : in out Panel; Value : Themes.Color) is
   begin
      if not Item.Look.Filled or else not Item.Fill_Fixed
        or else Item.Fill_Color /= Value
      then
         Item.Look.Filled := True;
         Item.Fill_Fixed := True;
         Item.Fill_Color := Value;
         Refresh (Item);
      end if;
   end Set_Fill_Color;

   procedure Clear_Fill (Item : in out Panel) is
   begin
      if Item.Look.Filled then
         Item.Look.Filled := False;
         Refresh (Item);
      end if;
   end Clear_Fill;

   function Has_Fill (Item : Panel) return Boolean is (Item.Look.Filled);

   function Fill (Item : Panel) return Themes.Slot is (Item.Fill_Slot);

   procedure Set_Border
     (Item : in out Panel; Value : Themes.Slot; Dashed : Boolean := False)
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

   procedure Set_Shadow (Item : in out Panel; Value : Themes.Slot) is
   begin
      if not Item.Look.Shadowed or else Item.Shadow_Slot /= Value then
         Item.Look.Shadowed := True;
         Item.Shadow_Slot := Value;
         Refresh (Item);
      end if;
   end Set_Shadow;

   procedure Set_Ring (Item : in out Panel; Value : Themes.Slot) is
   begin
      if not Item.Ringed or else Item.Ring_Slot /= Value then
         Item.Ringed := True;
         Item.Ring_Slot := Value;
         Refresh (Item);
      end if;
   end Set_Ring;

   procedure Clear_Ring (Item : in out Panel) is
   begin
      if Item.Ringed then
         Item.Ringed := False;
         Refresh (Item);
      end if;
   end Clear_Ring;

   overriding procedure Draw
     (Item   : in out Panel;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme)
   is
      Look : UI.Boxes.Look := Item.Look;
   begin
      Look.Fill :=
        (if Item.Fill_Fixed then Item.Fill_Color
         else Themes.Resolve (Colors, Item.Fill_Slot));
      Look.Border := Themes.Resolve (Colors, Item.Border_Slot);
      Look.Shadow := Themes.Resolve (Colors, Item.Shadow_Slot);
      UI.Boxes.Draw
        (Target, Look, Left_Of (Item), Top_Of (Item), Width_Of (Item),
         Height_Of (Item), Density (Item));
   end Draw;

   overriding procedure Draw_Over
     (Item   : in out Panel;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme)
   is
      Off : constant Float := UI.Boxes.Inset (Item.Look, Density (Item));
   begin
      if Item.Ringed then
         UI.Boxes.Outline
           (Target, Themes.Resolve (Colors, Item.Ring_Slot), Left_Of (Item),
            Top_Of (Item), Width_Of (Item) - Off, Height_Of (Item) - Off,
            Float'Max (1.0, Float'Rounding (Ring_Width * Density (Item))));
      end if;
   end Draw_Over;

end UI.Widgets.Panels;
