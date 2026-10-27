with Ada.Containers.Ordered_Sets;
with Ada.Containers.Vectors;
with Exports.Zips;

package body Exports.Odt is

   package Kind_Stacks is new Ada.Containers.Vectors (Positive, Block_Kinds);
   package Indent_Sets is new Ada.Containers.Ordered_Sets (Natural);

   Prolog : constant String := "<?xml version=""1.0"" encoding=""UTF-8""?>" & ASCII.LF;

   Namespaces : constant String :=
     " xmlns:office=""urn:oasis:names:tc:opendocument:xmlns:office:1.0"""
     & " xmlns:style=""urn:oasis:names:tc:opendocument:xmlns:style:1.0"""
     & " xmlns:text=""urn:oasis:names:tc:opendocument:xmlns:text:1.0"""
     & " xmlns:fo=""urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0"""
     & " xmlns:xlink=""http://www.w3.org/1999/xlink"""
     & " xmlns:dc=""http://purl.org/dc/elements/1.1/"""
     & " xmlns:meta=""urn:oasis:names:tc:opendocument:xmlns:meta:1.0""";

   Type_Of_File : constant String := "application/vnd.oasis.opendocument.text";

   Levels : constant := 10;
   --  ODF's list styles have these levels.

   Bullet_Character : constant String := [Character'Val (16#E2#), Character'Val (16#80#), Character'Val (16#A2#)];

   function Image (Value : Natural) return String is
      Text : constant String := Natural'Image (Value);
   begin
      return Text (Text'First + 1 .. Text'Last);
   end Image;

   function Centimetres (Thousandths : Natural) return String is
      Fraction : constant String := Image (1000 + Thousandths mod 1000);
   begin
      return Image (Thousandths / 1000) & "." & Fraction (Fraction'First + 1 .. Fraction'Last) & "cm";
   end Centimetres;

   --  A span's marks as a number, to name its style: Underlined, Struck, Bold, Italic as bits from the highest.
   function Code_Of (Marks : Mark_Set) return Natural
   is (8
       * Boolean'Pos (Marks (Underlined))
       + 4 * Boolean'Pos (Marks (Struck))
       + 2 * Boolean'Pos (Marks (Bold))
       + Boolean'Pos (Marks (Italic)));

   function Text_Style (Code : Positive) return String is
      Under  : constant Boolean := Code / 8 mod 2 = 1;
      Strike : constant Boolean := Code / 4 mod 2 = 1;
      Heavy  : constant Boolean := Code / 2 mod 2 = 1;
      Slant  : constant Boolean := Code mod 2 = 1;
   begin
      return
        "<style:style style:name=""T"
        & Image (Code)
        & """ style:family=""text""><style:text-properties"
        & (if Under
           then
             " style:text-underline-style=""solid"" style:text-underline-width=""auto"""
             & " style:text-underline-color=""font-color"""
           else "")
        & (if Strike then " style:text-line-through-style=""solid""" else "")
        & (if Heavy
           then " fo:font-weight=""bold"" style:font-weight-asian=""bold"" style:font-weight-complex=""bold"""
           else "")
        & (if Slant
           then " fo:font-style=""italic"" style:font-style-asian=""italic"" style:font-style-complex=""italic"""
           else "")
        & "/></style:style>";
   end Text_Style;

   function List_Style (Name : String; Numbered : Boolean) return String is
      Made : Unbounded.Unbounded_String;
      Tag  : constant String := (if Numbered then "number" else "bullet");
   begin
      Unbounded.Append (Made, "<text:list-style style:name=""" & Name & """>");
      for Level in 1 .. Levels loop
         Unbounded.Append
           (Made,
            "<text:list-level-style-"
            & Tag
            & " text:level="""
            & Image (Level)
            & """"
            & (if Numbered
               then " style:num-suffix=""."" style:num-format=""1"""
               else " text:bullet-char=""" & Bullet_Character & """")
            & "><style:list-level-properties text:list-level-position-and-space-mode=""label-alignment"">"
            & "<style:list-level-label-alignment text:label-followed-by=""listtab"" text:list-tab-stop-position="""
            & Centimetres (Level * 635)
            & """ fo:text-indent=""-0.635cm"" fo:margin-left="""
            & Centimetres (Level * 635)
            & """/></style:list-level-properties></text:list-level-style-"
            & Tag
            & ">");
      end loop;
      Unbounded.Append (Made, "</text:list-style>");
      return Unbounded.To_String (Made);
   end List_Style;

   --  The words of a span, with each space after another (or the first of a paragraph) a <text:s/>, which is all
   --  ODF keeps of a run of spaces.
   function Spaced (Words : String; After_Space : in out Boolean) return String is
      Made : Unbounded.Unbounded_String;
   begin
      for C of Escaped (Words) loop
         if C = ' ' then
            Unbounded.Append (Made, (if After_Space then "<text:s/>" else " "));
            After_Space := True;
         elsif C = ASCII.HT then
            Unbounded.Append (Made, "<text:tab/>");
            After_Space := True;
         else
            Unbounded.Append (Made, C);
            After_Space := False;
         end if;
      end loop;
      return Unbounded.To_String (Made);
   end Spaced;

   type Used_Styles is array (1 .. 15) of Boolean;

   function Inline (Spans : Span_Vectors.Vector; Used : in out Used_Styles) return String is
      Made  : Unbounded.Unbounded_String;
      After : Boolean := True;
   begin
      for Each of Spans loop
         declare
            Code : constant Natural := Code_Of (Each.Marks);
            Text : constant String := Spaced (Unbounded.To_String (Each.Words), After);
            Part : constant String :=
              (if Code = 0
               then Text
               else "<text:span text:style-name=""T" & Image (Code) & """>" & Text & "</text:span>");
         begin
            if Code /= 0 then
               Used (Code) := True;
            end if;
            Unbounded.Append
              (Made,
               (if Each.Marks (Linked)
                then
                  "<text:a xlink:type=""simple"" xlink:href="""
                  & Escaped (Unbounded.To_String (Each.Address))
                  & """>"
                  & Part
                  & "</text:a>"
                else Part));
         end;
      end loop;
      return Unbounded.To_String (Made);
   end Inline;

   --  The figure an item of a numbered list was typed with, if it is not 1: the number its list should start at.
   function Start_Of (Figure : String) return String
   is (if Figure'Length in 1 .. 9 and then Figure /= "1"
       then " text:start-value=""" & Image (Natural'Value (Figure)) & """"
       else "");

   function Content (Item : Texts.Documents.Document) return String is
      Made     : Unbounded.Unbounded_String;
      Lists    : Kind_Stacks.Vector;
      Used     : Used_Styles := [others => False];
      Indented : Indent_Sets.Set;
      Quoted   : Indent_Sets.Set;
      Styles   : Unbounded.Unbounded_String;

      function Tag (Kind : Block_Kinds) return String
      is (if Kind = Number then "LN" else "LB");

      procedure Close_Lists (Down_To : Natural) is
      begin
         while Natural (Lists.Length) > Down_To loop
            Unbounded.Append (Made, "</text:list-item></text:list>");
            Lists.Delete_Last;
         end loop;
      end Close_Lists;

      procedure Reach_Item (Kind : Block_Kinds; Level : Positive; Figure : String) is
      begin
         Close_Lists (Level);
         if Natural (Lists.Length) = Level and then Lists.Last_Element = Kind then
            Unbounded.Append (Made, "</text:list-item><text:list-item>");
            return;
         end if;
         Close_Lists (Level - 1);
         while Natural (Lists.Length) < Level loop
            Unbounded.Append
              (Made,
               "<text:list text:style-name="""
               & Tag (Kind)
               & """><text:list-item"
               & (if Natural (Lists.Length) = Level - 1 and then Kind = Number then Start_Of (Figure) else "")
               & ">");
            Lists.Append (Kind);
         end loop;
      end Reach_Item;
   begin
      for Each of Blocks_Of (Item) loop
         if Each.Kind not in Bullet | Number then
            Close_Lists (0);
         end if;
         case Each.Kind is
            when Heading         =>
               Unbounded.Append
                 (Made,
                  "<text:h text:style-name=""Heading_20_"
                  & Image (Each.Level)
                  & """ text:outline-level="""
                  & Image (Each.Level)
                  & """>"
                  & Inline (Each.Spans, Used)
                  & "</text:h>");

            when Paragraph       =>
               declare
                  Style : constant String :=
                    (if Each.Quoted
                     then (if Each.Indent = 0 then "Quotations" else "PQ" & Image (Each.Indent))
                     else (if Each.Indent = 0 then "Standard" else "PI" & Image (Each.Indent)));
               begin
                  if Each.Indent > 0 and then Each.Quoted then
                     Quoted.Include (Each.Indent);
                  elsif Each.Indent > 0 then
                     Indented.Include (Each.Indent);
                  end if;
                  Unbounded.Append
                    (Made, "<text:p text:style-name=""" & Style & """>" & Inline (Each.Spans, Used) & "</text:p>");
               end;

            when Bullet | Number =>
               Reach_Item (Each.Kind, Natural'Min (Each.Indent + 1, Levels), Unbounded.To_String (Each.Figure));
               Unbounded.Append
                 (Made, "<text:p text:style-name=""Standard"">" & Inline (Each.Spans, Used) & "</text:p>");
         end case;
      end loop;
      Close_Lists (0);
      for Code in Used'Range loop
         if Used (Code) then
            Unbounded.Append (Styles, Text_Style (Code));
         end if;
      end loop;
      for Each of Indented loop
         Unbounded.Append
           (Styles,
            "<style:style style:name=""PI"
            & Image (Each)
            & """ style:family=""paragraph"" "
            & "style:parent-style-name=""Standard""><style:paragraph-properties fo:margin-left="""
            & Centimetres (Each * 1000)
            & """/></style:style>");
      end loop;
      for Each of Quoted loop
         Unbounded.Append
           (Styles,
            "<style:style style:name=""PQ"
            & Image (Each)
            & """ style:family=""paragraph"" "
            & "style:parent-style-name=""Quotations""><style:paragraph-properties fo:margin-left="""
            & Centimetres ((Each + 1) * 1000)
            & """/></style:style>");
      end loop;
      return
        Prolog
        & "<office:document-content"
        & Namespaces
        & " office:version=""1.3""><office:automatic-styles>"
        & Unbounded.To_String (Styles)
        & List_Style ("LB", Numbered => False)
        & List_Style ("LN", Numbered => True)
        & "</office:automatic-styles><office:body><office:text>"
        & Unbounded.To_String (Made)
        & "</office:text></office:body></office:document-content>"
        & ASCII.LF;
   end Content;

   function Heading_Style (Level : Heading_Level) return String
   is ("<style:style style:name=""Heading_20_"
       & Image (Level)
       & """ style:display-name=""Heading "
       & Image (Level)
       & """ style:family=""paragraph"" style:parent-style-name=""Standard"" style:next-style-name=""Standard"" "
       & "style:default-outline-level="""
       & Image (Level)
       & """><style:paragraph-properties fo:margin-top=""0.4cm"" fo:margin-bottom=""0.2cm"" "
       & "fo:keep-with-next=""always""/><style:text-properties fo:font-size="""
       & Image (24 - 4 * Level)
       & "pt"" fo:font-weight=""bold"" style:font-weight-asian=""bold"" style:font-weight-complex=""bold""/>"
       & "</style:style>");

   Styles : constant String :=
     Prolog
     & "<office:document-styles"
     & Namespaces
     & " office:version=""1.3""><office:styles>"
     & "<style:default-style style:family=""paragraph""><style:text-properties fo:font-size=""12pt""/>"
     & "</style:default-style>"
     & "<style:style style:name=""Standard"" style:family=""paragraph"" style:class=""text"">"
     & "<style:paragraph-properties fo:margin-top=""0cm"" fo:margin-bottom=""0.3cm""/></style:style>"
     & Heading_Style (1)
     & Heading_Style (2)
     & Heading_Style (3)
     & "<style:style style:name=""Quotations"" style:family=""paragraph"" style:parent-style-name=""Standard"" "
     & "style:class=""html""><style:paragraph-properties fo:margin-left=""1cm"" fo:padding-left=""0.3cm"" "
     & "fo:border-left=""0.06cm solid #bbbbbb"" fo:border-top=""none"" fo:border-right=""none"" "
     & "fo:border-bottom=""none""/></style:style>"
     & "</office:styles></office:document-styles>"
     & ASCII.LF;

   Manifest : constant String :=
     Prolog
     & "<manifest:manifest xmlns:manifest=""urn:oasis:names:tc:opendocument:xmlns:manifest:1.0"" "
     & "manifest:version=""1.3"">"
     & "<manifest:file-entry manifest:full-path=""/"" manifest:version=""1.3"" manifest:media-type="""
     & Type_Of_File
     & """/>"
     & "<manifest:file-entry manifest:full-path=""content.xml"" manifest:media-type=""text/xml""/>"
     & "<manifest:file-entry manifest:full-path=""styles.xml"" manifest:media-type=""text/xml""/>"
     & "<manifest:file-entry manifest:full-path=""meta.xml"" manifest:media-type=""text/xml""/>"
     & "</manifest:manifest>"
     & ASCII.LF;

   function Of_Document (Item : Texts.Documents.Document; Title : String) return String is
      File : Exports.Zips.Archive;
   begin
      Exports.Zips.Add (File, "mimetype", Type_Of_File);
      Exports.Zips.Add (File, "META-INF/manifest.xml", Manifest);
      Exports.Zips.Add (File, "content.xml", Content (Item));
      Exports.Zips.Add (File, "styles.xml", Styles);
      Exports.Zips.Add
        (File,
         "meta.xml",
         Prolog
         & "<office:document-meta"
         & Namespaces
         & " office:version=""1.3""><office:meta><dc:title>"
         & Escaped (Title)
         & "</dc:title><meta:generator>Bonxie</meta:generator></office:meta></office:document-meta>"
         & ASCII.LF);
      return Exports.Zips.Image (File);
   end Of_Document;

end Exports.Odt;
