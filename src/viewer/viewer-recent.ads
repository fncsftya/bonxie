--  The home screen's list of recent projects, and renaming one in place.
private package Viewer.Recent is

   procedure Refresh (Item : in out Session);
   --  List the most recently updated projects, and stop any being
   --  renamed.

   procedure Cancel_Edit (Item : in out Session);
   --  Put back the buttons of the project being renamed, if any, in place
   --  of the field.

   procedure Begin_Rename (Item : in out Session; Row : Positive)
     with Pre => Row <= Item.Listed.Count;
   --  Put a field with the project's title in its row, in place of its
   --  buttons, with the title selected, to type over.

   procedure Accept_Rename (Item : in out Session);
   --  Give the project being renamed the title in the field, unless it is
   --  nothing.

end Viewer.Recent;
