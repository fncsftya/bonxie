--  The home screen's list of recent projects, and renaming one in place: the cards and the field set
--  from Home_VM, which has the rules.

private package View.Recent is

   procedure Refresh (Item : in out Session);
   --  List the most recently updated projects again, and stop any being renamed.

   procedure Cancel_Edit (Item : in out Session);
   --  Put back the buttons of the project being renamed, if any, in place of the field.

   procedure Sync (Item : in out Session);
   --  Take what was typed in the field for the title, and show what the view-model says if it has
   --  changed: the cards, and the field in the card of the project being renamed.

end View.Recent;
