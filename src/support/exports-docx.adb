with Exports.Zips;

package body Exports.Docx is

   Prolog : constant String := "<?xml version=""1.0"" encoding=""UTF-8"" standalone=""yes""?>" & ASCII.LF;

   Main_Namespace : constant String := "http://schemas.openxmlformats.org/wordprocessingml/2006/main";

   Relationships : constant String := "http://schemas.openxmlformats.org/officeDocument/2006/relationships";

   Package_Relationships : constant String := "http://schemas.openxmlformats.org/package/2006/relationships";

   Levels : constant := 9;
   --  Word's levels of a list.

   Step : constant := 720;
   --  Twentieths of a point (half an inch) to a step of indent, and to a level of a list.

   function Image (Value : Natural) return String is
      Text : constant String := Natural'Image (Value);
   begin
      return Text (Text'First + 1 .. Text'Last);
   end Image;

   function Run (Words : String; Marks : Mark_Set) return String
   is ("<w:r><w:rPr>"
       & (if Marks (Linked) then "<w:rStyle w:val=""Hyperlink""/>" else "")
       & (if Marks (Bold) then "<w:b/>" else "")
       & (if Marks (Italic) then "<w:i/>" else "")
       & (if Marks (Struck) then "<w:strike/>" else "")
       & (if Marks (Underlined) or else Marks (Linked) then "<w:u w:val=""single""/>" else "")
       & "</w:rPr><w:t xml:space=""preserve"">"
       & Escaped (Words)
       & "</w:t></w:r>");

   function Properties (Style : String; List : Natural; Level : Natural; Indent : Natural) return String
   is ("<w:pPr>"
       & (if Style /= "" then "<w:pStyle w:val=""" & Style & """/>" else "")
       & (if List > 0
          then "<w:numPr><w:ilvl w:val=""" & Image (Level) & """/><w:numId w:val=""" & Image (List) & """/></w:numPr>"
          else "")
       & (if Indent > 0 then "<w:ind w:left=""" & Image (Indent * Step) & """/>" else "")
       & "</w:pPr>");

   function Abstract_List (Id : Natural; Numbered : Boolean) return String is
      Made : Unbounded.Unbounded_String;
   begin
      Unbounded.Append
        (Made, "<w:abstractNum w:abstractNumId=""" & Image (Id) & """><w:multiLevelType w:val=""hybridMultilevel""/>");
      for Level in 0 .. Levels - 1 loop
         Unbounded.Append
           (Made,
            "<w:lvl w:ilvl="""
            & Image (Level)
            & """><w:start w:val=""1""/><w:numFmt w:val="""
            & (if Numbered then "decimal" else "bullet")
            & """/><w:lvlText w:val="""
            & (if Numbered then "%" & Image (Level + 1) & "." else "&#8226;")
            & """/><w:lvlJc w:val=""left""/><w:pPr><w:ind w:left="""
            & Image ((Level + 1) * Step)
            & """ w:hanging=""360""/></w:pPr></w:lvl>");
      end loop;
      Unbounded.Append (Made, "</w:abstractNum>");
      return Unbounded.To_String (Made);
   end Abstract_List;

   function Heading_Style (Level : Heading_Level) return String
   is ("<w:style w:type=""paragraph"" w:styleId=""Heading"
       & Image (Level)
       & """><w:name w:val=""heading "
       & Image (Level)
       & """/><w:basedOn w:val=""Normal""/><w:next w:val=""Normal""/><w:qFormat/><w:pPr><w:keepNext/>"
       & "<w:spacing w:before=""240"" w:after=""120""/><w:outlineLvl w:val="""
       & Image (Level - 1)
       & """/></w:pPr><w:rPr><w:b/><w:sz w:val="""
       & Image (2 * (24 - 4 * Level))
       & """/></w:rPr></w:style>");

   Styles : constant String :=
     Prolog
     & "<w:styles xmlns:w="""
     & Main_Namespace
     & """><w:docDefaults><w:rPrDefault><w:rPr><w:sz w:val=""24""/></w:rPr></w:rPrDefault>"
     & "<w:pPrDefault><w:pPr><w:spacing w:after=""160"" w:line=""276"" w:lineRule=""auto""/></w:pPr></w:pPrDefault>"
     & "</w:docDefaults>"
     & "<w:style w:type=""paragraph"" w:default=""1"" w:styleId=""Normal""><w:name w:val=""Normal""/><w:qFormat/>"
     & "</w:style>"
     & Heading_Style (1)
     & Heading_Style (2)
     & Heading_Style (3)
     & "<w:style w:type=""paragraph"" w:styleId=""Quote""><w:name w:val=""Quote""/><w:basedOn w:val=""Normal""/>"
     & "<w:qFormat/><w:pPr><w:pBdr><w:left w:val=""single"" w:sz=""12"" w:space=""8"" w:color=""BBBBBB""/></w:pBdr>"
     & "<w:ind w:left=""720""/></w:pPr></w:style>"
     & "<w:style w:type=""character"" w:styleId=""Hyperlink""><w:name w:val=""Hyperlink""/><w:rPr>"
     & "<w:color w:val=""0563C1""/></w:rPr></w:style>"
     & "</w:styles>"
     & ASCII.LF;

   Content_Types : constant String :=
     Prolog
     & "<Types xmlns=""http://schemas.openxmlformats.org/package/2006/content-types"">"
     & "<Default Extension=""rels"" ContentType=""application/vnd.openxmlformats-package.relationships+xml""/>"
     & "<Default Extension=""xml"" ContentType=""application/xml""/>"
     & "<Override PartName=""/word/document.xml"" ContentType="
     & """application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml""/>"
     & "<Override PartName=""/word/styles.xml"" ContentType="
     & """application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml""/>"
     & "<Override PartName=""/word/numbering.xml"" ContentType="
     & """application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml""/>"
     & "<Override PartName=""/docProps/core.xml"" ContentType="
     & """application/vnd.openxmlformats-package.core-properties+xml""/>"
     & "</Types>"
     & ASCII.LF;

   Root_Relationships : constant String :=
     Prolog
     & "<Relationships xmlns="""
     & Package_Relationships
     & """><Relationship Id=""rId1"" Type="""
     & Relationships
     & "/officeDocument"" Target=""word/document.xml""/>"
     & "<Relationship Id=""rId2"" Type=""http://schemas.openxmlformats.org/package/2006/relationships/metadata/"
     & "core-properties"" Target=""docProps/core.xml""/></Relationships>"
     & ASCII.LF;

   function Of_Document (Item : Texts.Documents.Document; Title : String) return String is
      Made                   : Unbounded.Unbounded_String;
      Links                  : Unbounded.Unbounded_String;
      Lists                  : Unbounded.Unbounded_String;
      Link_Count, List_Count : Natural := 0;
      Previous               : Block_Kinds := Paragraph;
      Number_Id              : Natural := 0;

      function Inline (Spans : Span_Vectors.Vector) return String is
         Part : Unbounded.Unbounded_String;
      begin
         for Each of Spans loop
            declare
               Words : constant String := Unbounded.To_String (Each.Words);
            begin
               if Each.Marks (Linked) then
                  Link_Count := Link_Count + 1;
                  Unbounded.Append
                    (Links,
                     "<Relationship Id=""rId"
                     & Image (Link_Count + 3)
                     & """ Type="""
                     & Relationships
                     & "/hyperlink"" Target="""
                     & Escaped (Unbounded.To_String (Each.Address))
                     & """ TargetMode=""External""/>");
                  Unbounded.Append
                    (Part,
                     "<w:hyperlink r:id=""rId"
                     & Image (Link_Count + 3)
                     & """>"
                     & Run (Words, Each.Marks)
                     & "</w:hyperlink>");
               else
                  Unbounded.Append (Part, Run (Words, Each.Marks));
               end if;
            end;
         end loop;
         return Unbounded.To_String (Part);
      end Inline;
   begin
      for Each of Blocks_Of (Item) loop
         declare
            Level : constant Natural := Natural'Min (Each.Indent, Levels - 1);
         begin
            case Each.Kind is
               when Heading         =>
                  Unbounded.Append
                    (Made,
                     "<w:p>" & Properties ("Heading" & Image (Each.Level), 0, 0, 0) & Inline (Each.Spans) & "</w:p>");

               when Paragraph       =>
                  Unbounded.Append
                    (Made,
                     "<w:p>"
                     & Properties
                         ((if Each.Quoted then "Quote" else ""), 0, 0, (if Each.Quoted then 0 else Each.Indent))
                     & Inline (Each.Spans)
                     & "</w:p>");

               when Bullet | Number =>
                  declare
                     Figure : constant String := Unbounded.To_String (Each.Figure);
                  begin
                     if Each.Kind = Number and then Previous /= Number then
                        List_Count := List_Count + 1;
                        Number_Id := List_Count + 1;
                        Unbounded.Append
                          (Lists,
                           "<w:num w:numId="""
                           & Image (Number_Id)
                           & """><w:abstractNumId w:val=""1""/><w:lvlOverride w:ilvl=""0""><w:startOverride w:val="""
                           & (if Figure'Length in 1 .. 9 then Image (Natural'Value (Figure)) else "1")
                           & """/></w:lvlOverride></w:num>");
                     end if;
                     Unbounded.Append
                       (Made,
                        "<w:p>"
                        & Properties ("", (if Each.Kind = Number then Number_Id else 1), Level, 0)
                        & Inline (Each.Spans)
                        & "</w:p>");
                  end;
            end case;
            Previous := Each.Kind;
         end;
      end loop;
      declare
         File : Exports.Zips.Archive;
      begin
         Exports.Zips.Add (File, "[Content_Types].xml", Content_Types);
         Exports.Zips.Add (File, "_rels/.rels", Root_Relationships);
         Exports.Zips.Add
           (File,
            "word/document.xml",
            Prolog
            & "<w:document xmlns:w="""
            & Main_Namespace
            & """ xmlns:r="""
            & Relationships
            & """><w:body>"
            & Unbounded.To_String (Made)
            & "<w:sectPr><w:pgSz w:w=""12240"" w:h=""15840""/>"
            & "<w:pgMar w:top=""1440"" w:right=""1440"" w:bottom=""1440"" w:left=""1440"" w:header=""720"" "
            & "w:footer=""720"" w:gutter=""0""/></w:sectPr></w:body></w:document>"
            & ASCII.LF);
         Exports.Zips.Add
           (File,
            "word/_rels/document.xml.rels",
            Prolog
            & "<Relationships xmlns="""
            & Package_Relationships
            & """><Relationship Id=""rId1"" Type="""
            & Relationships
            & "/styles"" Target=""styles.xml""/><Relationship Id=""rId2"" Type="""
            & Relationships
            & "/numbering"" Target=""numbering.xml""/>"
            & Unbounded.To_String (Links)
            & "</Relationships>"
            & ASCII.LF);
         Exports.Zips.Add (File, "word/styles.xml", Styles);
         Exports.Zips.Add
           (File,
            "word/numbering.xml",
            Prolog
            & "<w:numbering xmlns:w="""
            & Main_Namespace
            & """>"
            & Abstract_List (0, Numbered => False)
            & Abstract_List (1, Numbered => True)
            & "<w:num w:numId=""1""><w:abstractNumId w:val=""0""/></w:num>"
            & Unbounded.To_String (Lists)
            & "</w:numbering>"
            & ASCII.LF);
         Exports.Zips.Add
           (File,
            "docProps/core.xml",
            Prolog
            & "<cp:coreProperties xmlns:cp=""http://schemas.openxmlformats.org/package/2006/metadata/core-properties"" "
            & "xmlns:dc=""http://purl.org/dc/elements/1.1/""><dc:title>"
            & Escaped (Title)
            & "</dc:title></cp:coreProperties>"
            & ASCII.LF);
         return Exports.Zips.Image (File);
      end;
   end Of_Document;

end Exports.Docx;
