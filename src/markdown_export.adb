with Ada.Containers.Vectors;
with Texts;

package body Markdown_Export is

   use type Texts.Paragraph_Kind;
   use type Ada.Strings.Unbounded.Unbounded_String;

   package Unbounded renames Ada.Strings.Unbounded;
   package Docs renames Texts.Documents;

   Bullet_Mark : constant String :=
     [Character'Val (16#E2#), Character'Val (16#80#), Character'Val (16#A2#), ' '];
   --  What the editor puts before an item of a bulleted list.

   Em_Space : constant String := "&emsp;";
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
            elsif Line_Start and then C = ')' and then Each > Words'First
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
            when ' '    => Unbounded.Append (Made, "%20");
            when '('    => Unbounded.Append (Made, "%28");
            when ')'    => Unbounded.Append (Made, "%29");
            when '<'    => Unbounded.Append (Made, "%3C");
            when '>'    => Unbounded.Append (Made, "%3E");
            when others => Unbounded.Append (Made, C);
         end case;
      end loop;
      return Unbounded.To_String (Made);
   end Address_Of;

   type Mark is (Underlined, Struck, Bold, Italic, Linked);
   --  In the order they are opened, outermost first.

   type Mark_Set is array (Mark) of Boolean;

   type Piece is record
      Words   : Unbounded.Unbounded_String;
      Marks   : Mark_Set := [others => False];
      Address : Unbounded.Unbounded_String;
   end record;

   function Same (Left, Right : Piece) return Boolean is
     (Left.Marks = Right.Marks and then Left.Address = Right.Address);

   package Piece_Vectors is new Ada.Containers.Vectors (Positive, Piece);
   package Cut_Vectors is new Ada.Containers.Vectors (Positive, Positive);
   package Cut_Sorting is new Cut_Vectors.Generic_Sorting;

   function Repeated (Unit : String; Times : Natural) return String is
      Made : Unbounded.Unbounded_String;
   begin
      for Each in 1 .. Times loop
         Unbounded.Append (Made, Unit);
      end loop;
      return Unbounded.To_String (Made);
   end Repeated;

   function Is_Blank (Words : String) return Boolean is (for all C of Words => C in ' ' | ASCII.HT);

   --  The inline Markdown for the pieces of a paragraph, with marks opened and closed as they change.
   function Inline (Pieces : Piece_Vectors.Vector; Plain : Boolean) return String is
      Made    : Unbounded.Unbounded_String;
      Open    : array (1 .. Mark'Pos (Mark'Last) + 1) of Mark;
      Depth   : Natural := 0;
      Where   : Unbounded.Unbounded_String;  --  of the open link
      Pending : Unbounded.Unbounded_String;  --  space waiting to be put outside the marks that close
      Begun   : Boolean := False;

      function Opening (Which : Mark) return String is
        (case Which is
            when Underlined => "<u>",
            when Struck     => "~~",
            when Bold       => "**",
            when Italic     => "*",
            when Linked     => "[");

      function Closing (Which : Mark) return String is
        (case Which is
            when Underlined => "</u>",
            when Struck     => "~~",
            when Bold       => "**",
            when Italic     => "*",
            when Linked     => "](" & Address_Of (Unbounded.To_String (Where)) & ")");

      procedure Reach (Wanted : Mark_Set; Address : Unbounded.Unbounded_String) is
         Keep : Natural := 0;
      begin
         while Keep < Depth and then Wanted (Open (Keep + 1))
           and then (Open (Keep + 1) /= Linked or else Address = Where)
         loop
            Keep := Keep + 1;
         end loop;
         while Depth > Keep loop
            Unbounded.Append (Made, Closing (Open (Depth)));
            Depth := Depth - 1;
         end loop;
         Unbounded.Append (Made, Pending);
         Pending := Unbounded.Null_Unbounded_String;
         for Each in Mark loop
            if Wanted (Each) and then not (for some I in 1 .. Depth => Open (I) = Each) then
               Depth := Depth + 1;
               Open (Depth) := Each;
               if Each = Linked then
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
            Marks : Mark_Set := Each.Marks;
         begin
            if Plain then
               Marks (Bold) := False;
            end if;
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
                  Unbounded.Append
                    (Made, Escaped (Words (First .. Last), Line_Start => not Begun and then Depth = 0));
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

   function Separator (Into : Writer; Last : Blocks; Quoted : Boolean) return String is
     (if Into.Last = None then ""
      elsif Last in Bullet_Item | Number_Item and then Into.Last = Last and then Into.Quoted = Quoted then ""
      elsif Quoted and then Into.Quoted then ">" & ASCII.LF
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
         Put
           (Into, [1 .. Level => '#'] & ' ' & Escaped (Title, Line_Start => False), Other, Quoted => False);
      end if;
   end Add_Heading;

   --  The pieces of paragraph Para from byte Start: cut where a format begins or ends.
   function Pieces_Of
     (Item : Docs.Document; Para : Positive; Start : Positive) return Piece_Vectors.Vector
   is
      Stop   : constant Positive := Docs.Byte_Length (Item, Para) + 1;
      Result : Piece_Vectors.Vector;
      Cuts   : Cut_Vectors.Vector;
   begin
      Cuts.Append (Start);
      Cuts.Append (Stop);
      for Index in 1 .. Docs.Run_Count (Item) loop
         declare
            R : constant Docs.Format_Run := Docs.Run (Item, Index);
         begin
            if R.From.Paragraph <= Para and then Para <= R.To.Paragraph then
               Cuts.Append (Natural'Max (Start, (if R.From.Paragraph = Para then R.From.Index else 1)));
               Cuts.Append (Natural'Min (Stop, (if R.To.Paragraph = Para then R.To.Index else Stop)));
            end if;
         end;
      end loop;
      Cut_Sorting.Sort (Cuts);
      for Each in Cuts.First_Index .. Cuts.Last_Index - 1 loop
         declare
            From : constant Positive := Cuts (Each);
            To   : constant Positive := Cuts (Each + 1);
            Part : Piece;
         begin
            if From < To then
               Part.Words := Unbounded.To_Unbounded_String (Docs.Slice (Item, Para, From, To));
               for Index in 1 .. Docs.Run_Count (Item) loop
                  declare
                     R : constant Docs.Format_Run := Docs.Run (Item, Index);
                     Covers : constant Boolean :=
                       R.From.Paragraph <= Para and then Para <= R.To.Paragraph
                       and then (R.From.Paragraph < Para or else R.From.Index <= From)
                       and then (R.To.Paragraph > Para or else To <= R.To.Index);
                  begin
                     if Covers then
                        case R.Style is
                           when Docs.Bold          => Part.Marks (Bold) := True;
                           when Docs.Italic        => Part.Marks (Italic) := True;
                           when Docs.Underline     => Part.Marks (Underlined) := True;
                           when Docs.Strikethrough => Part.Marks (Struck) := True;
                           when Docs.Linked        =>
                              Part.Marks (Linked) := True;
                              Part.Address := R.Name;
                           when Docs.Faded | Docs.Sized | Docs.Faced | Docs.Versioned =>
                              null;
                        end case;
                     end if;
                  end;
               end loop;
               if not Result.Is_Empty and then Same (Result.Last_Element, Part) then
                  Unbounded.Append (Result (Result.Last_Index).Words, Part.Words);
               else
                  Result.Append (Part);
               end if;
            end if;
         end;
      end loop;
      return Result;
   end Pieces_Of;

   procedure Add_Document (Into : in out Writer; Item : Docs.Document) is
   begin
      for Para in 1 .. Docs.Count (Item) loop
         declare
            Line   : constant String := Docs.Text (Item, Para);
            Kind   : constant Texts.Paragraph_Kind := Docs.Kind (Item, Para);
            Inset  : constant Texts.Paragraph_Inset := Docs.Inset (Item, Para);
            Lead   : Natural := 0;
            Skip   : Natural := 0;
            Which  : Blocks := Other;
            Figures : Natural := 0;
            Number : Unbounded.Unbounded_String;
         begin
            if Kind = Texts.Plain or else Kind > Texts.Heading_3 then
               while Lead < Line'Length and then Line (Line'First + Lead) = ' ' loop
                  Lead := Lead + 1;
               end loop;
               declare
                  Rest : constant String := Line (Line'First + Lead .. Line'Last);
               begin
                  if Rest'Length >= Bullet_Mark'Length
                    and then Rest (Rest'First .. Rest'First + Bullet_Mark'Length - 1) = Bullet_Mark
                  then
                     Which := Bullet_Item;
                     Skip := Lead + Bullet_Mark'Length;
                  else
                     while Figures < Rest'Length and then Rest (Rest'First + Figures) in '0' .. '9' loop
                        Figures := Figures + 1;
                     end loop;
                     if Figures > 0 and then Rest'Length >= Figures + 2
                       and then Rest (Rest'First + Figures .. Rest'First + Figures + 1) = ". "
                     then
                        Which := Number_Item;
                        Skip := Lead + Figures + 2;
                        Number := Unbounded.To_Unbounded_String (Rest (Rest'First .. Rest'First + Figures - 1));
                     end if;
                  end if;
               end;
            end if;
            if not Is_Blank (Line (Line'First + Skip .. Line'Last)) then
               declare
                  Heading : constant Boolean := Kind in Texts.Heading_1 .. Texts.Heading_3;
                  Body_Text : constant String :=
                    Inline (Pieces_Of (Item, Para, Skip + 1), Plain => Heading);
                  Quote   : constant String := (if Inset.Quoted then "> " else "");
                  Marker  : constant String :=
                    (case Which is
                        when Bullet_Item => "- ",
                        when Number_Item => Unbounded.To_String (Number) & ". ",
                        when others      => "");
                  Nest    : constant String :=
                    (if Which in Bullet_Item | Number_Item then Repeated (Indent_Step, Inset.Indent)
                     elsif not Heading then Repeated (Em_Space, Inset.Indent)
                     else "");
                  Hashes  : constant String :=
                    (if Heading then [1 .. Natural (Kind) => '#'] & ' ' else "");
               begin
                  if Body_Text /= "" then
                     Put (Into, Quote & Nest & Marker & Hashes & Body_Text, Which, Inset.Quoted);
                  end if;
               end;
            end if;
         end;
      end loop;
   end Add_Document;

   function Text (From : Writer) return String is (Unbounded.To_String (From.Output));

   function Of_Document (Item : Docs.Document) return String is
      Made : Writer;
   begin
      Add_Document (Made, Item);
      return Text (Made);
   end Of_Document;

end Markdown_Export;
