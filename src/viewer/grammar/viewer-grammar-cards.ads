with Pomarine.Widgets;

--  The cards of the suggestions: shown, expanded, and their fixes applied.
private package Viewer.Grammar.Cards is

   package Widgets renames Pomarine.Widgets;

   procedure Refresh (Item : in out Session);

   procedure Toggle (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);

   procedure Expand (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);

   procedure Apply (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);

   procedure Inline_Chosen
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);

end Viewer.Grammar.Cards;
