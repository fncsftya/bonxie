with Projects;

--  The home screen, with the recent projects: for tests, which need not
--  find the buttons.
package View.Home_Screen is

   procedure New_Project (Item : in out Session)
     with Pre  => Is_Open (Item) and then Screen (Item) = Home,
          Post => Screen (Item) = Project;
   --  Keep a new project, and go to the project screen, as the New
   --  Project button does.

   procedure Open_Project (Item : in out Session; Key : Projects.Id)
     with Pre  => Is_Open (Item) and then Screen (Item) = Home,
          Post => Screen (Item) = Project;
   --  Go to the screen of the project Key, as a click on it in the recent
   --  projects does.

   procedure Add_Project
     (Item    : in out Session;
      Name    : String;
      Updated : Projects.Seconds)
     with Pre => Is_Open (Item) and then Updated >= 0;
   --  Keep a project last updated at Updated, to be listed.

   function Is_Renaming (Item : Session) return Boolean
     with Pre => Is_Open (Item);
   --  Whether a project listed on the home screen has a field to rename
   --  it, in place of its button.

   function Is_Confirming (Item : Session) return Boolean
     with Pre => Is_Open (Item);
   --  Whether the dialog to confirm deleting a project is shown, over the
   --  home screen.

   function Row_Title (Item : Session; Row : Positive) return String
     with Pre => Is_Open (Item) and then Row <= Projects.Recent_Count;
   --  What the button of the Rowth project listed shows, "" if none.

end View.Home_Screen;
