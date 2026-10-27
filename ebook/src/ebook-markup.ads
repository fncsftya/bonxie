--  A forgiving reader of XML and of the XHTML of e-books (which is often
--  not well formed): the tags, and the text between them, one after the
--  other. Nothing is built from them; the reader goes through the text
--  once, and what it finds points into it.

package Ebook.Markup is

   Max_Name : constant := 32;

   type Kinds is (Start_Tag, End_Tag, Text, Finished);

   type Token is record
      Kind         : Kinds := Finished;
      Name         : String (1 .. Max_Name) := [others => ' '];
      Name_Length  : Natural := 0;
      --  The tag's name, in lower case without a namespace ("dc:title" is
      --  "title"), Name (1 .. Name_Length).
      Self_Closing : Boolean := False;
      First, Last  : Natural := 0;
      --  Of a Start_Tag, where its attributes are in the source; of Text,
      --  where the text is, as written (see Decode).
   end record;

   function Tag (Item : Token) return String
   is (Item.Name (1 .. Item.Name_Length));

   procedure Next (Source : String; Cursor : in out Positive; Item : out Token)
   with Pre => Cursor >= Source'First, Post => Cursor > Cursor'Old or else Item.Kind = Finished;
   --  The token at Cursor, and Cursor moved past it. Comments,
   --  declarations and processing instructions are passed over. The
   --  content of CDATA sections is Text.

   function Attribute (Source : String; Item : Token; Name : String) return String
   with Pre => Item.Kind = Start_Tag;
   --  The value of the attribute of the tag, decoded; "" if it has none.
   --  Name is in lower case and without a namespace ("href").

   function Has_Attribute (Source : String; Item : Token; Name : String) return Boolean
   with Pre => Item.Kind = Start_Tag;

   function Decode (Raw : String) return String;
   --  Raw with its character references (&amp; &#8212; &#x2014;) and the
   --  named entities of HTML replaced by their UTF-8. An unknown one is
   --  left as written.

end Ebook.Markup;
