with Ada.Containers.Vectors;
with CoreText.Fonts;
with CoreText.Strings;

package CoreText.Wrapping is

   type Span is record
      First : Natural;  --  UTF-16 index of the line's first unit
      Stop  : Natural;  --  and of the unit after its last
   end record;

   package Span_Vectors is new Ada.Containers.Vectors (Positive, Span);

   function Is_Layout
     (Lines : Span_Vectors.Vector; Length : Natural) return Boolean is
     (not Lines.Is_Empty
      and then Lines.First_Element.First = 0
      and then Lines.Last_Element.Stop = Length);
   --  Whether Lines are the lines of a paragraph Length units long: the
   --  first starts it and the last ends it.

   Window : constant := 2048;
   --  How many UTF-16 units are typeset at once. A typesetter's line
   --  breaking costs in proportion to its whole string, on every line, so
   --  wrapping a long paragraph with one typesetter grows with the square
   --  of its length: 100 KB takes most of a second. In windows of this
   --  size it takes milliseconds.

   function Wrap
     (Using : Fonts.Font; Text : Strings.Text; Width : Float)
      return Span_Vectors.Vector
     with Pre  => Fonts.Is_Open (Using) and then Strings.Is_Set (Text),
          Post => Is_Layout (Wrap'Result, Strings.Length (Text));
   --  Break the paragraph Text in Using into lines no wider than Width
   --  pixels (a line may be wider where a single word is). The lines
   --  are contiguous, and an empty paragraph has one empty line.

   function Wrap
     (Using : Fonts.Font; Text : String; Width : Float)
      return Span_Vectors.Vector
     with Pre  => Fonts.Is_Open (Using),
          Post => Is_Layout (Wrap'Result, UTF16_Length (Text));
   --  The same, setting Text first.

   function Rewrap
     (Using    : Fonts.Font;
      Old      : Span_Vectors.Vector;
      Text     : Strings.Text;
      Width    : Float;
      Edit_At  : Natural;
      Old_Stop : Natural;
      New_Stop : Natural)
      return Span_Vectors.Vector
     with Pre  => Fonts.Is_Open (Using) and then Strings.Is_Set (Text)
                  and then not Old.Is_Empty
                  and then Edit_At <= Old_Stop
                  and then Edit_At <= New_Stop
                  and then New_Stop <= Strings.Length (Text),
          Post => Is_Layout (Rewrap'Result, Strings.Length (Text));
   --  The lines of Text, an edit of a paragraph laid out as Old (at the
   --  same Width) which replaced Old's UTF-16 range [Edit_At, Old_Stop)
   --  with what is now [Edit_At, New_Stop). Re-breaks only from the line
   --  before the edit until a break falls where one did before, shifted
   --  by the edit, and keeps Old's lines past there. So an edit to a long
   --  paragraph costs about a window, not the paragraph.

end CoreText.Wrapping;
