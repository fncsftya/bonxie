with Items.Windows;
with Pomarine.Themes;
with View.Outlines;

--  Linking an item to a section of the outline, so that the item is the
--  one the section is read from. A button in a note's status line on the
--  canvas, and in a document's bar in the writing view, opens a menu of
--  the sections: each has a colour, shown where the item is, and is faint
--  if another item has it. What is chosen is kept in the database.
private package View.Section_Links is

   function Section_Of (Item : Session; Which : Items.Slot) return Natural
     with Pre => Items.Windows.Is_Assigned (Item.Windows (Which));
   --  The place in the outline, from 1, of the section the item of the
   --  window is the own of; 0 if it is of none.

   function Ink_Of (Item : Session; Section : Positive) return Pomarine.Themes.Slot
     with Pre => Section <= Outlines.Section_Count (Item);
   --  The colour of the section, in the theme.

   procedure Open_Page_Menu (Item : in out Session; Rank : Positive);
   --  The button of the page of this rank was pressed: its section menu is shown, or put away.
   --  Have the Section button of the page of the slot do what it is for.

   function Is_Shown (Item : Session) return Boolean;
   --  Whether the menu is shown.

   function Is_Open_For (Item : Session; Which : Items.Slot) return Boolean;
   --  Whether it is shown for that item.

   procedure Open (Item : in out Session; Which : Items.Slot; Page : Natural := 0)
     with Pre => Items.Windows.Is_Assigned (Item.Windows (Which));
   --  Show the menu for the item, by its button: that of the window on the
   --  canvas, or, with Page (from 1), that of the page of the writing view.
   --  If it is shown for the item already, put it away.

   procedure Link_To (Item : in out Session; Which : Items.Slot; Section : Positive)
     with Pre => Items.Windows.Is_Assigned (Item.Windows (Which))
                 and then Section <= Outlines.Section_Count (Item);
   --  Make the item one of the section's, as choosing it in the menu
   --  does: it is called as the section if it has no name of its own.

   procedure Joined (Item : in out Session; Which : Items.Slot)
     with Pre => Items.Windows.Is_Assigned (Item.Windows (Which));
   --  The item has been put in a section's folder: read what is kept, and
   --  call it as the section if it has no name of its own.

   procedure Close (Item : in out Session);

   function Row_Count (Item : Session) return Natural;
   --  The rows of the menu: the heading, a box for each section, and so on.

   function Row_Enabled (Item : Session; Row : Positive) return Boolean
     with Pre => Row <= Row_Count (Item);
   function Row_Checked (Item : Session; Row : Positive) return Boolean
     with Pre => Row <= Row_Count (Item);
   --  Whether a row can be chosen (a section that another item has cannot),
   --  and whether it is ticked (the item's own).

   procedure Choose (Item : in out Session; Row : Positive)
     with Pre => Is_Shown (Item);
   --  As clicking the row does.

   procedure Update (Item : in out Session);
   --  Keep the menu by its button as the canvas is moved, and the colours
   --  shown by the windows as the links are.

   procedure Pressed (Item : in out Session; X, Y : Float);
   --  A press at X, Y points: puts the menu away if it is outside it.

   function Changes (Item : Session) return Natural;
   --  How many times a link was made or taken away: to see it has been.

end View.Section_Links;
