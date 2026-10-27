with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ebook;
with Ebook.Zip;
with Exports.Docx;
with Exports.Epub;
with Exports.HTML;
with Exports.Odt;
with Exports.Pdf;
with Exports.Plain;
with Files;
with Goldens;
with Texts.Documents;

package body Export_Tests is

   procedure Check (Name : String; Expected, Actual : String) renames Goldens.Check_Text;

   LF  : constant Character := ASCII.LF;
   Dot : constant String := [Character'Val (16#E2#), Character'Val (16#80#), Character'Val (16#A2#), ' '];

   procedure Sample (Doc : in out Texts.Documents.Document) is
   begin
      Texts.Documents.Load_Stored
        (Doc,
         "<version>1</version><p k=""1"">Title &amp; more</p>"
         & "<p>plain <b>bold</b> and <i>ital</i><u>under</u><s>strike</s> <a h=""https://x.org/a?b=1&amp;c=2"">link</a>"
         & " &lt;tag&gt;</p>"
         & "<p>"
         & Dot
         & "one</p><p i=""1"">"
         & Dot
         & "nested</p><p>"
         & Dot
         & "two</p><p>1. first</p><p>2. second</p>"
         & "<p q=""1"">quoted</p><p q=""1"">more</p><p i=""2"">indented</p><p></p>"
         & "<p k=""2""><b>Head</b></p><p><z n=""20"">big</z><f> faded</f></p>");
   end Sample;

   procedure Plain is
      Doc : Texts.Documents.Document;
   begin
      Sample (Doc);
      Check
        ("export-plain",
         "Title & more"
         & LF
         & LF
         & "plain bold and italunderstrike link <tag>"
         & LF
         & LF
         & Dot
         & "one"
         & LF
         & "  "
         & Dot
         & "nested"
         & LF
         & Dot
         & "two"
         & LF
         & LF
         & "1. first"
         & LF
         & "2. second"
         & LF
         & LF
         & "> quoted"
         & LF
         & LF
         & "> more"
         & LF
         & LF
         & "    indented"
         & LF
         & LF
         & "Head"
         & LF
         & LF
         & "big faded"
         & LF,
         Exports.Plain.Of_Document (Doc));
   end Plain;

   procedure HTML is
      Doc : Texts.Documents.Document;
   begin
      Sample (Doc);
      Check
        ("export-html-body",
         "<h1 id=""s1"">Title &amp; more</h1>"
         & LF
         & "<p>plain <b>bold</b> and <i>ital</i><u>under</u><s>strike</s> "
         & "<a href=""https://x.org/a?b=1&amp;c=2"">link</a> &lt;tag&gt;</p>"
         & LF
         & "<ul><li>one<ul><li>nested</li></ul></li><li>two</li></ul>"
         & LF
         & "<ol><li>first</li><li>second</li></ol>"
         & LF
         & "<blockquote>"
         & LF
         & "<p>quoted</p>"
         & LF
         & "<p>more</p>"
         & LF
         & "</blockquote>"
         & LF
         & "<p style=""margin-left:4em"">indented</p>"
         & LF
         & "<h2 id=""s2"">Head</h2>"
         & LF
         & "<p>big faded</p>"
         & LF,
         Exports.HTML.Body_Of (Doc));
      declare
         Page : constant String := Exports.HTML.Page (Doc, "A <title>");
      begin
         Check
           ("export-html-page", "<!DOCTYPE html>" & LF & "<html lang=""en"">", Page (Page'First .. Page'First + 31));
         Check
           ("export-html-title",
            "<title>A &lt;title&gt;</title>",
            Page (Ada.Strings.Fixed.Index (Page, "<title>") .. Ada.Strings.Fixed.Index (Page, "</title>") + 7));
      end;
   end HTML;

   function Part_Of (Path, Name : String) return String is
      Book    : Ebook.Zip.Archive;
      Ok      : Boolean;
      Last    : Natural;
      Message : String (1 .. Ebook.Max_Message);
   begin
      Ebook.Zip.Open (Book, Path, Ok, Message, Last);
      Check ("export-opens-" & Name, "TRUE", Ok'Image);
      return Words : constant String := Ebook.Zip.Read (Book, Name) do
         Ebook.Zip.Close (Book);
      end return;
   end Part_Of;

   procedure Has (Name, Whole, Part : String) is
   begin
      Check (Name, "found", (if Ada.Strings.Fixed.Index (Whole, Part) > 0 then "found" else "missing " & Part));
   end Has;

   function Chapters_At
     (Start_1 : Positive;
      Name_1  : String;
      Start_2 : Natural := 0;
      Name_2  : String := "";
      Start_3 : Natural := 0;
      Name_3  : String := "") return Exports.Epub.Chapter_Vectors.Vector
   is
      Made : Exports.Epub.Chapter_Vectors.Vector;

      procedure Add (Start : Natural; Name : String) is
      begin
         if Start > 0 then
            Made.Append
              (Exports.Epub.Chapter'(First => Start, Title => Ada.Strings.Unbounded.To_Unbounded_String (Name)));
         end if;
      end Add;
   begin
      Add (Start_1, Name_1);
      Add (Start_2, Name_2);
      Add (Start_3, Name_3);
      return Made;
   end Chapters_At;

   procedure Epub is
      Doc  : Texts.Documents.Document;
      Path : constant String := Goldens.Scratch ("export.epub");

      function Body_Of_Page (Page : String) return String
      is (Ada.Strings.Fixed.Trim
            (Page (Ada.Strings.Fixed.Index (Page, "<body>") + 7 .. Ada.Strings.Fixed.Index (Page, "</body>") - 1),
             Ada.Strings.Right));

      procedure Write_Book (Chapters : Exports.Epub.Chapter_Vectors.Vector) is
      begin
         Files.Write (Path, Exports.Epub.Of_Document (Doc, "A & B", Chapters));
      end Write_Book;
   begin
      Sample (Doc);
      Write_Book (Exports.Epub.Chapter_Vectors.Empty_Vector);
      Check ("export-epub-mimetype", "application/epub+zip", Part_Of (Path, "mimetype"));
      Check ("export-epub-text", Exports.HTML.Body_Of (Doc), Body_Of_Page (Part_Of (Path, "OEBPS/chapter-1.xhtml")));
      Has
        ("export-epub-one-chapter-nav",
         Part_Of (Path, "OEBPS/nav.xhtml"),
         "<li><a href=""chapter-1.xhtml"">A &amp; B</a><ol><li><a href=""chapter-1.xhtml#s1"">Title &amp; more</a>");
      --  The paragraphs are the title (1) to the empty one (11), then "Head" (12) and its text.
      Write_Book (Chapters_At (1, "First", 12, "Second & last"));
      declare
         First  : constant String := Body_Of_Page (Part_Of (Path, "OEBPS/chapter-1.xhtml"));
         Second : constant String := Body_Of_Page (Part_Of (Path, "OEBPS/chapter-2.xhtml"));
         Nav    : constant String := Part_Of (Path, "OEBPS/nav.xhtml");
      begin
         Has ("export-epub-chapter-first", First, "Title &amp; more");
         Check ("export-epub-chapter-first-ends", "TRUE", Boolean'Image (Ada.Strings.Fixed.Index (First, "Head") = 0));
         Check ("export-epub-chapter-second", "<h2 id=""s1"">Head</h2>" & LF & "<p>big faded</p>" & LF, Second);
         Has
           ("export-epub-chapter-nav",
            Nav,
            "<li><a href=""chapter-2.xhtml"">Second &amp; last</a><ol><li><a href=""chapter-2.xhtml#s1"">Head</a>");
      end;
      Has
        ("export-epub-chapter-spine",
         Part_Of (Path, "OEBPS/content.opf"),
         "<spine><itemref idref=""c1""/><itemref idref=""c2""/></spine>");
      Write_Book (Chapters_At (12, "Late"));
      Has
        ("export-epub-before-first-chapter",
         Part_Of (Path, "OEBPS/nav.xhtml"),
         "<a href=""chapter-1.xhtml"">A &amp; B</a>");
      Has ("export-epub-late-chapter", Part_Of (Path, "OEBPS/nav.xhtml"), "<a href=""chapter-2.xhtml"">Late</a>");
      Write_Book (Chapters_At (1, "One", 11, "Nothing", 12, "Two"));
      Check
        ("export-epub-empty-chapter-left-out",
         "<spine><itemref idref=""c1""/><itemref idref=""c2""/></spine>",
         Ada.Strings.Fixed.Trim
           (Part_Of (Path, "OEBPS/content.opf")
              (Ada.Strings.Fixed.Index (Part_Of (Path, "OEBPS/content.opf"), "<spine>")
               .. Ada.Strings.Fixed.Index (Part_Of (Path, "OEBPS/content.opf"), "</spine>") + 7),
            Ada.Strings.Both));
   end Epub;

   procedure Odt is
      Doc  : Texts.Documents.Document;
      Path : constant String := Goldens.Scratch ("export.odt");
   begin
      Sample (Doc);
      Files.Write (Path, Exports.Odt.Of_Document (Doc, "A & B"));
      Check ("export-odt-mimetype", "application/vnd.oasis.opendocument.text", Part_Of (Path, "mimetype"));
      declare
         Content : constant String := Part_Of (Path, "content.xml");
      begin
         Has
           ("export-odt-heading",
            Content,
            "<text:h text:style-name=""Heading_20_1"" text:outline-level=""1"">Title &amp; more</text:h>");
         Has
           ("export-odt-marks",
            Content,
            "<text:span text:style-name=""T2"">bold</text:span> and "
            & "<text:span text:style-name=""T1"">ital</text:span>"
            & "<text:span text:style-name=""T8"">under</text:span>"
            & "<text:span text:style-name=""T4"">strike</text:span>");
         Has
           ("export-odt-link",
            Content,
            "<text:a xlink:type=""simple"" xlink:href=""https://x.org/a?b=1&amp;c=2"">link</text:a>");
         Has
           ("export-odt-nested-list",
            Content,
            "<text:list text:style-name=""LB""><text:list-item><text:p text:style-name=""Standard"">one</text:p>"
            & "<text:list text:style-name=""LB""><text:list-item><text:p text:style-name=""Standard"">nested</text:p>"
            & "</text:list-item></text:list></text:list-item><text:list-item>");
         Has ("export-odt-numbered", Content, "<text:list text:style-name=""LN""><text:list-item><text:p");
         Has ("export-odt-quote", Content, "<text:p text:style-name=""Quotations"">quoted</text:p>");
         Has ("export-odt-indent", Content, "<text:p text:style-name=""PI2"">indented</text:p>");
      end;
      Has ("export-odt-title", Part_Of (Path, "meta.xml"), "<dc:title>A &amp; B</dc:title>");
   end Odt;

   procedure Docx is
      Doc  : Texts.Documents.Document;
      Path : constant String := Goldens.Scratch ("export.docx");
   begin
      Sample (Doc);
      Files.Write (Path, Exports.Docx.Of_Document (Doc, "A & B"));
      declare
         Content : constant String := Part_Of (Path, "word/document.xml");
      begin
         Has ("export-docx-heading", Content, "<w:pStyle w:val=""Heading1""/>");
         Has ("export-docx-marks", Content, "<w:rPr><w:b/></w:rPr><w:t xml:space=""preserve"">bold</w:t>");
         Has ("export-docx-link", Content, "<w:hyperlink r:id=""rId4"">");
         Has ("export-docx-quote", Content, "<w:pStyle w:val=""Quote""/>");
         Has ("export-docx-indent", Content, "<w:ind w:left=""1440""/>");
         Has ("export-docx-nested-list", Content, "<w:ilvl w:val=""1""/><w:numId w:val=""1""/>");
         Has ("export-docx-numbered", Content, "<w:numId w:val=""2""/>");
      end;
      Has
        ("export-docx-link-target",
         Part_Of (Path, "word/_rels/document.xml.rels"),
         "Target=""https://x.org/a?b=1&amp;c=2"" TargetMode=""External""");
      Has ("export-docx-numbering", Part_Of (Path, "word/numbering.xml"), "<w:num w:numId=""2"">");
      Has ("export-docx-title", Part_Of (Path, "docProps/core.xml"), "<dc:title>A &amp; B</dc:title>");
   end Docx;

   procedure Pdf is
      Doc     : Texts.Documents.Document;
      Path    : constant String := Goldens.Scratch ("export.pdf");
      Found   : Ebook.Information;
      Message : String (1 .. Ebook.Max_Message);
      Last    : Natural;
      Long    : Ada.Strings.Unbounded.Unbounded_String;
   begin
      Sample (Doc);
      Files.Write (Goldens.Scratch ("export-sample.pdf"), Exports.Pdf.Of_Document (Doc, "A & B"));
      Has ("export-pdf-link", Files.Read (Goldens.Scratch ("export-sample.pdf")), "/Subtype /Link");
      Ebook.Open (Goldens.Scratch ("export-sample.pdf"), Found, Message, Last);
      Check ("export-pdf-pages", "1", Ada.Strings.Fixed.Trim (Found.Pages'Image, Ada.Strings.Left));
      Check ("export-pdf-title", "A & B", Found.Title (1 .. Found.Last));
      for Each in 1 .. 120 loop
         Ada.Strings.Unbounded.Append
           (Long, "<p>Paragraph " & Each'Image & ": the quick brown fox jumps over the lazy dog, again and again.</p>");
      end loop;
      Texts.Documents.Load_Stored (Doc, "<version>1</version>" & Ada.Strings.Unbounded.To_String (Long));
      Files.Write (Path, Exports.Pdf.Of_Document (Doc, "Long", Exports.Pdf.A4));
      Ebook.Open (Path, Found, Message, Last);
      Check ("export-pdf-many-pages", "several", (if Found.Pages > 2 then "several" else "few"));
      Texts.Documents.Load (Doc, "");
      Files.Write (Path, Exports.Pdf.Of_Document (Doc, "Empty"));
      Ebook.Open (Path, Found, Message, Last);
      Check ("export-pdf-empty", "1", Ada.Strings.Fixed.Trim (Found.Pages'Image, Ada.Strings.Left));
   end Pdf;

end Export_Tests;
