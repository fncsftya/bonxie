--  Going between the home screen and a project's.
private package Viewer.Navigation is

   procedure Enter (Item : in out Session; Key : Projects.Id)
     with Pre => Screen (Item) = Home;
   --  Go to the screen of the project Key.

   procedure Enter_New (Item : in out Session)
     with Pre => Screen (Item) = Home;
   --  Keep a new project, and go to its screen.

   procedure Leave (Item : in out Session)
     with Pre => Screen (Item) = Project;
   --  Go back to the home screen.

   procedure Keep
     (Item    : in out Session;
      Name    : String;
      Updated : Projects.Seconds);
   --  Keep a project last updated at Updated, to be listed.

end Viewer.Navigation;
