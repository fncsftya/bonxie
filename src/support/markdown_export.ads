with Ada.Strings.Unbounded;
with Texts.Documents;

--  Rich text as Markdown (CommonMark, with ~~strike~~ from GitHub's).
--
--  What a document has, and what becomes of it:
--    bold, italic        **bold** and *italic*;
--    strikethrough       ~~struck~~;
--    underline           <u>underlined</u> (Markdown has none; HTML in it is allowed);
--    links               [words](address);
--    Heading_1 .. 3      #, ## and ###;
--    lists               the literal prefixes "• " and "N. " are - and N. , a step of indent
--                        nesting by four spaces;
--    quoted paragraphs   > ;
--    indented text       an em space (&emsp;) to each step, as Markdown has no indent for text;
--    a text with versions  the version that is the text;
--    sizes, families, fading  none: the words are kept as they are.
--  Characters that Markdown would take for its own are escaped with a backslash. Space at the
--  edge of a styled run is put outside its marks, where they would not otherwise apply.
package Markdown_Export is

   type Writer is limited private;
   --  The Markdown of what is added to it, in order.

   subtype Heading_Level is Positive range 1 .. 6;

   procedure Add_Heading (Into : in out Writer; Level : Heading_Level; Title : String);
   --  A heading of its own, as of a section or a document's title. Nothing is added if Title is blank.

   procedure Add_Document (Into : in out Writer; Item : Texts.Documents.Document);
   --  The paragraphs of Item; empty ones are left out.

   function Text (From : Writer) return String
     with Post => Text'Result'Length = 0 or else Text'Result (Text'Result'Last) = ASCII.LF;
   --  All that was added: lines each ended by a line feed, blocks apart by a blank line.

   function Of_Document (Item : Texts.Documents.Document) return String;
   --  Add_Document to a new Writer, and its Text.

private

   type Blocks is (None, Bullet_Item, Number_Item, Other);
   --  What the last block was, to tell whether the next belongs with it.

   type Writer is limited record
      Output : Ada.Strings.Unbounded.Unbounded_String;
      Last   : Blocks := None;
      Quoted : Boolean := False;
      --  Whether the last block was in a quote.
   end record;

end Markdown_Export;
