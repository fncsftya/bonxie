with Ada.Directories;
with Ada.Text_IO;
with Pomarine.Page_Builds;
with SDL3.Events;
with SDL3.Pictures.Jobs;
with Webshot;
with Goldens;
with Item_Tests;
with Items;
with Projects;
with Viewer;
with Viewer.Canvas_Links;
with Viewer.Canvas_Windows;
with Viewer.Documents;
with Viewer.Home_Screen;
with Viewer.Project_Screen;
with Viewer.Sources;

package body Write_Tests is

   package Events renames SDL3.Events;
   package Links renames Viewer.Canvas_Links;
   package Windows renames Viewer.Canvas_Windows;
   package Docs renames Viewer.Documents;
   package Home renames Viewer.Home_Screen;
   package Proj renames Viewer.Project_Screen;
   package Source_List renames Viewer.Sources;
   package Pictures renames Goldens.Images;

   procedure Check (Name : String; Expected, Actual : String)
     renames Goldens.Check_Text;

   Width  : constant := 720;
   Height : constant := 480;
   --  Of the window, in points; the toolbar is 44 high at the top.

   Pin_X     : constant Float := 655.0;
   Pin_Y     : constant Float := 83.0;
   Marker_X  : constant Float := 356.0;
   Status_Y  : constant Float := 440.0;
   --  In the window of the source, when first opened: its pin button, and
   --  the highlighter in its status line.
   Reader_Y  : constant Float := 120.0;
   --  In its picture.

   Canvas_Marker_X : constant Float := 387.5;
   Canvas_Status_Y : constant Float := 339.0;
   --  The highlighter in the status line of the source's window on the
   --  canvas.
   Canvas_Picture_Y : constant Float := 272.0;
   --  In its picture.

   Sources_Button_X : constant Float := 597.0;
   Bar_Y : constant Float := 82.0;
   Menu_Item_X : constant Float := 500.0;
   Menu_Item_Y : constant Float := 138.0;
   --  The first page's Sources button, above it, and the first item of the
   --  menu under it.

   Text_X : constant Float := 650.0;
   Text_Y : constant Float := 140.0;
   --  At the end of the first line of the first page.

   Doc_Row_X : constant Float := 100.0;

   function Tree_Row_Y (Row : Positive) return Float is
     (200.5 + Float (Row - 1) * 38.0);
   --  The rows of the tree of documents, in the sidebar, the Overview's
   --  first.

   function Doc_Row_Y (Row : Positive) return Float is
     (Tree_Row_Y (Row + 1));
   --  Those of the documents, before there are directories.

   Add_Document_X : constant Float := 181.0;
   Add_Directory_X : constant Float := 153.0;
   Add_Document_Y : constant Float := 166.0;
   --  The buttons beside the name of the list of documents.

   Pane_Edge_X : constant Float := 435.0;
   Pane_Pin_X  : constant Float := 682.0;
   Pane_Pin_Y  : constant Float := 59.0;
   --  The edge of the pane, as wide as it starts in a window this size,
   --  and its pin button, after it has been made 50 wider.

   Source_Row_X : constant Float := 100.0;

   function Source_Row_Y (Documents : Natural) return Float is
     (185.0 + 24.5 + 38.0
      + (if Documents = 0 then 31.0
         else Float (Documents) * 34.0 + Float (Documents - 1) * 4.0)
      + 67.5);
   --  The row of the first source, in the sidebar, below the Overview and
   --  the list of so many documents (or the line that says there are
   --  none), and the grammar switch above them and the handle between.

   --  Events

   procedure Move_To (Session : in out Viewer.Session; X, Y : Float;
                      Held : Boolean := False) is
   begin
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Move, Mouse_X => X,
                                Mouse_Y => Y, Left_Held => Held,
                                others => <>));
   end Move_To;

   procedure Click_On (Session : in out Viewer.Session; X, Y : Float) is
   begin
      Move_To (Session, X, Y);
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Down, Button => 1,
                                Clicks => 1, Mouse_X => X, Mouse_Y => Y,
                                others => <>));
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Up, Button => 1,
                                Clicks => 1, Mouse_X => X, Mouse_Y => Y,
                                others => <>));
   end Click_On;

   procedure Type_In (Session : in out Viewer.Session; Text : String) is
   begin
      Viewer.Handle (Session, Events.Text_Event (Text));
   end Type_In;

   procedure Drag
     (Session : in out Viewer.Session; From_X, From_Y, To_X, To_Y : Float) is
   begin
      Move_To (Session, From_X, From_Y);
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Down, Button => 1,
                                Clicks => 1, Mouse_X => From_X,
                                Mouse_Y => From_Y, others => <>));
      Move_To
        (Session, (From_X + To_X) / 2.0, (From_Y + To_Y) / 2.0, Held => True);
      Move_To (Session, To_X, To_Y, Held => True);
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Up, Button => 1,
                                Clicks => 1, Mouse_X => To_X, Mouse_Y => To_Y,
                                others => <>));
   end Drag;

   procedure Settle (Session : in out Viewer.Session) is
      Drawn : Pictures.Image;
   begin
      --  Drawn, as it is between a person's clicks, which lays it out.
      Viewer.Render (Session, Drawn);
      SDL3.Pictures.Jobs.Wait_Until_Idle;
      Pomarine.Page_Builds.Wait_Until_Idle;
      Viewer.Handle (Session, (Kind => Events.Redraw, others => <>));
   end Settle;

   procedure Snap (Session : in out Viewer.Session; Name : String) is
      Drawn : Pictures.Image;
   begin
      Viewer.Render (Session, Drawn);
      SDL3.Pictures.Jobs.Wait_Until_Idle;
      Pomarine.Page_Builds.Wait_Until_Idle;
      Viewer.Handle (Session, (Kind => Events.Redraw, others => <>));
      Viewer.Render (Session, Drawn);
      Goldens.Check (Name, Drawn);
   end Snap;

   procedure Start_With_Three (Session : in out Viewer.Session; High : Positive := Height) is
   begin
      Viewer.Open (Session, "", Width, High, 2.0);
      Home.New_Project (Session);
      Viewer.Project_Screen.Set_Mode (Session, Viewer.Canvas);
      Windows.Add_Item (Session, "Opening");
      Type_In (Session, "It was a dark and stormy night.");
      Windows.Add_Item (Session, "Middle");
      Type_In (Session, "Then things happened.");
      Windows.Add_Item (Session, "Page", Items.Source);
      Windows.Add_Item (Session, "Ending");
      Type_In (Session, "And they all lived.");
      Move_To (Session, 600.0, 60.0);
   end Start_With_Three;

   procedure Searching is
      Session : Viewer.Session;
      procedure Key (Code : Events.Key_Code; Command : Boolean := False; Shift : Boolean := False) is
      begin
         Viewer.Handle (Session, (Kind => Events.Key_Down, Key => Code,
                                  Command => Command, Shift => Shift, others => <>));
      end Key;
      procedure Expect (Name : String; Total, Current, Document : Natural) is
      begin
         Check (Name & "-count", Total'Image, Docs.Search_Count (Session)'Image);
         Check (Name & "-current", Current'Image, Docs.Search_Current (Session)'Image);
         Check (Name & "-document", Document'Image, Docs.Search_Document (Session)'Image);
      end Expect;
   begin
      Start_With_Three (Session);
      Proj.Set_Mode (Session, Viewer.Write);
      Settle (Session);
      Docs.Add_Directory (Session, "First only");
      Docs.Move_Document_To (Session, 1, 1);
      Docs.Show_Directory (Session, 1);
      Settle (Session);
      Key (Events.Key_F, Command => True);
      Type_In (Session, "th");
      Expect ("write-search-all", 3, 1, 1);
      Snap (Session, "write-search-first");
      Check ("write-search-reveals-hidden", " 0", Docs.Shown_Directory (Session)'Image);
      Key (Events.Key_F3);
      Expect ("write-search-next", 3, 2, 1);
      Key (Events.Key_F3);
      Expect ("write-search-next-document", 3, 3, 2);
      Snap (Session, "write-search-last");
      Key (Events.Key_F3);
      Expect ("write-search-wrap", 3, 1, 1);
      Key (Events.Key_F3, Shift => True);
      Expect ("write-search-wrap-back", 3, 3, 2);
      Key (Events.Key_Return);
      Expect ("write-search-enter", 3, 3, 2);
      Click_On (Session, 652.0, 458.0);
      Expect ("write-search-button-next", 3, 1, 1);
      Click_On (Session, 608.0, 458.0);
      Expect ("write-search-button-back", 3, 3, 2);
      Key (Events.Key_F, Command => True);
      Type_In (Session, "absent");
      Expect ("write-search-absent", 0, 0, 0);
      Key (Events.Key_F3);
      Snap (Session, "write-search-empty");
      Key (Events.Key_F, Command => True);
      Type_In (Session, "th");
      Key (Events.Key_Escape);
      Check ("write-search-closed", "FALSE", Windows.Search_Is_Open (Session)'Image);
      for Rank in 1 .. Docs.Document_Count (Session) loop
         Check ("write-search-cleared", " 0", Docs.Search_Highlights (Session, Rank)'Image);
      end loop;
      Snap (Session, "write-search-dismissed");
   end Searching;

   procedure Pages is
      Session : Viewer.Session;
   begin
      Start_With_Three (Session);
      Proj.Set_Mode (Session, Viewer.Write);
      Check ("write-mode", "WRITE",
             Viewer.Modes'Image (Proj.Mode (Session)));
      Check ("write-documents", " 3",
             Natural'Image (Docs.Document_Count (Session)));
      Check ("write-sources", " 1",
             Natural'Image (Source_List.Source_Count (Session)));
      Check ("write-first", "Opening", Docs.Document_Title (Session, 1));
      Check ("write-last", "Ending", Docs.Document_Title (Session, 3));
      Snap (Session, "write-pages");
      Proj.Set_Mode (Session, Viewer.Canvas);
      Snap (Session, "write-back-to-canvas");
   end Pages;

   procedure Ordering is
      Session : Viewer.Session;
      Key     : Projects.Id;
   begin
      Start_With_Three (Session);
      Key := Proj.Current_Project (Session);
      Proj.Set_Mode (Session, Viewer.Write);
      Docs.Move_Document (Session, 3, 1);
      Check ("write-moved-first", "Ending",
             Docs.Document_Title (Session, 1));
      Check ("write-moved-second", "Opening",
             Docs.Document_Title (Session, 2));
      Snap (Session, "write-reordered");
      Proj.Close_Project (Session);
      Home.Open_Project (Session, Key);
      Viewer.Project_Screen.Set_Mode (Session, Viewer.Canvas);
      Proj.Set_Mode (Session, Viewer.Write);
      Check ("write-order-kept", "Ending",
             Docs.Document_Title (Session, 1));
      Check ("write-order-kept-last", "Middle",
             Docs.Document_Title (Session, 3));
   end Ordering;

   procedure Dragging is
      Session : Viewer.Session;
   begin
      Start_With_Three (Session);
      Proj.Set_Mode (Session, Viewer.Write);
      Settle (Session);
      --  The first row is dragged down past the others, to the lower half
      --  of the last, which puts it after.
      Drag (Session, Doc_Row_X, Doc_Row_Y (1), Doc_Row_X,
            Doc_Row_Y (3) + 8.0);
      Check ("write-dragged-first", "Middle",
             Docs.Document_Title (Session, 1));
      Check ("write-dragged-last", "Opening",
             Docs.Document_Title (Session, 3));
      Move_To (Session, 600.0, 60.0);
      Snap (Session, "write-dragged");

      --  A click on a row is not a drag: nothing is moved, and the pages
      --  go to its page.
      Settle (Session);
      Click_On (Session, Doc_Row_X, Doc_Row_Y (3));
      Check ("write-clicked-not-moved", "Opening",
             Docs.Document_Title (Session, 3));
      Settle (Session);
      Move_To (Session, 600.0, 60.0);
      Snap (Session, "write-scrolled-to-page");
   end Dragging;

   procedure Name_Directory (Session : in out Viewer.Session; Name : String)
   is
   begin
      Type_In (Session, Name);
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Key_Down,
                                Key => Events.Key_Return, others => <>));
      Settle (Session);
   end Name_Directory;

   procedure Many_Directories is
      Session : Viewer.Session;
      Many    : constant := 140;
   begin
      Start_With_Three (Session, High => 640);
      Proj.Set_Mode (Session, Viewer.Write);
      Settle (Session);
      for Each in 1 .. Many loop
         Docs.Add_Directory (Session);
      end loop;
      Check ("write-many-directories", Natural'Image (Many), Natural'Image (Docs.Directory_Count (Session)));
   end Many_Directories;

   procedure Directories is
      Session : Viewer.Session;
      Key     : Projects.Id;

      function Where (Row : Positive) return String is
        (Natural'Image (Docs.Document_Directory (Session, Row)));
   begin
      --  Tall enough for all the rows of the tree.
      Start_With_Three (Session, High => 640);
      Key := Proj.Current_Project (Session);
      Proj.Set_Mode (Session, Viewer.Write);
      Settle (Session);

      --  The button beside the name of the list makes one, last of the
      --  tree, and its name is renamed at once.
      Click_On (Session, Add_Directory_X, Add_Document_Y);
      Check ("write-directory-made", " 1",
             Natural'Image (Docs.Directory_Count (Session)));
      Check ("write-directory-named", "Untitled folder",
             Docs.Directory_Title (Session, 1));
      Name_Directory (Session, "Part one");
      Check ("write-directory-renamed", "Part one",
             Docs.Directory_Title (Session, 1));
      Move_To (Session, 600.0, 60.0);
      Snap (Session, "write-directory-listed");

      --  A document dropped on it (the middle of its row) is in it.
      Drag (Session, Doc_Row_X, Tree_Row_Y (4), Doc_Row_X, Tree_Row_Y (5));
      Check ("write-dropped-in", " 1", Where (3));
      Check ("write-dropped-last", "Ending",
             Docs.Document_Title (Session, 3));
      Check ("write-dropped-others", " 0", Where (1));
      Settle (Session);
      Move_To (Session, 600.0, 60.0);
      Snap (Session, "write-directory-dropped");

      --  Clicking the directory shows only its documents; the Overview,
      --  all of them.
      Click_On (Session, Doc_Row_X, Tree_Row_Y (4));
      Settle (Session);
      Check ("write-directory-shown", " 1",
             Natural'Image (Docs.Shown_Directory (Session)));
      Move_To (Session, 600.0, 60.0);
      Snap (Session, "write-directory-pages");
      Click_On (Session, Doc_Row_X, Tree_Row_Y (1));
      Settle (Session);
      Check ("write-overview-shown", " 0",
             Natural'Image (Docs.Shown_Directory (Session)));

      --  Held over the top of the directory's row, a line shows above it;
      --  let go, the document is before it, and in none.
      Move_To (Session, Doc_Row_X, Tree_Row_Y (2));
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Down, Button => 1,
                                Clicks => 1, Mouse_X => Doc_Row_X,
                                Mouse_Y => Tree_Row_Y (2), others => <>));
      Move_To (Session, Doc_Row_X, Tree_Row_Y (3), Held => True);
      Move_To (Session, Doc_Row_X, Tree_Row_Y (4) - 10.0, Held => True);
      Settle (Session);
      Snap (Session, "write-drop-line");
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Up, Button => 1,
                                Clicks => 1, Mouse_X => Doc_Row_X,
                                Mouse_Y => Tree_Row_Y (4) - 10.0,
                                others => <>));
      Check ("write-before-directory", "Middle",
             Docs.Document_Title (Session, 1));
      Check ("write-before-directory-moved", "Opening",
             Docs.Document_Title (Session, 2));
      Check ("write-before-directory-in-none", " 0", Where (2));

      --  The foot of the last document in a directory puts one after it.
      Drag (Session, Doc_Row_X, Tree_Row_Y (2), Doc_Row_X,
            Tree_Row_Y (5) + 13.0);
      Check ("write-after-directory", "Middle",
             Docs.Document_Title (Session, 3));
      Check ("write-after-directory-in-none", " 0", Where (3));
      Check ("write-after-directory-others", " 1", Where (2));

      --  A second directory is put before the first row, a directory with
      --  its documents after the last, and one is taken out of it.
      Click_On (Session, Add_Directory_X, Add_Document_Y);
      Name_Directory (Session, "Part two");
      Drag (Session, Doc_Row_X, Tree_Row_Y (6), Doc_Row_X,
            Tree_Row_Y (2) - 8.0);
      Drag (Session, Doc_Row_X, Tree_Row_Y (4), Doc_Row_X,
            Tree_Row_Y (6) + 10.0);
      Check ("write-directory-moved-first", "Opening",
             Docs.Document_Title (Session, 1));
      Check ("write-directory-moved-second", "Middle",
             Docs.Document_Title (Session, 2));
      Check ("write-directory-moved-with-its-documents", "Ending",
             Docs.Document_Title (Session, 3));
      Check ("write-directory-moved-with-its-documents-in", " 1", Where (3));
      Settle (Session);
      Move_To (Session, 600.0, 60.0);
      Snap (Session, "write-directories-moved");

      --  On the Overview, a document is out of its directory, and last.
      Drag (Session, Doc_Row_X, Tree_Row_Y (6), Doc_Row_X, Tree_Row_Y (1));
      Check ("write-overview-dropped", " 0", Where (3));
      Check ("write-overview-dropped-last", "Ending",
             Docs.Document_Title (Session, 3));
      Drag (Session, Doc_Row_X, Tree_Row_Y (4), Doc_Row_X, Tree_Row_Y (5));
      Check ("write-dropped-in-the-moved", " 1", Where (2));

      --  Their order, and what is in them, are kept.
      Proj.Close_Project (Session);
      Home.Open_Project (Session, Key);
      Viewer.Project_Screen.Set_Mode (Session, Viewer.Canvas);
      Proj.Set_Mode (Session, Viewer.Write);
      Check ("write-directories-kept", " 2",
             Natural'Image (Docs.Directory_Count (Session)));
      Check ("write-directory-order-kept", "Part two",
             Docs.Directory_Title (Session, 1));
      Check ("write-directory-name-kept", "Part one",
             Docs.Directory_Title (Session, 2));
      Check ("write-directory-contents-kept", " 2", Where (2));
      Check ("write-directory-others-kept", " 0", Where (3));
      Check ("write-directory-order-of-documents-kept", "Middle",
             Docs.Document_Title (Session, 2));
      Check ("write-directory-shown-again", " 0",
             Natural'Image (Docs.Shown_Directory (Session)));
      Settle (Session);
      Move_To (Session, 600.0, 60.0);
      Snap (Session, "write-directories-kept");
   end Directories;

   Confirm_Delete_X : constant Float := 460.0;
   Confirm_Cancel_X : constant Float := 352.0;
   Confirm_Y        : constant Float := 301.0;
   --  The buttons of the dialog that confirms a deletion.

   procedure Right_Click_On (Session : in out Viewer.Session; X, Y : Float) is
   begin
      Move_To (Session, X, Y);
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Down, Button => 3,
                                Clicks => 1, Mouse_X => X, Mouse_Y => Y,
                                others => <>));
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Up, Button => 3,
                                Clicks => 1, Mouse_X => X, Mouse_Y => Y,
                                others => <>));
   end Right_Click_On;

   procedure Context_Menus is
      Session : Viewer.Session;
      Key     : Projects.Id;

      Rename_Dy : constant Float := 17.0;
      Delete_Dy : constant Float := 43.0;
      --  The rows of the menu, below where it was asked for.

      procedure Choose (Row_Y, Dy : Float) is
      begin
         Right_Click_On (Session, Doc_Row_X, Row_Y);
         Settle (Session);
         Click_On (Session, Doc_Row_X + 40.0,
                   (if Dy > Delete_Dy then Float'Min (Row_Y, 480.0 - 124.0) else Row_Y) + Dy);
         Settle (Session);
      end Choose;
   begin
      Start_With_Three (Session);
      Key := Proj.Current_Project (Session);
      Proj.Set_Mode (Session, Viewer.Write);
      Settle (Session);
      Right_Click_On (Session, Doc_Row_X, Doc_Row_Y (2));
      Settle (Session);
      Snap (Session, "write-context-menu");

      --  Rename puts a field over the row, as a directory's.
      Click_On (Session, Doc_Row_X + 40.0, Doc_Row_Y (2) + Rename_Dy);
      Settle (Session);
      Type_In (Session, "Centre");
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Key_Down,
                                Key => Events.Key_Return, others => <>));
      Settle (Session);
      Check ("write-context-renamed", "Centre",
             Docs.Document_Title (Session, 2));

      Click_On (Session, Add_Directory_X, Add_Document_Y);
      Name_Directory (Session, "Part one");
      Choose (Tree_Row_Y (5), Rename_Dy + 61.0);
      Type_In (Session, "Act one");
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Key_Down,
                                Key => Events.Key_Return, others => <>));
      Settle (Session);
      Check ("write-context-directory-renamed", "Act one",
             Docs.Directory_Title (Session, 1));
      Drag (Session, Doc_Row_X, Tree_Row_Y (4), Doc_Row_X, Tree_Row_Y (5));
      Settle (Session);

      --  Delete asks first; Escape leaves it all.
      Choose (Tree_Row_Y (5), Delete_Dy);
      Check ("write-delete-asked", "TRUE",
             Boolean'Image (Home.Is_Confirming (Session)));
      Move_To (Session, 600.0, 60.0);
      Snap (Session, "write-delete-confirm");
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Key_Down,
                                Key => Events.Key_Escape, others => <>));
      Check ("write-delete-escaped", "FALSE",
             Boolean'Image (Home.Is_Confirming (Session)));
      Check ("write-delete-escaped-kept", " 1",
             Natural'Image (Docs.Directory_Count (Session)));

      --  Deleting a directory keeps what was in it, in none.
      Choose (Tree_Row_Y (4), Delete_Dy + 61.0);
      Check ("write-delete-directory-asked", "TRUE",
             Boolean'Image (Home.Is_Confirming (Session)));
      Click_On (Session, Confirm_Delete_X, Confirm_Y);
      Settle (Session);
      Check ("write-delete-directory", " 0",
             Natural'Image (Docs.Directory_Count (Session)));
      Check ("write-delete-directory-kept-documents", " 3",
             Natural'Image (Docs.Document_Count (Session)));
      Check ("write-delete-directory-kept-ending", "Ending",
             Docs.Document_Title (Session, 3));
      Check ("write-delete-directory-in-none", " 0",
             Natural'Image (Docs.Document_Directory (Session, 3)));

      --  Cancel deletes nothing; Delete deletes a document.
      Choose (Tree_Row_Y (3), Delete_Dy);
      Click_On (Session, Confirm_Cancel_X, Confirm_Y);
      Check ("write-delete-cancelled", " 3",
             Natural'Image (Docs.Document_Count (Session)));
      Choose (Tree_Row_Y (3), Delete_Dy);
      Click_On (Session, Confirm_Delete_X, Confirm_Y);
      Settle (Session);
      Check ("write-delete-document", " 2",
             Natural'Image (Docs.Document_Count (Session)));
      Check ("write-delete-document-gone", "Ending",
             Docs.Document_Title (Session, 2));
      Move_To (Session, 600.0, 60.0);
      Snap (Session, "write-deleted");

      --  They are gone for good.
      Proj.Close_Project (Session);
      Home.Open_Project (Session, Key);
      Viewer.Project_Screen.Set_Mode (Session, Viewer.Canvas);
      Proj.Set_Mode (Session, Viewer.Write);
      Check ("write-delete-kept-documents", " 2",
             Natural'Image (Docs.Document_Count (Session)));
      Check ("write-delete-kept-directories", " 0",
             Natural'Image (Docs.Directory_Count (Session)));
   end Context_Menus;

   procedure Context_Menus_Elsewhere is
      Session : Viewer.Session;

      procedure Choose (X, Y, Dy : Float) is
      begin
         Right_Click_On (Session, X, Y);
         Settle (Session);
         Click_On (Session, Float'Min (X, 560.0) + 60.0, Y + Dy);
         Settle (Session);
      end Choose;

      Source_Y : constant Float := Source_Row_Y (3);
   begin
      Start_With_Three (Session);
      Proj.Set_Mode (Session, Viewer.Write);
      Settle (Session);

      --  In a page's text, with nothing on the clipboard, only Select all
      --  can be chosen: Paste is faint.
      Right_Click_On (Session, 400.0, Text_Y);
      Settle (Session);
      Snap (Session, "write-context-text");
      Click_On (Session, 460.0, Text_Y + 43.0);
      Settle (Session);

      --  On the selection, Copy, Cut and Paste: cut, it is gone.
      Right_Click_On (Session, 300.0, Text_Y);
      Settle (Session);
      Snap (Session, "write-context-selection");
      Click_On (Session, 360.0, Text_Y + 43.0);
      Settle (Session);
      Check ("write-context-cut", "", Windows.Item_Text (Session, 1));

      --  Now there is something to paste, which is put back.
      Right_Click_On (Session, 300.0, Text_Y);
      Settle (Session);
      Click_On (Session, 360.0, Text_Y + 17.0);
      Settle (Session);
      Check ("write-context-pasted", "It was a dark and stormy night.",
             Windows.Item_Text (Session, 1));

      --  In a source's window; it has no words, so Select all is faint.
      Click_On (Session, Source_Row_X, Source_Y);
      Settle (Session);
      Right_Click_On (Session, 340.0, Reader_Y);
      Settle (Session);
      Snap (Session, "write-context-source");
      Move_To (Session, 700.0, 300.0);

      --  A source in the list is renamed on the canvas as well, and
      --  deleted there.
      Choose (Source_Row_X, Source_Y, 17.0);
      Type_In (Session, "Renamed");
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Key_Down,
                                Key => Events.Key_Return, others => <>));
      Settle (Session);
      Check ("write-source-renamed", "Renamed",
             Source_List.Source_Title (Session, 1));
      Check ("write-source-renamed-on-canvas", "Renamed",
             Windows.Item_Title (Session, 3));
      Choose (Source_Row_X, Source_Y, 43.0);
      Check ("write-source-delete-asked", "TRUE",
             Boolean'Image (Home.Is_Confirming (Session)));
      Click_On (Session, Confirm_Delete_X, Confirm_Y);
      Settle (Session);
      Check ("write-source-deleted", " 0",
             Natural'Image (Source_List.Source_Count (Session)));
      Check ("write-source-deleted-on-canvas", " 3",
             Natural'Image (Windows.Item_Count (Session)));
   end Context_Menus_Elsewhere;

   procedure Context_Menus_On_Canvas is
      Session : Viewer.Session;
      --  The last window's text, and the link of the source's, which shows
      --  at the left of the windows over it.
      Text_At_X : constant Float := 450.0;
      Text_At_Y : constant Float := 330.0;
      Word_At_X : constant Float := 350.0;
      Word_At_Y : constant Float := 285.0;
      Link_At_X : constant Float := 530.0;
      Link_At_Y : constant Float := 220.0;

      procedure Choose (X, Y, Dy : Float) is
      begin
         Right_Click_On (Session, X, Y);
         Settle (Session);
         Click_On (Session, Float'Min (X, 560.0) + 60.0, Y + Dy);
         Settle (Session);
      end Choose;
   begin
      Start_With_Three (Session);
      Settle (Session);

      --  In a window's text, as in a page's: Paste is faint with nothing
      --  to paste, and Select all has no icon.
      Right_Click_On (Session, Text_At_X, Text_At_Y);
      Settle (Session);
      Snap (Session, "write-canvas-context-text");
      Click_On (Session, Text_At_X + 60.0, Text_At_Y + 43.0);
      Settle (Session);

      --  On the selection, Copy, Cut and Paste.
      Choose (Word_At_X, Word_At_Y, 43.0);
      Check ("write-canvas-cut", "", Windows.Item_Text (Session, 4));
      Choose (Text_At_X, Text_At_Y, 17.0);
      Check ("write-canvas-pasted", "And they all lived.",
             Windows.Item_Text (Session, 4));

      --  In a source's link, once its window is raised.
      Click_On (Session, Link_At_X, Link_At_Y);
      Settle (Session);
      Right_Click_On (Session, 300.0, 254.0);
      Settle (Session);
      Snap (Session, "write-canvas-context-link");
      --  And in its picture, which has no words yet.
      Right_Click_On (Session, 400.0, 330.0);
      Settle (Session);
      Snap (Session, "write-canvas-context-picture");
   end Context_Menus_On_Canvas;

   procedure Adding is
      Session : Viewer.Session;
   begin
      Start_With_Three (Session);
      Proj.Set_Mode (Session, Viewer.Write);
      Settle (Session);
      Click_On (Session, Add_Document_X, Add_Document_Y);
      Check ("write-added", " 4",
             Natural'Image (Docs.Document_Count (Session)));
      Check ("write-added-title", "Untitled document",
             Docs.Document_Title (Session, 4));
      --  It is where the typing goes.
      Type_In (Session, "Fresh.");
      Check ("write-added-typed", "Fresh.", Windows.Item_Text (Session, 5));
      Move_To (Session, 600.0, 60.0);
      Snap (Session, "write-added");
   end Adding;

   procedure Linked_Sources is
      Session : Viewer.Session;
   begin
      Start_With_Three (Session);
      --  The first and last documents are linked to the source.
      Links.Link_Items (Session, 1, 3);
      Links.Link_Items (Session, 3, 4);
      Proj.Set_Mode (Session, Viewer.Write);
      Settle (Session);
      Click_On (Session, Sources_Button_X, Bar_Y);
      Settle (Session);
      Move_To (Session, 600.0, 300.0);
      Snap (Session, "write-sources-menu");
      --  An item of the menu opens and pins the source.
      Click_On (Session, Menu_Item_X, Menu_Item_Y);
      Settle (Session);
      Check ("write-menu-pinned", " 1",
             Natural'Image (Source_List.Pinned_Source (Session)));
      --  A document with no links has none to list.
      Move_To (Session, 600.0, 300.0);
      Snap (Session, "write-sources-pinned-from-menu");
   end Linked_Sources;

   procedure Typing is
      Session : Viewer.Session;
   begin
      Start_With_Three (Session);
      Proj.Set_Mode (Session, Viewer.Write);
      Click_On (Session, Text_X, Text_Y);
      Type_In (Session, " More.");
      Snap (Session, "write-typed");
      --  It is in the item's window on the canvas too, which writes it.
      Check ("write-typed-text", "It was a dark and stormy night. More.",
             Windows.Item_Text (Session, 1));
      Proj.Set_Mode (Session, Viewer.Canvas);
      Check ("write-typed-words", " 8",
             Natural'Image (Windows.Item_Words (Session, 1)));
      Proj.Set_Mode (Session, Viewer.Write);
      Check ("write-typed-still", "It was a dark and stormy night. More.",
             Windows.Item_Text (Session, 1));

      --  Typed on a page, it is kept as if typed on the canvas.
      declare
         Key : constant Projects.Id := Proj.Current_Project (Session);
      begin
         Proj.Close_Project (Session);
         Home.Open_Project (Session, Key);
         Viewer.Project_Screen.Set_Mode (Session, Viewer.Canvas);
         Check ("write-typed-kept", "It was a dark and stormy night. More.",
                Windows.Item_Text (Session, 1));
      end;
   end Typing;

   procedure Word_Tools is
      Session : Viewer.Session;

      procedure Command_Key (Letter : Character) is
      begin
         Viewer.Handle
           (Session, Events.Event'(Kind => Events.Key_Down, Key => Events.Key_Code (Character'Pos (Letter)),
                                   Command => True, others => <>));
         Settle (Session);
      end Command_Key;

      procedure Select_Everything is
      begin
         Viewer.Handle
           (Session, Events.Event'(Kind => Events.Key_Down, Key => Events.Key_A, Command => True,
                                   others => <>));
      end Select_Everything;
   begin
      Start_With_Three (Session);
      Proj.Set_Mode (Session, Viewer.Write);
      Click_On (Session, Text_X, Text_Y);

      --  Nothing is selected: nothing is done.
      Command_Key ('d');
      Command_Key ('r');
      Check ("write-tools-need-selection", "It was a dark and stormy night.", Windows.Item_Text (Session, 1));
      Check ("write-tools-none-kept", "<version>1</version><p>It was a dark and stormy night.</p>",
             Windows.Item_Stored_Text (Session, 1));

      --  Faded, and kept so.
      Select_Everything;
      Command_Key ('d');
      Check ("write-fade-kept", "<version>1</version><p><f>It was a dark and stormy night.</f></p>",
             Windows.Item_Stored_Text (Session, 1));
      Command_Key ('d');
      Check ("write-fade-undone", "<version>1</version><p>It was a dark and stormy night.</p>",
             Windows.Item_Stored_Text (Session, 1));

      --  Reworded: the text goes, what is typed is the other version.
      Command_Key ('r');
      Check ("write-reword-gone", "", Windows.Item_Text (Session, 1));
      Type_In (Session, "Once upon a time.");
      Viewer.Handle (Session, Events.Event'(Kind => Events.Key_Down, Key => Events.Key_Return, others => <>));
      Settle (Session);
      Check ("write-reword-kept",
             "<version>1</version><p><v sel=""2""><o>It was a dark and stormy night.</o>Once upon a time.</v></p>",
             Windows.Item_Stored_Text (Session, 1));
      Check ("write-reword-text", "Once upon a time.", Windows.Item_Text (Session, 1));

      --  Given up with Escape, it is as it was; the versions come back after the project is reopened.
      Select_Everything;
      Command_Key ('r');
      Type_In (Session, "Never.");
      Viewer.Handle (Session, Events.Event'(Kind => Events.Key_Down, Key => Events.Key_Escape, others => <>));
      Settle (Session);
      Check ("write-reword-given-up", "Once upon a time.", Windows.Item_Text (Session, 1));
      declare
         Key : constant Projects.Id := Proj.Current_Project (Session);
      begin
         Proj.Close_Project (Session);
         Home.Open_Project (Session, Key);
         Viewer.Project_Screen.Set_Mode (Session, Viewer.Canvas);
         Check ("write-reword-persisted",
                "<version>1</version><p><v sel=""2""><o>It was a dark and stormy night.</o>Once upon a time.</v></p>",
                Windows.Item_Stored_Text (Session, 1));
      end;
   end Word_Tools;

   procedure Sources is
      Session : Viewer.Session;
   begin
      Start_With_Three (Session);
      Proj.Set_Mode (Session, Viewer.Write);
      Snap (Session, "write-sources-listed");
      Check ("write-source-closed", "FALSE",
             Boolean'Image (Source_List.Source_Is_Open (Session, 1)));
      Click_On (Session, Source_Row_X, Source_Row_Y (3));
      Settle (Session);
      Check ("write-source-opened", "TRUE",
             Boolean'Image (Source_List.Source_Is_Open (Session, 1)));
      Move_To (Session, 600.0, 60.0);
      Snap (Session, "write-source-window");

      --  Pinned, it is in the pane, and has no window.
      Click_On (Session, Pin_X, Pin_Y);
      Settle (Session);
      Check ("write-source-pinned", " 1",
             Natural'Image (Source_List.Pinned_Source (Session)));
      Move_To (Session, 600.0, 60.0);
      Snap (Session, "write-source-pinned");

      --  The edge of the pane is dragged to size it.
      Drag (Session, Pane_Edge_X, 200.0, Pane_Edge_X - 50.0, 200.0);
      Move_To (Session, 600.0, 60.0);
      Snap (Session, "write-pane-sized");

      --  Its pin button lets it go to a window again.
      Click_On (Session, Pane_Pin_X, Pane_Pin_Y);
      Settle (Session);
      Check ("write-pane-let-go", " 0",
             Natural'Image (Source_List.Pinned_Source (Session)));
      Check ("write-pane-window", "TRUE",
             Boolean'Image (Source_List.Source_Is_Open (Session, 1)));
      Click_On (Session, Source_Row_X, Source_Row_Y (3));
      Settle (Session);
      Click_On (Session, Source_Row_X, Source_Row_Y (3));
      Settle (Session);
      Click_On (Session, Pin_X, Pin_Y);
      Settle (Session);
      Click_On (Session, Source_Row_X, Source_Row_Y (3));
      Check ("write-source-unpinned", " 0",
             Natural'Image (Source_List.Pinned_Source (Session)));
      Check ("write-source-closed-again", "FALSE",
             Boolean'Image (Source_List.Source_Is_Open (Session, 1)));
   end Sources;

   procedure Source_Documents is
      Session : Viewer.Session;
      Folder  : constant String := "/tmp/bonxie-write-document";
      Book    : constant String := Folder & "/book.pdf";
      File    : Ada.Text_IO.File_Type;
      Tick    : SDL3.Events.Milliseconds := 1_000;

      procedure Wait is
         Waited : Natural := 0;
      begin
         while Windows.Is_Capturing (Session) and then Waited < 600 loop
            delay 0.05;
            Tick := SDL3.Events.Milliseconds (Natural (Tick) + 100);
            Viewer.Tick (Session, Tick);
            Waited := Waited + 1;
         end loop;
      end Wait;
   begin
      if not Ada.Directories.Exists (Folder) then
         Ada.Directories.Create_Path (Folder);
      end if;
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Book);
      Ada.Text_IO.Put (File, Item_Tests.Two_Pages);
      Ada.Text_IO.Close (File);

      Viewer.Open (Session, "", Width, Height, 2.0);
      Home.New_Project (Session);
      Viewer.Project_Screen.Set_Mode (Session, Viewer.Canvas);
      Windows.Pin_Capture_Time (Session, 1_700_000_000);
      Windows.Add_Item (Session, "Book", Items.Source);
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Key_Down,
                                Key => Events.Key_A, Command => True,
                                others => <>));
      Type_In (Session, "file://" & Book);
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Key_Down,
                                Key => Events.Key_Return, others => <>));
      Wait;

      --  The page that was drawn on the canvas is in the writing view.
      Proj.Set_Mode (Session, Viewer.Write);
      Click_On (Session, Source_Row_X, Source_Row_Y (0));
      Settle (Session);
      Check ("write-document-open", "TRUE",
             Boolean'Image (Source_List.Source_Is_Open (Session, 1)));
      Move_To (Session, 600.0, 60.0);
      Snap (Session, "write-source-document");

      --  Turned on the canvas, the next is in the writing view too.
      Proj.Set_Mode (Session, Viewer.Canvas);
      Settle (Session);
      Click_On (Session, Item_Tests.Next_X, Item_Tests.Pager_Y);
      Wait;
      Check ("write-document-turned", "Page 2 of 2", Windows.Item_Status (Session, 1));
      Proj.Set_Mode (Session, Viewer.Write);
      Settle (Session);
      Move_To (Session, 600.0, 60.0);
      Snap (Session, "write-source-document-second");

      Ada.Directories.Delete_Tree
        (Ada.Directories.Containing_Directory
           (Ada.Directories.Containing_Directory
              (Windows.Item_Picture_File (Session, 1))));
      Ada.Directories.Delete_Tree (Folder);
   end Source_Documents;

   procedure Sharing_Marks is
      Session : Viewer.Session;
      Folder  : constant String := "/tmp/bonxie-write-page";
      Page    : constant String := Folder & "/page.html";
      File    : Ada.Text_IO.File_Type;
      Tick    : SDL3.Events.Milliseconds := 1_000;
      Waited  : Natural := 0;
   begin
      if not Ada.Directories.Exists (Folder) then
         Ada.Directories.Create_Path (Folder);
      end if;
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Page);
      Ada.Text_IO.Put
        (File, "<html><body><h1>Sharing</h1><p>Some words to mark, over "
         & "a few lines of text on a page.</p></body></html>");
      Ada.Text_IO.Close (File);

      Viewer.Open (Session, "", Width, Height, 2.0);
      Home.New_Project (Session);
      Viewer.Project_Screen.Set_Mode (Session, Viewer.Canvas);
      Windows.Pin_Capture_Time (Session, 1_700_000_000);
      Windows.Add_Item (Session, "Page", Items.Source);
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Key_Down,
                                Key => Events.Key_A, Command => True,
                                others => <>));
      Type_In (Session, "file://" & Page);
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Key_Down,
                                Key => Events.Key_Return, others => <>));
      while Windows.Is_Capturing (Session) and then Waited < 600 loop
         Webshot.Pump (100);
         Tick := SDL3.Events.Milliseconds (Natural (Tick) + 100);
         Viewer.Tick (Session, Tick);
         Waited := Waited + 1;
      end loop;
      Proj.Set_Mode (Session, Viewer.Write);
      Click_On (Session, Source_Row_X, Source_Row_Y (0));
      Settle (Session);
      Check ("write-marks-none", " 0",
             Natural'Image (Source_List.Source_Marks (Session, 1)));

      --  Marked in the writing view, they are on the canvas too.
      Click_On (Session, Marker_X, Status_Y);
      Drag (Session, 340.0, Reader_Y, 340.0, Reader_Y + 40.0);
      Check ("write-marks-made", " 1",
             Natural'Image (Source_List.Source_Marks (Session, 1)));
      Check ("write-marks-shared", " 1",
             Natural'Image (Windows.Item_Marks (Session, 1)));

      --  And erased on the canvas, they are gone from the writing view.
      Proj.Set_Mode (Session, Viewer.Canvas);
      Check ("write-marks-in-canvas", " 1",
             Natural'Image (Windows.Item_Marks (Session, 1)));

      --  Marked there, they are in the writing view too.
      Settle (Session);
      Click_On (Session, Canvas_Marker_X, Canvas_Status_Y);
      Drag (Session, 300.0, Canvas_Picture_Y, 400.0, Canvas_Picture_Y - 30.0);
      Check ("write-marks-more", " 2",
             Natural'Image (Windows.Item_Marks (Session, 1)));
      --  Undo can cross from the canvas stroke back through the reader's
      --  stroke; redo restores both, and every change is shared and saved.
      Viewer.Handle (Session, (Kind => Events.Key_Down, Key => Events.Key_Z, Command => True, others => <>));
      Check ("write-marks-undo-canvas", " 1", Natural'Image (Windows.Item_Marks (Session, 1)));
      Viewer.Handle (Session, (Kind => Events.Key_Down, Key => Events.Key_Z, Command => True, others => <>));
      Check ("write-marks-undo-reader", " 0", Natural'Image (Windows.Item_Marks (Session, 1)));
      for Index in 1 .. 2 loop
         Viewer.Handle
           (Session, (Kind => Events.Key_Down, Key => Events.Key_Z, Command => True, Shift => True, others => <>));
      end loop;
      Check ("write-marks-redone", " 2", Natural'Image (Windows.Item_Marks (Session, 1)));
      Proj.Set_Mode (Session, Viewer.Write);
      Check ("write-marks-more-shared", " 2",
             Natural'Image (Source_List.Source_Marks (Session, 1)));

      --  Undo from the reader also reaches edits made on the canvas.
      Settle (Session);
      Click_On (Session, 340.0, Reader_Y);
      Viewer.Handle (Session, (Kind => Events.Key_Down, Key => Events.Key_Z, Command => True, others => <>));
      Check ("write-marks-undo-shared", " 1", Natural'Image (Source_List.Source_Marks (Session, 1)));
      Check ("write-marks-undo-in-canvas", " 1", Natural'Image (Windows.Item_Marks (Session, 1)));

      --  The undone result is kept when reopened.
      declare
         Key : constant Projects.Id := Proj.Current_Project (Session);
      begin
         Proj.Close_Project (Session);
         Home.Open_Project (Session, Key);
         Viewer.Project_Screen.Set_Mode (Session, Viewer.Canvas);
         Proj.Set_Mode (Session, Viewer.Write);
         Check ("write-marks-kept", " 1",
                Natural'Image (Source_List.Source_Marks (Session, 1)));
      end;
   end Sharing_Marks;

end Write_Tests;
