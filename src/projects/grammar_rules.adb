with Long_Texts;

package body Grammar_Rules is

   use type Projects.Rules.Actions;
   use type Harper.Span;

   function Flagged (Text : String; Item : Harper.Diagnostic) return String
   is (if Item.Location.First < Item.Location.Last and then Item.Location.Last <= Text'Length
       then Text (Item.Location.First + 1 .. Item.Location.Last)
       else "");

   function Is_Word_Byte (C : Character) return Boolean
   is (C in 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' or else Character'Pos (C) >= 16#80#);

   function Whole_Word (Text : String; First, Last : Positive) return Boolean
   is ((First = Text'First or else not Is_Word_Byte (Text (First - 1)))
       and then (Last = Text'Last or else not Is_Word_Byte (Text (Last + 1))));

   function Message_For (Pattern, Replacement : String) return Harper.Messages.Bounded_String is
      Full : constant String := "Your rule: replace """ & Pattern & """ with """ & Replacement & """.";
   begin
      --  Never cut inside a character: a long one is said without the texts.
      return
        Harper.Messages.To_Bounded_String
          (if Full'Length <= Harper.Max_Message then Full else "Your rule: replace this text.");
   end Message_For;

   function Later (A, B : Harper.Span) return Boolean
   is (A.First > B.First or else (A.First = B.First and then A.Last > B.Last));

   function Usable (Rule : Projects.Rules.Rule) return Boolean
   is (Rule.Action = Projects.Rules.Correct
       and then Long_Texts.Length (Rule.Pattern) > 0
       and then Long_Texts.Length (Rule.Replacement) <= Harper.Max_Replacement
       and then Long_Texts.To_String (Rule.Pattern) /= Long_Texts.To_String (Rule.Replacement));
   --  A correction that changes something, and that fits a suggestion: a longer one is left out, not cut.

   procedure Offer (Item : in out Harper.Diagnostic; Pattern, Replacement : String) is
      Old   : constant Harper.Suggestion_Array := Item.Suggestions;
      Count : constant Natural := Item.Suggestion_Count;
      Kept  : Natural := 1;
   begin
      Item.Suggestions (1) := (Item.Location, Harper.Replacements.To_Bounded_String (Replacement));
      for Each in 1 .. Count loop
         if Old (Each).Location /= Item.Location or else Harper.Replacements.To_String (Old (Each).Text) /= Replacement
         then
            if Kept < Harper.Max_Suggestions then
               Kept := Kept + 1;
               Item.Suggestions (Kept) := Old (Each);
            else
               Item.Suggestions_Truncated := True;
            end if;
         end if;
      end loop;
      Item.Suggestion_Count := Kept;
      Item.Message := Message_For (Pattern, Replacement);
      Item.Message_Truncated := False;
      Item.Priority := 0;
      Item.Custom := True;
   end Offer;

   procedure Apply (Rules : Projects.Rules.Rule_List; Text : String; Result : in out Harper.Check_Result) is
      Kept  : Natural := 0;
      Added : Boolean := False;

      function Ignored (Item : Harper.Diagnostic) return Boolean is
         Marked : constant String := Flagged (Text, Item);
      begin
         for Rule of Rules loop
            if Rule.Action = Projects.Rules.Ignore
              and then Rule.Kind = Kind_Code (Item.Kind)
              and then Long_Texts.To_String (Rule.Pattern) = Marked
            then
               return True;
            end if;
         end loop;
         return False;
      end Ignored;

      function Has_Diagnostic_At (Place : Harper.Span) return Boolean is
      begin
         for Index in 1 .. Result.Count loop
            if Result.Lints (Index).Location = Place then
               return True;
            end if;
         end loop;
         return False;
      end Has_Diagnostic_At;

      procedure Add_At (Rule : Projects.Rules.Rule; Place : Harper.Span) is
         Pattern : constant String := Long_Texts.To_String (Rule.Pattern);
      begin
         if Result.Count = Harper.Max_Lints then
            Result.Truncated := True;
            return;
         end if;
         Result.Count := Result.Count + 1;
         Result.Lints (Result.Count) := (Location => Place, Kind => Harper.Spelling, others => <>);
         Offer (Result.Lints (Result.Count), Pattern, Long_Texts.To_String (Rule.Replacement));
         Added := True;
      end Add_At;

      procedure Find_Uncovered (Rule : Projects.Rules.Rule) is
         Pattern : constant String := Long_Texts.To_String (Rule.Pattern);
         From    : Positive := 1;
      begin
         while From + Pattern'Length - 1 <= Text'Length loop
            if Text (From .. From + Pattern'Length - 1) = Pattern
              and then Whole_Word (Text, From, From + Pattern'Length - 1)
            then
               declare
                  Place : constant Harper.Span := (From - 1, From - 1 + Pattern'Length);
               begin
                  if not Has_Diagnostic_At (Place) then
                     Add_At (Rule, Place);
                  end if;
               end;
               From := From + Pattern'Length;
            else
               From := From + 1;
            end if;
         end loop;
      end Find_Uncovered;
   begin
      for Index in 1 .. Result.Count loop
         if not Ignored (Result.Lints (Index)) then
            Kept := Kept + 1;
            if Kept /= Index then
               Result.Lints (Kept) := Result.Lints (Index);
            end if;
            declare
               Marked : constant String := Flagged (Text, Result.Lints (Kept));
            begin
               for Rule of Rules loop
                  if Usable (Rule) and then Long_Texts.To_String (Rule.Pattern) = Marked then
                     Offer (Result.Lints (Kept), Marked, Long_Texts.To_String (Rule.Replacement));
                     exit;
                  end if;
               end loop;
            end;
         end if;
      end loop;
      Result.Count := Kept;
      for Rule of Rules loop
         if Usable (Rule) then
            Find_Uncovered (Rule);
         end if;
      end loop;
      if Added then
         --  Insertion sort by place: stable, so Harper's order holds among diagnostics on one place.
         for Index in 2 .. Result.Count loop
            declare
               Moving : constant Harper.Diagnostic := Result.Lints (Index);
               Slot   : Natural := Index - 1;
            begin
               while Slot >= 1 and then Later (Result.Lints (Slot).Location, Moving.Location) loop
                  Result.Lints (Slot + 1) := Result.Lints (Slot);
                  Slot := Slot - 1;
               end loop;
               Result.Lints (Slot + 1) := Moving;
            end;
         end loop;
      end if;
   end Apply;

end Grammar_Rules;
