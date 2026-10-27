with Texts.Documents;

--  Rich text as an OpenDocument text file (ODF 1.3), written by hand: headings, paragraphs, bold, italic,
--  underline, strikethrough, links, nested bulleted and numbered lists (a numbered list starts at the figure its
--  first item was typed with), quoted paragraphs with a rule along the left, and indented text. A heading or a
--  list's item is not set apart as quoted, as ODF has no quote round them. Lists have the ten levels ODF's list
--  styles do; deeper items stay at the tenth.

package Exports.Odt is

   function Of_Document (Item : Texts.Documents.Document; Title : String) return String;
   --  The bytes of the file, Title its title.

end Exports.Odt;
