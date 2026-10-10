with Ada.Containers.Vectors;
with Ada.Finalization;
with CoreText.Fonts;
with CoreText.Shaping;
with CoreText.Strings;
with CoreText.Wrapping;

--  A document of paragraphs and the layout of them in one font at one
--  width, made lazily and kept: a paragraph is only broken into lines
--  when it is wanted, and an edit re-breaks only what it changes. The
--  heights of paragraphs not yet laid out are estimated, so that a long
--  document has a size and can be scrolled to anywhere at once.
--
--  Lengths and positions inside a paragraph's text are UTF-8 bytes, as an
--  Ada String has them. Lines are UTF-16 ranges: see CoreText.
--  Everything on the page is in the layout units of Configure, whose
--  size the font is set at: the display scales them.
package Typeset.Documents is

   type Document is limited private;

   subtype Paragraph_Number is Positive;

   procedure Configure
     (Item    : in out Document;
      Family  : String;
      Size    : Float;
      Page_Width : Float;
      Spacing : Float := 0.0)
     with Pre => Size > 0.0 and then Page_Width > 0.0 and then Spacing >= 0.0,
          Post => Is_Configured (Item);
   --  Set the document in font Family at Size, its lines no wider than
   --  Page_Width, with Spacing between paragraphs. Forgets all layout.

   function Is_Configured (Item : Document) return Boolean;

   procedure Load (Item : in out Document; Content : String);
   --  Replace the document with Content, a paragraph to each line. A
   --  document always has a paragraph, perhaps empty.

   function Count (Item : Document) return Positive;
   --  How many paragraphs.

   function Text (Item : Document; Para : Paragraph_Number) return String
     with Pre => Para <= Count (Item);

   function Byte_Length
     (Item : Document; Para : Paragraph_Number) return Natural
     with Pre => Para <= Count (Item);
   --  Of Text.

   function Length (Item : Document; Para : Paragraph_Number) return Natural
     with Pre => Para <= Count (Item);
   --  In UTF-16 units.

   --  Editing

   function Is_Boundary
     (Item : Document; Para : Paragraph_Number; Index : Positive)
      return Boolean
     with Pre => Para <= Count (Item)
                 and then Index <= Byte_Length (Item, Para) + 1;
   --  Whether Index, a byte position in the paragraph, is where a
   --  character starts, or is the end of the text. Edit only at these.

   procedure Replace
     (Item : in out Document;
      Para : Paragraph_Number;
      First, Last : Integer;
      By   : String)
     with Pre => Is_Configured (Item) and then Para <= Count (Item)
                 and then First >= 1
                 and then First <= Byte_Length (Item, Para) + 1
                 and then Last >= First - 1
                 and then Last <= Byte_Length (Item, Para)
                 and then Is_Boundary (Item, Para, First)
                 and then Is_Boundary (Item, Para, Last + 1)
                 and then (for all C of By => C /= ASCII.LF);
   --  Replace the bytes First .. Last of the paragraph's text with By;
   --  Last = First - 1 inserts.

   procedure Split
     (Item  : in out Document;
      Para  : Paragraph_Number;
      Index : Positive)
     with Pre => Is_Configured (Item) and then Para <= Count (Item)
                 and then Index <= Byte_Length (Item, Para) + 1
                 and then Is_Boundary (Item, Para, Index),
          Post => Count (Item) = Count (Item)'Old + 1;
   --  Break the paragraph before byte Index: the rest of it becomes the
   --  next paragraph.

   procedure Join (Item : in out Document; Para : Paragraph_Number)
     with Pre => Is_Configured (Item) and then Para < Count (Item),
          Post => Count (Item) = Count (Item)'Old - 1;
   --  Append the next paragraph to this one.

   --  Metrics

   function Line_Height (Item : Document) return Float
     with Pre => Is_Configured (Item);
   function Ascent (Item : Document) return Float
     with Pre => Is_Configured (Item);
   function Font_Size (Item : Document) return Float
     with Pre => Is_Configured (Item);
   function Width (Item : Document) return Float
     with Pre => Is_Configured (Item);

   --  Layout

   function Is_Laid_Out
     (Item : Document; Para : Paragraph_Number) return Boolean
     with Pre => Para <= Count (Item);
   --  Whether the paragraph's lines are made and current.

   procedure Lay_Out (Item : in out Document; Para : Paragraph_Number)
     with Pre => Is_Configured (Item) and then Para <= Count (Item),
          Post => Is_Laid_Out (Item, Para);
   --  Break the paragraph into lines, unless it is. Changes its height,
   --  and so the top of every paragraph after it.

   function Line_Count
     (Item : Document; Para : Paragraph_Number) return Positive
     with Pre => Para <= Count (Item) and then Is_Laid_Out (Item, Para);

   function Line
     (Item : Document; Para : Paragraph_Number; Number : Positive)
      return CoreText.Wrapping.Span
     with Pre => Para <= Count (Item) and then Is_Laid_Out (Item, Para)
                 and then Number <= Line_Count (Item, Para);

   function Layout_Id
     (Item : Document; Para : Paragraph_Number) return Positive
     with Pre => Para <= Count (Item) and then Is_Laid_Out (Item, Para);
   --  A number for this laying out of the paragraph: no other has it,
   --  so that things made from its lines can be kept by it.

   procedure Shape_Line
     (Item   : in out Document;
      Reg    : in out CoreText.Shaping.Registry;
      Para   : Paragraph_Number;
      Number : Positive;
      Result : out CoreText.Shaping.Shaped)
     with Pre => Para <= Count (Item) and then Is_Laid_Out (Item, Para)
                 and then Number <= Line_Count (Item, Para);
   --  Set the line as glyphs.

   --  Position

   function Top (Item : in out Document; Para : Paragraph_Number)
      return Float
     with Pre => Para <= Count (Item);
   --  How far down the page the paragraph is, as far as it is known.

   function Height (Item : Document; Para : Paragraph_Number) return Float
     with Pre => Para <= Count (Item);

   function Total_Height (Item : in out Document) return Float;

   function Paragraph_At
     (Item : in out Document; Y : Float) return Paragraph_Number;
   --  The paragraph that covers Y down the page; the first or last if
   --  Y is above or below the page.

   procedure Scroll
     (Item   : in out Document;
      Anchor : in out Paragraph_Number;
      Offset : in out Float;
      By     : Float;
      Extent : Float)
     with Pre => Anchor <= Count (Item) and then Extent >= 0.0;
   --  Move the top of a view Extent high, which is Offset below the top
   --  of paragraph Anchor, down the page by By (up if negative), but not
   --  off the page. Holding the view as a paragraph and an offset in it
   --  keeps it steady when paragraphs above it are laid out and so
   --  change height.

   procedure Visible
     (Item   : in out Document;
      Anchor : in out Paragraph_Number;
      Offset : in out Float;
      Extent : Float;
      First, Last : out Paragraph_Number)
     with Pre => Is_Configured (Item) and then Anchor <= Count (Item)
                 and then Extent >= 0.0,
          Post => First <= Last and then Last <= Count (Item)
                  and then (for all P in First .. Last =>
                              Is_Laid_Out (Item, P));
   --  Lay out the paragraphs of a view Extent high whose top is Offset
   --  below the top of paragraph Anchor, and give those it shows.
   --  Anchor and Offset are renormalized: Anchor is First and Offset
   --  within its height.

