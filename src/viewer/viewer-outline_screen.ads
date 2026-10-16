--  The outline view of a project, to look at and move about: for tests.
package Viewer.Outline_Screen is

   function Section_Count (Item : Session) return Natural
     with Pre => Is_Open (Item) and then Screen (Item) = Project;
   --  How many sections the outline has.

   function Section_Title (Item : Session; Row : Positive) return String
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Section_Count (Item);
   --  The title of the Rowth section, as shown.

   function Project_Title (Item : Session) return String
     with Pre => Is_Open (Item) and then Screen (Item) = Project;
   function Project_Description (Item : Session) return String
     with Pre => Is_Open (Item) and then Screen (Item) = Project;
   --  What the form shows.

   procedure Add_Section (Item : in out Session)
     with Pre => Is_Open (Item) and then Screen (Item) = Project;
   --  As the Add Section button does.

   procedure Move_Section (Item : in out Session; From, To : Positive)
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then From <= Section_Count (Item)
                 and then To <= Section_Count (Item);
   --  As dragging a block does, or its buttons.

   procedure Remove_Section (Item : in out Session; Row : Positive)
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Section_Count (Item);
   --  As a block's delete button does.

end Viewer.Outline_Screen;
