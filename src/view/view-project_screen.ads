with Projects;

--  The project screen, as a whole: which project and which view of it is
--  shown, and the way back to the home screen.
package View.Project_Screen is

   function Mode (Item : Session) return Modes
     with Pre => Is_Open (Item) and then Screen (Item) = Project;
   --  Which view of the project is shown.

   procedure Set_Mode (Item : in out Session; To : Modes)
     with Pre  => Is_Open (Item) and then Screen (Item) = Project,
          Post => Mode (Item) = To;
   --  Show the view, as its tab does.

   function Current_Project (Item : Session) return Projects.Id
     with Pre => Is_Open (Item) and then Screen (Item) = Project;
   --  The one the project screen is of.

   procedure Close_Project (Item : in out Session)
     with Pre  => Is_Open (Item) and then Screen (Item) = Project,
          Post => Screen (Item) = Home;
   --  Go back to the home screen, as the Close button does.

   function Is_Listing (Item : Session) return Boolean
     with Pre => Is_Open (Item);
   --  Whether the list of the project's items is shown, over the project
   --  screen.

end View.Project_Screen;
