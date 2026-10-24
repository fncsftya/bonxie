package Grammar_Tests is
   procedure Checking;
   procedure Rules;
   --  A project's rules: ignored and corrected texts, kept, and first among the diagnostics.
   procedure Rule_Cards;
   --  The cards' buttons make rules, which change what is found and are kept in the project.
   procedure Entry_By_Name;
   --  The form that makes a correction, found by what it is called: shown, refused what changes nothing,
   --  accepted, and put away.
end Grammar_Tests;
