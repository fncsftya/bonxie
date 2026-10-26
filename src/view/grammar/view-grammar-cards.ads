with Pomarine.Widgets;

--  The cards of the suggestions: shown, expanded, and their fixes applied.
private package View.Grammar.Cards is

   package Widgets renames Pomarine.Widgets;

   procedure Refresh (Item : in out Session);

   procedure Rules_Changed (Item : in out Session);

   function State_Of
     (Item : Session; What : Grammar_VM.Card_Command; Index : Natural) return Grammar_VM.Card_State;
   procedure Run (Item : in out Session; What : Grammar_VM.Card_Command; Index : Natural);

   procedure Choose_Row (Item : in out Session; Row : Positive);

end View.Grammar.Cards;
