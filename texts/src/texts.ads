--  Text to edit, held as paragraphs apart from how it is shown: an
--  application owns its documents (Texts.Documents), and views show and
--  edit them, catching up with each other's changes.
--
--  Text is UTF-8, as an Ada String has it, a line to each paragraph.
--  Positions in a paragraph are bytes; CoreText's, for layout, are UTF-16
--  units, which Documents converts to and from.
package Texts is

   type Position is record
      Paragraph : Positive := 1;
      Index     : Positive := 1;  --  the byte of its text it is before
   end record;
   --  Before a character of the text, or at the end of a paragraph.

   function "<" (Left, Right : Position) return Boolean is
     (Left.Paragraph < Right.Paragraph
      or else (Left.Paragraph = Right.Paragraph
               and then Left.Index < Right.Index));

   function End_After (From : Position; Added : String) return Position;
   --  Where Added, a line to each paragraph, ends if put at From.

   type Paragraph_Id is new Positive;
   --  Names a paragraph for as long as it lasts, wherever it moves: a
   --  paragraph's number changes as others come and go before it, its
   --  id does not. Undoing an edit that removed a paragraph brings it
   --  back with its id.

   type Paragraph_Kind is new Natural;
   --  What a paragraph is, as the application sees it: a heading, a line
   --  of dialogue, a note. Texts only keeps it.

   Plain : constant Paragraph_Kind := 0;

   --  UTF-8

   function Is_Continuation (C : Character) return Boolean is
     (Character'Pos (C) in 16#80# .. 16#BF#);

   function Units_Of (Lead : Character) return Natural is
     (case Character'Pos (Lead) is
         when 16#80# .. 16#BF# => 0,  --  not a lead
         when 16#F0# .. 16#FF# => 2,  --  a surrogate pair
         when others           => 1);
   --  The UTF-16 units of the character Lead starts.

   function UTF16_Length (Text : String) return Natural;
   --  How many UTF-16 units the UTF-8 Text takes.

end Texts;
