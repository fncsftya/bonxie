package body UI.Widgets.Labels is

   use SDL3.Windows.Renderers;

   procedure Set_Text (Item : in out Label; Value : String) is
   begin
      if Value /= Text (Item) then
         Item.Length := Value'Length;
         Item.Content (1 .. Item.Length) := Value;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Text;

   procedure Set_Style (Item : in out Label; To : Line_Texts.Style) is
      use type Line_Texts.Style;
   begin
      if To /= Item.Using then
         Item.Using := To;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Style;

   procedure Set_Ink (Item : in out Label; To : Themes.Color) is
   begin
      if not Item.Inked or else Item.Ink /= To then
         Item.Inked := True;
         Item.Ink := To;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Ink;

   function Style (Item : Label) return Line_Texts.Style is (Item.Using);

   function Text (Item : Label) return String is
     (Item.Content (1 .. Item.Length));

   overriding procedure Draw
     (Item   : in out Label;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme)
   is
      Scale : constant Positive :=
        Positive (Float'Max (1.0, Float'Rounding (Density (Item))));
      High  : constant Float := Float (Debug_Text_Size * Scale);
      Ink   : constant Themes.Color :=
        (if Item.Inked then Item.Ink else Colors.Foreground);
   begin
      if Item.Length > 0 and then Text_Lines (Item) /= null then
         Line_Texts.Draw
           (Text_Lines (Item).all, Target, Ink, Text (Item),
            Left_Of (Item), Top_Of (Item) + Height_Of (Item) / 2.0,
            Density (Item), Item.Using);
      elsif Item.Length > 0 then
         Draw_Text
           (Target, Ink,
            Float'Rounding (Left_Of (Item)),
            Float'Rounding (Top_Of (Item) + (Height_Of (Item) - High) / 2.0),
            Text (Item), Scale);
      end if;
   end Draw;

end UI.Widgets.Labels;
