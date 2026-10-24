--  The documents of the writing view, and the directories they are in: for
--  tests.
package Viewer.Documents is

   function Search_Count (Item : Session) return Natural;
   function Search_Current (Item : Session) return Natural;
   function Search_Document (Item : Session) return Natural;
   function Search_Highlights (Item : Session; Row : Positive) return Natural
     with Pre => Row <= Document_Count (Item);

   function Context_Open (Item : Session) return Boolean;

   function Document_Count (Item : Session) return Natural
     with Pre => Is_Open (Item) and then Screen (Item) = Project;
   --  How many items there are that are not sources: the pages.

   function Grammar_Suggestions_Shown (Item : Session) return Boolean;
   function Grammar_Pending (Item : Session) return Boolean;
   function Grammar_Running (Item : Session) return Natural;
   function Grammar_Count (Item : Session) return String;
   --  The label of the button that counts the fixable suggestions.
   function Grammar_Highlights (Item : Session; Row : Positive) return Natural
     with Pre => Row <= Document_Count (Item);
   --  Background checking and decorations, for the writing view's tests.

   function Grammar_Marking (Item : Session; Marked : String) return Natural;
   --  How many diagnostics shown mark exactly Text, and how many of those a rule of the project made.
   function Grammar_Made_By_Rule (Item : Session; Marked : String) return Natural;
   function Grammar_First_Suggestion (Item : Session; Marked : String) return String;
   procedure Grammar_Show (Item : in out Session);
   procedure Grammar_Expand (Item : in out Session; Marked : String);
   procedure Grammar_Begin_Rule (Item : in out Session; Marked : String);
   function Grammar_First_Card_Made_By_Rule (Item : Session) return Boolean;
   function Grammar_Rule_Count (Item : Session) return Natural;
   procedure Grammar_Ignore (Item : in out Session; Marked : String);
   procedure Grammar_Correct (Item : in out Session; Marked, To : String);
   procedure Grammar_Remove_Rule (Item : in out Session; Marked : String);
   --  What the cards' buttons do, on the diagnostic marking Text.

   function Document_Title (Item : Session; Row : Positive) return String
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Document_Count (Item);
   --  The title of the Rowth page, in the order they are written in.

   procedure Move_Document (Item : in out Session; From, To : Positive)
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then From <= Document_Count (Item)
                 and then To <= Document_Count (Item);
   --  Put the From-th page at the To-th, as dragging its row in the list
   --  does, and keep that order.

   function Sidebar_Width (Item : Session) return Float
     with Pre => Is_Open (Item);
   --  How wide the list of documents is, in points.

   procedure Add_For_Section (Item : in out Session; Section : Positive)
     with Pre => Is_Open (Item) and then Screen (Item) = Project;
   --  As the button of a section that has no documents does: write one,
   --  which is of the section.

   function Directory_Count (Item : Session) return Natural
     with Pre => Is_Open (Item) and then Screen (Item) = Project;
   --  How many directories the documents are in.

   procedure Ask_Delete_Directory (Item : in out Session; Dir : Positive)
     with Pre => Dir <= Directory_Count (Item);
   procedure Deletion_Points (Item : Session; Check_X, Check_Y, Delete_X, Delete_Y : out Float);
   function Delete_Documents_Checked (Item : Session) return Boolean;
   function Directory_Row (Item : Session; Dir : Positive) return Natural;

   function Directory_Parent (Item : Session; Row : Positive) return Natural
     with Pre => Row <= Directory_Count (Item);

   function Directory_Title (Item : Session; Row : Positive) return String
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Directory_Count (Item);

   procedure Add_Directory
     (Item : in out Session; Name : String := "Untitled folder")
     with Pre => Is_Open (Item) and then Screen (Item) = Project;
   --  Make a directory, as the button in the sidebar does, and begin to
   --  rename it.

   function Document_Directory
     (Item : Session; Row : Positive) return Natural
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Document_Count (Item);
   --  Which directory the Rowth page is in, 0 if none.

   procedure Move_Document_To
     (Item : in out Session; Row : Positive; Directory : Natural)
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Document_Count (Item)
                 and then Directory <= Directory_Count (Item);
   --  Put the Rowth page last in the directory (none, if 0), as dropping
   --  its row on that directory's, or on the Overview's, does, and keep it.

   function Shown_Directory (Item : Session) return Natural
     with Pre => Is_Open (Item) and then Screen (Item) = Project;
   --  The directory whose pages are shown in the writing view, 0 for all.

   procedure Show_Directory (Item : in out Session; Directory : Natural)
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Directory <= Directory_Count (Item);
   --  As clicking its row does (0, the Overview's).

end Viewer.Documents;
