--  The menu bar across the top of the screen: the commands of the window
--  that a Mac application has there, with the keys they are chosen by,
--  said as the buttons say them, and what is possible when.
private package Viewer.Menus is

   procedure Build (Item : in out Session);
   --  Make the menus, which say what the window's buttons do, and have
   --  what each is for follow what is shown. Not for a session opened
   --  without a window.

   procedure Update (Item : in out Session);
   --  Do what has been chosen, and show what is possible now.

end Viewer.Menus;
