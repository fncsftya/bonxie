with Items;
with Projects;

--  The items on the project's canvas, in the order they were made, as their
--  windows show them: for tests.
package Viewer.Canvas_Windows is

   function Item_Count (Item : Session) return Natural
     with Pre => Is_Open (Item) and then Screen (Item) = Project;
   --  How many the project has, whether shown or not.

   procedure Add_Item
     (Item : in out Session;
      Name : String := "Untitled item";
      Kind : Items.Kinds := Items.Note)
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Name'Length <= Projects.Title_Capacity;
   --  Add one called Name in the middle of the canvas, with the focus in
   --  its text, as the Add Item button does (or, of a Source, as Add
   --  Source does, in its link); none if the project has Items.Capacity.

   function Item_Title (Item : Session; Row : Positive) return String
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Item_Count (Item);

   function Item_Text (Item : Session; Row : Positive) return String
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Item_Count (Item);

   function Item_Kind (Item : Session; Row : Positive) return Items.Kinds
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Item_Count (Item);

   function Item_Status (Item : Session; Row : Positive) return String
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Item_Count (Item);
   --  What the status line of the item says.

   function Item_State (Item : Session; Row : Positive) return Items.States
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Item_Count (Item);

   function Item_Frame (Item : Session; Row : Positive) return Items.Frame
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Item_Count (Item);
   --  Where it is on the canvas.

   function Item_Box (Item : Session; Row : Positive) return Items.Frame
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Item_Count (Item);
   --  Where its window is on the screen, in pixels, as of the last layout.

   function Is_Editing_Title (Item : Session; Row : Positive) return Boolean
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Item_Count (Item);
   --  Whether the item's title is a field to type in, not text.

   function Item_Words (Item : Session; Row : Positive) return Natural
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Item_Count (Item);
   --  As the status line of the item says.

   --  Dictating into a note

   procedure Dictate_Live
     (Item : in out Session; Row : Positive; Said : String)
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Item_Count (Item)
                 and then Items."=" (Item_Kind (Item, Row), Items.Note);
   --  Show Said in the note's text, as what has been heard so far is
   --  while dictating (see Items.Windows.Set_Live_Dictation): for tests.

   procedure Dictate_Into
     (Item : in out Session; Row : Positive; Said : String)
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Item_Count (Item)
                 and then Items."=" (Item_Kind (Item, Row), Items.Note);
   --  Put Said in the note's text, as what was dictated is when the
   --  microphone is stopped (see Items.Windows.Add_Dictation): for tests,
   --  which cannot speak.

   --  The pictures of sources

   procedure Pin_Capture_Time (Item : in out Session; To : Projects.Seconds)
     with Pre => To > 0;
   --  Record every picture taken from now on as taken at To, whatever
   --  the time is: for tests.

   function Is_Capturing (Item : Session) return Boolean
     with Pre => Is_Open (Item) and then Screen (Item) = Project;
   --  Whether the picture of a page is being taken, for some source.

   function Item_Zoom (Item : Session; Row : Positive) return Float
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Item_Count (Item)
                 and then Items."=" (Item_Kind (Item, Row), Items.Source);
   --  How far the picture of the item is zoomed within its window.

   function Item_Picture_File (Item : Session; Row : Positive) return String
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Item_Count (Item);
   --  Where the picture of the item, if a source, is kept.

   function Item_Recognized (Item : Session; Row : Positive) return Natural
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Item_Count (Item)
                 and then Items."=" (Item_Kind (Item, Row), Items.Source);
   --  How many words of text have been found in the picture of the
   --  source, to be selected over it.

   function Item_Selected_Text (Item : Session; Row : Positive) return String
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Item_Count (Item)
                 and then Items."=" (Item_Kind (Item, Row), Items.Source);
   --  What is selected in the picture of the source: what copying gives.

   function Item_Marks (Item : Session; Row : Positive) return Natural
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Item_Count (Item);
   --  How many highlights the item's picture has.

   function Item_Highlighting (Item : Session; Row : Positive) return Boolean
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Item_Count (Item);
   --  Whether the highlighter is the tool of the item's window.

   function Item_Erasing (Item : Session; Row : Positive) return Boolean
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Item_Count (Item);
   --  Whether the eraser is the tool of the item's window.

end Viewer.Canvas_Windows;
