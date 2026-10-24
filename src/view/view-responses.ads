with Pomarine.Widgets;

--  What the buttons, checks, menus and lists are for: what is done when each
--  says what it has to (see Pomarine.Widgets.Callbacks). Each widget is given
--  the procedure that does it, by Install, as the screens are built.
private package View.Responses is

   procedure Install (Item : in out Session);
   --  Give each widget the procedure it calls when it is clicked, chosen
   --  or has its say.

   procedure Listen_Section (Item : in out Session; Index : Positive);
   --  Give the buttons of the section's parts among the pages the procedures they call.

   procedure Listen_Slot (Item : in out Session; Which : Items.Slot);
   --  Give the buttons of the page and the source row of the slot the procedures they call.

   procedure Perform
     (Item  : in out Session;
      Event : Pomarine.Widgets.Widget_Event);
   --  Do what the menu bar or a key asked, as a Command (see
   --  Pomarine.Widgets.Perform_Command): what a button of it does, when
   --  there is one, is done as the button's.

end View.Responses;
