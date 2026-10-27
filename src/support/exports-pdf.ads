with Texts.Documents;

--  Rich text as a PDF, set in Georgia by CoreText and written by Core Graphics (see exports_pdf.m): headings of three
--  sizes, paragraphs with bold, italic, underline, strikethrough and links that can be followed, bulleted and
--  numbered lists with their levels, quoted paragraphs with a rule along the left, and indented text, on pages of
--  an inch of margin, with the fonts embedded. A character Georgia lacks is set in a font that has it.
--  PDFium, which this program has for reading PDFs, is not used: it cannot make a link, and it does not set text.

package Exports.Pdf is

   type Paper_Sizes is (A4, Letter);

   Failed : exception;
   --  Raised if the system could not make the PDF.

   function Of_Document (Item : Texts.Documents.Document; Title : String; Paper : Paper_Sizes := A4) return String
   with Post => Of_Document'Result'Length >= 8 and then Of_Document'Result (1 .. 5) = "%PDF-";
   --  The bytes of the PDF, Title its title.

end Exports.Pdf;
