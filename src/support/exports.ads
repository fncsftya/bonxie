with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Texts.Documents;

--  What a document is to the formats it is exported as: blocks of spans, read once from the paragraphs and
--  format runs, so that each writer (Markdown, text, HTML, EPUB, ODT, DOCX, PDF) only says how to write them.
--
--  What a document has, and what becomes of it:
--    bold, italic, underline, strikethrough and links   marks of a span, with a link's address;
--    Heading_1 .. 3          headings, their words not bold (a heading is that already);
--    lists                   the literal prefixes "• " and "N. " are a bullet and a numbered item, their prefix
--                            taken off, a step of indent nesting;
--    quoted paragraphs       Quoted blocks;
--    indented text           its steps of indent;
--    a text with versions    the version that is the text;
--    sizes, families, fading none: the words are kept as they are.
--  Paragraphs with no words, and lists' items with none after the prefix, are left out.

package Exports is

   package Unbounded renames Ada.Strings.Unbounded;

   type Mark is (Underlined, Struck, Bold, Italic, Linked);
   --  In the order a writer opens them, outermost first.

   type Mark_Set is array (Mark) of Boolean;

   type Span is record
      Words   : Unbounded.Unbounded_String;
      Marks   : Mark_Set := [others => False];
      Address : Unbounded.Unbounded_String;
      --  Where a Linked span goes.
   end record;

   package Span_Vectors is new Ada.Containers.Vectors (Positive, Span);

   type Block_Kinds is (Paragraph, Heading, Bullet, Number);

   subtype Heading_Level is Positive range 1 .. 3;

   type Block is record
      Kind   : Block_Kinds := Paragraph;
      Level  : Heading_Level := 1;
      --  Of a Heading.
      Figure : Unbounded.Unbounded_String;
      --  Of a Number: the digits it was typed with.
      Para   : Positive := 1;
      --  The paragraph of the document it was read from.
      Indent : Natural := 0;
      Quoted : Boolean := False;
      Spans  : Span_Vectors.Vector;
   end record;

   package Block_Vectors is new Ada.Containers.Vectors (Positive, Block);

   function Blocks_Of (Item : Texts.Documents.Document) return Block_Vectors.Vector
   with Post => (for all B of Blocks_Of'Result => not B.Spans.Is_Empty);
   --  The blocks of Item in order.

   function Words_Of (Item : Block) return String;
   --  What the spans of Item say, together.

   function Is_Blank (Words : String) return Boolean
   is (for all C of Words => C in ' ' | ASCII.HT | ASCII.LF | ASCII.CR);

   function Escaped (Words : String) return String;
   --  Words for XML text or an attribute in quotes: & < > and " by their entities, and a control character that XML
   --  cannot hold left out.

end Exports;
