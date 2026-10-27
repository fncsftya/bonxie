with Exports;

package body Markdown_Export is

   use type Ada.Strings.Unbounded.Unbounded_String;
   use type Exports.Block_Kinds;
   use type Exports.Mark;

   package Unbounded renames Ada.Strings.Unbounded;
   package Ex renames Exports;

   Em_Space    : constant String := "&emsp;";
   Indent_Step : constant String := "    ";

   function Escaped (Words : String; Line_Start : Boolean) return String is
      Made : Unbounded.Unbounded_String;
   begin
      for Each in Words'Range loop
         declare
            C : constant Character := Words (Each);
         begin
            if C in '\' | '`' | '*' | '_' | '[' | ']' | '<' | '>' | '~' then
               Unbounded.Append (Made, '\');
            elsif Line_Start and then Each = Words'First and then C in '#' | '+' | '-' | '=' then
               Unbounded.Append (Made, '\');
            elsif Line_Start
              and then C = ')'
              and then Each > Words'First
              and then (for all I in Words'First .. Each - 1 => Words (I) in '0' .. '9')
            then
               Unbounded.Append (Made, '\');
            end if;
            Unbounded.Append (Made, C);
         end;
      end loop;
      return Unbounded.To_String (Made);
   end Escaped;

   function Address_Of (Raw : String) return String is
      Made : Unbounded.Unbounded_String;
   begin
      for C of Raw loop
         case C is
            when ' '    =>
               Unbounded.Append (Made, "%20");

            when '('    =>
               Unbounded.Append (Made, "%28");

            when ')'    =>
               Unbounded.Append (Made, "%29");

            when '<'    =>
               Unbounded.Append (Made, "%3C");

            when '>'    =>
               Unbounded.Append (Made, "%3E");

            when others =>
               Unbounded.Append (Made, C);
         end case;
      end loop;
      return Unbounded.To_String (Made);
   end Address_Of;

   function Repeated (Unit : String; Times : Natural) return String is
      Made : Unbounded.Unbounded_String;
   begin
      for Each in 1 .. Times loop
         Unbounded.Append (Made, Unit);
      end loop;
      return Unbounded.To_String (Made);
   end Repeated;

   function Is_Blank (Words : String) return Boolean
   is (for all C of Words => C in ' ' | ASCII.HT);
   --  Of what is at the edge of a span: not the line feeds that Exports.Is_Blank counts.

   --  The inline Markdown for the pieces of a paragraph, with marks opened and closed as they change.
   function Inline (Pieces : Ex.Span_Vectors.Vector) return String is
      Made    : Unbounded.Unbounded_String;
      Open    : array (1 .. Ex.Mark'Pos (Ex.Mark'Last) + 1) of Ex.Mark;
      Depth   : Natural := 0;
      Where   : Unbounded.Unbounded_String;  --  of the open link
      Pending : Unbounded.Unbounded_String;  --  space waiting to be put outside the marks that close
      Begun   : Boolean := False;

      function Opening (Which : Ex.Mark) return String
      is (case Which is
            when Ex.Underlined => "<u>",
            when Ex.Struck     => "~~",
            when Ex.Bold       => "**",
            when Ex.Italic     => "*",
            when Ex.Linked     => "[");

      function Closing (Which : Ex.Mark) return String
      is (case Which is
            when Ex.Underlined => "</u>",
            when Ex.Struck     => "~~",
            when Ex.Bold       => "**",
            when Ex.Italic     => "*",
            when Ex.Linked     => "](" & Address_Of (Unbounded.To_String (Where)) & ")");

      procedure Reach (Wanted : Ex.Mark_Set; Address : Unbounded.Unbounded_String) is
         Keep : Natural := 0;
      begin
         while Keep < Depth
           and then Wanted (Open (Keep + 1))
           and then (Open (Keep + 1) /= Ex.Linked or else Address = Where)
         loop
            Keep := Keep + 1;
         end loop;
         while Depth > Keep loop
            Unbounded.Append (Made, Closing (Open (Depth)));
            Depth := Depth - 1;
         end loop;
         Unbounded.Append (Made, Pending);
         Pending := Unbounded.Null_Unbounded_String;
         for Each in Ex.Mark loop
            if Wanted (Each) and then not (for some I in 1 .. Depth => Open (I) = Each) then
               Depth := Depth + 1;
               Open (Depth) := Each;
               if Each = Ex.Linked then
                  Where := Address;
               end if;
               Unbounded.Append (Made, Opening (Each));
            end if;
         end loop;
      end Reach;
   begin
      for Each of Pieces loop
         declare
            Words : constant String := Unbounded.To_String (Each.Words);
            First : Positive := Words'First;
            Last  : Natural := Words'Last;
            Marks : constant Ex.Mark_Set := Each.Marks;
         begin
            while First <= Last and then Words (First) in ' ' | ASCII.HT loop
               First := First + 1;
            end loop;
            while Last >= First and then Words (Last) in ' ' | ASCII.HT loop
               Last := Last - 1;
            end loop;
            if First > Last then
               if Begun then
                  Unbounded.Append (Pending, Words);
               end if;
            else
               declare
                  Lead : constant String := (if Begun then Words (Words'First .. First - 1) else "");
               begin
                  Unbounded.Append (Pending, Lead);
                  Reach (Marks, Each.Address);
                  Unbounded.Append (Made, Escaped (Words (First .. Last), Line_Start => not Begun and then Depth = 0));
                  Begun := True;
                  Pending := Unbounded.To_Unbounded_String (Words (Last + 1 .. Words'Last));
               end;
            end if;
         end;
      end loop;
      Pending := Unbounded.Null_Unbounded_String;
      Reach ([others => False], Unbounded.Null_Unbounded_String);
      return Unbounded.To_String (Made);
   end Inline;

   function Separator (Into : Writer; Last : Blocks; Quoted : Boolean) return String
   is (if Into.Last = None
       then ""
       elsif Last in Bullet_Item | Number_Item and then Into.Last = Last and then Into.Quoted = Quoted
       then ""
       elsif Quoted and then Into.Quoted
       then ">" & ASCII.LF
       else String'[1 => ASCII.LF]);

   procedure Put (Into : in out Writer; Line : String; Last : Blocks; Quoted : Boolean) is
   begin
      Unbounded.Append (Into.Output, Separator (Into, Last, Quoted) & Line & ASCII.LF);
      Into.Last := Last;
      Into.Quoted := Quoted;
   end Put;

   procedure Add_Heading (Into : in out Writer; Level : Heading_Level; Title : String) is
   begin
      if not Is_Blank (Title) then
         Put (Into, [1 .. Level => '#'] & ' ' & Escaped (Title, Line_Start => False), Other, Quoted => False);
      end if;
   end Add_Heading;

   procedure Add_Document (Into : in out Writer; Item : Texts.Documents.Document) is
   begin
      for Each of Ex.Blocks_Of (Item) loop
         declare
            Heading : constant Boolean := Each.Kind = Ex.Heading;
            Which   : constant Blocks :=
              (case Each.Kind is
                 when Ex.Bullet => Bullet_Item,
                 when Ex.Number => Number_Item,
                 when others    => Other);
            Quote   : constant String := (if Each.Quoted then "> " else "");
            Marker  : constant String :=
              (case Each.Kind is
                 when Ex.Bullet => "- ",
                 when Ex.Number => Unbounded.To_String (Each.Figure) & ". ",
                 when others    => "");
            Nest    : constant String :=
              (if Each.Kind in Ex.Bullet | Ex.Number
               then Repeated (Indent_Step, Each.Indent)
               elsif not Heading
               then Repeated (Em_Space, Each.Indent)
               else "");
            Hashes  : constant String := (if Heading then [1 .. Each.Level => '#'] & ' ' else "");
            Words   : constant String := Inline (Each.Spans);
         begin
            if Words /= "" then
               Put (Into, Quote & Nest & Marker & Hashes & Words, Which, Each.Quoted);
            end if;
         end;
      end loop;
   end Add_Document;

   function Text (From : Writer) return String
   is (Unbounded.To_String (From.Output));

   function Of_Document (Item : Texts.Documents.Document) return String is
      Made : Writer;
   begin
      Add_Document (Made, Item);
      return Text (Made);
   end Of_Document;

end Markdown_Export;
