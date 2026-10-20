--  The toast and the list of sources found for a note, as shown: for tests.
--  See Viewer.Find_Sources.
package Viewer.Found_Sources is

   function Toast_Shown (Item : Session) return Boolean
     with Pre => Is_Open (Item);

   function Toast_Message (Item : Session) return String
     with Pre => Is_Open (Item);

   function Toast_Action (Item : Session) return String
     with Pre => Is_Open (Item);
   --  The label of its button; "" if it has none.

   procedure Toast_Action_Point (Item : Session; X, Y : out Float)
     with Pre => Is_Open (Item) and then Toast_Shown (Item);
   --  Where to click on the toast's button, in points of the window.

   function Review_Shown (Item : Session) return Boolean
     with Pre => Is_Open (Item);
   --  Whether the list of what was found is shown under the toast.

   function Review_Row_Count (Item : Session) return Natural
     with Pre => Is_Open (Item);

   function Review_Row (Item : Session; Row : Positive) return String
     with Pre => Is_Open (Item) and then Row <= Review_Row_Count (Item);
   --  The text of the row, "" for a line between rows.

   procedure Review_Row_Point (Item : Session; Row : Positive; X, Y : out Float)
     with Pre => Is_Open (Item) and then Review_Shown (Item) and then Row <= Review_Row_Count (Item);
   --  Where to click on the row, in points of the window.

   function Preview_Shown (Item : Session) return Boolean
     with Pre => Is_Open (Item);
   --  Whether the window that previews a source found is shown beside the list.

   function Preview_Index (Item : Session) return Natural
     with Pre => Is_Open (Item);
   --  Which of the sources found (as the list has them, from 1) it shows; 0 if none.

   function Preview_Is_Paged (Item : Session) return Boolean
     with Pre => Is_Open (Item) and then Preview_Shown (Item);
   --  Whether it shows a PDF, as pages one under another.

   function Preview_Title (Item : Session) return String
     with Pre => Is_Open (Item) and then Preview_Shown (Item);

   procedure Preview_Point (Item : Session; X, Y : out Float)
     with Pre => Is_Open (Item) and then Preview_Shown (Item);
   --  Where to click on the middle of the preview's window, in points of the window.

   procedure Adopt (Item : in out Session; Row : Positive)
     with Pre => Is_Open (Item) and then Screen (Item) = Project;
   --  Make the work that Source_Finder has (or ended with, as Offer makes it
   --  do) that of this session, for the note that is the Rowth item, as if
   --  its Find Sources button had been clicked.

   procedure Start (Item : in out Session; Row : Positive)
     with Pre => Is_Open (Item) and then Screen (Item) = Project;
   --  As if the Find Sources button of the Rowth item had been clicked.

end Viewer.Found_Sources;
