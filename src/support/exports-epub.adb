with Ada.Containers;
with Ada.Strings.Hash;
with Exports.HTML;
with Exports.Zips;

package body Exports.Epub is

   Prolog : constant String := "<?xml version=""1.0"" encoding=""UTF-8""?>" & ASCII.LF;

   Container : constant String :=
     Prolog
     & "<container version=""1.0"" xmlns=""urn:oasis:names:tc:opendocument:xmlns:container"">"
     & "<rootfiles><rootfile full-path=""OEBPS/content.opf"" media-type=""application/oebps-package+xml""/>"
     & "</rootfiles></container>"
     & ASCII.LF;

   Style : constant String :=
     "body{font-family:Georgia,serif;line-height:1.5}"
     & ASCII.LF
     & "blockquote{margin:1em 0 1em 1em;padding-left:1em;border-left:3px solid #bbb}"
     & ASCII.LF;

   function Image (Value : Natural) return String is
      Text : constant String := Natural'Image (Value);
   begin
      return Text (Text'First + 1 .. Text'Last);
   end Image;

   use type Ada.Containers.Hash_Type;

   function Hex (Value : Ada.Containers.Hash_Type) return String is
      Digits_Of : constant String := "0123456789abcdef";
   begin
      return [for Each in 1 .. 8 => Digits_Of (Digits_Of'First + Natural ((Value / 16**(8 - Each)) mod 16))];
   end Hex;

   function Page (Body_Text : String; Title : String) return String
   is (Prolog
       & "<html xmlns=""http://www.w3.org/1999/xhtml"" xml:lang=""en"" lang=""en"">"
       & ASCII.LF
       & "<head><meta charset=""utf-8""/><title>"
       & Escaped (Title)
       & "</title><link rel=""stylesheet"" type=""text/css"" href=""style.css""/></head>"
       & ASCII.LF
       & "<body>"
       & ASCII.LF
       & Body_Text
       & "</body>"
       & ASCII.LF
       & "</html>"
       & ASCII.LF);

   type Part is record
      Title  : Unbounded.Unbounded_String;
      Blocks : Block_Vectors.Vector;
   end record;

   package Part_Vectors is new Ada.Containers.Vectors (Positive, Part);

   --  The blocks of the document cut into the chapters, a chapter from its paragraph to the next one's.
   function Parts_Of
     (Item : Texts.Documents.Document; Title : String; Chapters : Chapter_Vectors.Vector) return Part_Vectors.Vector
   is
      Starts : Chapter_Vectors.Vector := Chapters;
      Result : Part_Vectors.Vector;
      Whole  : constant Block_Vectors.Vector := Blocks_Of (Item);
   begin
      if Starts.Is_Empty or else Starts.First_Element.First > 1 then
         Starts.Prepend (Chapter'(First => 1, Title => Unbounded.To_Unbounded_String (Title)));
      end if;
      for Index in Starts.First_Index .. Starts.Last_Index loop
         declare
            Made : Part := (Title => Starts (Index).Title, Blocks => <>);
         begin
            for Each of Whole loop
               if Each.Para >= Starts (Index).First
                 and then (Index = Starts.Last_Index or else Each.Para < Starts (Index + 1).First)
               then
                  Made.Blocks.Append (Each);
               end if;
            end loop;
            if not Made.Blocks.Is_Empty then
               Result.Append (Made);
            end if;
         end;
      end loop;
      if Result.Is_Empty then
         Result.Append (Part'(Title => Unbounded.To_Unbounded_String (Title), Blocks => <>));
      end if;
      return Result;
   end Parts_Of;

   function File_Of (Chapter_Number : Positive) return String
   is ("chapter-" & Image (Chapter_Number) & ".xhtml");

   --  The chapters in order, each a link with the headings in it below.
   function Navigation (Parts : Part_Vectors.Vector; Title : String) return String is
      Made : Unbounded.Unbounded_String;
   begin
      for Index in Parts.First_Index .. Parts.Last_Index loop
         declare
            Count : Natural := 0;
            Inner : Unbounded.Unbounded_String;
         begin
            for Each of Parts (Index).Blocks loop
               if Each.Kind = Heading then
                  Count := Count + 1;
                  Unbounded.Append
                    (Inner,
                     "<li><a href="""
                     & File_Of (Index)
                     & "#s"
                     & Image (Count)
                     & """>"
                     & Escaped (Words_Of (Each))
                     & "</a></li>");
               end if;
            end loop;
            Unbounded.Append
              (Made,
               "<li><a href="""
               & File_Of (Index)
               & """>"
               & Escaped (Unbounded.To_String (Parts (Index).Title))
               & "</a>"
               & (if Count > 0 then "<ol>" & Unbounded.To_String (Inner) & "</ol>" else "")
               & "</li>");
         end;
      end loop;
      return
        Prolog
        & "<html xmlns=""http://www.w3.org/1999/xhtml"" xmlns:epub=""http://www.idpf.org/2007/ops"" "
        & "xml:lang=""en"" lang=""en"">"
        & ASCII.LF
        & "<head><meta charset=""utf-8""/><title>"
        & Escaped (Title)
        & "</title></head>"
        & ASCII.LF
        & "<body><nav epub:type=""toc""><h1>Contents</h1><ol>"
        & Unbounded.To_String (Made)
        & "</ol></nav></body>"
        & ASCII.LF
        & "</html>"
        & ASCII.LF;
   end Navigation;

   function Of_Document
     (Item     : Texts.Documents.Document;
      Title    : String;
      Chapters : Chapter_Vectors.Vector := Chapter_Vectors.Empty_Vector;
      Modified : String := "2026-01-01T00:00:00Z") return String
   is
      Parts    : constant Part_Vectors.Vector := Parts_Of (Item, Title, Chapters);
      Book     : Exports.Zips.Archive;
      Manifest : Unbounded.Unbounded_String;
      Spine    : Unbounded.Unbounded_String;
      Seed     : Unbounded.Unbounded_String := Unbounded.To_Unbounded_String (Title);

      function Words_Of_Chapter (Index : Positive) return String
      is (Exports.HTML.Body_Of (Parts (Index).Blocks));
   begin
      for Index in Parts.First_Index .. Parts.Last_Index loop
         Unbounded.Append
           (Seed, ASCII.NUL & Unbounded.To_String (Parts (Index).Title) & ASCII.NUL & Words_Of_Chapter (Index));
         Unbounded.Append
           (Manifest,
            "<item id=""c"
            & Image (Index)
            & """ href="""
            & File_Of (Index)
            & """ media-type=""application/xhtml+xml""/>");
         Unbounded.Append (Spine, "<itemref idref=""c" & Image (Index) & """/>");
      end loop;
      Exports.Zips.Add (Book, "mimetype", "application/epub+zip");
      Exports.Zips.Add (Book, "META-INF/container.xml", Container);
      Exports.Zips.Add
        (Book,
         "OEBPS/content.opf",
         Prolog
         & "<package xmlns=""http://www.idpf.org/2007/opf"" version=""3.0"" unique-identifier=""id"" xml:lang=""en"">"
         & ASCII.LF
         & "<metadata xmlns:dc=""http://purl.org/dc/elements/1.1/"">"
         & "<dc:identifier id=""id"">urn:bonxie:"
         & Hex (Ada.Strings.Hash (Unbounded.To_String (Seed)))
         & "</dc:identifier><dc:title>"
         & Escaped (Title)
         & "</dc:title><dc:language>en</dc:language><meta property=""dcterms:modified"">"
         & Escaped (Modified)
         & "</meta></metadata>"
         & ASCII.LF
         & "<manifest><item id=""nav"" href=""nav.xhtml"" media-type=""application/xhtml+xml"" properties=""nav""/>"
         & Unbounded.To_String (Manifest)
         & "<item id=""style"" href=""style.css"" media-type=""text/css""/></manifest>"
         & ASCII.LF
         & "<spine>"
         & Unbounded.To_String (Spine)
         & "</spine></package>"
         & ASCII.LF);
      Exports.Zips.Add (Book, "OEBPS/nav.xhtml", Navigation (Parts, Title));
      for Index in Parts.First_Index .. Parts.Last_Index loop
         Exports.Zips.Add
           (Book,
            "OEBPS/" & File_Of (Index),
            Page (Words_Of_Chapter (Index), Unbounded.To_String (Parts (Index).Title)));
      end loop;
      Exports.Zips.Add (Book, "OEBPS/style.css", Style);
      return Exports.Zips.Image (Book);
   end Of_Document;

end Exports.Epub;
