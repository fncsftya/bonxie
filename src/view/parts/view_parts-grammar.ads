with Grammar_VM;
with Grammar_VM.Stored;
with Pomarine.Events;
with Harper;
with Grammar_Cards;
with Growing;
with Items;
with Slot_Tables;
with Texts.Documents;
with Pomarine.Widgets;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Menus;
with Pomarine.Widgets.Panels;
with Pomarine.Widgets.Text_Fields;
with Pomarine.Widgets.Scrollers;

--  The grammar checks of the documents, and the cards that show them.
package View_Parts.Grammar is

   --  Grammar requests use a fixed worker pool and retain no document pointers.

   Grammar_Workers : constant := 4;

   type Grammar_Document is record
      Serial   : Natural := 0;
      Seen     : Texts.Documents.Version := 0;
      Token    : Harper.Request_Id := 0;
      Due      : Pomarine.Events.Milliseconds := 0;
      Cursor   : Texts.Position := (1, 1);
      Retained : Natural range 0 .. 512 := 0;
      Finished : Boolean := False;
      Busy     : Boolean := False;
   end record;

   package Document_Lists is new Growing (Grammar_Document);
   subtype Grammar_Documents is Document_Lists.List;
   --  One to each slot.

   type Grammar_Worker is limited record
      Checker : Harper.Checker;
      Busy    : Boolean := False;
      Rank    : Items.Slot := 1;
      Token   : Harper.Request_Id := 0;
      First   : Texts.Position;
      Next_Position : Texts.Position;
      Last    : Boolean := False;
      Length  : Natural range 0 .. Harper.Max_Text := 0;
      Text    : String (1 .. Harper.Max_Text);
      --  What was submitted, for the project's rules to read the places in the result against.
   end record;

   type Grammar_Worker_Array is array (1 .. Grammar_Workers) of Grammar_Worker;

   type Grammar_Row is limited record
      Lint : Harper.Diagnostic;
      Rank : Items.Slot := 1;
      Token : Harper.Request_Id := 0;
      First : Texts.Position := (1, 1);
   end record;

   package Row_Tables is new Slot_Tables (Grammar_Row);
   subtype Grammar_Rows is Row_Tables.Table;
   --  Only the viewport's cards need widgets, even with many diagnostics.

   type Grammar_Card_Array is array (1 .. 32) of Grammar_Cards.Card;

   type Grammar_Bindings is array (1 .. 32) of Natural;

   type Grammar_Actions is array (1 .. Harper.Max_Suggestions) of Pomarine.Widgets.Buttons.Button;

   type Choice_Command is (Nothing, Apply_Suggestion, Add_Rule, Ignore_Text, Remove_Rule);

   type Grammar_Choice is record
      Command : Choice_Command := Apply_Suggestion;
      Row : Natural := 0;
      Suggestion : Natural range 0 .. Harper.Max_Suggestions := 0;
      Token : Harper.Request_Id := 0;
   end record;

   type Grammar_Choices is array (1 .. 64) of Grammar_Choice;
   --  The fixes offered at one place at once: those that overlap there, more than are ever shown.

   type Grammar_State is limited record
      Workers : Grammar_Worker_Array;
      Documents : Grammar_Documents;
      Enabled : Boolean := True;
      Serial  : Harper.Request_Id := 0;
      Rows : Grammar_Rows;
      Cards : Grammar_Card_Array;
      Bindings : Grammar_Bindings := [others => 0];
      Measure_Card : Grammar_Cards.Card;
      Offset : Float := -1.0;
      Popout : Pomarine.Widgets.Panels.Panel;
      Heading : Pomarine.Widgets.Labels.Label;
      Empty : Pomarine.Widgets.Labels.Label;
      Scroll : Pomarine.Widgets.Scrollers.Scroller;
      Content : Pomarine.Widgets.Panels.Panel;
      Actions : Grammar_Actions;
      Add_Rule, Ignore_Text : Pomarine.Widgets.Buttons.Button;
      --  Over the footer of the expanded card.
      Entry_Panel : Pomarine.Widgets.Panels.Panel;
      Entry_Prompt : Pomarine.Widgets.Labels.Label;
      Entry_Field : Pomarine.Widgets.Text_Fields.Text_Field;
      Entry_Doc : aliased Texts.Documents.Document;
      Entry_Row : Pomarine.Widgets.Panels.Panel;
      Entry_Ok, Entry_Cancel : Pomarine.Widgets.Buttons.Button;
      Inline_Menu : Pomarine.Widgets.Menus.Menu;
      Inline_Choices : Grammar_Choices;
      Inline_Count : Natural range 0 .. 64 := 0;
      Inline_Open : Boolean := False;
      Over_Diagnostic : Boolean := False;
      Pointer_Known, Pointer_Held : Boolean := False;
      Pointer_X, Pointer_Y : Float := 0.0;
      Press_Rank : Natural := 0;
      Press_X, Press_Y : Float := 0.0;
      Expanded : Natural := 0;
      Showing : Boolean := False;
      Dirty : Boolean := True;
      Width : Float := 360.0;
      Left, Top, Height : Float := -1.0;
   end record;

   type Rule_Choices is limited record
      Library : aliased Grammar_VM.Stored.Rules_Kept;
      Model   : aliased Grammar_VM.View_Model;
      --  The project's rules, and the rule being made: the text it is for, and what it is to be corrected to.
   end record;
   --  The view-model of the grammar rules.

end View_Parts.Grammar;
