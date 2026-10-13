with Ada.Directories;
with Ada.Text_IO;
with SDL3.Events;
with SDL3.Pictures.Jobs;
with Webshot;
with Goldens;
with Items;
with Projects;
with Viewer;

package body Write_Tests is

   package Events renames SDL3.Events;
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

   Canvas_Marker_X : constant Float := 357.5;
   Canvas_Status_Y : constant Float := 346.0;
   --  The highlighter in the status line of the source's window on the
   --  canvas.
   Canvas_Picture_Y : constant Float := 272.0;
   --  In its picture.

   Sources_Button_X : constant Float := 597.0;
   Bar_Y : constant Float := 82.0;
   Menu_Item_X : constant Float := 545.0;
   Menu_Item_Y : constant Float := 111.5;
   --  The first page's Sources button, above it, and the first item of the
   --  menu under it.

   Text_X : constant Float := 650.0;
   Text_Y : constant Float := 140.0;
   --  At the end of the first line of the first page.

   Doc_Row_X : constant Float := 100.0;

   function Doc_Row_Y (Row : Positive) return Float is
     (114.5 + Float (Row - 1) * 38.0);
   --  The rows of the list of documents, in the sidebar.

   Add_Document_X : constant Float := 181.0;
   Add_Document_Y : constant Float := 80.0;
   --  The button beside the name of the list of documents.

   Pane_Edge_X : constant Float := 435.0;
   Pane_Pin_X  : constant Float := 682.0;
   Pane_Pin_Y  : constant Float := 59.0;
   --  The edge of the pane, as wide as it starts in a window this size,
   --  and its pin button, after it has been made 50 wider.

   Source_Row_X : constant Float := 100.0;

   function Source_Row_Y (Documents : Natural) return Float is
     (99.0
      + (if Documents = 0 then 31.0
         else Float (Documents) * 34.0 + Float (Documents - 1) * 4.0)
      + 67.5);
   --  The row of the first source, in the sidebar, below the list of so
   --  many documents (or the line that says there are none).

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
      Viewer.Handle (Session, (Kind => Events.Redraw, others => <>));
   end Settle;

   procedure Snap (Session : in out Viewer.Session; Name : String) is
      Drawn : Pictures.Image;
   begin
      Viewer.Render (Session, Drawn);
      SDL3.Pictures.Jobs.Wait_Until_Idle;
      Viewer.Handle (Session, (Kind => Events.Redraw, others => <>));
      Viewer.Render (Session, Drawn);
      Goldens.Check (Name, Drawn);
   end Snap;

   procedure Start_With_Three (Session : in out Viewer.Session) is
   begin
      Viewer.Open (Session, "", Width, Height, 2.0);
      Viewer.New_Project (Session);
      Viewer.Add_Item (Session, "Opening");
      Type_In (Session, "It was a dark and stormy night.");
      Viewer.Add_Item (Session, "Middle");
      Type_In (Session, "Then things happened.");
      Viewer.Add_Item (Session, "Page", Items.Source);
      Viewer.Add_Item (Session, "Ending");
      Type_In (Session, "And they all lived.");
      Move_To (Session, 600.0, 60.0);
   end Start_With_Three;

   procedure Pages is
      Session : Viewer.Session;
   begin
      Start_With_Three (Session);
      Viewer.Set_Mode (Session, Viewer.Write);
      Check ("write-mode", "WRITE",
             Viewer.Modes'Image (Viewer.Mode (Session)));
      Check ("write-documents", " 3",
             Natural'Image (Viewer.Document_Count (Session)));
      Check ("write-sources", " 1",
             Natural'Image (Viewer.Source_Count (Session)));
      Check ("write-first", "Opening", Viewer.Document_Title (Session, 1));
      Check ("write-last", "Ending", Viewer.Document_Title (Session, 3));
      Snap (Session, "write-pages");
      Viewer.Set_Mode (Session, Viewer.Canvas);
      Snap (Session, "write-back-to-canvas");
   end Pages;

   procedure Ordering is
      Session : Viewer.Session;
      Key     : Projects.Id;
   begin
      Start_With_Three (Session);
      Key := Viewer.Current_Project (Session);
      Viewer.Set_Mode (Session, Viewer.Write);
      Viewer.Move_Document (Session, 3, 1);
      Check ("write-moved-first", "Ending",
             Viewer.Document_Title (Session, 1));
      Check ("write-moved-second", "Opening",
             Viewer.Document_Title (Session, 2));
      Snap (Session, "write-reordered");
      Viewer.Close_Project (Session);
      Viewer.Open_Project (Session, Key);
      Viewer.Set_Mode (Session, Viewer.Write);
      Check ("write-order-kept", "Ending",
             Viewer.Document_Title (Session, 1));
      Check ("write-order-kept-last", "Middle",
             Viewer.Document_Title (Session, 3));
   end Ordering;

   procedure Dragging is
      Session : Viewer.Session;
   begin
      Start_With_Three (Session);
      Viewer.Set_Mode (Session, Viewer.Write);
      Settle (Session);
      --  The first row is dragged down past the others, which makes room.
      Drag (Session, Doc_Row_X, Doc_Row_Y (1), Doc_Row_X, Doc_Row_Y (3));
      Check ("write-dragged-first", "Middle",
             Viewer.Document_Title (Session, 1));
      Check ("write-dragged-last", "Opening",
             Viewer.Document_Title (Session, 3));
      Move_To (Session, 600.0, 60.0);
      Snap (Session, "write-dragged");

      --  A click on a row is not a drag: nothing is moved, and the pages
      --  go to its page.
      Settle (Session);
      Click_On (Session, Doc_Row_X, Doc_Row_Y (3));
      Check ("write-clicked-not-moved", "Opening",
             Viewer.Document_Title (Session, 3));
      Settle (Session);
      Move_To (Session, 600.0, 60.0);
      Snap (Session, "write-scrolled-to-page");
   end Dragging;

   procedure Adding is
      Session : Viewer.Session;
   begin
      Start_With_Three (Session);
      Viewer.Set_Mode (Session, Viewer.Write);
      Settle (Session);
      Click_On (Session, Add_Document_X, Add_Document_Y);
      Check ("write-added", " 4",
             Natural'Image (Viewer.Document_Count (Session)));
      Check ("write-added-title", "Untitled document",
             Viewer.Document_Title (Session, 4));
      --  It is where the typing goes.
      Type_In (Session, "Fresh.");
      Check ("write-added-typed", "Fresh.", Viewer.Item_Text (Session, 5));
      Move_To (Session, 600.0, 60.0);
      Snap (Session, "write-added");
   end Adding;

   procedure Linked_Sources is
      Session : Viewer.Session;
   begin
      Start_With_Three (Session);
      --  The first and last documents are linked to the source.
      Viewer.Link_Items (Session, 1, 3);
      Viewer.Link_Items (Session, 3, 4);
      Viewer.Set_Mode (Session, Viewer.Write);
      Settle (Session);
      Click_On (Session, Sources_Button_X, Bar_Y);
      Settle (Session);
      Move_To (Session, 600.0, 300.0);
      Snap (Session, "write-sources-menu");
      --  An item of the menu opens and pins the source.
      Click_On (Session, Menu_Item_X, Menu_Item_Y);
      Settle (Session);
      Check ("write-menu-pinned", " 1",
             Natural'Image (Viewer.Pinned_Source (Session)));
      --  A document with no links has none to list.
      Move_To (Session, 600.0, 300.0);
      Snap (Session, "write-sources-pinned-from-menu");
   end Linked_Sources;

   procedure Typing is
      Session : Viewer.Session;
   begin
      Start_With_Three (Session);
      Viewer.Set_Mode (Session, Viewer.Write);
      Click_On (Session, Text_X, Text_Y);
      Type_In (Session, " More.");
      Snap (Session, "write-typed");
      --  It is in the item's window on the canvas too, which writes it.
      Check ("write-typed-text", "It was a dark and stormy night. More.",
             Viewer.Item_Text (Session, 1));
      Viewer.Set_Mode (Session, Viewer.Canvas);
      Check ("write-typed-words", " 8",
             Natural'Image (Viewer.Item_Words (Session, 1)));
      Viewer.Set_Mode (Session, Viewer.Write);
      Check ("write-typed-still", "It was a dark and stormy night. More.",
             Viewer.Item_Text (Session, 1));

      --  Typed on a page, it is kept as if typed on the canvas.
      declare
         Key : constant Projects.Id := Viewer.Current_Project (Session);
      begin
         Viewer.Close_Project (Session);
         Viewer.Open_Project (Session, Key);
         Check ("write-typed-kept", "It was a dark and stormy night. More.",
                Viewer.Item_Text (Session, 1));
      end;
   end Typing;

   procedure Sources is
      Session : Viewer.Session;
   begin
      Start_With_Three (Session);
      Viewer.Set_Mode (Session, Viewer.Write);
      Snap (Session, "write-sources-listed");
      Check ("write-source-closed", "FALSE",
             Boolean'Image (Viewer.Source_Is_Open (Session, 1)));
      Click_On (Session, Source_Row_X, Source_Row_Y (3));
      Settle (Session);
      Check ("write-source-opened", "TRUE",
             Boolean'Image (Viewer.Source_Is_Open (Session, 1)));
      Move_To (Session, 600.0, 60.0);
      Snap (Session, "write-source-window");

      --  Pinned, it is in the pane, and has no window.
      Click_On (Session, Pin_X, Pin_Y);
      Settle (Session);
      Check ("write-source-pinned", " 1",
             Natural'Image (Viewer.Pinned_Source (Session)));
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
             Natural'Image (Viewer.Pinned_Source (Session)));
      Check ("write-pane-window", "TRUE",
             Boolean'Image (Viewer.Source_Is_Open (Session, 1)));
      Click_On (Session, Source_Row_X, Source_Row_Y (3));
      Settle (Session);
      Click_On (Session, Source_Row_X, Source_Row_Y (3));
      Settle (Session);
      Click_On (Session, Pin_X, Pin_Y);
      Settle (Session);
      Click_On (Session, Source_Row_X, Source_Row_Y (3));
      Check ("write-source-unpinned", " 0",
             Natural'Image (Viewer.Pinned_Source (Session)));
      Check ("write-source-closed-again", "FALSE",
             Boolean'Image (Viewer.Source_Is_Open (Session, 1)));
   end Sources;

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
      Viewer.New_Project (Session);
      Viewer.Pin_Capture_Time (Session, 1_700_000_000);
      Viewer.Add_Item (Session, "Page", Items.Source);
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Key_Down,
                                Key => Events.Key_A, Command => True,
                                others => <>));
      Type_In (Session, "file://" & Page);
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Key_Down,
                                Key => Events.Key_Return, others => <>));
      while Viewer.Is_Capturing (Session) and then Waited < 600 loop
         Webshot.Pump (100);
         Tick := SDL3.Events.Milliseconds (Natural (Tick) + 100);
         Viewer.Tick (Session, Tick);
         Waited := Waited + 1;
      end loop;
      Viewer.Set_Mode (Session, Viewer.Write);
      Click_On (Session, Source_Row_X, Source_Row_Y (0));
      Settle (Session);
      Check ("write-marks-none", " 0",
             Natural'Image (Viewer.Source_Marks (Session, 1)));

      --  Marked in the writing view, they are on the canvas too.
      Click_On (Session, Marker_X, Status_Y);
      Drag (Session, 340.0, Reader_Y, 440.0, Reader_Y);
      Check ("write-marks-made", " 1",
             Natural'Image (Viewer.Source_Marks (Session, 1)));
      Check ("write-marks-shared", " 1",
             Natural'Image (Viewer.Item_Marks (Session, 1)));
      Snap (Session, "write-source-marked");

      --  And erased on the canvas, they are gone from the writing view.
      Viewer.Set_Mode (Session, Viewer.Canvas);
      Check ("write-marks-in-canvas", " 1",
             Natural'Image (Viewer.Item_Marks (Session, 1)));

      --  Marked there, they are in the writing view too.
      Settle (Session);
      Click_On (Session, Canvas_Marker_X, Canvas_Status_Y);
      Drag (Session, 300.0, Canvas_Picture_Y, 400.0, Canvas_Picture_Y);
      Check ("write-marks-more", " 2",
             Natural'Image (Viewer.Item_Marks (Session, 1)));
      Viewer.Set_Mode (Session, Viewer.Write);
      Check ("write-marks-more-shared", " 2",
             Natural'Image (Viewer.Source_Marks (Session, 1)));

      --  They are kept.
      declare
         Key : constant Projects.Id := Viewer.Current_Project (Session);
      begin
         Viewer.Close_Project (Session);
         Viewer.Open_Project (Session, Key);
         Viewer.Set_Mode (Session, Viewer.Write);
         Check ("write-marks-kept", " 2",
                Natural'Image (Viewer.Source_Marks (Session, 1)));
      end;
   end Sharing_Marks;

end Write_Tests;
