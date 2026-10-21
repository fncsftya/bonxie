with Pomarine.Widgets;

--  The cards of the suggestions: shown, expanded, and their fixes applied.
private package Viewer.Grammar.Cards is

   package Widgets renames Pomarine.Widgets;

   procedure Refresh (Item : in out Session);

   procedure Toggle (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);

   procedure Expand (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);

   procedure Apply (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);

   procedure Rule_Clicked
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);
   --  The expanded card's button: to make a rule of its text, or to unmake the rule that made it.

   procedure Ignore_Clicked
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);

   procedure Entry_Accepted
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);

   procedure Entry_Cancelled
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);

   procedure Inline_Chosen
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);

end Viewer.Grammar.Cards;
