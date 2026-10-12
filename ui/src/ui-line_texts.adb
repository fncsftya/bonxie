package body UI.Line_Texts is

   procedure Shape (Item : in out Drawer; Text : String; Using : Style);
   --  Into Item.Line, opening the font the first time.

   procedure Shape (Item : in out Drawer; Text : String; Using : Style) is
   begin
      if not CoreText.Fonts.Is_Open (Item.Faces (Using)) then
         CoreText.Fonts.Open
           (Item.Faces (Using),
            (case Using is
                when Regular => System_UI,
                when Strong  => Semibold_System_UI,
                when Heading => Bold_System_UI),
            Size (Using));
      end if;
      CoreText.Strings.Set (Item.Source, Text);
      CoreText.Shaping.Shape
        (Item.Reg, Item.Faces (Using), Item.Source, 0,
         CoreText.Strings.Length (Item.Source), Item.Line);
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
      Shape (Item, Text, Using);
      return Item.Line.Width * Scale;
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
      Shape (Item, Text, Using);
      declare
         Face    : CoreText.Fonts.Font renames Item.Faces (Using);
         Ascent  : constant Float := CoreText.Fonts.Ascent (Face);
         Descent : constant Float := CoreText.Fonts.Descent (Face);
      begin
         Typeset.Glyph_Atlas.Draw
           (Item.Atlas, Item.Reg, Target, Item.Line,
            X => Float'Rounding (Left),
            Baseline => Float'Rounding
              (Middle + (Ascent - Descent) / 2.0 * Scale),
            Scale => Scale, Size => Size (Using) * Scale,
            Value => Value, Settled => True);
      end;
      Typeset.Glyph_Atlas.Flush (Item.Atlas, Target);
   end Draw;

end UI.Line_Texts;
