with Ada.Strings.Equal_Case_Insensitive;
with Ada.Strings.Unbounded;
with JSON.Parsers;
with JSON.Types;

package body Outline_Generation is

   package Titles renames Projects.Sections.Title_Texts;
   use Ada.Strings.Unbounded;

   package JSON_Types is new JSON.Types (Long_Long_Integer, Long_Float);
   package JSON_Parsers is new JSON.Parsers (JSON_Types, Default_Maximum_Depth => 16);

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
      use JSON_Types;

      function Object_End (Text : String; First : Positive) return Natural is
         Depth : Natural := 0;
         Quoted, Escaped : Boolean := False;
      begin
         for Index in First .. Text'Last loop
            declare
               C : constant Character := Text (Index);
            begin
               if Quoted then
                  if Escaped then
                     Escaped := False;
                  elsif C = '\' then
                     Escaped := True;
                  elsif C = '"' then
                     Quoted := False;
                  end if;
               elsif C = '"' then
                  Quoted := True;
               elsif C = '{' then
                  Depth := Depth + 1;
               elsif C = '}' then
                  Depth := Depth - 1;
                  if Depth = 0 then
                     return Index;
                  end if;
               end if;
            end;
         end loop;
         return 0;
      end Object_End;

      procedure Add_Title (Words : String; At_Index : out Natural) is
         Clean : String := Words;
      begin
         At_Index := 0;
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
            Result.Items (Result.Count) :=
              (Title => Titles.To_Bounded_String (Clean (First .. Last)), others => <>);
            At_Index := Result.Count;
         end;
      end Add_Title;

      function Bullet (Words : String) return String is
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

      procedure Add_Notes (Notes : JSON_Value; At_Index : Natural) is
         Text : Unbounded_String;
      begin
         if Notes.Kind /= Array_Kind then
            raise JSON_Parsers.Parse_Error;
         end if;
         if At_Index = 0 then
            return;
         end if;
         for Each of Notes loop
            if Each.Kind /= String_Kind then
               raise JSON_Parsers.Parse_Error;
            end if;
            declare
               Line : constant String := Bullet (Each.Value);
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
         end loop;
         Result.Items (At_Index).Notes :=
           Projects.Sections.Note_Texts.To_Bounded_String (To_String (Text));
      end Add_Notes;

      First : Natural := Reply'First;
      Last  : Natural;
   begin
      Result.Count := 0;
      Valid := False;
      while First <= Reply'Last and then Reply (First) /= '{' loop
         First := First + 1;
      end loop;
      if First > Reply'Last then
         return;
      end if;
      Last := Object_End (Reply, First);
      if Last = 0 then
         return;
      end if;
      declare
         Parser : JSON_Parsers.Parser :=
           JSON_Parsers.Create (Reply (First .. Last), Maximum_Depth => 16);
         Root : constant JSON_Value := Parser.Parse;
      begin
         if Root.Kind /= Object_Kind or else not Root.Contains ("sections") then
            return;
         end if;
         declare
            Sections : constant JSON_Value := Root ("sections");
         begin
            if Sections.Kind /= Array_Kind then
               return;
            end if;
            for Section of Sections loop
               if Section.Kind /= Object_Kind or else not Section.Contains ("title") then
                  raise JSON_Parsers.Parse_Error;
               end if;
               declare
                  Title : constant JSON_Value := Section ("title");
                  At_Index : Natural := 0;
               begin
                  if Title.Kind /= String_Kind then
                     raise JSON_Parsers.Parse_Error;
                  end if;
                  Add_Title (Title.Value, At_Index);
                  if Section.Contains ("notes") then
                     Add_Notes (Section ("notes"), At_Index);
                  end if;
               end;
            end loop;
         end;
         Valid := Result.Count > 0;
      end;
   exception
      --  Including what is wrong with the reply as a whole, found as it is parsed.
      when JSON_Parsers.Parse_Error | JSON_Types.Invalid_Type_Error | Constraint_Error | Program_Error =>
         Result.Count := 0;
         Valid := False;
   end Parse;

end Outline_Generation;
