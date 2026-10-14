with Ada.Strings.Fixed;
with UI.Boxes;

package body UI.Widgets.Badges is

   use SDL3.Windows.Renderers;

   Tag_Pad   : constant Float := 6.0;  --  in points, at each side of a tag
   Count_Pad : constant Float := 4.0;  --  of a count of several figures

   function Figures (Item : Badge) return String is
     (Ada.Strings.Fixed.Trim (Item.Value'Image, Ada.Strings.Both));

   function Shown (Item : Badge) return String is
     (case Item.Form is
         when Number => Figures (Item),
         when Tag   => Item.Content (1 .. Item.Length));

   function Style_Of (Item : Badge) return UI.Line_Texts.Style is
     (case Item.Form is
         when Number => UI.Line_Texts.Strong,
         when Tag   => UI.Line_Texts.Caption);

   procedure Changed_Look (Item : in out Badge);

   procedure Changed_Look (Item : in out Badge) is
   begin
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Changed_Look;

   procedure Set_Kind (Item : in out Badge; To : Kind) is
   begin
      if To /= Item.Form then
         Item.Form := To;
         Changed_Look (Item);
      end if;
   end Set_Kind;

   procedure Set_Count (Item : in out Badge; To : Natural) is
   begin
      if To /= Item.Value then
         Item.Value := To;
         Changed_Look (Item);
      end if;
   end Set_Count;

   function Count_Of (Item : Badge) return Natural is (Item.Value);

   procedure Set_Text (Item : in out Badge; Value : String) is
   begin
      if Value /= Text (Item) then
         Item.Length := Value'Length;
         Item.Content (1 .. Item.Length) := Value;
         Changed_Look (Item);
      end if;
   end Set_Text;

   function Text (Item : Badge) return String is
     (Item.Content (1 .. Item.Length));

   function Natural_Width (Item : Badge) return Float is
      Span : constant Float :=
        (if Text_Lines (Item) = null then 0.0
         else UI.Line_Texts.Width
                (Text_Lines (Item).all, Shown (Item), 1.0, Style_Of (Item)));
   begin
      return
        (case Item.Form is
            when Number => Float'Max (Count_Size, Span + 2.0 * Count_Pad),
            when Tag   => Span + 2.0 * Tag_Pad);
   end Natural_Width;

   overriding procedure Draw
     (Item   : in out Badge;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme)
   is
      Pixels : constant Float := Density (Item);
      Words  : constant String := Shown (Item);
      Using  : constant UI.Line_Texts.Style := Style_Of (Item);
      High   : constant Float :=
        (case Item.Form is
            when Number =>
              Float'Min (Height_Of (Item),
                         Float'Rounding (Count_Size * Pixels)),
            when Tag   => Height_Of (Item));
      Top    : constant Float :=
        Float'Rounding (Top_Of (Item) + (Height_Of (Item) - High) / 2.0);
      Ink    : constant Themes.Color :=
        (case Item.Form is
            when Number => Themes.White,
            when Tag   => Themes.Quiet (Colors));
   begin
      case Item.Form is
         when Number =>
            Fill_Rect
              (Target, Colors.Bar, Left_Of (Item), Top, Width_Of (Item),
               High);
         when Tag =>
            Fill_Rect
              (Target, Colors.Tint, Left_Of (Item), Top, Width_Of (Item),
               High);
            UI.Boxes.Outline
              (Target, Colors.Border, Left_Of (Item), Top, Width_Of (Item),
               High, UI.Boxes.Edge (Pixels));
      end case;
      if Text_Lines (Item) /= null and then Words'Length > 0 then
         UI.Line_Texts.Draw
           (Text_Lines (Item).all, Target, Ink, Words,
            Left_Of (Item)
            + (Width_Of (Item)
               - UI.Line_Texts.Width
                   (Text_Lines (Item).all, Words, Pixels, Using)) / 2.0,
            Top + High / 2.0, Pixels, Using);
      end if;
   end Draw;

end UI.Widgets.Badges;
