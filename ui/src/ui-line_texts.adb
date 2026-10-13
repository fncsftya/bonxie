package body UI.Line_Texts is

   function Shape
     (Item : in out Drawer; Text : String; Using : Style) return Positive;
   --  Which of Item.Cache is Text shaped in Using, opening the font and
   --  shaping it if it is not there. A line is shaped again each time it
   --  is drawn otherwise: labels and buttons are drawn, and measured,
   --  every time what is behind them is.

   function Shape
     (Item : in out Drawer; Text : String; Using : Style) return Positive
   is
      use Ada.Strings.Unbounded;
   begin
      for Entry_Of in Item.Cache'Range loop
         if Item.Cache (Entry_Of).Used
           and then Item.Cache (Entry_Of).Using = Using
           and then Item.Cache (Entry_Of).Text = Text
         then
            return Entry_Of;
         end if;
      end loop;

      if not CoreText.Fonts.Is_Open (Item.Faces (Using)) then
         CoreText.Fonts.Open
           (Item.Faces (Using), Face_Name (Using), Size (Using));
      end if;
      CoreText.Strings.Set (Item.Source, Text);
      declare
         Slot : constant Positive := Item.Next;
      begin
         CoreText.Shaping.Shape
           (Item.Reg, Item.Faces (Using), Item.Source, 0,
            CoreText.Strings.Length (Item.Source), Item.Cache (Slot).Line);
         Item.Cache (Slot).Used := True;
         Item.Cache (Slot).Using := Using;
         Item.Cache (Slot).Text := To_Unbounded_String (Text);
         Item.Next := (if Slot = Cache_Size then 1 else Slot + 1);
         return Slot;
      end;
   end Shape;

   procedure Begin_Frame (Item : in out Drawer) is
   begin
      Typeset.Glyph_Atlas.Begin_Frame (Item.Atlas);
   end Begin_Frame;

   function Width
     (Item  : in out Drawer;
      Text  : String;
      Scale : Float;
      Using : Style := Regular) return Float is
   begin
      declare
         Which : constant Positive := Shape (Item, Text, Using);
      begin
         return Item.Cache (Which).Line.Width * Scale;
      end;
   end Width;

   procedure Draw
     (Item   : in out Drawer;
      Target : SDL3.Windows.Renderers.Renderer;
      Value  : SDL3.Windows.Renderers.Color;
      Text   : String;
      Left   : Float;
      Middle : Float;
      Scale  : Float;
      Using  : Style := Regular) is
   begin
      declare
         Which   : constant Positive := Shape (Item, Text, Using);
         Face    : CoreText.Fonts.Font renames Item.Faces (Using);
         Ascent  : constant Float := CoreText.Fonts.Ascent (Face);
         Descent : constant Float := CoreText.Fonts.Descent (Face);
      begin
         Typeset.Glyph_Atlas.Draw
           (Item.Atlas, Item.Reg, Target, Item.Cache (Which).Line,
            X => Float'Rounding (Left),
            Baseline => Float'Rounding
              (Middle + (Ascent - Descent) / 2.0 * Scale),
            Scale => Scale, Size => Size (Using) * Scale,
            Value => Value, Settled => True);
      end;
      Typeset.Glyph_Atlas.Flush (Item.Atlas, Target);
   end Draw;

end UI.Line_Texts;
