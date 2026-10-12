--  Building the widgets of the screens, once there is a target.
private package Viewer.Build is

   procedure Set_Up
     (Item       : in out Session;
      Source     : String;
      File_Name  : String;
      Store_Path : String);
   --  Open the projects, load the script, add and style the widgets of
   --  both screens and the dialog, and lay them out, at the home screen.

end Viewer.Build;
