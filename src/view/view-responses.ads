with Pomarine.Widgets;

--  Native menu and key commands.
--  Screen controls declare command bindings beside their layouts.
private package View.Responses is

   procedure Perform
     (Item  : in out Session;
      Event : Pomarine.Widgets.Widget_Event);
   --  Do what the menu bar or a key asked, as a Command (see
   --  Pomarine.Widgets.Perform_Command): what a button of it does, when
   --  there is one, is done as the button's.

end View.Responses;
