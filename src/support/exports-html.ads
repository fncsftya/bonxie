with Texts.Documents;

--  Rich text as HTML, in the XML form (every tag closed, no entity but the five XML has) that an EPUB's XHTML needs:
--  <p>, <h1> .. <h3> (each with an id, s1, s2, ..., in order), <b>, <i>, <u>, <s>, <a href>, lists as nested <ul> and
--  <ol> (a step of indent a level; a list apart from the next by a block that is not an item), quoted blocks in a
--  <blockquote>, and indented text with a margin of 2em to a step.

package Exports.HTML is

   function Body_Of (Items : Block_Vectors.Vector) return String;
   --  The blocks as elements, to go in a <body>; the headings number from s1.

   function Body_Of (Item : Texts.Documents.Document) return String;
   --  The blocks of Item as elements, to go in a <body>.

   function Page (Item : Texts.Documents.Document; Title : String) return String;
   --  A whole HTML5 page of Body_Of (Item), with Title, in UTF-8, and a style for reading.

end Exports.HTML;
