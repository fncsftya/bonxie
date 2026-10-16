with Ada.Strings.Equal_Case_Insensitive;
with Ada.Strings.Unbounded;

package body Outline_Generation is

   package Titles renames Projects.Sections.Title_Texts;
   use Ada.Strings.Unbounded;

   Max_Depth : constant := 16;
   --  How deep the JSON that is passed over may go.

   function Prompt
     (Title, Description : String;
      Existing           : Projects.Sections.Section_List) return String
   is
      Text : Unbounded_String;
   begin
      Append (Text, "Title: " & (if Title = "" then "(none yet)" else Title) & LF & LF);
      Append (Text, "Description:" & LF & (if Description = "" then "(none yet)" else Description) & LF & LF);
      if Existing.Count = 0 then
         Append (Text, "There are no sections yet." & LF & LF);
      else
         Append (Text, "The sections so far, which the outline keeps:" & LF);
         for Each in 1 .. Existing.Count loop
            Append
              (Text,
               Each'Image & ". " & Titles.To_String (Existing.Items (Each).Title) & LF);
         end loop;
         Append (Text, LF);
      end if;
      Append
        (Text,
         "Plan the full outline of this project, and reply with the JSON object of its sections, "
         & "in order, and nothing else.");
      return To_String (Text);
   end Prompt;

   procedure Parse
     (Reply  : String;
      Result : out Projects.Sections.Section_List;
      Valid  : out Boolean)
   is
      Malformed : exception;

      Pos : Natural := Reply'First;
      --  The next byte to read.

      Found : Boolean := False;
      --  Whether the object had its list of sections.

      function Peek return Character is
        (if Pos <= Reply'Last then Reply (Pos) else Character'Val (0));

      procedure Skip_Blank is
      begin
         while Pos <= Reply'Last and then Reply (Pos) in ' ' | Character'Val (9) | Character'Val (10)
           | Character'Val (13)
         loop
            Pos := Pos + 1;
         end loop;
      end Skip_Blank;

      procedure Expect (Wanted : Character) is
      begin
         Skip_Blank;
         if Peek /= Wanted then
            raise Malformed;
         end if;
         Pos := Pos + 1;
      end Expect;

      function Hex4 return Natural is
         Code : Natural := 0;
      begin
         for Each in 1 .. 4 loop
            if Pos > Reply'Last then
               raise Malformed;
            end if;
            Code := Code * 16
              + (case Reply (Pos) is
                    when '0' .. '9' => Character'Pos (Reply (Pos)) - Character'Pos ('0'),
                    when 'a' .. 'f' => Character'Pos (Reply (Pos)) - Character'Pos ('a') + 10,
                    when 'A' .. 'F' => Character'Pos (Reply (Pos)) - Character'Pos ('A') + 10,
                    when others     => raise Malformed);
            Pos := Pos + 1;
         end loop;
         return Code;
      end Hex4;

      procedure Append_Code (Text : in out Unbounded_String; Code : Natural) is
         procedure Byte (Value : Natural) is
         begin
            Append (Text, Character'Val (Value));
         end Byte;
      begin
         if Code < 16#80# then
            Byte (Code);
         elsif Code < 16#800# then
            Byte (16#C0# + Code / 64);
            Byte (16#80# + Code mod 64);
         elsif Code < 16#10000# then
            Byte (16#E0# + Code / 4096);
            Byte (16#80# + Code / 64 mod 64);
            Byte (16#80# + Code mod 64);
         else
            Byte (16#F0# + Code / 262_144);
            Byte (16#80# + Code / 4096 mod 64);
            Byte (16#80# + Code / 64 mod 64);
            Byte (16#80# + Code mod 64);
         end if;
      end Append_Code;

      function Read_String return String is
         Text : Unbounded_String;
      begin
         Expect ('"');
         loop
            if Pos > Reply'Last then
               raise Malformed;
            end if;
            declare
               Here : constant Character := Reply (Pos);
            begin
               Pos := Pos + 1;
               case Here is
                  when '"' =>
                     exit;
                  when Character'Val (0) .. Character'Val (31) =>
                     raise Malformed;
                  when '\' =>
                     if Pos > Reply'Last then
                        raise Malformed;
                     end if;
                     declare
                        Escaped : constant Character := Reply (Pos);
                     begin
                        Pos := Pos + 1;
                        case Escaped is
                           when '"' | '\' | '/' => Append (Text, Escaped);
                           when 'b' => Append (Text, Character'Val (8));
                           when 'f' => Append (Text, Character'Val (12));
                           when 'n' => Append (Text, Character'Val (10));
                           when 'r' => Append (Text, Character'Val (13));
                           when 't' => Append (Text, Character'Val (9));
                           when 'u' =>
                              declare
                                 Code : Natural := Hex4;
                              begin
                                 if Code in 16#D800# .. 16#DBFF# then
                                    --  The first half of a pair: the second follows.
                                    if Pos + 1 > Reply'Last or else Reply (Pos) /= '\'
                                      or else Reply (Pos + 1) /= 'u'
                                    then
                                       raise Malformed;
                                    end if;
                                    Pos := Pos + 2;
                                    declare
                                       Low : constant Natural := Hex4;
                                    begin
                                       if Low not in 16#DC00# .. 16#DFFF# then
                                          raise Malformed;
                                       end if;
                                       Code := 16#10000# + (Code - 16#D800#) * 1024 + (Low - 16#DC00#);
                                    end;
                                 elsif Code in 16#DC00# .. 16#DFFF# then
                                    raise Malformed;
                                 end if;
                                 Append_Code (Text, Code);
                              end;
                           when others => raise Malformed;
                        end case;
                     end;
                  when others =>
                     Append (Text, Here);
               end case;
            end;
         end loop;
         return To_String (Text);
      end Read_String;

      procedure Skip_Literal (Word : String) is
      begin
         if Pos + Word'Length - 1 > Reply'Last or else Reply (Pos .. Pos + Word'Length - 1) /= Word then
            raise Malformed;
         end if;
         Pos := Pos + Word'Length;
      end Skip_Literal;

      procedure Skip_Value (Depth : Natural);
      --  Pass over a value that is of no use.

      procedure Skip_Value (Depth : Natural) is
         Digits_Seen : Boolean := False;
      begin
         if Depth > Max_Depth then
            raise Malformed;
         end if;
         Skip_Blank;
         case Peek is
            when '"' =>
               declare
                  Ignored : constant String := Read_String;
               begin
                  pragma Unreferenced (Ignored);
               end;
            when '{' =>
               Pos := Pos + 1;
               Skip_Blank;
               if Peek = '}' then
                  Pos := Pos + 1;
               else
                  loop
                     declare
                        Ignored : constant String := Read_String;
                     begin
                        pragma Unreferenced (Ignored);
                     end;
                     Expect (':');
                     Skip_Value (Depth + 1);
                     Skip_Blank;
                     if Peek = ',' then
                        Pos := Pos + 1;
                     else
                        Expect ('}');
                        exit;
                     end if;
                  end loop;
               end if;
            when '[' =>
               Pos := Pos + 1;
               Skip_Blank;
               if Peek = ']' then
                  Pos := Pos + 1;
               else
                  loop
                     Skip_Value (Depth + 1);
                     Skip_Blank;
                     if Peek = ',' then
                        Pos := Pos + 1;
                     else
                        Expect (']');
                        exit;
                     end if;
                  end loop;
               end if;
            when 't' => Skip_Literal ("true");
            when 'f' => Skip_Literal ("false");
            when 'n' => Skip_Literal ("null");
            when '-' | '0' .. '9' =>
               while Pos <= Reply'Last and then Reply (Pos) in '0' .. '9' | '-' | '+' | '.' | 'e' | 'E' loop
                  Digits_Seen := Digits_Seen or else Reply (Pos) in '0' .. '9';
                  Pos := Pos + 1;
               end loop;
               if not Digits_Seen then
                  raise Malformed;
               end if;
            when others =>
               raise Malformed;
         end case;
      end Skip_Value;

      Added_At : Natural := 0;
      --  Where the last title added went in Result; 0 if it was left out.

      procedure Add_Title (Words : String) is
         Clean : String := Words;
      begin
         Added_At := 0;
         for Each of Clean loop
            if Character'Pos (Each) < 32 then
               Each := ' ';
            end if;
         end loop;
         declare
            First : Positive := Clean'First;
            Last  : Natural := Clean'Last;
         begin
            while First <= Last and then Clean (First) = ' ' loop
               First := First + 1;
            end loop;
            while Last >= First and then Clean (Last) = ' ' loop
               Last := Last - 1;
            end loop;
            if First > Last or else Result.Count = Projects.Sections.Max_Sections then
               return;
            end if;
            --  Not more than fits, nor part of a character.
            if Last - First + 1 > Projects.Sections.Max_Title then
               Last := First + Projects.Sections.Max_Title - 1;
               while Last >= First and then Character'Pos (Clean (Last + 1)) in 16#80# .. 16#BF# loop
                  Last := Last - 1;
               end loop;
            end if;
            for Each in 1 .. Result.Count loop
               if Ada.Strings.Equal_Case_Insensitive
                    (Titles.To_String (Result.Items (Each).Title), Clean (First .. Last))
               then
                  return;
               end if;
            end loop;
            Result.Count := Result.Count + 1;
            Result.Items (Result.Count) := (Title => Titles.To_Bounded_String (Clean (First .. Last)), others => <>);
            Added_At := Result.Count;
         end;
      end Add_Title;

      function Bullet (Words : String) return String is
         --  The note as a line, without what is blank or a control character.
         Clean : String := Words;
         First : Positive := Clean'First;
         Last  : Natural := Clean'Last;
      begin
         for Each of Clean loop
            if Character'Pos (Each) < 32 then
               Each := ' ';
            end if;
         end loop;
         while First <= Last and then Clean (First) = ' ' loop
            First := First + 1;
         end loop;
         while Last >= First and then Clean (Last) = ' ' loop
            Last := Last - 1;
         end loop;
         return (if First > Last then "" else "- " & Clean (First .. Last));
      end Bullet;

      function Read_Notes return String is
         --  A list of strings, as bullets, a line each, whole lines only.
         Text : Unbounded_String;
      begin
         Expect ('[');
         Skip_Blank;
         if Peek = ']' then
            Pos := Pos + 1;
            return "";
         end if;
         loop
            Skip_Blank;
            declare
               Line : constant String := Bullet (Read_String);
               Room : constant Integer :=
                 Projects.Sections.Max_Notes - Length (Text) - (if Length (Text) > 0 then 1 else 0);
            begin
               if Line /= "" and then Line'Length <= Room then
                  if Length (Text) > 0 then
                     Append (Text, LF);
                  end if;
                  Append (Text, Line);
               end if;
            end;
            Skip_Blank;
            if Peek = ',' then
               Pos := Pos + 1;
            else
               Expect (']');
               exit;
            end if;
         end loop;
         return To_String (Text);
      end Read_Notes;

      procedure Read_Section is
         Titled : Boolean := False;
         Notes  : Unbounded_String;
      begin
         Expect ('{');
         Skip_Blank;
         if Peek = '}' then
            raise Malformed;
         end if;
         loop
            declare
               Key : constant String := Read_String;
            begin
               Expect (':');
               if Key = "title" then
                  Skip_Blank;
                  Add_Title (Read_String);
                  Titled := True;
                  if Length (Notes) > 0 and then Added_At /= 0 then
                     --  The notes came first: they are of this title.
                     Result.Items (Added_At).Notes :=
                       Projects.Sections.Note_Texts.To_Bounded_String (To_String (Notes));
                  end if;
               elsif Key = "notes" then
                  Skip_Blank;
                  Notes := To_Unbounded_String (Read_Notes);
                  if Titled and then Added_At /= 0 then
                     Result.Items (Added_At).Notes :=
                       Projects.Sections.Note_Texts.To_Bounded_String (To_String (Notes));
                  end if;
               else
                  Skip_Value (3);
               end if;
            end;
            Skip_Blank;
            if Peek = ',' then
               Pos := Pos + 1;
            else
               Expect ('}');
               exit;
            end if;
         end loop;
         if not Titled then
            raise Malformed;
         end if;
      end Read_Section;

      procedure Read_Sections is
      begin
         Expect ('[');
         Skip_Blank;
         if Peek = ']' then
            Pos := Pos + 1;
            return;
         end if;
         loop
            Read_Section;
            Skip_Blank;
            if Peek = ',' then
               Pos := Pos + 1;
            else
               Expect (']');
               exit;
            end if;
         end loop;
      end Read_Sections;

      procedure Read_Object is
      begin
         Expect ('{');
         Skip_Blank;
         if Peek = '}' then
            raise Malformed;
         end if;
         loop
            declare
               Key : constant String := Read_String;
            begin
               Expect (':');
               if Key = "sections" and then not Found then
                  Read_Sections;
                  Found := True;
               else
                  Skip_Value (2);
               end if;
            end;
            Skip_Blank;
            if Peek = ',' then
               Pos := Pos + 1;
            else
               Expect ('}');
               exit;
            end if;
         end loop;
      end Read_Object;
   begin
      Result.Count := 0;
      Valid := False;
      while Pos <= Reply'Last and then Reply (Pos) /= '{' loop
         Pos := Pos + 1;
      end loop;
      Read_Object;
      Valid := Found and then Result.Count > 0;
   exception
      when Malformed =>
         Result.Count := 0;
         Valid := False;
   end Parse;

end Outline_Generation;