private

   type Text_Access is access String;

   type Paragraph is limited record
      Body_Text  : Text_Access;
      Units      : Natural := 0;  --  Body_Text, in UTF-16
      Held       : CoreText.Strings.Text;  --  set when laid out
      Lines      : CoreText.Wrapping.Span_Vectors.Vector;
      Dirty      : Boolean := False;
      --  Lines are of an earlier text; they are only of use to rewrap.
      Laid_Units : Natural := 0;  --  Units when the Lines were made
      Edit_At    : Natural := 0;
      Edit_Stop  : Natural := 0;  --  the edit since, in the text now
      Id         : Natural := 0;  --  of the laying out
   end record;

   type Paragraph_Access is access Paragraph;

   package Paragraph_Vectors is new Ada.Containers.Vectors
     (Positive, Paragraph_Access);

   package Float_Vectors is new Ada.Containers.Vectors
     (Positive, Long_Float);

   type Document is new Ada.Finalization.Limited_Controlled with record
      Paragraphs : Paragraph_Vectors.Vector;
      Font       : CoreText.Fonts.Font;
      Wide       : Float := 0.0;
      Gap        : Float := 0.0;

      Heights    : Float_Vectors.Vector;
      --  Of each paragraph: measured once laid out, otherwise estimated.
      Tops       : Float_Vectors.Vector;
      --  One more than Paragraphs; the first Known are right.
      Known      : Natural := 0;

      Next_Id    : Natural := 0;
      Units_Seen : Long_Float := 0.0;
      --  Of the paragraphs of more than a line laid out, and
      Lines_Seen : Long_Float := 0.0;
      --  their lines, the base of the estimate.
      Laid_Out   : Natural := 0;
      Next_Sample : Natural := 8;
      Per_Line   : Long_Float := 1.0;
      --  UTF-16 units a line is estimated to hold.
   end record;

   overriding procedure Finalize (Item : in out Document);

end Typeset.Documents;
