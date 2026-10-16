with Items;

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

   function Section_Colour (Item : Session; Row : Positive) return Natural
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Section_Count (Item);
   --  Which of the colours the section was given, from 0.

   function Section_Item (Item : Session; Row : Positive) return String
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Section_Count (Item);
   --  The titles of the items that are of the section, each followed by a
   --  comma, in the order of their windows; "" if none.

   function Section_Notes (Item : Session; Row : Positive) return String
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Section_Count (Item);
   --  The notes of the Rowth section, as kept.

   function Notes_Shown (Item : Session; Row : Positive) return Boolean
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Section_Count (Item);
   --  Whether its notes are shown.

   procedure Toggle_Notes (Item : in out Session; Row : Positive)
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Section_Count (Item);
   --  As its Notes button does; the notes then have the focus.

   procedure Open_Link_Menu (Item : in out Session; Which : Items.Slot)
     with Pre => Is_Open (Item) and then Screen (Item) = Project;
   --  As the Link to Outline button of the item's window does.

   function Link_Menu_Open (Item : Session) return Boolean
     with Pre => Is_Open (Item);
   --  Whether the menu is shown.

   function Link_Menu_Rows (Item : Session) return Natural
     with Pre => Is_Open (Item);
   --  The rows of the menu: a heading, then a box for each section.

   function Link_Menu_Row_Enabled (Item : Session; Row : Positive) return Boolean
     with Pre => Is_Open (Item) and then Row <= Link_Menu_Rows (Item);
   function Link_Menu_Row_Checked (Item : Session; Row : Positive) return Boolean
     with Pre => Is_Open (Item) and then Row <= Link_Menu_Rows (Item);
   --  Whether it can be chosen, and whether it is ticked.

   procedure Choose_Link_Row (Item : in out Session; Row : Positive)
     with Pre => Is_Open (Item) and then Row <= Link_Menu_Rows (Item);
   --  As clicking the row does.

   function Generate_Enabled (Item : Session) return Boolean
     with Pre => Is_Open (Item) and then Screen (Item) = Project;
   --  Whether the Generate Sections button can be pressed: AI is on, and
   --  the model is not being asked.

   procedure Write_Notes_Point (Item : in out Session; Row : Positive; X, Y : out Float)
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Section_Count (Item);
   --  A point of the window, in points, on the Notes button of the Rowth
   --  section's heading in the writing view.

   function Generate_Label (Item : Session) return String
     with Pre => Is_Open (Item) and then Screen (Item) = Project;
   --  What the Generate button says.

   function Generate_Menu_Shown (Item : Session) return Boolean
     with Pre => Is_Open (Item) and then Screen (Item) = Project;
   --  Whether the menu under its caret is shown.

   procedure Generate_Point (Item : in out Session; Caret : Boolean; X, Y : out Float)
     with Pre => Is_Open (Item) and then Screen (Item) = Project;
   --  A point of the window, in points, on the caret of the button, or on
   --  the rest of it.

   procedure Choose_Generate (Item : in out Session; Row : Positive)
     with Pre => Is_Open (Item) and then Screen (Item) = Project;
   --  As a row of the menu does.

   function Take_Reply (Item : in out Session; Reply : String) return Boolean
     with Pre => Is_Open (Item) and then Screen (Item) = Project;
   --  As the model's reply to Generate Sections is used; False, and the
   --  outline as it was, if it is not valid.

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
