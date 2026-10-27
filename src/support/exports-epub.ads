with Ada.Containers.Vectors;
with Texts.Documents;

--  Rich text as an EPUB 3 book: a chapter to each of the Chapters given (the sections of a project), each an XHTML
--  file of Exports.HTML's body, a navigation document listing the chapters with the headings in each, and a style.
--  An EPUB's XML is written by hand, to the letter of the EPUB 3.3 package: mimetype first and stored, then
--  META-INF/container.xml and OEBPS/.

package Exports.Epub is

   type Chapter is record
      First : Positive := 1;
      --  The paragraph of the document it starts at.
      Title : Unbounded.Unbounded_String;
   end record;

   package Chapter_Vectors is new Ada.Containers.Vectors (Positive, Chapter);

   function Of_Document
     (Item     : Texts.Documents.Document;
      Title    : String;
      Chapters : Chapter_Vectors.Vector := Chapter_Vectors.Empty_Vector;
      Modified : String := "2026-01-01T00:00:00Z") return String
   with
     Pre =>
       (for all I in Chapters.First_Index .. Chapters.Last_Index - 1 => Chapters (I).First < Chapters (I + 1).First);
   --  The bytes of the book, Title its title and Modified when it was made (UTC, as the package says
   --  dcterms:modified). Chapters start at their paragraphs, in order; what is before the first is a chapter
   --  called Title, as is the whole if there are none. A chapter with nothing in it is left out. Its identifier is
   --  made from what it holds, so the same document is the same book.

end Exports.Epub;
