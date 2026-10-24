with Pomarine.Events;

--  The menu bar across the top of the screen: the commands of the window
--  that a Mac application has there, with the keys they are chosen by,
--  said as the buttons say them, and what is possible when.
private package Viewer.Menus is

   procedure Build (Item : in out Session);
   --  Make the menus, which say what the window's buttons do, and have
   --  what each is for follow what is shown. Not for a session opened
   --  without a window.

   procedure Key_Taken (Item : in out Session; Event : Pomarine.Events.Event);
   --  A key was handled by a widget. If a menu item has that key (the
   --  Edit menu's: Command-V and the rest) the system has said the item
   --  was chosen too, so that it is not done twice.

   procedure Update (Item : in out Session);
   --  Do what has been chosen, and show what is possible now.

end Viewer.Menus;
