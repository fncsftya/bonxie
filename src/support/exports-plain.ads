with Texts.Documents;

--  Rich text as plain text: the words of each block, blocks apart by a blank line, a list's items together.
--  Items keep their marks ("• " and "N. "), two spaces to a step of indent; quoted blocks start with "> ".

package Exports.Plain is

   function Of_Document (Item : Texts.Documents.Document) return String
   with Post => Of_Document'Result'Length = 0 or else Of_Document'Result (Of_Document'Result'Last) = ASCII.LF;

end Exports.Plain;
