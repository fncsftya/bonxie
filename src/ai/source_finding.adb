with Ada.Strings.Equal_Case_Insensitive;
with JSON.Parsers;
with JSON.Types;
with Model_Replies;

package body Source_Finding is

   package JSON_Types is new JSON.Types (Long_Long_Integer, Long_Float);
   package JSON_Parsers is new JSON.Parsers (JSON_Types, Default_Maximum_Depth => 16);

   function Query_Prompt (Text : String) return String is
     ("The passage:" & LF & LF & Model_Replies.Cut (Text, Max_Text) & LF & LF
      & "Write the web search queries, and reply with the JSON object of them and nothing else.");

   function Evaluation_Prompt (Text, Title, Address, Page : String) return String is
     ("The passage the writer is working on:" & LF & LF & Model_Replies.Cut (Text, Max_Text) & LF & LF
      & "The page:" & LF
      & "Title: " & (if Title = "" then "(none)" else Model_Replies.Tidy (Title, 200)) & LF
      & "Address: " & Model_Replies.Tidy (Address, 300) & LF
      & "Text:" & LF & (if Page = "" then "(none)" else Model_Replies.Cut (Page, Max_Text)) & LF & LF
      & "Mark the page as a source for the passage, and reply with the JSON object and nothing else.");

   function Banner_Prompt (Words : String; Refused : String := "") return String is
     ("The words read from the top of the page:" & LF & LF
      & (if Words = "" then "(none)" else Model_Replies.Cut (Words, Max_Text)) & LF & LF
      & (if Refused = "" then ""
         else "The button """ & Model_Replies.Tidy (Refused, Max_Button) & """ could not be pressed: choose "
              & "another that closes what covers the page, or say that nothing covers it if there is none." & LF & LF)
      & "Say whether something covers the page and which button closes it, and reply with the JSON object "
      & "and nothing else.");

   function Percent (Of_Evaluation : Evaluation) return Natural is
     (((Of_Evaluation.Relevance + Of_Evaluation.Support + Of_Evaluation.Quality) * 100 + 15) / 30);

   procedure Parse_Queries
     (Reply  : String;
      Result : out Query_List;
      Valid  : out Boolean)
   is
      use JSON_Types;

      procedure Add (Words : String) is
         Clean : constant String := Model_Replies.Tidy (Words, Max_Query);
      begin
         if Clean'Length < 2 or else Result.Count = Max_Queries then
            return;
         end if;
         for Each in 1 .. Result.Count loop
            if Ada.Strings.Equal_Case_Insensitive (Query_Texts.To_String (Result.Items (Each)), Clean) then
               return;
            end if;
         end loop;
         Result.Count := Result.Count + 1;
         Result.Items (Result.Count) := Query_Texts.To_Bounded_String (Clean);
      end Add;

      procedure Read_Object (Text : String) is
         Parser : JSON_Parsers.Parser := JSON_Parsers.Create (Text, Maximum_Depth => 16);
         Root   : constant JSON_Value := Parser.Parse;
      begin
         if Root.Kind /= Object_Kind or else not Root.Contains ("queries") then
            return;
         end if;
         declare
            Queries : constant JSON_Value := Root ("queries");
         begin
            if Queries.Kind /= Array_Kind then
               return;
            end if;
            for Each of Queries loop
               if Each.Kind /= String_Kind then
                  raise JSON_Parsers.Parse_Error;
               end if;
               Add (Each.Value);
            end loop;
         end;
      end Read_Object;

      From, First, Last : Natural := 0;
   begin
      Result.Count := 0;
      Valid := False;
      From := Reply'First;
      --  The first object that gives a query: a model that thinks aloud may say
      --  other things in braces first.
      while From in Reply'Range loop
         Model_Replies.Find_Object (Reply, From, First, Last);
         exit when Last = 0;
         begin
            Result.Count := 0;
            Read_Object (Reply (First .. Last));
         exception
            when JSON_Parsers.Parse_Error | JSON_Types.Invalid_Type_Error | Constraint_Error | Program_Error =>
               Result.Count := 0;
         end;
         if Result.Count > 0 then
            Valid := True;
            return;
         end if;
         From := Last + 1;
      end loop;
      Result.Count := 0;
   end Parse_Queries;

   procedure Parse_Banner
     (Reply   : String;
      Covered : out Boolean;
      Button  : out Button_Texts.Bounded_String;
      Valid   : out Boolean)
   is
      use JSON_Types;

      procedure Read_Object (Text : String) is
         Parser : JSON_Parsers.Parser := JSON_Parsers.Create (Text, Maximum_Depth => 16);
         Root   : constant JSON_Value := Parser.Parse;
      begin
         if Root.Kind /= Object_Kind or else not Root.Contains ("covered")
           or else Root ("covered").Kind /= Boolean_Kind
         then
            return;
         end if;
         declare
            Said : constant Boolean := Root ("covered").Value;
            Name : constant String :=
              (if Root.Contains ("button") and then Root ("button").Kind = String_Kind
               then Model_Replies.Tidy (Root ("button").Value, Max_Button) else "");
         begin
            Covered := Said and then Name /= "";
            Button := Button_Texts.To_Bounded_String (if Covered then Name else "");
            Valid := True;
         end;
      end Read_Object;

      From, First, Last : Natural := 0;
   begin
      Covered := False;
      Button := Button_Texts.Null_Bounded_String;
      Valid := False;
      From := Reply'First;
      --  The first object that answers: a model that thinks aloud may say other
      --  things in braces first.
      while From in Reply'Range loop
         Model_Replies.Find_Object (Reply, From, First, Last);
         exit when Last = 0;
         begin
            Read_Object (Reply (First .. Last));
         exception
            when JSON_Parsers.Parse_Error | JSON_Types.Invalid_Type_Error | Constraint_Error | Program_Error =>
               Covered := False;
               Button := Button_Texts.Null_Bounded_String;
               Valid := False;
         end;
         exit when Valid;
         From := Last + 1;
      end loop;
   end Parse_Banner;

   procedure Parse_Evaluation
     (Reply  : String;
      Result : out Evaluation;
      Valid  : out Boolean)
   is
      use JSON_Types;

      function Mark_Of (Root : JSON_Value; Key : String) return Mark is
      begin
         if not Root.Contains (Key) then
            raise JSON_Parsers.Parse_Error;
         end if;
         declare
            Given : constant JSON_Value := Root (Key);
         begin
            if Given.Kind /= Integer_Kind then
               raise JSON_Parsers.Parse_Error;
            end if;
            declare
               Whole : constant Long_Long_Integer := Given.Value;
            begin
               if Whole not in 0 .. Long_Long_Integer (Mark'Last) then
                  raise JSON_Parsers.Parse_Error;
               end if;
               return Mark (Whole);
            end;
         end;
      end Mark_Of;

      procedure Read_Object (Text : String) is
         Parser : JSON_Parsers.Parser := JSON_Parsers.Create (Text, Maximum_Depth => 16);
         Root   : constant JSON_Value := Parser.Parse;
      begin
         if Root.Kind /= Object_Kind then
            return;
         end if;
         Result.Relevance := Mark_Of (Root, "relevance");
         Result.Support := Mark_Of (Root, "support");
         Result.Quality := Mark_Of (Root, "quality");
         if Root.Contains ("reason") and then Root ("reason").Kind = String_Kind then
            Result.Reason := Reason_Texts.To_Bounded_String (Model_Replies.Tidy (Root ("reason").Value, Max_Reason));
         end if;
         Valid := True;
      end Read_Object;

      From, First, Last : Natural := 0;
   begin
      Result := (others => <>);
      Valid := False;
      From := Reply'First;
      --  The first object that has the marks: a model that thinks aloud may say
      --  other things in braces first.
      while From in Reply'Range loop
         Model_Replies.Find_Object (Reply, From, First, Last);
         exit when Last = 0;
         begin
            Read_Object (Reply (First .. Last));
         exception
            when JSON_Parsers.Parse_Error | JSON_Types.Invalid_Type_Error | Constraint_Error | Program_Error =>
               Result := (others => <>);
               Valid := False;
         end;
         exit when Valid;
         From := Last + 1;
      end loop;
   end Parse_Evaluation;

end Source_Finding;
