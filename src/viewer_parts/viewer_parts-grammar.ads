with SDL3.Events;
with Harper;
with Grammar_Cards;
with Items;
with Texts.Documents;
with Pomarine.Widgets;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Menus;
with Pomarine.Widgets.Panels;
with Pomarine.Widgets.Scrollers;

--  The grammar checks of the documents, and the cards that show them.
package Viewer_Parts.Grammar is

   --  Grammar requests use a fixed worker pool and retain no document pointers.

   Grammar_Workers : constant := 4;

   type Grammar_Document is record
      Serial   : Natural := 0;
      Seen     : Texts.Documents.Version := 0;
      Token    : Harper.Request_Id := 0;
      Due      : SDL3.Events.Milliseconds := 0;
      Cursor   : Texts.Position := (1, 1);
      Retained : Natural range 0 .. 512 := 0;
      Finished : Boolean := False;
      Busy     : Boolean := False;
   end record;

   type Grammar_Documents is array (Items.Slot) of Grammar_Document;

   type Grammar_Worker is limited record
      Checker : Harper.Checker;
      Busy    : Boolean := False;
      Rank    : Items.Slot := 1;
      Token   : Harper.Request_Id := 0;
      First   : Texts.Position;
      Next_Position : Texts.Position;
      Last    : Boolean := False;
   end record;

   type Grammar_Worker_Array is array (1 .. Grammar_Workers) of Grammar_Worker;

   Max_Diagnostics : constant := 512 * Items.Slot'Last;

   subtype Diagnostic_Index is Positive range 1 .. Max_Diagnostics;

   type Grammar_Row is limited record
      Lint : Harper.Diagnostic;
      Rank : Items.Slot := 1;
      Token : Harper.Request_Id := 0;
      First : Texts.Position := (1, 1);
   end record;

   type Grammar_Rows is array (Diagnostic_Index) of Grammar_Row;
   --  Only the viewport's cards need widgets, even with many diagnostics.

   type Grammar_Card_Array is array (1 .. 32) of Grammar_Cards.Card;

   type Grammar_Bindings is array (1 .. 32) of Natural range 0 .. Max_Diagnostics;

   type Grammar_Actions is array (1 .. Harper.Max_Suggestions) of Pomarine.Widgets.Buttons.Button;

   type Grammar_Choice is record
      Row : Natural range 0 .. Max_Diagnostics := 0;
      Suggestion : Natural range 0 .. Harper.Max_Suggestions := 0;
      Token : Harper.Request_Id := 0;
   end record;

   type Grammar_Choices is array (1 .. Pomarine.Widgets.Menus.Row_Capacity) of Grammar_Choice;

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
      Inline_Menu : Pomarine.Widgets.Menus.Menu;
      Inline_Choices : Grammar_Choices;
      Inline_Count : Natural range 0 .. Pomarine.Widgets.Menus.Row_Capacity := 0;
      Inline_Open : Boolean := False;
      Over_Diagnostic : Boolean := False;
      Pointer_Known, Pointer_Held : Boolean := False;
      Pointer_X, Pointer_Y : Float := 0.0;
      Press_Rank : Natural range 0 .. Items.Slot'Last := 0;
      Press_X, Press_Y : Float := 0.0;
      Expanded : Natural range 0 .. Max_Diagnostics := 0;
      Showing : Boolean := False;
      Dirty : Boolean := True;
      Width : Float := 360.0;
      Left, Top, Height : Float := -1.0;
   end record;

end Viewer_Parts.Grammar;
