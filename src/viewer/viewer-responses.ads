with Pomarine.Widgets;

--  What the buttons, checks, menus and lists are for: what is done when each
--  says what it has to (see Pomarine.Widgets.Callbacks). Each widget is given
--  the procedure that does it, by Install, as the screens are built.
private package Viewer.Responses is

   procedure Install (Item : in out Session);
   --  Give each widget the procedure it calls when it is clicked, chosen
   --  or has its say.

   procedure Perform
     (Item  : in out Session;
      Event : Pomarine.Widgets.Widget_Event);
   --  Do what the menu bar or a key asked, as a Command (see
   --  Pomarine.Widgets.Perform_Command): what a button of it does, when
   --  there is one, is done as the button's.

end Viewer.Responses;
