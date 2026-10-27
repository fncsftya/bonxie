with Texts.Documents;

--  Rich text as a Word document (Office Open XML, WordprocessingML), written by hand: headings, paragraphs, bold,
--  italic, underline, strikethrough, links, bulleted and numbered lists (a numbered list starts at the figure its
--  first item was typed with, and each list apart from the last begins again), quoted blocks in the Quote style,
--  and indented text. A list has Word's nine levels; deeper items stay at the ninth.

package Exports.Docx is

   function Of_Document (Item : Texts.Documents.Document; Title : String) return String;
   --  The bytes of the file, Title its title.

end Exports.Docx;
