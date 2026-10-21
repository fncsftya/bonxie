with Harper;
with Pomarine.Widgets;
with Pomarine.Themes;
with Pomarine.Semantics;
with SDL3.Events;
with SDL3.Painters;

--  A bounded diagnostic card. Correction buttons are ordinary widgets
--  placed over its suggestion rows by the owning popout.
package Grammar_Cards is

   type Card is new Pomarine.Widgets.Widget with private;

   procedure Set_Diagnostic
     (Item : in out Card; Value : Harper.Diagnostic; Caption : String; Ink : Pomarine.Themes.Color);
   function Diagnostic (Item : Card) return Harper.Diagnostic;
   procedure Set_Expanded (Item : in out Card; To : Boolean);
   function Expanded (Item : Card) return Boolean;
   function Height_For (Item : Card; Width : Float) return Float
     with Pre => Width >= 120.0;
   function Action_Top (Item : Card; Number : Positive; Width : Float) return Float
     with Pre => Number <= Diagnostic (Item).Suggestion_Count and then Width >= 120.0;
   function Footer_Top (Item : Card; Width : Float) return Float
     with Pre => Width >= 120.0;
   --  Where the buttons for the rules go, under the suggestions, when it is expanded.
   function Kind_Name (Kind : Harper.Lint_Kind) return String;

   overriding procedure Draw
     (Item : in out Card; Target : SDL3.Painters.Painter'Class; Colors : Pomarine.Themes.Theme);
   overriding procedure Handle (Item : in out Card; Event : SDL3.Events.Event; Handled : out Boolean);
   overriding function Accepts_Focus (Item : Card) return Boolean is (True);
   overriding procedure Focus_Changed (Item : in out Card; Focused : Boolean);
   overriding procedure Describe (Item : Card; Facts : in out Pomarine.Semantics.Description);
   overriding procedure Perform
     (Item : in out Card; Request : Pomarine.Semantics.Request; Done : out Boolean);

private

   type Card is new Pomarine.Widgets.Widget with record
      Lint : Harper.Diagnostic;
      Caption : String (1 .. 96) := [others => ' '];
      Caption_Length : Natural range 0 .. 96 := 0;
      Ink : Pomarine.Themes.Color := (0, 0, 0, 255);
      Open : Boolean := False;
      Down : Boolean := False;
   end record;

end Grammar_Cards;
