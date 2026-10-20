--  Building the widgets of the screens, once there is a target.
private package Viewer.Build is

   procedure Set_Up
     (Item       : in out Session;
      Source     : String;
      File_Name  : String;
      Store_Path : String);
   --  Open the projects, load the script, add and style the widgets of
   --  both screens and the dialog, and lay them out, at the home screen.

   procedure Reserve_Items (Item : in out Session; Count : Natural);
   --  Have the widgets for at least Count items: a window on the canvas,
   --  a page, a reader and a row of the sidebar to each, and pins to link
   --  them by; those there are stay. Do it before an item is given a
   --  window; the widgets of the sections and of the tree are made too.

   procedure Reserve_Sections (Item : in out Session; Count : Natural);
   --  Have the widgets for at least Count sections: a block in the outline,
   --  and a heading, notes and empty box among the pages, and the mark
   --  for loose documents after it.

   procedure Reserve_Rows (Item : in out Session);
   --  Have a row of the tree of documents for the Overview, each directory
   --  and each item.

end Viewer.Build;
