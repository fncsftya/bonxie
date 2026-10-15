with Items.Records;
with Items.Schema;
with Items.Sources;
with Items.Words;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with SDL3.Cursors;
with SDL3.Events;
with SDL3.Pictures.Jobs;
with Vision;
with Webshot;
with Goldens;
with Items.Windows;
with Pomarine.Application;
with Projects;
with Viewer;
with Viewer.Canvas_Camera;
with Viewer.Canvas_Links;
with Viewer.Canvas_Windows;
with Viewer.Home_Screen;
with Viewer.Project_Screen;

package body Item_Tests is

   package Events renames SDL3.Events;
   package Camera renames Viewer.Canvas_Camera;
   package Links renames Viewer.Canvas_Links;
   package Windows renames Viewer.Canvas_Windows;
   package Home renames Viewer.Home_Screen;
   package Proj renames Viewer.Project_Screen;
   package Pictures renames Goldens.Images;

   use type Items.States;
   use type Items.Id;

   procedure Check (Name : String; Expected, Actual : String)
     renames Goldens.Check_Text;

   Width  : constant := 720;
   Height : constant := 480;
   --  Of the window, in points. The canvas is 436 high below the toolbar,
   --  44, so its middle, where the origin starts and items are added, is
   --  at 360, 262.

   Add_X    : constant Float := 299.5;
   Source_X : constant Float := 427.5;
   Tools_Y  : constant Float := 440.5;
   --  The middle of the buttons in the tray over the foot of the canvas:
   --  Add Document and Add Source.
   List_X   : constant Float := 668.0;
   List_Y   : constant Float := 22.0;
   --  Items, at the right of the toolbar.

   --  A source's window is 360 x 200, from 180, 162 to 540, 362; its status
   --  line is the 26 above the foot of it, less the shadow.
   Menu_X   : constant Float := 493.0;
   Marker_X : constant Float := 357.5;
   Eraser_X : constant Float := 379.5;
   Cursor_X : constant Float := 335.5;
   Status_Y : constant Float := 346.0;
   Preset_X : constant Float := 452.0;
   Preset_Y : constant Float := 323.5;
   --  A zoom's button in the menu of a source's window: 200%.
   Slider_X : constant Float := 433.0;
   Slider_End_X : constant Float := 466.0;
   --  Along its slider, and near its end.
   Picture_Y : constant Float := 242.0;
   --  In the picture, below the link.

   --  A new item is 280 x 200 on the canvas, with its middle at its origin,
   --  which is at 360, 262 on the screen: from 220, 162 to 500, 362 (less
   --  the shadow, 3, at the right and the foot). Its bar is 28 high, with
   --  the title from the left, and the buttons at the right.
   Title_X  : constant Float := 260.0;
   Bar_Y    : constant Float := 177.0;
   Hold_X   : constant Float := 428.0;
   --  Where the bar can be held: between the title and the buttons.
   Minimize_X : constant Float := 459.0;
   Close_X    : constant Float := 481.0;
   Corner_X   : constant Float := 488.0;
   Corner_Y   : constant Float := 346.0;
   --  The corner to size it by, in the status line.
   Text_X   : constant Float := 300.0;
   Text_Y   : constant Float := 254.0;
   --  In the text.

   --  The bar in the dock, when the item is minimised: from 8, 446, with
   --  the title to click to restore it, and the button to close it, at the
   --  right.
   Restore_X : constant Float := 80.0;
   Dock_Close_X : constant Float := 195.0;
   Dock_Y    : constant Float := 460.0;

   --  The list of items: a dialog 440 x 380 in the middle, under a dark
   --  bar with the button to close it at its right. Its rows are 36 high,
   --  from 105, with the button to show or hide the item, and the one to
   --  remove it, at the right.
   Toggle_X : constant Float := 482.0;
   Remove_X : constant Float := 530.0;
   List_Close_X : constant Float := 558.0;
   List_Close_Y : constant Float := 65.0;

   function Row_Y (Row : Positive) return Float is
     (105.0 + Float (Row - 1) * 42.0 + 18.0);

   function Whole (Value : Float) return String is
     (Integer'Image (Integer (Float'Rounding (Value))));

   function Place (Frame : Items.Frame) return String is
     (Whole (Frame.Left) & Whole (Frame.Top)
      & Whole (Frame.Width) & Whole (Frame.Height));

   function Item_Place (Session : Viewer.Session; Row : Positive)
      return String is (Place (Windows.Item_Frame (Session, Row)));

   --  Events

   procedure Move_To (Session : in out Viewer.Session; X, Y : Float;
                      Held : Boolean := False) is
   begin
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Move, Mouse_X => X,
                                Mouse_Y => Y, Left_Held => Held,
                                others => <>));
   end Move_To;

   procedure Press (Session : in out Viewer.Session; X, Y : Float) is
   begin
      Move_To (Session, X, Y);
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Down, Button => 1,
                                Clicks => 1, Mouse_X => X, Mouse_Y => Y,
                                others => <>));
   end Press;

   procedure Release (Session : in out Viewer.Session; X, Y : Float) is
   begin
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Up, Button => 1,
                                Clicks => 1, Mouse_X => X, Mouse_Y => Y,
                                others => <>));
   end Release;

   procedure Click_On (Session : in out Viewer.Session; X, Y : Float) is
   begin
      Press (Session, X, Y);
      Release (Session, X, Y);
   end Click_On;

   procedure Double_Click_On (Session : in out Viewer.Session; X, Y : Float)
   is
   begin
      Click_On (Session, X, Y);
      Move_To (Session, X, Y);
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Down, Button => 1,
                                Clicks => 2, Mouse_X => X, Mouse_Y => Y,
                                others => <>));
      Release (Session, X, Y);
   end Double_Click_On;

   procedure Drag
     (Session : in out Viewer.Session; From_X, From_Y, To_X, To_Y : Float) is
   begin
      Press (Session, From_X, From_Y);
      --  In two moves, as a pointer is.
      Move_To
        (Session, (From_X + To_X) / 2.0, (From_Y + To_Y) / 2.0, Held => True);
      Move_To (Session, To_X, To_Y, Held => True);
      Release (Session, To_X, To_Y);
   end Drag;

   procedure Type_In (Session : in out Viewer.Session; Text : String) is
   begin
      Viewer.Handle (Session, Events.Text_Event (Text));
   end Type_In;

   procedure Press_Key
     (Session : in out Viewer.Session; Code : Events.Key_Code;
      Command : Boolean := False) is
   begin
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Key_Down, Key => Code,
                                Command => Command, others => <>));
   end Press_Key;

   procedure Start (Session : in out Viewer.Session) is
   begin
      Viewer.Open (Session, "", Width, Height, 2.0);
      Home.New_Project (Session);
   end Start;

   procedure Start_With_One (Session : in out Viewer.Session) is
   begin
      Start (Session);
      Click_On (Session, Add_X, Tools_Y);
      --  Away from it, for the pointer not to be over anything.
      Move_To (Session, 600.0, 60.0);
   end Start_With_One;

   procedure Snap (Session : in out Viewer.Session; Name : String) is
      Drawn : Pictures.Image;
   begin
      --  A picture is read in the background: draw once to ask for it,
      --  and again when it is there.
      Viewer.Render (Session, Drawn);
      SDL3.Pictures.Jobs.Wait_Until_Idle;
      Viewer.Handle (Session, (Kind => Events.Redraw, others => <>));
      Viewer.Render (Session, Drawn);
      Goldens.Check (Name, Drawn);
   end Snap;

   function Image_Of (Value : Natural) return String is
     (Natural'Image (Value));

   --  Without a window

   procedure Counting_Words is
      function Words (Text : String) return String is
        (Image_Of (Items.Windows.Count_Words (Text)));
   begin
      Check ("words-none", " 0", Words (""));
      Check ("words-spaces", " 0", Words ("  " & ASCII.LF));
      Check ("words-one", " 1", Words ("one"));
      Check
        ("words-many", " 5",
         Words (" one two" & ASCII.LF & ASCII.HT & "three  four" & ASCII.CR
                & ASCII.LF & "five "));
   end Counting_Words;

   procedure Stored is
      Store   : Projects.Store;
      First   : Projects.Id;
      Second  : Projects.Id;
      Listed  : Items.Info_List;
      Where   : constant Items.Frame := (10.0, 20.0, 300.0, 150.0);
      Notes   : Items.Id;
      Ideas   : Items.Id;
      Other   : Items.Id;
   begin
      Projects.Open (Store, Projects.Memory);
      Items.Schema.Prepare (Store);
      Items.Schema.Prepare (Store);  --  again, which is no harm
      First := Projects.Create (Store, "First");
      Second := Projects.Create (Store, "Second");

      Notes :=
        Items.Records.Create (Store, First, "Notes", Where, "some text");
      Ideas :=
        Items.Records.Create
          (Store, First, "Ideas", (1.0, 2.0, 3.0, 4.0));
      Other := Items.Records.Create (Store, Second, "Elsewhere", Where);
      Check ("items-ids", "TRUE",
             Boolean'Image (Notes < Ideas and then Ideas < Other));
      Check
        ("items-count", " 2 1",
         Natural'Image (Items.Records.Count (Store, First))
         & Natural'Image (Items.Records.Count (Store, Second)));

      Items.Records.Load (Store, First, Listed);
      Check
        ("items-loaded", "Notes,Ideas,",
         Projects.Titles.To_String (Listed.Items (1).Title) & ","
         & Projects.Titles.To_String (Listed.Items (2).Title) & ",");
      Check
        ("items-loaded-frame", " 10 20 300 150",
         Place (Listed.Items (1).Where));
      Check
        ("items-loaded-state", "OPEN",
         Items.States'Image (Listed.Items (1).State));
      Check
        ("items-content", "some text",
         Items.Records.Content (Store, Listed.Items (1).Key));

      Items.Records.Set_Title (Store, Listed.Items (1).Key, "Renamed");
      Items.Records.Set_Content
        (Store, Listed.Items (1).Key, "other" & ASCII.LF & "text");
      Items.Records.Set_Frame
        (Store, Listed.Items (1).Key, (5.0, 6.0, 7.0, 8.0));
      Items.Records.Set_State (Store, Listed.Items (1).Key, Items.Minimized);
      Items.Records.Set_State (Store, Listed.Items (2).Key, Items.Closed);
      Items.Records.Load (Store, First, Listed);
      Check
        ("items-changed", "Renamed MINIMIZED 5 6 7 8",
         Projects.Titles.To_String (Listed.Items (1).Title) & " "
         & Items.States'Image (Listed.Items (1).State)
         & Place (Listed.Items (1).Where));
      Check
        ("items-changed-closed", "CLOSED",
         Items.States'Image (Listed.Items (2).State));
      Check
        ("items-changed-content", "other" & ASCII.LF & "text",
         Items.Records.Content (Store, Listed.Items (1).Key));

      Check
        ("items-scroll-none", "TRUE",
         Boolean'Image (Listed.Items (1).Scroll = 0.0));
      Items.Records.Set_Scroll (Store, Listed.Items (1).Key, 42.5, 0.25);
      Items.Records.Load (Store, First, Listed);
      Check
        ("items-scroll-kept", "TRUE",
         Boolean'Image
           (Listed.Items (1).Scroll = 42.5
            and then Listed.Items (1).Scroll_Across = 0.25));

      --  One goes.
      Items.Records.Delete (Store, Listed.Items (1).Key);
      Items.Records.Delete (Store, 9999);  --  none such
      Check
        ("items-deleted", " 1",
         Natural'Image (Items.Records.Count (Store, First)));
      Check
        ("items-deleted-content", "",
         Items.Records.Content (Store, Listed.Items (1).Key));

      --  A source: a link, and a picture that goes with it.
      declare
         Link    : constant Items.Id :=
           Items.Records.Create
             (Store, First, "Page", Where, "https://example.org",
              Kind => Items.Source);
         Picture : constant String :=
           Items.Sources.Image_File (Store, First, Link);
         File    : Ada.Text_IO.File_Type;
         Found   : Items.Info_List;
      begin
         Items.Sources.Set_Captured (Store, Link, 1_700_000_000);
         Items.Records.Load (Store, First, Found);
         Check
           ("source-stored", "SOURCE 1700000000 https://example.org",
            Items.Kinds'Image (Found.Items (Found.Count).Kind)
            & Projects.Seconds'Image (Found.Items (Found.Count).Captured_At)
            & " " & Items.Records.Content (Store, Link));
         Check
           ("source-note-kind", "NOTE 0",
            Items.Kinds'Image (Found.Items (1).Kind)
            & Projects.Seconds'Image (Found.Items (1).Captured_At));
         Check
           ("source-picture-place", "TRUE",
            Boolean'Image
              (Picture = Projects.Folder (Store, First) & "/sources/"
               & Ada.Strings.Fixed.Trim (Link'Image, Ada.Strings.Both)
               & ".png"));
         Items.Sources.Make_Image_Folder (Store, First);
         Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Picture);
         Ada.Text_IO.Close (File);

         --  The words found in its picture are kept, a row to a word.
         declare
            Words : Vision.Result;
            Again : Vision.Result;
         begin
            Check
              ("words-none", "FALSE",
               Boolean'Image (Items.Words.Has_Words (Store, Link)));
            Words.Text (1 .. 10) := "helloworld";
            Words.Length := 10;
            Words.Count := 2;
            Words.Words (1) :=
              (Line => 1, First => 1, Last => 5,
               Left => 0.25, Top => 0.5, Width => 0.125, Height => 0.0625);
            Words.Words (2) :=
              (Line => 2, First => 6, Last => 10,
               Left => 0.5, Top => 0.75, Width => 0.25, Height => 0.125);
            Items.Words.Save_Words (Store, Link, Words, 1_700_000_001);
            Check
              ("words-kept", "TRUE",
               Boolean'Image (Items.Words.Has_Words (Store, Link)));
            Items.Words.Load_Words (Store, Link, Again);
            Check
              ("words-loaded", " 2 10 hello world",
               Natural'Image (Again.Count) & Natural'Image (Again.Length)
               & " " & Vision.Image (Again.Words (1), Again) & " "
               & Vision.Image (Again.Words (2), Again));
            Check
              ("words-boxes", "2 TRUE",
               Ada.Strings.Fixed.Trim
                 (Natural'Image (Again.Words (2).Line), Ada.Strings.Both)
               & " "
               & Boolean'Image
                   (Again.Words (2).Left = 0.5
                    and then Again.Words (2).Top = 0.75
                    and then Again.Words (2).Width = 0.25
                    and then Again.Words (2).Height = 0.125));

            --  Kept again, they are the new words, not more.
            Words.Count := 1;
            Items.Words.Save_Words (Store, Link, Words, 1_700_000_002);
            Items.Words.Load_Words (Store, Link, Again);
            Check
              ("words-replaced", " 1", Natural'Image (Again.Count));

            --  A new picture is of other words.
            Items.Sources.Set_Captured (Store, Link, 1_700_000_003);
            Items.Words.Load_Words (Store, Link, Again);
            Check
              ("words-forgotten", "FALSE 0",
               Boolean'Image (Items.Words.Has_Words (Store, Link))
               & Natural'Image (Again.Count));

            --  No words in a picture is something kept too.
            Words.Count := 0;
            Words.Length := 0;
            Items.Words.Save_Words (Store, Link, Words, 1_700_000_004);
            Check
              ("words-none-found", "TRUE",
               Boolean'Image (Items.Words.Has_Words (Store, Link)));
            Words.Count := 1;
            Words.Length := 10;
            Items.Words.Save_Words (Store, Link, Words, 1_700_000_005);
         end;
         Items.Records.Delete (Store, Link);
         declare
            Gone : Vision.Result;
         begin
            Items.Words.Load_Words (Store, Link, Gone);
            Check
              ("words-deleted", " 0", Natural'Image (Gone.Count));
         end;
         Check
           ("source-picture-deleted", "FALSE",
            Boolean'Image (Ada.Directories.Exists (Picture)));

         --  And a project's files go with it.
         Items.Sources.Make_Image_Folder (Store, First);
         Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Picture);
         Ada.Text_IO.Close (File);
      end;

      --  All of a project's go with it, and no others.
      Projects.Delete (Store, First);
      Check
        ("project-files-deleted", "FALSE",
         Boolean'Image
           (Ada.Directories.Exists (Projects.Folder (Store, First))));
      Check
        ("items-with-project", " 0 1",
         Natural'Image (Items.Records.Count (Store, First))
         & Natural'Image (Items.Records.Count (Store, Second)));
   end Stored;

   --  On the canvas

   procedure Added is
      Session : Viewer.Session;
   begin
      Start (Session);
      Check
        ("item-none", " 0", Natural'Image (Windows.Item_Count (Session)));
      Click_On (Session, Add_X, Tools_Y);
      Check
        ("item-one", " 1", Natural'Image (Windows.Item_Count (Session)));
      Check
        ("item-new-title", "Untitled item", Windows.Item_Title (Session, 1));
      Check
        ("item-new-place", "-140-100 280 200", Item_Place (Session, 1));
      Check
        ("item-new-state", "OPEN",
         Items.States'Image (Windows.Item_State (Session, 1)));
      Check
        ("item-new-words", " 0",
         Natural'Image (Windows.Item_Words (Session, 1)));
      Move_To (Session, 600.0, 60.0);
      Snap (Session, "item-added");

      --  The focus is in the text.
      Type_In (Session, "Hello");
      Check
        ("item-new-typed", "Hello", Windows.Item_Text (Session, 1));

      --  Another is a little down and right of it, and on top.
      Click_On (Session, Add_X, Tools_Y);
      Check
        ("item-second-place", "-116-76 280 200", Item_Place (Session, 2));
      Move_To (Session, 600.0, 60.0);
      Snap (Session, "item-added-two");
   end Added;

   procedure Typing is
      Session : Viewer.Session;
   begin
      Start_With_One (Session);
      Type_In (Session, "One two three");
      Check
        ("item-typed-words", " 3",
         Natural'Image (Windows.Item_Words (Session, 1)));
      Press_Key (Session, Events.Key_Return);
      Type_In (Session, "four");
      Check
        ("item-typed-lines", "One two three" & ASCII.LF & "four",
         Windows.Item_Text (Session, 1));
      Check
        ("item-typed-more-words", " 4",
         Natural'Image (Windows.Item_Words (Session, 1)));
      Snap (Session, "item-typed");

      --  Clicked into, it takes the typing.
      Click_On (Session, Text_X, Text_Y);
      Type_In (Session, "X");
      Check
        ("item-typed-clicked", "One two three" & ASCII.LF & "four" & "X",
         Windows.Item_Text (Session, 1));
   end Typing;

   procedure Dictating is
      Session : Viewer.Session;
   begin
      Start_With_One (Session);

      --  Focused, with a caret: it goes in at the caret, and keeps what
      --  is selected.
      Type_In (Session, "ac");
      Press_Key (Session, Events.Key_Left_Arrow);
      Windows.Dictate_Into (Session, 1, "b");
      Check ("dictate-at-caret", "abc", Windows.Item_Text (Session, 1));

      --  Not focused: a new paragraph after the text.
      Click_On (Session, 600.0, 60.0);
      Windows.Dictate_Into (Session, 1, "next line");
      Check
        ("dictate-new-paragraph", "abc" & ASCII.LF & "next line",
         Windows.Item_Text (Session, 1));

      --  Nothing said, nothing added.
      Windows.Dictate_Into (Session, 1, "");
      Check
        ("dictate-nothing", "abc" & ASCII.LF & "next line",
         Windows.Item_Text (Session, 1));
      Move_To (Session, 610.0, 70.0);
      Check
        ("dictate-words", " 3",
         Natural'Image (Windows.Item_Words (Session, 1)));
   end Dictating;

   procedure Dictating_Into_Empty is
      Session : Viewer.Session;
   begin
      Start_With_One (Session);
      Click_On (Session, 600.0, 60.0);
      Windows.Dictate_Into (Session, 1, "first");
      Check ("dictate-into-empty", "first", Windows.Item_Text (Session, 1));
   end Dictating_Into_Empty;

   procedure Dictating_Live is
      Session : Viewer.Session;
   begin
      Start_With_One (Session);

      --  Not focused: what is heard shows as a new paragraph, and each
      --  hearing replaces the last.
      Type_In (Session, "abc");
      Click_On (Session, 600.0, 60.0);
      Windows.Dictate_Live (Session, 1, "");
      Check ("live-nothing", "abc", Windows.Item_Text (Session, 1));
      Windows.Dictate_Live (Session, 1, "hel");
      Check
        ("live-first", "abc" & ASCII.LF & "hel",
         Windows.Item_Text (Session, 1));
      Windows.Dictate_Live (Session, 1, "hello wor");
      Check
        ("live-grown", "abc" & ASCII.LF & "hello wor",
         Windows.Item_Text (Session, 1));
      Windows.Dictate_Live (Session, 1, "hello world");
      Windows.Dictate_Live (Session, 1, "hello world");

      --  What is finally heard takes its place.
      Windows.Dictate_Into (Session, 1, "Hello, world.");
      Check
        ("live-final", "abc" & ASCII.LF & "Hello, world.",
         Windows.Item_Text (Session, 1));

      --  Focused, it shows at the caret, and the final text is one step
      --  to undo, back to the text before.
      Click_On (Session, Text_X, Text_Y);
      for Step in 1 .. 30 loop
         Press_Key (Session, Events.Key_Right_Arrow);
      end loop;
      Windows.Dictate_Live (Session, 1, " and");
      Windows.Dictate_Live (Session, 1, " and more");
      Check
        ("live-at-caret", "abc" & ASCII.LF & "Hello, world. and more",
         Windows.Item_Text (Session, 1));
      Windows.Dictate_Into (Session, 1, " and more.");
      Check
        ("live-final-at-caret", "abc" & ASCII.LF & "Hello, world. and more.",
         Windows.Item_Text (Session, 1));
      Press_Key (Session, Events.Key_Z, Command => True);
      Check
        ("live-undone", "abc" & ASCII.LF & "Hello, world.",
         Windows.Item_Text (Session, 1));
   end Dictating_Live;

   procedure Titling is
      Session : Viewer.Session;
   begin
      Start_With_One (Session);
      --  The title is text: clicking it, or typing, does not change it.
      Move_To (Session, Title_X, Bar_Y);
      Snap (Session, "item-title-hovered");
      Click_On (Session, Title_X, Bar_Y);
      Type_In (Session, "Not here");
      Check
        ("item-title-not-editable", "Untitled item",
         Windows.Item_Title (Session, 1));
      Check ("item-title-not-editing", "FALSE",
             Boolean'Image (Windows.Is_Editing_Title (Session, 1)));

      --  Double-clicked, it is a field, with all of it selected.
      Double_Click_On (Session, Title_X, Bar_Y);
      Check ("item-title-editing", "TRUE",
             Boolean'Image (Windows.Is_Editing_Title (Session, 1)));
      Type_In (Session, "Interview notes");
      Check
        ("item-title-typed", "Interview notes",
         Windows.Item_Title (Session, 1));
      Snap (Session, "item-title");

      --  Return keeps it, and it is text again.
      Press_Key (Session, Events.Key_Return);
      Check ("item-title-done", "FALSE",
             Boolean'Image (Windows.Is_Editing_Title (Session, 1)));
      Type_In (Session, "Q1");  --  to nothing
      Check
        ("item-title-return", "Not here", Windows.Item_Text (Session, 1));
      Check
        ("item-title-kept", "Interview notes",
         Windows.Item_Title (Session, 1));
      Move_To (Session, 650.0, 60.0);
      Snap (Session, "item-titled");

      --  Clicking elsewhere also ends it.
      Double_Click_On (Session, Title_X, Bar_Y);
      Type_In (Session, "Other");
      Click_On (Session, Text_X, Text_Y);
      Check ("item-title-left", "FALSE",
             Boolean'Image (Windows.Is_Editing_Title (Session, 1)));
      Check ("item-title-left-kept", "Other", Windows.Item_Title (Session, 1));
   end Titling;

   procedure Moving is
      Session : Viewer.Session;
   begin
      Start_With_One (Session);
      Move_To (Session, Hold_X, Bar_Y);
      Check
        ("item-bar-cursor", "MOVE",
         SDL3.Cursors.Kind'Image (Viewer.Cursor (Session)));
      Press (Session, Hold_X, Bar_Y);
      Move_To (Session, Hold_X + 30.0, Bar_Y + 20.0, Held => True);
      Check
        ("item-moving-place", "-110-80 280 200", Item_Place (Session, 1));
      Check
        ("item-moving-cursor", "MOVE",
         SDL3.Cursors.Kind'Image (Viewer.Cursor (Session)));
      Move_To (Session, Hold_X - 60.0, Bar_Y - 10.0, Held => True);
      Release (Session, Hold_X - 60.0, Bar_Y - 10.0);
      Check
        ("item-moved-place", "-200-110 280 200", Item_Place (Session, 1));
      Snap (Session, "item-moved");

      --  Let go, it stays where it is.
      Move_To (Session, 300.0, 300.0);
      Check
        ("item-moved-stays", "-200-110 280 200", Item_Place (Session, 1));
   end Moving;

   procedure Sizing is
      Session : Viewer.Session;
   begin
      Start_With_One (Session);
      Move_To (Session, Corner_X, Corner_Y);
      Check
        ("item-corner-cursor", "RESIZE",
         SDL3.Cursors.Kind'Image (Viewer.Cursor (Session)));
      Drag (Session, Corner_X, Corner_Y, Corner_X + 60.0, Corner_Y + 40.0);
      Check
        ("item-sized-place", "-140-100 340 240", Item_Place (Session, 1));
      Move_To (Session, 650.0, 60.0);
      Snap (Session, "item-sized");
   end Sizing;

   procedure Smallest is
      Session : Viewer.Session;
   begin
      Start_With_One (Session);
      Drag (Session, Corner_X, Corner_Y, 100.0, 120.0);
      Check
        ("item-smallest", "-140-100 160 100", Item_Place (Session, 1));
      Move_To (Session, 650.0, 60.0);
      Snap (Session, "item-smallest");
   end Smallest;

   procedure Minimizing is
      Session : Viewer.Session;
   begin
      Start_With_One (Session);
      Type_In (Session, "Kept");
      Click_On (Session, Minimize_X, Bar_Y);
      Check
        ("item-minimized", "MINIMIZED",
         Items.States'Image (Windows.Item_State (Session, 1)));
      Move_To (Session, 600.0, 60.0);
      Snap (Session, "item-minimized");

      --  Brought back where it was.
      Click_On (Session, Restore_X, Dock_Y);
      Check
        ("item-restored", "OPEN",
         Items.States'Image (Windows.Item_State (Session, 1)));
      Check
        ("item-restored-place", "-140-100 280 200", Item_Place (Session, 1));
      Check
        ("item-restored-text", "Kept", Windows.Item_Text (Session, 1));
      Move_To (Session, 600.0, 60.0);
      Snap (Session, "item-restored");

      --  Closed from the dock.
      Click_On (Session, Minimize_X, Bar_Y);
      Click_On (Session, Dock_Close_X, Dock_Y);
      Check
        ("item-closed-from-dock", "CLOSED",
         Items.States'Image (Windows.Item_State (Session, 1)));
      Move_To (Session, 600.0, 60.0);
      Snap (Session, "item-closed-dock-gone");
   end Minimizing;

   procedure Closing is
      Session : Viewer.Session;
   begin
      Start_With_One (Session);
      Click_On (Session, Close_X, Bar_Y);
      Check
        ("item-closed", "CLOSED",
         Items.States'Image (Windows.Item_State (Session, 1)));
      Check
        ("item-closed-kept", " 1",
         Natural'Image (Windows.Item_Count (Session)));
      Move_To (Session, 600.0, 60.0);
      Snap (Session, "item-closed");
   end Closing;

   procedure Listing is
      Session : Viewer.Session;
   begin
      Start_With_One (Session);
      Click_On (Session, Add_X, Tools_Y);
      Click_On (Session, Close_X + 24.0, Bar_Y + 24.0);
      Click_On (Session, List_X, List_Y);
      Check
        ("list-shown", "TRUE", Boolean'Image (Proj.Is_Listing (Session)));
      Move_To (Session, 600.0, 60.0);
      Snap (Session, "list-shown");
   end Listing;

   procedure Keyboard_List is
      Session : Viewer.Session;
      Was     : Items.States;
   begin
      Start (Session);
      Windows.Add_Item (Session, "First");
      Windows.Add_Item (Session, "Second");
      Click_On (Session, List_X, List_Y);
      Check ("list-keys-shown", "TRUE", Boolean'Image (Proj.Is_Listing (Session)));

      --  The list has the focus: an arrow chooses the first row, and Space
      --  does what its first button does, as the pointer would.
      Was := Windows.Item_State (Session, 1);
      Press_Key (Session, Events.Key_Down_Arrow);
      Press_Key (Session, Events.Key_Space);
      Check
        ("list-keys-space", "TRUE",
         Boolean'Image (Windows.Item_State (Session, 1) /= Was));
      Press_Key (Session, Events.Key_Space);
      Check
        ("list-keys-space-again", "TRUE",
         Boolean'Image (Windows.Item_State (Session, 1) = Was));

      --  Delete removes the item chosen.
      Press_Key (Session, Events.Key_Delete);
      Check ("list-keys-delete", " 1", Natural'Image (Windows.Item_Count (Session)));

      --  Tab goes round the dialog only: from the list to its button to
      --  close it, which Return presses, and not on to the screen behind.
      Press_Key (Session, Events.Key_Tab);
      Press_Key (Session, Events.Key_Return);
      Check ("list-keys-closed", "FALSE", Boolean'Image (Proj.Is_Listing (Session)));

      --  Return on a row, chosen with the arrows, shows the item and puts
      --  the list away.
      Click_On (Session, List_X, List_Y);
      Press_Key (Session, Events.Key_Down_Arrow);
      Press_Key (Session, Events.Key_Return);
      Check ("list-keys-return", "FALSE", Boolean'Image (Proj.Is_Listing (Session)));
   end Keyboard_List;

   procedure Removing is
      Session : Viewer.Session;
   begin
      Start_With_One (Session);
      Click_On (Session, Close_X, Bar_Y);
      Click_On (Session, List_X, List_Y);

      --  Shown again from the list.
      Click_On (Session, Toggle_X, Row_Y (1));
      Check
        ("list-shown-again", "OPEN",
         Items.States'Image (Windows.Item_State (Session, 1)));
      Move_To (Session, 600.0, 60.0);
      Snap (Session, "list-item-shown");

      --  Hidden again.
      Click_On (Session, Toggle_X, Row_Y (1));
      Check
        ("list-hidden-again", "CLOSED",
         Items.States'Image (Windows.Item_State (Session, 1)));

      --  Removed for good.
      Click_On (Session, Remove_X, Row_Y (1));
      Check
        ("list-removed", " 0", Natural'Image (Windows.Item_Count (Session)));
      Move_To (Session, 600.0, 60.0);
      Snap (Session, "list-empty");

      --  Closed, by its button or by Escape.
      Click_On (Session, List_Close_X, List_Close_Y);
      Check
        ("list-closed", "FALSE", Boolean'Image (Proj.Is_Listing (Session)));
      Click_On (Session, List_X, List_Y);
      Press_Key (Session, Events.Key_Escape);
      Check
        ("list-escaped", "FALSE", Boolean'Image (Proj.Is_Listing (Session)));
      Snap (Session, "list-gone");
   end Removing;

   procedure Revealing is
      Session : Viewer.Session;
   begin
      Start (Session);
      Windows.Add_Item (Session, "First");
      Windows.Add_Item (Session, "Second");
      --  The first, behind the second, is closed, and the canvas panned
      --  well away from both.
      Click_On (Session, Minimize_X, Bar_Y);
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Wheel, Wheel_X => -20.0,
                                Wheel_Y => -10.0, Mouse_X => 650.0,
                                Mouse_Y => 60.0, others => <>));
      Click_On (Session, List_X, List_Y);
      Move_To (Session, 300.0, Row_Y (1));
      Snap (Session, "list-title-hovered");

      --  Clicking its title closes the list and shows it, in the middle.
      Click_On (Session, 300.0, Row_Y (1));
      Check ("list-reveal-closed", "FALSE",
             Boolean'Image (Proj.Is_Listing (Session)));
      Check ("list-reveal-open", "OPEN",
             Items.States'Image (Windows.Item_State (Session, 1)));
      Move_To (Session, 650.0, 60.0);
      Snap (Session, "list-revealed");
   end Revealing;

   procedure Scrolling_Dock is
      Session : Viewer.Session;
   begin
      Start (Session);
      --  Five bars, 200 wide, are wider than the window: each is
      --  minimised in turn, by the button at the right of its bar.
      for I in 1 .. 5 loop
         Windows.Add_Item (Session, "Item" & Natural'Image (I));
         declare
            Where : constant Items.Frame := Windows.Item_Frame (Session, I);
         begin
            Click_On
              (Session, 360.0 + Where.Left + Where.Width - 41.0,
               262.0 + Where.Top + 15.0);
         end;
      end loop;
      Move_To (Session, 360.0, Dock_Y);
      Snap (Session, "dock-long");
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Wheel, Wheel_Y => -40.0,
                                Mouse_X => 360.0, Mouse_Y => Dock_Y,
                                others => <>));
      Snap (Session, "dock-long-end");
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Wheel, Wheel_X => 40.0,
                                Mouse_X => 360.0, Mouse_Y => Dock_Y,
                                others => <>));
      Snap (Session, "dock-long-start");
   end Scrolling_Dock;

   procedure Scrolling_List is
      Session : Viewer.Session;
   begin
      Start (Session);
      for I in 1 .. 9 loop
         Windows.Add_Item (Session, "Item" & Natural'Image (I));
      end loop;
      Click_On (Session, List_X, List_Y);
      Move_To (Session, 360.0, 240.0);
      Snap (Session, "list-long");
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Wheel, Wheel_Y => -4.0,
                                Mouse_X => 360.0, Mouse_Y => 240.0,
                                others => <>));
      Snap (Session, "list-long-scrolled");
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Wheel, Wheel_Y => -40.0,
                                Mouse_X => 360.0, Mouse_Y => 240.0,
                                others => <>));
      Snap (Session, "list-long-end");
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Wheel, Wheel_Y => 40.0,
                                Mouse_X => 360.0, Mouse_Y => 240.0,
                                others => <>));
      Snap (Session, "list-long-start");

      --  Dragging the bar scrolls it, too.
      Move_To (Session, 551.0, 130.0);
      Snap (Session, "list-long-bar-near");
      Drag (Session, 551.0, 130.0, 551.0, 300.0);
      Snap (Session, "list-long-bar-dragged");
   end Scrolling_List;

   procedure Panning_And_Zooming is
      Session : Viewer.Session;
   begin
      Start_With_One (Session);
      Type_In (Session, "Moves with the canvas");
      --  Panned by the wheel, over the bar, which does not take it.
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Wheel, Wheel_X => -2.0,
                                Wheel_Y => -1.0, Mouse_X => Hold_X,
                                Mouse_Y => Bar_Y, others => <>));
      Move_To (Session, 650.0, 60.0);
      Snap (Session, "item-panned");
      Check
        ("item-panned-place", "-140-100 280 200", Item_Place (Session, 1));

      --  Zoomed about the pointer: the item is bigger, and so is its text.
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Wheel, Wheel_Y => 3.0,
                                Command => True, Mouse_X => 300.0,
                                Mouse_Y => 200.0, others => <>));
      Move_To (Session, 650.0, 60.0);
      Snap (Session, "item-zoomed-in");
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Wheel, Wheel_Y => -8.0,
                                Command => True, Mouse_X => 300.0,
                                Mouse_Y => 200.0, others => <>));
      Move_To (Session, 650.0, 60.0);
      Snap (Session, "item-zoomed-out");

      --  Further out, a window is compact: a smaller bar, and no status
      --  line. Zoomed back, it has them again.
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Wheel, Wheel_Y => -6.0,
                                Command => True, Mouse_X => 300.0,
                                Mouse_Y => 200.0, others => <>));
      Move_To (Session, 650.0, 60.0);
      Snap (Session, "item-compact");
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Wheel, Wheel_Y => 6.0,
                                Command => True, Mouse_X => 300.0,
                                Mouse_Y => 200.0, others => <>));
      Move_To (Session, 650.0, 60.0);

      --  Moved at that zoom, by as much of the canvas as it is on screen.
      Press (Session, 260.0, 198.0);
      Release (Session, 260.0, 198.0);

      --  The view is kept with the project: opening it again is at the
      --  same zoom, and the same place.
      declare
         Zoom : constant Float := Camera.Canvas_Zoom (Session);
         X    : constant Float := Camera.Canvas_Origin_X (Session);
         Y    : constant Float := Camera.Canvas_Origin_Y (Session);
         Key  : constant Projects.Id := Proj.Current_Project (Session);
         function Near (A, B : Float) return String is
           (Boolean'Image (abs (A - B) < 0.01));
      begin
         Proj.Close_Project (Session);
         Home.Open_Project (Session, Key);
         Check
           ("view-zoom-kept", "TRUE",
            Near (Zoom, Camera.Canvas_Zoom (Session)));
         Check
           ("view-x-kept", "TRUE",
            Near (X, Camera.Canvas_Origin_X (Session)));
         Check
           ("view-y-kept", "TRUE",
            Near (Y, Camera.Canvas_Origin_Y (Session)));
      end;
   end Panning_And_Zooming;

   procedure Raising is
      Session : Viewer.Session;
   begin
      Start_With_One (Session);
      Click_On (Session, Add_X, Tools_Y);
      Move_To (Session, 650.0, 60.0);
      Snap (Session, "item-raise-before");
      --  The first, behind, is used by clicking its bar, which the second
      --  does not cover.
      Click_On (Session, Title_X, Bar_Y);
      Move_To (Session, 650.0, 60.0);
      Snap (Session, "item-raised");
   end Raising;

   procedure Repainting is
      Session : Viewer.Session;
      Step    : Natural := 0;

      procedure Compare is
         Partial, Fresh : Pictures.Image;
      begin
         Step := Step + 1;
         Viewer.Render (Session, Partial);
         Viewer.Handle (Session, Events.Event'(Kind => Events.Redraw,
                                               others => <>));
         Viewer.Render (Session, Fresh);
         Goldens.Check_Same
           ("item-repaint" & Natural'Image (Step), Fresh, Partial);
      end Compare;
   begin
      Start_With_One (Session);
      Compare;
      Type_In (Session, "Some words to count and wrap round the line so");
      Compare;
      for T in 1 .. 6 loop
         Viewer.Tick (Session, Events.Milliseconds (T * 400));
         Compare;
      end loop;
      Move_To (Session, Title_X, Bar_Y);
      Compare;
      Move_To (Session, Hold_X, Bar_Y);
      Compare;
      Press (Session, Hold_X, Bar_Y);
      Move_To (Session, Hold_X + 13.0, Bar_Y + 7.0, Held => True);
      Compare;
      Move_To (Session, Hold_X + 41.0, Bar_Y + 19.0, Held => True);
      Compare;
      Release (Session, Hold_X + 41.0, Bar_Y + 19.0);
      Compare;
      Drag (Session, Corner_X + 41.0, Corner_Y + 19.0,
            Corner_X + 71.0, Corner_Y + 49.0);
      Compare;
      Click_On (Session, Add_X, Tools_Y);
      Compare;
      Move_To (Session, 300.0, 300.0);
      Compare;

      --  By amounts that are not whole pixels.
      Press (Session, 270.3, 183.7);
      Move_To (Session, 275.77, 188.31, Held => True);
      Compare;
      Move_To (Session, 281.13, 191.93, Held => True);
      Compare;
      Release (Session, 281.13, 191.93);
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Wheel, Wheel_X => -0.37,
                                Wheel_Y => 0.21, Mouse_X => 650.0,
                                Mouse_Y => 60.0, others => <>));
      Compare;
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Wheel, Wheel_Y => 0.7,
                                Command => True, Mouse_X => 301.3,
                                Mouse_Y => 235.9, others => <>));
      Compare;
      Move_To (Session, 400.0, 400.0);
      Compare;
      Snap (Session, "item-fractional");

      --  Whole pixels, so that the borders are not a pixel more or less
      --  at one place than another.
      for Row in 1 .. 2 loop
         declare
            Box : constant Items.Frame := Windows.Item_Box (Session, Row);
            function Whole_Pixels (Value : Float) return String is
              (if Value = Float'Rounding (Value) then "whole" else "not");
         begin
            Check
              ("item-box-whole" & Natural'Image (Row),
               "whole whole whole whole",
               Whole_Pixels (Box.Left) & " " & Whole_Pixels (Box.Top) & " "
               & Whole_Pixels (Box.Width) & " " & Whole_Pixels (Box.Height));
         end;
      end loop;
   end Repainting;

   procedure Fractional_Density is
      Session : Viewer.Session;
      Drawn   : Pictures.Image;
   begin
      Viewer.Open (Session, "", Width, Height, 1.5);
      Home.New_Project (Session);
      Click_On (Session, Add_X, Tools_Y);
      Type_In (Session, "Six words are in this text");
      Move_To (Session, 650.0, 60.0);
      Viewer.Render (Session, Drawn);
      Goldens.Check ("item-density-1-5", Drawn);
   end Fractional_Density;

   procedure Full is
      Session : Viewer.Session;
   begin
      Start (Session);
      for I in 1 .. Items.Capacity + 3 loop
         Windows.Add_Item (Session);
      end loop;
      Check
        ("item-full", Natural'Image (Items.Capacity),
         Natural'Image (Windows.Item_Count (Session)));
   end Full;

   procedure Kept is
      Session : Viewer.Session;
      Key     : Projects.Id;
   begin
      Start_With_One (Session);
      Key := Proj.Current_Project (Session);
      Type_In (Session, "Written down");
      Double_Click_On (Session, Title_X, Bar_Y);
      Type_In (Session, "Kept item");
      Press_Key (Session, Events.Key_Return);
      Drag (Session, Hold_X, Bar_Y, Hold_X + 50.0, Bar_Y + 25.0);
      Click_On (Session, Add_X, Tools_Y);
      Type_In (Session, "Second");
      Click_On (Session, Close_X + 24.0, Bar_Y + 24.0);
      --  Items are as the project was left, shown, minimised or closed.
      Check
        ("item-kept-closed", "CLOSED",
         Items.States'Image (Windows.Item_State (Session, 2)));
      Click_On (Session, Minimize_X + 50.0, Bar_Y + 25.0);

      Proj.Close_Project (Session);
      Home.Open_Project (Session, Key);
      Check
        ("item-kept-count", " 2",
         Natural'Image (Windows.Item_Count (Session)));
      Check
        ("item-kept-title", "Kept item", Windows.Item_Title (Session, 1));
      Check
        ("item-kept-text", "Written down", Windows.Item_Text (Session, 1));
      Check
        ("item-kept-place", "-90-75 280 200", Item_Place (Session, 1));
      Check
        ("item-kept-state", "MINIMIZED",
         Items.States'Image (Windows.Item_State (Session, 1)));
      Check
        ("item-kept-second", "Second", Windows.Item_Text (Session, 2));
      Check
        ("item-kept-second-state", "CLOSED",
         Items.States'Image (Windows.Item_State (Session, 2)));
      Move_To (Session, 650.0, 60.0);
      Snap (Session, "item-kept");
   end Kept;

   --  Links

   procedure Linking is
      Session : Viewer.Session;
      Key     : Projects.Id;

      Source_Pin_X : constant Float := 350.0;
      Source_Pin_Y : constant Float := 262.0;
      Target_Pin_X : constant Float := 364.0;
      Target_Pin_Y : constant Float := 346.0;
      --  After the first is moved 150 left, and the second 120 right and 60
      --  down: the middle of the right side of the first, and of the left
      --  side of the second (the canvas starts 16 down).

      function Count (Value : Natural) return String is
        (Natural'Image (Value));
   begin
      Start_With_One (Session);
      Key := Proj.Current_Project (Session);
      Drag (Session, Hold_X, Bar_Y, Hold_X - 150.0, Bar_Y);
      Click_On (Session, Add_X, Tools_Y);
      Drag (Session, Hold_X + 24.0, Bar_Y + 24.0,
            Hold_X + 144.0, Bar_Y + 84.0);
      Check ("links-first", "-290-100 280 200", Item_Place (Session, 1));
      Check ("links-second", " 4-16 280 200", Item_Place (Session, 2));

      --  Pins are shown while the pointer is over a window.
      Move_To (Session, 600.0, 60.0);
      Check ("links-none-away", " 0", Count (Links.Pin_Count (Session)));
      Move_To (Session, 200.0, 250.0);
      Check ("links-four", " 4", Count (Links.Pin_Count (Session)));
      Move_To (Session, Source_Pin_X, Source_Pin_Y);
      Check ("links-pin-hovered", " 4", Count (Links.Pin_Count (Session)));
      Check ("links-pin-cursor", "POINTER",
             SDL3.Cursors.Kind'Image (Viewer.Cursor (Session)));

      --  Let go on nothing, there is no link.
      Press (Session, Source_Pin_X, Source_Pin_Y);
      Check ("links-dragging-pins", " 5", Count (Links.Pin_Count (Session)));
      Move_To (Session, 500.0, 120.0, Held => True);
      Release (Session, 500.0, 120.0);
      Check ("links-nothing", " 0", Count (Links.Link_Count (Session)));

      --  Dragged to a pin of the other window, there is.
      Move_To (Session, 200.0, 250.0);
      Press (Session, Source_Pin_X, Source_Pin_Y);
      Move_To (Session, 400.0, 250.0, Held => True);
      Move_To (Session, Target_Pin_X, Target_Pin_Y, Held => True);
      Snap (Session, "links-dragging");
      Release (Session, Target_Pin_X, Target_Pin_Y);
      Check ("links-made", " 1", Count (Links.Link_Count (Session)));
      Move_To (Session, 600.0, 60.0);
      Check ("links-pins-away", " 0", Count (Links.Pin_Count (Session)));
      Snap (Session, "links-made");

      --  Not twice between the same two, nor back to the same window.
      Move_To (Session, 300.0, 250.0);
      Press (Session, Target_Pin_X, Target_Pin_Y);
      Move_To (Session, Source_Pin_X, 150.0, Held => True);
      Release (Session, Source_Pin_X, 150.0);
      Move_To (Session, Source_Pin_X, 150.0);
      Check ("links-not-twice", " 1", Count (Links.Link_Count (Session)));

      --  Kept.
      Proj.Close_Project (Session);
      Home.Open_Project (Session, Key);
      Check ("links-kept", " 1", Count (Links.Link_Count (Session)));
      Move_To (Session, 650.0, 60.0);
      Snap (Session, "links-kept");

      --  They go with an item.
      Click_On (Session, List_X, List_Y);
      Click_On (Session, Remove_X, Row_Y (2));
      Check ("links-removed", " 0", Count (Links.Link_Count (Session)));
   end Linking;

   procedure Editing_Links is
      Session : Viewer.Session;
      Key     : Projects.Id;

      Source_Pin_X : constant Float := 350.0;
      Source_Pin_Y : constant Float := 262.0;
      Target_Pin_X : constant Float := 364.0;
      Target_Pin_Y : constant Float := 346.0;
      Line_X       : constant Float := 357.0;
      Line_Y       : constant Float := 304.0;
      --  Halfway along it, between the windows.
      Top_Pin_X    : constant Float := 504.0;
      Top_Pin_Y    : constant Float := 246.0;
      --  The middle of the top side of the second window.

      --  The toolbar is under the lower end of the line, 294 wide: its
      --  buttons are 22, 2 apart, in three groups 6 further apart.
      Tool_Y   : constant Float := 375.0;
      Dash_X   : constant Float := 279.0;
      Arrow_X  : constant Float := 333.0;
      Orange_X : constant Float := 387.0;
      Delete_X : constant Float := 489.0;

      function Text (Value : Natural) return String is
        (Natural'Image (Value));

      procedure Make_Link is
      begin
         Move_To (Session, 200.0, 250.0);
         Press (Session, Source_Pin_X, Source_Pin_Y);
         Move_To (Session, Target_Pin_X, Target_Pin_Y, Held => True);
         Release (Session, Target_Pin_X, Target_Pin_Y);
         Move_To (Session, 650.0, 60.0);
      end Make_Link;
   begin
      Start_With_One (Session);
      Key := Proj.Current_Project (Session);
      Drag (Session, Hold_X, Bar_Y, Hold_X - 150.0, Bar_Y);
      Click_On (Session, Add_X, Tools_Y);
      Drag (Session, Hold_X + 24.0, Bar_Y + 24.0,
            Hold_X + 144.0, Bar_Y + 84.0);
      Make_Link;
      Check ("link-edit-made", " 1", Text (Links.Link_Count (Session)));
      Check ("link-edit-default",
             "SOLID PLAIN  1 LEFT",
             Links.Link_Description (Session, 1));

      --  A press on the line selects it, and on nothing else does not.
      Check ("link-edit-unselected", "FALSE",
             Boolean'Image (Links.Link_Selected (Session)));
      Click_On (Session, Line_X, Line_Y);
      Check ("link-edit-selected", "TRUE",
             Boolean'Image (Links.Link_Selected (Session)));
      Snap (Session, "link-selected");

      --  Its style, kept.
      Click_On (Session, Dash_X, Tool_Y);
      Click_On (Session, Arrow_X, Tool_Y);
      Click_On (Session, Orange_X, Tool_Y);
      Check ("link-edit-styled", "DASHED ARROW  2 LEFT",
             Links.Link_Description (Session, 1));
      Snap (Session, "link-styled");
      Proj.Close_Project (Session);
      Home.Open_Project (Session, Key);
      Check ("link-edit-style-kept", "DASHED ARROW  2 LEFT",
             Links.Link_Description (Session, 1));
      Move_To (Session, 650.0, 60.0);
      Snap (Session, "link-style-kept");

      --  Its target end dragged to another pin: the pins of the window it
      --  starts from are not shown.
      Click_On (Session, Line_X, Line_Y);
      Move_To (Session, Target_Pin_X, Target_Pin_Y);
      Press (Session, Target_Pin_X, Target_Pin_Y);
      Move_To (Session, Top_Pin_X, Top_Pin_Y, Held => True);
      Check ("link-edit-moving-pins", " 4",
             Text (Links.Pin_Count (Session)));
      Snap (Session, "link-moving");
      Release (Session, Top_Pin_X, Top_Pin_Y);
      Check ("link-edit-moved", "DASHED ARROW  2 TOP",
             Links.Link_Description (Session, 1));
      Check ("link-edit-moved-count", " 1",
             Text (Links.Link_Count (Session)));

      --  Let go on nothing, it stays.
      Move_To (Session, 650.0, 60.0);
      Check ("link-edit-still-selected", "TRUE",
             Boolean'Image (Links.Link_Selected (Session)));

      --  A press on the canvas puts it away.
      Click_On (Session, 600.0, 60.0);
      Check ("link-edit-deselected", "FALSE",
             Boolean'Image (Links.Link_Selected (Session)));

      --  Backspace deletes it; so does its toolbar's button.
      Press_Key (Session, Events.Key_Backspace);
      Check ("link-edit-not-yet", " 1", Text (Links.Link_Count (Session)));
      Click_On (Session, 357.0, 261.0);
      Press_Key (Session, Events.Key_Backspace);
      Check ("link-edit-backspace", " 0", Text (Links.Link_Count (Session)));
      Make_Link;
      Click_On (Session, Line_X, Line_Y);
      Click_On (Session, Delete_X, Tool_Y);
      Check ("link-edit-deleted", " 0", Text (Links.Link_Count (Session)));
      Check ("link-edit-deleted-selection", "FALSE",
             Boolean'Image (Links.Link_Selected (Session)));
   end Editing_Links;

   --  Sources

   Whole_Page : constant String :=
     "<html><body style='margin:0'>"
     & "<div style='height:600px;background:#c0392b'></div>"
     & "<div style='height:600px;background:#27ae60'></div>"
     & "<div style='height:600px;background:#2980b9'></div>"
     & "</body></html>";
   --  Three blocks of colour, with no text, which is not the same on
   --  every release.

   procedure Capture_From
     (Session : in out Viewer.Session; Link : String)
   is
      Tick  : SDL3.Events.Milliseconds := 1_000;
      Waited : Natural := 0;
   begin
      Press_Key (Session, Events.Key_A, Command => True);
      Type_In (Session, Link);
      Press_Key (Session, Events.Key_Return);
      while Windows.Is_Capturing (Session) and then Waited < 600 loop
         Webshot.Pump (100);
         Tick := SDL3.Events.Milliseconds (Natural (Tick) + 100);
         Viewer.Tick (Session, Tick);
         Waited := Waited + 1;
      end loop;
   end Capture_From;

   procedure Source_Windows is
      Session : Viewer.Session;
   begin
      Start (Session);
      Click_On (Session, Source_X, Tools_Y);
      Check
        ("source-count", " 1", Natural'Image (Windows.Item_Count (Session)));
      Check
        ("source-kind", "SOURCE",
         Items.Kinds'Image (Windows.Item_Kind (Session, 1)));
      Check
        ("source-status", "Choose where it comes from",
         Windows.Item_Status (Session, 1));
      Check
        ("source-origin", "UNCHOSEN",
         Items.Origins'Image (Windows.Item_Origin (Session, 1)));
      Move_To (Session, 600.0, 60.0);
      Snap (Session, "source-added");

      --  From URL makes it as it was: a link to type.
      Click_On (Session, From_Url_X, From_Url_Y);
      Check
        ("source-chosen-url", "REMOTE",
         Items.Origins'Image (Windows.Item_Origin (Session, 1)));
      Check
        ("source-url-status", "Press Return to capture",
         Windows.Item_Status (Session, 1));
      Move_To (Session, 600.0, 60.0);
      Snap (Session, "source-added-url");
      Type_In (Session, "example.org");
      Check ("source-link", "example.org", Windows.Item_Text (Session, 1));
      Click_On (Session, Add_X, Tools_Y);
      Check
        ("source-and-note", "NOTE",
         Items.Kinds'Image (Windows.Item_Kind (Session, 2)));
   end Source_Windows;

   Text_Page : constant String :=
     "<html><body style='margin:40px;background:white;color:black;"
     & "font:72px Helvetica'>"
     & "<p>Bonxies nest on moorland</p>"
     & "<p>and winter at sea</p>"
     & "</body></html>";
   --  Plain large text, which Vision reads the same on any release.

   procedure Source_Words is
      Session : Viewer.Session;
      Folder  : constant String := "/tmp/bonxie-source-words";
      Page    : constant String := Folder & "/page.html";
      File    : Ada.Text_IO.File_Type;
      Key     : Projects.Id;
      Words   : Natural;

      function Has (Text, Part : String) return Boolean is
        (Ada.Strings.Fixed.Index (Text, Part) > 0);

      procedure Draw is
         Drawn : Pictures.Image;
      begin
         --  What is drawn is not compared: it has the page's text, which
         --  WebKit draws a little differently from release to release.
         Viewer.Render (Session, Drawn);
      end Draw;
   begin
      if not Ada.Directories.Exists (Folder) then
         Ada.Directories.Create_Path (Folder);
      end if;
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Page);
      Ada.Text_IO.Put (File, Text_Page);
      Ada.Text_IO.Close (File);

      Start (Session);
      Windows.Pin_Capture_Time (Session, 1_700_000_000);
      Key := Proj.Current_Project (Session);
      Windows.Add_Item (Session, "Page", Items.Source);
      Check
        ("words-before", " 0",
         Natural'Image (Windows.Item_Recognized (Session, 1)));

      --  Once the picture is taken its text is looked for, in the
      --  background, and the loop goes on until it is found.
      Pomarine.Application.Run_Posted;
      Capture_From (Session, "file://" & Page);
      Words := Windows.Item_Recognized (Session, 1);
      Check
        ("words-found", "TRUE", Boolean'Image (Words >= 8));

      --  The task that found them woke the loop, which was waiting for an
      --  event, with a post (it is posted just after the words are there).
      declare
         Waited : Natural := 0;
      begin
         while not Pomarine.Application.Is_Waiting and then Waited < 100 loop
            delay 0.01;
            Waited := Waited + 1;
         end loop;
      end;
      Check
        ("words-woke-the-loop", "TRUE", Boolean'Image (Pomarine.Application.Is_Waiting));
      Pomarine.Application.Run_Posted;

      --  Selected, from the window, and copied.
      Draw;
      Click_On (Session, 300.0, Picture_Y);
      Press_Key (Session, Events.Key_A, Command => True);
      Check
        ("words-selected", "TRUE",
         Boolean'Image
           (Has (Windows.Item_Selected_Text (Session, 1), "moorland")
            and then Has (Windows.Item_Selected_Text (Session, 1), "winter")));
      Draw;

      --  Kept, so that opening the project again finds them in the
      --  database and does not look again.
      Proj.Close_Project (Session);
      Home.Open_Project (Session, Key);
      Check
        ("words-not-looked-for", "FALSE",
         Boolean'Image (Windows.Is_Capturing (Session)));
      Check
        ("words-kept", Natural'Image (Words),
         Natural'Image (Windows.Item_Recognized (Session, 1)));
      Draw;
      Click_On (Session, 300.0, Picture_Y);
      Press_Key (Session, Events.Key_A, Command => True);
      Check
        ("words-kept-selected", "TRUE",
         Boolean'Image
           (Has (Windows.Item_Selected_Text (Session, 1), "moorland")));

      Ada.Directories.Delete_Tree
        (Ada.Directories.Containing_Directory
           (Ada.Directories.Containing_Directory
              (Windows.Item_Picture_File (Session, 1))));
      Ada.Directories.Delete_Tree (Folder);
   end Source_Words;

   procedure Source_Documents is
      Session : Viewer.Session;
      Folder  : constant String := "/tmp/bonxie-source-document";
      Book    : constant String := Folder & "/book.pdf";
      File    : Ada.Text_IO.File_Type;
      Key     : Projects.Id;

      procedure Wait is
         Tick   : SDL3.Events.Milliseconds := 1_000;
         Waited : Natural := 0;
      begin
         while Windows.Is_Capturing (Session) and then Waited < 600 loop
            delay 0.05;
            Tick := SDL3.Events.Milliseconds (Natural (Tick) + 100);
            Viewer.Tick (Session, Tick);
            Waited := Waited + 1;
         end loop;
         Pomarine.Application.Run_Posted;
      end Wait;
   begin
      if not Ada.Directories.Exists (Folder) then
         Ada.Directories.Create_Path (Folder);
      end if;
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Book);
      Ada.Text_IO.Put (File, Two_Pages);
      Ada.Text_IO.Close (File);

      Start (Session);
      Windows.Pin_Capture_Time (Session, 1_700_000_000);
      Key := Proj.Current_Project (Session);
      Windows.Add_Item (Session, "Book", Items.Source);

      --  A link to a PDF is fetched, not shown by WebKit: its first page
      --  is the picture.
      Press_Key (Session, Events.Key_A, Command => True);
      Type_In (Session, "file://" & Book);
      Press_Key (Session, Events.Key_Return);
      Wait;
      Check
        ("document-picture", "TRUE",
         Boolean'Image
           (Ada.Directories.Exists (Windows.Item_Picture_File (Session, 1))));
      Check ("document-status", "Page 1 of 2", Windows.Item_Status (Session, 1));
      declare
         Picture : constant String := Windows.Item_Picture_File (Session, 1);
      begin
         Check
           ("document-fetched", "TRUE",
            Boolean'Image
              (Ada.Directories.Exists
                 (Picture (Picture'First .. Picture'Last - 3) & "pdf")));
      end;
      Move_To (Session, 600.0, 60.0);
      Snap (Session, "document-first");
      Check
        ("document-words-first", "TRUE",
         Boolean'Image (Windows.Item_Recognized (Session, 1) >= 3));

      --  The next page is drawn, and its words found.
      Click_On (Session, Next_X, Pager_Y);
      Wait;
      Check ("document-status-next", "Page 2 of 2", Windows.Item_Status (Session, 1));
      Snap (Session, "document-second");
      Click_On (Session, Next_X, Pager_Y);
      Check ("document-last", "Page 2 of 2", Windows.Item_Status (Session, 1));
      Click_On (Session, Previous_X, Pager_Y);
      Wait;
      Check ("document-back", "Page 1 of 2", Windows.Item_Status (Session, 1));

      --  Kept, with its page.
      Click_On (Session, Next_X, Pager_Y);
      Wait;
      Proj.Close_Project (Session);
      Home.Open_Project (Session, Key);
      Check ("document-kept", "Page 2 of 2", Windows.Item_Status (Session, 1));
      Check
        ("document-kept-words", "TRUE",
         Boolean'Image (Windows.Item_Recognized (Session, 1) >= 3));

      Ada.Directories.Delete_Tree
        (Ada.Directories.Containing_Directory
           (Ada.Directories.Containing_Directory
              (Windows.Item_Picture_File (Session, 1))));
      Ada.Directories.Delete_Tree (Folder);
   end Source_Documents;

   procedure Source_Files is
      Session : Viewer.Session;
      Folder  : constant String := "/tmp/bonxie-source-files";
      Book    : constant String := Folder & "/book.pdf";
      Notes   : constant String := Folder & "/notes.txt";
      Odd     : constant String := Folder & "/picture.xyz";
      Words   : constant String :=
        "Bonxies nest on moorland" & ASCII.CR & ASCII.LF & "and winter at sea.";
      --  (Closing the file ends its last line.)
      File    : Ada.Text_IO.File_Type;

      procedure Write (Name, Contents : String) is
      begin
         Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Name);
         Ada.Text_IO.Put (File, Contents);
         Ada.Text_IO.Close (File);
      end Write;

      procedure Wait is
         Tick   : SDL3.Events.Milliseconds := 1_000;
         Waited : Natural := 0;
      begin
         while Windows.Is_Capturing (Session) and then Waited < 600 loop
            delay 0.05;
            Tick := SDL3.Events.Milliseconds (Natural (Tick) + 100);
            Viewer.Tick (Session, Tick);
            Waited := Waited + 1;
         end loop;
         Pomarine.Application.Run_Posted;
      end Wait;
   begin
      if not Ada.Directories.Exists (Folder) then
         Ada.Directories.Create_Path (Folder);
      end if;
      Write (Book, Two_Pages);
      Write (Notes, Words);
      Write (Odd, "not a thing we show");

      Start (Session);
      Windows.Pin_Capture_Time (Session, 1_700_000_000);
      Windows.Add_Unchosen_Source (Session);

      --  A file of a kind that cannot be shown is not taken, and the
      --  source stays as it was.
      Windows.Pick_File (Session, 1, Odd);
      Check
        ("file-unsupported", "Failed: not a PDF, e-book or text file",
         Windows.Item_Status (Session, 1));

      --  A PDF: its path is the source's text, which cannot be typed
      --  over, and its first page is shown.
      Windows.Pick_File (Session, 1, Book);
      Wait;
      Check
        ("file-origin", "LOCAL", Items.Origins'Image (Windows.Item_Origin (Session, 1)));
      Check ("file-path", Book, Windows.Item_Text (Session, 1));
      Check ("file-status", "Page 1 of 2", Windows.Item_Status (Session, 1));
      Check
        ("file-words", "TRUE", Boolean'Image (Windows.Item_Recognized (Session, 1) >= 3));
      Check ("file-title", "book", Windows.Item_Title (Session, 1));
      Move_To (Session, 600.0, 60.0);
      Snap (Session, "file-pdf");
      Type_In (Session, "typed over");
      Check ("file-not-typed", Book, Windows.Item_Text (Session, 1));
      Click_On (Session, Next_X, Pager_Y);
      Wait;
      Check ("file-next", "Page 2 of 2", Windows.Item_Status (Session, 1));

      --  A text file: copied, and shown as text that cannot be changed,
      --  with line ends as line feeds.
      Windows.Pick_File (Session, 1, Notes);
      Wait;
      Check ("file-text-path", Notes, Windows.Item_Text (Session, 1));
      Check
        ("file-text-shown", "Bonxies nest on moorland" & ASCII.LF & "and winter at sea." & ASCII.LF,
         Windows.Item_Shown_Text (Session, 1));
      Check
        ("file-text-status", "Captured 14 Nov 2023", Windows.Item_Status (Session, 1));
      Move_To (Session, 600.0, 60.0);
      Snap (Session, "file-text");
      Click_On (Session, 300.0, Picture_Y);
      Type_In (Session, "typed over");
      Check
        ("file-text-immutable", "Bonxies nest on moorland" & ASCII.LF & "and winter at sea." & ASCII.LF,
         Windows.Item_Shown_Text (Session, 1));
      Press_Key (Session, Events.Key_A, Command => True);
      Check
        ("file-text-selected", "TRUE",
         Boolean'Image (Windows.Item_Text_Selected (Session, 1) = Windows.Item_Shown_Text (Session, 1)));

      --  Kept: opening the project again shows it as it was.
      declare
         Key : constant Projects.Id := Proj.Current_Project (Session);
      begin
         Proj.Close_Project (Session);
         Home.Open_Project (Session, Key);
      end;
      Check
        ("file-text-kept", "Bonxies nest on moorland" & ASCII.LF & "and winter at sea." & ASCII.LF,
         Windows.Item_Shown_Text (Session, 1));
      Check ("file-text-path-kept", Notes, Windows.Item_Text (Session, 1));
      Check
        ("file-origin-kept", "LOCAL", Items.Origins'Image (Windows.Item_Origin (Session, 1)));

      --  A link to a text file is fetched and shown as text too.
      Windows.Add_Item (Session, "Remote", Items.Source);
      Press_Key (Session, Events.Key_A, Command => True);
      Type_In (Session, "file://" & Notes);
      Press_Key (Session, Events.Key_Return);
      Wait;
      Check
        ("remote-text-shown", "Bonxies nest on moorland" & ASCII.LF & "and winter at sea." & ASCII.LF,
         Windows.Item_Shown_Text (Session, 2));

      Ada.Directories.Delete_Tree
        (Ada.Directories.Containing_Directory
           (Ada.Directories.Containing_Directory
              (Windows.Item_Picture_File (Session, 1))));
      Ada.Directories.Delete_Tree (Folder);
   end Source_Files;

   procedure Source_Pages is
      Session : Viewer.Session;
      Folder  : constant String :=
        "/tmp/bonxie-source-page";
      Page    : constant String := Folder & "/page.html";
      File    : Ada.Text_IO.File_Type;
      Key     : Projects.Id;
   begin
      if not Ada.Directories.Exists (Folder) then
         Ada.Directories.Create_Path (Folder);
      end if;
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Page);
      Ada.Text_IO.Put (File, Whole_Page);
      Ada.Text_IO.Close (File);

      Start (Session);
      Windows.Pin_Capture_Time (Session, 1_700_000_000);
      Key := Proj.Current_Project (Session);
      Windows.Add_Item (Session, "Page", Items.Source);
      Capture_From (Session, "file://" & Page);
      Check
        ("source-captured", "FALSE",
         Boolean'Image (Windows.Is_Capturing (Session)));
      Check
        ("source-picture", "TRUE",
         Boolean'Image
           (Ada.Directories.Exists (Windows.Item_Picture_File (Session, 1))));
      Check
        ("source-status-done", "Captured ",
         Windows.Item_Status (Session, 1) (1 .. 9));
      Move_To (Session, 600.0, 60.0);
      Snap (Session, "source-captured");

      --  Highlighted: the tool is chosen in the status line, and a drag
      --  over the picture marks it, where a drag did nothing before.
      Check
        ("source-cursor-first", "FALSE",
         Boolean'Image (Windows.Item_Highlighting (Session, 1)));
      Drag (Session, 300.0, Picture_Y, 400.0, Picture_Y);
      Check
        ("source-no-mark", " 0",
         Natural'Image (Windows.Item_Marks (Session, 1)));
      Click_On (Session, Marker_X, Status_Y);
      Check
        ("source-marker-chosen", "TRUE",
         Boolean'Image (Windows.Item_Highlighting (Session, 1)));
      Drag (Session, 300.0, Picture_Y, 400.0, Picture_Y);
      Check
        ("source-mark", " 1", Natural'Image (Windows.Item_Marks (Session, 1)));
      Click_On (Session, 340.0, Picture_Y + 30.0);
      Check
        ("source-click-no-mark", " 1",
         Natural'Image (Windows.Item_Marks (Session, 1)));
      Snap (Session, "source-marked");

      --  The eraser removes the mark it is clicked on, and no other.
      Click_On (Session, Eraser_X, Status_Y);
      Check
        ("source-eraser-chosen", "TRUE",
         Boolean'Image (Windows.Item_Erasing (Session, 1)));
      Click_On (Session, 340.0, Picture_Y + 30.0);
      Check
        ("source-erase-miss", " 1",
         Natural'Image (Windows.Item_Marks (Session, 1)));
      Click_On (Session, 350.0, Picture_Y);
      Check
        ("source-erased", " 0",
         Natural'Image (Windows.Item_Marks (Session, 1)));
      Click_On (Session, Marker_X, Status_Y);
      Drag (Session, 300.0, Picture_Y, 400.0, Picture_Y);
      Check
        ("source-marked-again", " 1",
         Natural'Image (Windows.Item_Marks (Session, 1)));

      --  The cursor puts it away; so does a click outside the window.
      Click_On (Session, Cursor_X, Status_Y);
      Check
        ("source-cursor-chosen", "FALSE",
         Boolean'Image (Windows.Item_Highlighting (Session, 1)));
      Click_On (Session, Marker_X, Status_Y);
      Click_On (Session, 100.0, 100.0);
      Check
        ("source-marker-put-away", "FALSE",
         Boolean'Image (Windows.Item_Highlighting (Session, 1)));

      --  Zoomed within the window: by the slider, and from the menu.
      Check
        ("source-zoom-start", " 1.00000E+00",
         Float'Image (Windows.Item_Zoom (Session, 1)));
      Click_On (Session, Menu_X, Status_Y);
      Snap (Session, "source-menu");
      Click_On (Session, Preset_X, Preset_Y);
      Check
        ("source-zoom-menu", " 2.00000E+00",
         Float'Image (Windows.Item_Zoom (Session, 1)));
      Snap (Session, "source-zoomed");

      --  Dragged part of the way, with the knob held: the zoom it is
      --  rounded to is not where the knob is, which it must leave alone
      --  while it is held (this once failed a postcondition).
      Press (Session, Slider_X, Status_Y);
      Move_To (Session, Slider_X + 6.3, Status_Y - 16.0, Held => True);
      Move_To (Session, Slider_X + 12.7, Status_Y - 16.0, Held => True);
      Release (Session, Slider_X + 12.7, Status_Y);
      Check
        ("source-zoom-dragged", "TRUE",
         Boolean'Image
           (Windows.Item_Zoom (Session, 1) > 1.0
            and then Windows.Item_Zoom (Session, 1) < 4.0));
      Click_On (Session, Slider_End_X, Status_Y);
      Check
        ("source-zoom-slider", " 4.00000E+00",
         Float'Image (Windows.Item_Zoom (Session, 1)));

      --  Scrolled with the wheel, over the picture.
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Wheel, Wheel_Y => -4.0,
                                Mouse_X => 360.0, Mouse_Y => 262.0,
                                others => <>));
      Snap (Session, "source-scrolled");
      Check
        ("source-marked-still", " 1",
         Natural'Image (Windows.Item_Marks (Session, 1)));

      --  Kept with the project, picture and all.
      Proj.Close_Project (Session);
      Home.Open_Project (Session, Key);
      Check
        ("source-kept-status", "Captured ",
         Windows.Item_Status (Session, 1) (1 .. 9));
      Snap (Session, "source-kept");
      Check
        ("source-mark-kept", " 1",
         Natural'Image (Windows.Item_Marks (Session, 1)));
      Check
        ("source-zoom-kept", " 4.00000E+00",
         Float'Image (Windows.Item_Zoom (Session, 1)));

      --  A page that is not there fails, and says so.
      Windows.Add_Item (Session, "Nowhere", Items.Source);
      Capture_From (Session, "https://nowhere.invalid/");
      Check
        ("source-failed", "Failed: ",
         Windows.Item_Status (Session, 2) (1 .. 8));

      --  What the test made, and the project's pictures, are tidied away.
      Ada.Directories.Delete_Tree
        (Ada.Directories.Containing_Directory
           (Ada.Directories.Containing_Directory
              (Windows.Item_Picture_File (Session, 1))));
      Ada.Directories.Delete_Tree (Folder);
   end Source_Pages;

end Item_Tests;
