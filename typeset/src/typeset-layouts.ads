with CoreText.Shaping;
with CoreText.Wrapping;
with Texts.Documents;
private with Ada.Containers.Vectors;
private with Ada.Finalization;
private with CoreText.Fonts;
private with CoreText.Strings;
private with Typeset.Sums;

--  How a document is laid out to be shown, in one font at one width: its
--  paragraphs broken into lines, made lazily and kept. A view has a
--  layout of its own, so that two views of a document can be of
--  different widths; it catches up with the document's changes (Sync),
--  and an edit re-breaks only what it changes.
--
--  A paragraph is broken into lines when it is wanted, and a long one
--  only as far as it is wanted. The heights of what is not yet broken
--  are estimated, so that a long document has a size and can be
--  scrolled to anywhere at once; where each paragraph is down the page
--  is kept as running sums of the heights.
--
--  Lengths and positions in a paragraph's text are UTF-8 bytes, as Texts
--  has them; lines are UTF-16 ranges, as CoreText has them. Everything
--  on the page is in the layout units of Configure, at whose size the
--  font is set: the display scales them.
package Typeset.Layouts is

   subtype Document is Texts.Documents.Document;

   type Layout is limited private;

   procedure Configure
     (Item       : in out Layout;
      Family     : String;
      Size       : Float;
      Page_Width : Float;
      Spacing    : Float := 0.0)
     with Pre  => Size > 0.0 and then Page_Width > 0.0
                  and then Spacing >= 0.0,
          Post => Is_Configured (Item);
   --  Set text in font Family at Size, its lines no wider than
   --  Page_Width, with Spacing between paragraphs. Forgets all layout.

   function Is_Configured (Item : Layout) return Boolean;

   procedure Set_Width (Item : in out Layout; Page_Width : Float)
     with Pre => Is_Configured (Item) and then Page_Width > 0.0;
   --  Make lines no wider than Page_Width. Forgets all layout, but keeps
   --  the font.

   procedure Sync (Item : in out Layout; Doc : Document)
     with Pre  => Is_Configured (Item),
          Post => Is_Synced (Item, Doc);
   --  Catch up with Doc's changes since the layout last saw it. The
   --  layout of another document, or of one too far behind, starts
   --  again. Sync after Doc changes, before asking anything else of it.

   function Is_Synced (Item : Layout; Doc : Document) return Boolean;

   function Count (Item : Layout) return Natural;
   --  The paragraphs it has, as many as the document had when synced.

   --  Metrics

   function Line_Height (Item : Layout) return Float
     with Pre => Is_Configured (Item);
   function Ascent (Item : Layout) return Float
     with Pre => Is_Configured (Item);
   function Font_Size (Item : Layout) return Float
     with Pre => Is_Configured (Item);
   function Width (Item : Layout) return Float
     with Pre => Is_Configured (Item);

   --  Lines

   function Is_Laid_Out (Item : Layout; Para : Positive) return Boolean
     with Pre => Para <= Count (Item);
   --  Whether some of the paragraph's lines are made and current.

   function Is_Complete (Item : Layout; Para : Positive) return Boolean
     with Pre => Para <= Count (Item);
   --  Whether all of them are.

   procedure Lay_Out
     (Item  : in out Layout;
      Doc   : Document;
      Para  : Positive;
      Lines : Positive := Positive'Last)
     with Pre  => Is_Synced (Item, Doc) and then Para <= Count (Item),
          Post => Is_Laid_Out (Item, Para)
                  and then (Is_Complete (Item, Para)
                            or else Line_Count (Item, Para) >= Lines);
   --  Break the paragraph into at least Lines lines, or all of them.
   --  Changes its height, and so where those after it are.

   function Covers
     (Item : Layout; Para : Positive; Units : Natural) return Boolean
     with Pre => Para <= Count (Item);
   --  Whether the line the caret before UTF-16 unit Units is on is made.

   procedure Lay_Out_To
     (Item  : in out Layout;
      Doc   : Document;
      Para  : Positive;
      Units : Natural)
     with Pre  => Is_Synced (Item, Doc) and then Para <= Count (Item),
          Post => Is_Laid_Out (Item, Para) and then Covers (Item, Para, Units);
   --  Break the paragraph into lines as far as unit Units.

   function Line_Count (Item : Layout; Para : Positive) return Positive
     with Pre => Para <= Count (Item) and then Is_Laid_Out (Item, Para);
   --  How many are made.

   function Line
     (Item : Layout; Para : Positive; Number : Positive)
      return CoreText.Wrapping.Span
     with Pre => Para <= Count (Item) and then Is_Laid_Out (Item, Para)
                 and then Number <= Line_Count (Item, Para);

   function Layout_Id (Item : Layout; Para : Positive) return Positive
     with Pre => Para <= Count (Item) and then Is_Laid_Out (Item, Para);
   --  A number for this laying out of the paragraph's lines, which no
   --  other has, so that things made from its lines can be kept by it.
   --  Lines made later, further on, are of the same laying out.

   procedure Shape_Line
     (Item   : in out Layout;
      Doc    : Document;
      Reg    : in out CoreText.Shaping.Registry;
      Para   : Positive;
      Number : Positive;
      Result : out CoreText.Shaping.Shaped)
     with Pre => Is_Synced (Item, Doc) and then Para <= Count (Item)
                 and then Is_Laid_Out (Item, Para)
                 and then Number <= Line_Count (Item, Para);
   --  Set the line as glyphs.

   --  Where paragraphs are

   function Top (Item : Layout; Para : Positive) return Float
     with Pre => Para <= Count (Item) + 1;
   --  How far down the page the paragraph is, as far as it is known.

   function Height (Item : Layout; Para : Positive) return Float
     with Pre => Para <= Count (Item);

   function Total_Height (Item : Layout) return Float;

   function Paragraph_At (Item : Layout; Y : Float) return Positive
     with Pre => Count (Item) > 0;
   --  The paragraph that covers Y down the page; the first or last if Y
   --  is above or below the page.

   procedure Scroll
     (Item   : Layout;
      Anchor : in out Positive;
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
     (Item   : in out Layout;
      Doc    : Document;
      Anchor : in out Positive;
      Offset : in out Float;
      Extent : Float;
      First, Last : out Positive)
     with Pre  => Is_Synced (Item, Doc) and then Anchor <= Count (Item)
                  and then Extent >= 0.0,
          Post => First <= Last and then Last <= Count (Item)
                  and then (for all P in First .. Last =>
                              Is_Laid_Out (Item, P));
   --  Lay out what a view Extent high shows, whose top is Offset below
   --  the top of paragraph Anchor, and give the paragraphs it shows.
   --  Anchor and Offset are renormalized: Anchor is First and Offset
   --  within its height.

   --  Carets: a caret is before a UTF-16 unit of a paragraph, or at its
   --  end. One at the break between two lines is at the start of the
   --  second.

   function Line_At
     (Item : Layout; Para : Positive; Units : Natural) return Positive
     with Pre  => Para <= Count (Item) and then Is_Laid_Out (Item, Para)
                  and then Covers (Item, Para, Units),
          Post => Line_At'Result <= Line_Count (Item, Para);
   --  The line the caret before unit Units is on.

   function Caret_Offset
     (Item   : Layout;
      Doc    : Document;
      Para   : Positive;
      Number : Positive;
      Units  : Natural) return Float
     with Pre => Is_Synced (Item, Doc) and then Para <= Count (Item)
                 and then Is_Laid_Out (Item, Para)
                 and then Number <= Line_Count (Item, Para)
                 and then Units >= Line (Item, Para, Number).First
                 and then Units <= Line (Item, Para, Number).Stop;
   --  How far along line Number, in layout units, the caret before unit
   --  Units is.

   function Units_At_Offset
     (Item   : Layout;
      Doc    : Document;
      Para   : Positive;
      Number : Positive;
      X      : Float) return Natural
     with Pre  => Is_Synced (Item, Doc) and then Para <= Count (Item)
                  and then Is_Laid_Out (Item, Para)
                  and then Number <= Line_Count (Item, Para),
          Post => Units_At_Offset'Result >= Line (Item, Para, Number).First
                  and then Units_At_Offset'Result
                           <= Line (Item, Para, Number).Stop
                  and then Line_At (Item, Para, Units_At_Offset'Result)
                           = Number;
   --  Where on line Number the caret nearest X layout units along it is.

   --  Characters and words, as a reader sees them (an emoji and its
   --  modifiers are one character): see CoreText.Strings. Positions are
   --  bytes.

   function Next_Character
     (Doc : Document; Para : Positive; Index : Positive) return Positive
     with Pre  => Para <= Texts.Documents.Count (Doc)
                  and then Texts.Documents.Is_Position (Doc, (Para, Index))
                  and then Index <= Texts.Documents.Byte_Length (Doc, Para),
          Post => Next_Character'Result > Index
                  and then Texts.Documents.Is_Position
                             (Doc, (Para, Next_Character'Result));

   function Previous_Character
     (Doc : Document; Para : Positive; Index : Positive) return Positive
     with Pre  => Para <= Texts.Documents.Count (Doc)
                  and then Texts.Documents.Is_Position (Doc, (Para, Index))
                  and then Index > 1,
          Post => Previous_Character'Result < Index
                  and then Texts.Documents.Is_Position
                             (Doc, (Para, Previous_Character'Result));

   function Previous_Word
     (Doc : Document; Para : Positive; Index : Positive) return Positive
     with Pre  => Para <= Texts.Documents.Count (Doc)
                  and then Texts.Documents.Is_Position (Doc, (Para, Index)),
          Post => Previous_Word'Result <= Index
                  and then (Index = 1 or else Previous_Word'Result < Index)
                  and then Texts.Documents.Is_Position
                             (Doc, (Para, Previous_Word'Result));
   --  The start of the last word that starts before Index; the
   --  paragraph's start if none does.

   function Next_Word
     (Doc : Document; Para : Positive; Index : Positive) return Positive
     with Pre  => Para <= Texts.Documents.Count (Doc)
                  and then Texts.Documents.Is_Position (Doc, (Para, Index)),
          Post => Next_Word'Result >= Index
                  and then (Index > Texts.Documents.Byte_Length (Doc, Para)
                            or else Next_Word'Result > Index)
                  and then Texts.Documents.Is_Position
                             (Doc, (Para, Next_Word'Result));
   --  After the end of the first word that ends after Index; the
   --  paragraph's end if none does.

   procedure Word_At
     (Doc   : Document;
      Para  : Positive;
      Index : Positive;
      First, Stop : out Positive)
     with Pre  => Para <= Texts.Documents.Count (Doc)
                  and then Texts.Documents.Is_Position (Doc, (Para, Index)),
          Post => First <= Index and then Index <= Stop
                  and then Texts.Documents.Is_Position (Doc, (Para, First))
                  and then Texts.Documents.Is_Position (Doc, (Para, Stop));
   --  The bytes First .. Stop - 1 of the word Index is in, or that ends
   --  there; none, First = Stop = Index, if there is no such word.

   Reach : constant := 256;
   --  UTF-16 units around a position looked at for its character or
   --  word: what is further does not cost a long paragraph's time.

private

   type Paragraph_Layout is limited record
      Held       : CoreText.Strings.Text;
      --  The text, for CoreText: set when wanted, and edited as the
      --  paragraph is.
      Lines      : CoreText.Wrapping.Span_Vectors.Vector;
      Complete   : Boolean := False;
      --  Lines go to the paragraph's end.
      Dirty      : Boolean := False;
      --  Lines, complete, are of an earlier text; they are only of use
      --  to rewrap.
      Laid_Units : Natural := 0;  --  the text's length when they were
      Edit_At    : Natural := 0;
      Edit_Stop  : Natural := 0;  --  the edit since, in the text now
      Id         : Natural := 0;  --  of the laying out
   end record;

   type Paragraph_Access is access Paragraph_Layout;

   package Paragraph_Vectors is new Ada.Containers.Vectors
     (Positive, Paragraph_Access);

   package Length_Vectors is new Ada.Containers.Vectors (Positive, Natural);

   type Layout is new Ada.Finalization.Limited_Controlled with record
      Paragraphs : Paragraph_Vectors.Vector;
      --  Null for those never laid out: a long document is loaded
      --  without making anything for each paragraph but its length.
      Lengths    : Length_Vectors.Vector;
      --  Of each paragraph's text, in UTF-16 units: so far as it has been
      --  laid out or edited; before, its length in bytes, an estimate
      --  that costs nothing to find.
      Font       : CoreText.Fonts.Font;
      Line_High  : Long_Float := 0.0;  --  the font's
      Wide       : Float := 0.0;
      Gap        : Float := 0.0;

      Heights    : Sums.Sum_Tree;
      --  Of each paragraph: measured where laid out, otherwise estimated.

      Serial     : Natural := 0;  --  of the document laid out
      Seen       : Texts.Documents.Version := 0;

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

   overriding procedure Finalize (Item : in out Layout);

end Typeset.Layouts;
