with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with SDL3.Cursors;
with SDL3.Events;
with Document_Tests;
with Field_Tests;
with Goldens;
with Item_Tests;
with Picture_Tests;
with Projects;
with Text_Area_Tests;
with Widget_Tests;
with Viewer;

--  Draws the viewer, and a text area by itself, in various setups and
--  compares what they draw with golden images: golden [part of a test's
--  name]. See Goldens.
procedure Golden is

   package Events renames SDL3.Events;
   package Images renames Goldens.Images;

   Filter : constant String :=
     (if Ada.Command_Line.Argument_Count > 0
      then Ada.Command_Line.Argument (1) else "");

   --  Events

   function Key
     (Code : Events.Key_Code; Command : Boolean := False) return Events.Event
   is ((Kind => Events.Key_Down, Key => Code, Command => Command,
        others => <>));

   --  Shorthands

   Default_Width  : constant := 720;
   Default_Height : constant := 480;
   --  In points. The toolbar takes 32 of the height, at the bottom.

   Tools_Item_X : constant Float := 242.0;
   Tools_Item_Y : constant Float := 464.0;
   --  In points: the middle of the item on the tools bar, above the
   --  toolbar.

   function Wheel
     (Across, Down : Float; X, Y : Float; Command : Boolean := False)
      return Events.Event
   is ((Kind => Events.Mouse_Wheel, Wheel_X => Across, Wheel_Y => Down,
        Mouse_X => X, Mouse_Y => Y, Command => Command, others => <>));

   function Click (X, Y : Float) return Events.Event is
     ((Kind => Events.Mouse_Down, Button => 1, Clicks => 1,
       Mouse_X => X, Mouse_Y => Y, others => <>));
   --  At X, Y points.

   function Pointer_At (X, Y : Float; Held : Boolean := False)
      return Events.Event
   is ((Kind => Events.Mouse_Move, Mouse_X => X, Mouse_Y => Y,
        Left_Held => Held, others => <>));

   function Press_Button (Which : Natural; X, Y : Float) return Events.Event
   is ((Kind => Events.Mouse_Down, Button => Which, Clicks => 1,
        Mouse_X => X, Mouse_Y => Y, others => <>));

   function Release_Button (Which : Natural; X, Y : Float)
      return Events.Event
   is ((Kind => Events.Mouse_Up, Button => Which, Clicks => 1,
        Mouse_X => X, Mouse_Y => Y, others => <>));

   function Whole (Value : Float) return String is
     (Integer'Image (Integer (Float'Rounding (Value))));
   --  To the nearest whole number, to compare as text.

   function Percent (Value : Float) return String is
     (Whole (Value * 100.0));

   procedure Press
     (Item  : in out Viewer.Session;
      Code  : Events.Key_Code;
      Times : Positive := 1;
      Command : Boolean := False) is
   begin
      for K in 1 .. Times loop
         Viewer.Handle (Item, Key (Code, Command));
      end loop;
   end Press;

   procedure Start
     (Item    : in out Viewer.Session;
      Width   : Positive := Default_Width;
      Height  : Positive := Default_Height;
      Density : Float := 2.0) is
   begin
      Viewer.Open (Item, "", Width, Height, Density);
      Viewer.New_Project (Item);
   end Start;
   --  A project, at its canvas.

   procedure Show
     (Name    : String;
      Width   : Positive := Default_Width;
      Height  : Positive := Default_Height;
      Density : Float := 2.0)
   is
      Session : Viewer.Session;
      Drawn   : Images.Image;
   begin
      Start (Session, Width, Height, Density);
      Viewer.Render (Session, Drawn);
      Goldens.Check (Name, Drawn);
   end Show;

   --  The canvas

   procedure Canvas_Starts is
      Session : Viewer.Session;
   begin
      Show ("canvas");
      Start (Session);
      Goldens.Check_Text
        ("canvas-mode", "CANVAS", Viewer.Modes'Image (Viewer.Mode (Session)));
      --  The origin in the middle, at a zoom of 1.
      Goldens.Check_Text
        ("canvas-origin", " 360 224",
         Whole (Viewer.Canvas_Origin_X (Session))
         & Whole (Viewer.Canvas_Origin_Y (Session)));
      Goldens.Check_Text
        ("canvas-first-zoom", " 100", Percent (Viewer.Canvas_Zoom (Session)));
   end Canvas_Starts;

   procedure Canvas_Low_Density is
   begin
      Show ("canvas-1x", Density => 1.0);
   end Canvas_Low_Density;

   procedure Canvas_Narrow is
   begin
      Show ("canvas-narrow", Width => 200, Height => 300);
   end Canvas_Narrow;

   procedure Canvas_Resized is
      Session : Viewer.Session;
      Drawn   : Images.Image;
   begin
      Start (Session);
      Viewer.Render (Session, Drawn);
      Viewer.Resize (Session, 400, 600);
      Viewer.Render (Session, Drawn);
      Goldens.Check ("canvas-resized", Drawn);
   end Canvas_Resized;

   procedure Canvas_Panned is
      Session : Viewer.Session;
      Drawn   : Images.Image;
   begin
      --  The wheel, or two fingers on a trackpad, pans by 24 points a
      --  notch: down by Y, and left by X.
      Start (Session);
      Viewer.Handle (Session, Wheel (-1.0, 2.0, 400.0, 300.0));
      Goldens.Check_Text
        ("canvas-panned-origin", " 384 272",
         Whole (Viewer.Canvas_Origin_X (Session))
         & Whole (Viewer.Canvas_Origin_Y (Session)));
      Goldens.Check_Text
        ("canvas-panned-zoom", " 100", Percent (Viewer.Canvas_Zoom (Session)));
      Viewer.Render (Session, Drawn);
      Goldens.Check ("canvas-panned", Drawn);

      --  As far as it goes.
      Viewer.Handle (Session, Wheel (0.0, -1000.0, 400.0, 300.0));
      Viewer.Render (Session, Drawn);
      Goldens.Check ("canvas-panned-far", Drawn);
   end Canvas_Panned;

   procedure Canvas_Zoomed is
      Session : Viewer.Session;
      Drawn   : Images.Image;

      function Under_Pointer return String is
        (Whole ((500.0 - Viewer.Canvas_Origin_X (Session))
                / Viewer.Canvas_Zoom (Session))
         & Whole ((300.0 - Viewer.Canvas_Origin_Y (Session))
                  / Viewer.Canvas_Zoom (Session)));
   begin
      Start (Session);
      Goldens.Check_Text ("canvas-zoom-before", " 140 76", Under_Pointer);

      --  Command with the wheel zooms about the pointer, which keeps what
      --  is under it.
      Viewer.Handle
        (Session, Wheel (0.0, 3.0, 500.0, 300.0, Command => True));
      Goldens.Check_Text
        ("canvas-zoom-in", " 133", Percent (Viewer.Canvas_Zoom (Session)));
      Goldens.Check_Text ("canvas-zoom-kept", " 140 76", Under_Pointer);
      Viewer.Render (Session, Drawn);
      Goldens.Check ("canvas-zoomed-in", Drawn);

      Viewer.Handle
        (Session, Wheel (0.0, -8.0, 500.0, 300.0, Command => True));
      Goldens.Check_Text
        ("canvas-zoom-out", " 62", Percent (Viewer.Canvas_Zoom (Session)));
      Goldens.Check_Text ("canvas-zoom-out-kept", " 140 76", Under_Pointer);
      Viewer.Render (Session, Drawn);
      Goldens.Check ("canvas-zoomed-out", Drawn);
   end Canvas_Zoomed;

   procedure Canvas_Zoom_Keys is
      Session : Viewer.Session;
   begin
      Start (Session);
      Press (Session, Events.Key_Equals, Times => 2, Command => True);
      Goldens.Check_Text
        ("canvas-keys-in", " 121", Percent (Viewer.Canvas_Zoom (Session)));
      Press (Session, Events.Key_Minus, Times => 4, Command => True);
      Goldens.Check_Text
        ("canvas-keys-out", " 83", Percent (Viewer.Canvas_Zoom (Session)));
      Press (Session, Events.Key_0, Command => True);
      Goldens.Check_Text
        ("canvas-keys-reset", " 100", Percent (Viewer.Canvas_Zoom (Session)));
      --  About the middle.
      Goldens.Check_Text
        ("canvas-keys-origin", " 360 224",
         Whole (Viewer.Canvas_Origin_X (Session))
         & Whole (Viewer.Canvas_Origin_Y (Session)));

      --  Within limits.
      Press (Session, Events.Key_Equals, Times => 100, Command => True);
      Goldens.Check_Text
        ("canvas-keys-most", " 800", Percent (Viewer.Canvas_Zoom (Session)));
      Press (Session, Events.Key_Minus, Times => 200, Command => True);
      Goldens.Check_Text
        ("canvas-keys-least", " 10", Percent (Viewer.Canvas_Zoom (Session)));
   end Canvas_Zoom_Keys;

   procedure Canvas_Pinched is
      Session : Viewer.Session;
   begin
      Start (Session);
      Viewer.Handle
        (Session,
         (Kind => Events.Pinch, Scale => 1.5, Mouse_X => 360.0,
          Mouse_Y => 208.0, others => <>));
      Goldens.Check_Text
        ("canvas-pinch-in", " 150", Percent (Viewer.Canvas_Zoom (Session)));
      Viewer.Handle
        (Session,
         (Kind => Events.Pinch, Scale => 0.5, Mouse_X => 360.0,
          Mouse_Y => 208.0, others => <>));
      Goldens.Check_Text
        ("canvas-pinch-out", " 75", Percent (Viewer.Canvas_Zoom (Session)));
   end Canvas_Pinched;

   procedure Canvas_Dragged is
      Session : Viewer.Session;
      Drawn   : Images.Image;

      function Cursor return String is
        (SDL3.Cursors.Kind'Image (Viewer.Cursor (Session)));
   begin
      Start (Session);
      Viewer.Handle (Session, Pointer_At (300.0, 200.0));
      Goldens.Check_Text ("canvas-cursor-idle", "DEFAULT", Cursor);

      --  The left button does not pan.
      Viewer.Handle (Session, Click (300.0, 200.0));
      Viewer.Handle (Session, Pointer_At (340.0, 230.0, Held => True));
      Viewer.Handle (Session, Release_Button (1, 340.0, 230.0));
      Goldens.Check_Text
        ("canvas-left-drag", " 360 224",
         Whole (Viewer.Canvas_Origin_X (Session))
         & Whole (Viewer.Canvas_Origin_Y (Session)));

      --  The middle button does, with the move cursor while it does.
      Viewer.Handle (Session, Press_Button (2, 300.0, 200.0));
      Goldens.Check_Text ("canvas-cursor-panning", "MOVE", Cursor);
      Viewer.Handle (Session, Pointer_At (340.0, 230.0));
      Viewer.Handle (Session, Pointer_At (350.0, 210.0));
      Goldens.Check_Text
        ("canvas-middle-drag", " 410 234",
         Whole (Viewer.Canvas_Origin_X (Session))
         & Whole (Viewer.Canvas_Origin_Y (Session)));
      Goldens.Check_Text ("canvas-cursor-still-panning", "MOVE", Cursor);
      Viewer.Render (Session, Drawn);
      Goldens.Check ("canvas-middle-dragged", Drawn);
      Viewer.Handle (Session, Release_Button (2, 350.0, 210.0));
      Goldens.Check_Text ("canvas-cursor-let-go", "DEFAULT", Cursor);

      --  Let go, it follows the pointer no more.
      Viewer.Handle (Session, Pointer_At (400.0, 300.0));
      Goldens.Check_Text
        ("canvas-after-drag", " 410 234",
         Whole (Viewer.Canvas_Origin_X (Session))
         & Whole (Viewer.Canvas_Origin_Y (Session)));
   end Canvas_Dragged;

   --  The tools bar

   procedure Tools_Shown is
      Session : Viewer.Session;
      Hovered : Images.Image;
   begin
      Start (Session);
      Viewer.Handle (Session, Pointer_At (Tools_Item_X, Tools_Item_Y));
      Viewer.Render (Session, Hovered);
      Goldens.Check ("tools-item-hovered", Hovered);
   end Tools_Shown;

   procedure Tools_Item_Click is
      Session : Viewer.Session;
   begin
      --  A click on the item does nothing yet.
      Start (Session);
      Viewer.Handle (Session, Pointer_At (Tools_Item_X, Tools_Item_Y));
      Viewer.Handle (Session, Click (Tools_Item_X, Tools_Item_Y));
      Viewer.Handle
        (Session, Release_Button (1, Tools_Item_X, Tools_Item_Y));
      Goldens.Check_Text
        ("tools-item-clicked", "PROJECT",
         Viewer.Screens'Image (Viewer.Screen (Session)));
      Goldens.Check_Text
        ("tools-item-cursor", "DEFAULT",
         SDL3.Cursors.Kind'Image (Viewer.Cursor (Session)));
   end Tools_Item_Click;

   --  The screens

   Hour : constant := 3600;

   function Titles (Item : Projects.Recent_List) return String is
      Result : String (1 .. 1024);
      Last   : Natural := 0;
   begin
      for I in 1 .. Item.Count loop
         declare
            Name : constant String :=
              Projects.Titles.To_String (Item.Items (I).Title) & ",";
         begin
            Result (Last + 1 .. Last + Name'Length) := Name;
            Last := Last + Name'Length;
         end;
      end loop;
      return Result (1 .. Last);
   end Titles;

   function Button_Click (X, Y : Float) return Events.Event is
     ((Kind => Events.Mouse_Up, Button => 1, Clicks => 1,
       Mouse_X => X, Mouse_Y => Y, others => <>));

   procedure Click_On (Item : in out Viewer.Session; X, Y : Float) is
   begin
      Viewer.Handle (Item, Events.Event'(Kind => Events.Mouse_Move,
                                         Mouse_X => X, Mouse_Y => Y,
                                         others => <>));
      Viewer.Handle (Item, Click (X, Y));
      Viewer.Handle (Item, Button_Click (X, Y));
   end Click_On;

   --  Where the buttons are, in points, in a window Default_Width wide
   --  and Default_Height high: in the middle of the right half.
   Actions_X : constant Float := Float (Default_Width) * 0.75;
   New_Y     : constant Float := 212.0;
   Settings_Y : constant Float := 268.0;
   Close_X   : constant Float := Float (Default_Width) - 4.0 - 36.0;
   Close_Y   : constant Float := Float (Default_Height) - 16.0;

   function Row_Y (Row : Positive) return Float is
     (72.0 + Float (Row - 1) * 48.0 + 18.0);
   --  The middle of a project's row, in points: below the title.

   Rename_X : constant Float := 254.0;
   Delete_X : constant Float := 306.0;
   Ok_X     : constant Float := 232.0;
   Cancel_X : constant Float := 296.0;
   --  Of the buttons beside a project's button, and of the field's.

   procedure Move_Away (Item : in out Viewer.Session) is
   begin
      Viewer.Handle (Item, Events.Event'(Kind => Events.Mouse_Move,
                                         Mouse_X => 1.0, Mouse_Y => 1.0,
                                         others => <>));
   end Move_Away;

   procedure With_Three (Session : in out Viewer.Session) is
   begin
      Viewer.Open (Session, "", Default_Width, Default_Height);
      for I in 1 .. 3 loop
         Viewer.Add_Project
           (Session, "Episode" & Natural'Image (I), Hour * Long_Integer (I));
      end loop;
   end With_Three;

   procedure Renaming is
      Session : Viewer.Session;
      Drawn   : Images.Image;
   begin
      With_Three (Session);
      Click_On (Session, Rename_X, Row_Y (2));
      Goldens.Check_Text
        ("rename-started", "TRUE",
         Boolean'Image (Viewer.Is_Renaming (Session)));
      Viewer.Render (Session, Drawn);
      Goldens.Check ("rename-field", Drawn);

      --  The title is selected, to type over.
      Viewer.Handle (Session, Events.Text_Event ("Renamed"));
      Viewer.Render (Session, Drawn);
      Goldens.Check ("rename-typed", Drawn);
      Click_On (Session, Ok_X, Row_Y (2));
      Goldens.Check_Text
        ("rename-done", "FALSE",
         Boolean'Image (Viewer.Is_Renaming (Session)));
      Goldens.Check_Text ("rename-first", "Renamed",
                          Viewer.Row_Title (Session, 1));
      Goldens.Check_Text ("rename-second", "Episode 3",
                          Viewer.Row_Title (Session, 2));
      Goldens.Check_Text ("rename-third", "Episode 1",
                          Viewer.Row_Title (Session, 3));
      Move_Away (Session);
      Viewer.Render (Session, Drawn);
      Goldens.Check ("rename-list", Drawn);

      --  Clicking the project's button opens that project.
      Click_On (Session, 100.0, Row_Y (1));
      Goldens.Check_Text
        ("rename-opened", "PROJECT",
         Viewer.Screens'Image (Viewer.Screen (Session)));
      --  Its title is on the toolbar.
      Viewer.Render (Session, Drawn);
      Goldens.Check ("project-title", Drawn);
   end Renaming;

   --  The dialog to confirm a deletion, in a window Default_Width wide
   --  and Default_Height high: in the middle.
   Dialog_Delete_X : constant Float := 447.0;
   Dialog_Cancel_X : constant Float := 343.0;
   Dialog_Buttons_Y : constant Float := 294.0;

   procedure Deleting is
      Session : Viewer.Session;
      Drawn   : Images.Image;
   begin
      With_Three (Session);
      Click_On (Session, Delete_X, Row_Y (2));
      Goldens.Check_Text
        ("delete-asks", "TRUE",
         Boolean'Image (Viewer.Is_Confirming (Session)));
      Viewer.Render (Session, Drawn);
      Goldens.Check ("delete-dialog", Drawn);

      --  The screen behind takes no clicks, nor keys.
      Click_On (Session, 100.0, Row_Y (1));
      Goldens.Check_Text
        ("delete-modal-screen", "HOME",
         Viewer.Screens'Image (Viewer.Screen (Session)));
      Click_On (Session, Delete_X, Row_Y (3));
      Goldens.Check_Text
        ("delete-modal-same", "TRUE",
         Boolean'Image (Viewer.Is_Confirming (Session)));

      --  Cancel keeps it.
      Click_On (Session, Dialog_Cancel_X, Dialog_Buttons_Y);
      Goldens.Check_Text
        ("delete-cancelled", "FALSE",
         Boolean'Image (Viewer.Is_Confirming (Session)));
      Goldens.Check_Text ("delete-cancelled-title", "Episode 2",
                          Viewer.Row_Title (Session, 2));
      Move_Away (Session);
      Viewer.Render (Session, Drawn);
      Goldens.Check ("delete-after-cancel", Drawn);

      --  So does Escape.
      Click_On (Session, Delete_X, Row_Y (2));
      Viewer.Handle (Session, Key (Events.Key_Escape));
      Goldens.Check_Text
        ("delete-escaped", "FALSE",
         Boolean'Image (Viewer.Is_Confirming (Session)));
      Goldens.Check_Text ("delete-escaped-title", "Episode 2",
                          Viewer.Row_Title (Session, 2));

      --  Delete removes it.
      Click_On (Session, Delete_X, Row_Y (2));
      Click_On (Session, Dialog_Delete_X, Dialog_Buttons_Y);
      Goldens.Check_Text
        ("delete-done", "FALSE",
         Boolean'Image (Viewer.Is_Confirming (Session)));
      Goldens.Check_Text ("delete-first", "Episode 3",
                          Viewer.Row_Title (Session, 1));
      Goldens.Check_Text ("delete-second", "Episode 1",
                          Viewer.Row_Title (Session, 2));
      Goldens.Check_Text ("delete-third", "", Viewer.Row_Title (Session, 3));
      Move_Away (Session);
      Viewer.Render (Session, Drawn);
      Goldens.Check ("delete-list", Drawn);
   end Deleting;

   procedure Rename_Cancelled is
      Session : Viewer.Session;
      Before, After : Images.Image;
   begin
      With_Three (Session);
      Move_Away (Session);
      Viewer.Render (Session, Before);
      Click_On (Session, Rename_X, Row_Y (1));
      Viewer.Handle (Session, Events.Text_Event ("Nope"));
      Click_On (Session, Cancel_X, Row_Y (1));
      Goldens.Check_Text
        ("cancel-renaming", "FALSE",
         Boolean'Image (Viewer.Is_Renaming (Session)));
      Goldens.Check_Text ("cancel-title", "Episode 3",
                          Viewer.Row_Title (Session, 1));
      Move_Away (Session);
      Viewer.Render (Session, After);
      Goldens.Check_Same ("cancel-same", Before, After);

      --  Another renamed after, and the first is not.
      Click_On (Session, Rename_X, Row_Y (1));
      Click_On (Session, Rename_X, Row_Y (3));
      Goldens.Check_Text
        ("cancel-other", "TRUE",
         Boolean'Image (Viewer.Is_Renaming (Session)));
      Viewer.Render (Session, After);
      Goldens.Check ("rename-other-row", After);
   end Rename_Cancelled;

   procedure Rename_Entered is
      Session : Viewer.Session;
   begin
      --  Return accepts, as OK does.
      With_Three (Session);
      Click_On (Session, Rename_X, Row_Y (3));
      Viewer.Handle (Session, Events.Text_Event ("  Pilot  "));
      Viewer.Handle (Session, Key (Events.Key_Return));
      Goldens.Check_Text ("enter-renaming", "FALSE",
                          Boolean'Image (Viewer.Is_Renaming (Session)));
      Goldens.Check_Text ("enter-title", "Pilot",
                          Viewer.Row_Title (Session, 1));

      --  Nothing is not a title.
      Click_On (Session, Rename_X, Row_Y (1));
      Viewer.Handle (Session, Key (Events.Key_Backspace));
      Click_On (Session, Ok_X, Row_Y (1));
      Goldens.Check_Text ("empty-renaming", "TRUE",
                          Boolean'Image (Viewer.Is_Renaming (Session)));
      Goldens.Check_Text ("empty-title", "Pilot",
                          Viewer.Row_Title (Session, 1));

      --  Opening another project, or leaving, stops it.
      Click_On (Session, Actions_X, New_Y);
      Click_On (Session, Close_X, Close_Y);
      Goldens.Check_Text ("left-renaming", "FALSE",
                          Boolean'Image (Viewer.Is_Renaming (Session)));
   end Rename_Entered;

   procedure Home_Empty is
      Session : Viewer.Session;
      Drawn   : Images.Image;
   begin
      Viewer.Open (Session, "", Default_Width, Default_Height);
      Goldens.Check_Text
        ("home-is-first", "HOME",
         Viewer.Screens'Image (Viewer.Screen (Session)));
      Goldens.Check_Text ("home-title", "bonxie", Viewer.Title (Session));
      Viewer.Render (Session, Drawn);
      Goldens.Check ("home-empty", Drawn);
   end Home_Empty;

   procedure Home_Recent is
      Session : Viewer.Session;
      Drawn   : Images.Image;
   begin
      --  The five latest, the latest first.
      Viewer.Open (Session, "", Default_Width, Default_Height);
      for I in 1 .. 7 loop
         Viewer.Add_Project
           (Session, "Episode" & Natural'Image (I), Hour * Long_Integer (I));
      end loop;
      Viewer.Render (Session, Drawn);
      Goldens.Check ("home-recent", Drawn);
   end Home_Recent;

   procedure Home_Settings is
      Session : Viewer.Session;
      Expected, Drawn : Images.Image;
   begin
      --  Settings does nothing yet.
      Viewer.Open (Session, "", Default_Width, Default_Height);
      Viewer.Render (Session, Expected);
      Click_On (Session, Actions_X, Settings_Y);
      --  Not over it, to look as it did.
      Viewer.Handle (Session, Events.Event'(Kind => Events.Mouse_Move,
                                            Mouse_X => 1.0, Mouse_Y => 1.0,
                                            others => <>));
      Viewer.Render (Session, Drawn);
      Goldens.Check_Same ("settings-no-change", Expected, Drawn);
      Goldens.Check_Text
        ("settings-stays-home", "HOME",
         Viewer.Screens'Image (Viewer.Screen (Session)));
   end Home_Settings;

   procedure New_And_Close is
      Session : Viewer.Session;
      Drawn   : Images.Image;
   begin
      Viewer.Open (Session, "Bonxie", Default_Width, Default_Height);
      Viewer.Add_Project (Session, "Episode 1", Hour);
      Click_On (Session, Actions_X, New_Y);
      Goldens.Check_Text
        ("new-project-screen", "PROJECT",
         Viewer.Screens'Image (Viewer.Screen (Session)));
      Viewer.Render (Session, Drawn);
      Goldens.Check ("project-screen", Drawn);

      Click_On (Session, Close_X, Close_Y);
      Goldens.Check_Text
        ("close-project-screen", "HOME",
         Viewer.Screens'Image (Viewer.Screen (Session)));
      Viewer.Render (Session, Drawn);
      Goldens.Check ("home-after-close", Drawn);
   end New_And_Close;

   procedure Add
     (Store       : in out Projects.Store;
      Title       : String;
      Description : String := "";
      Time        : Projects.Seconds)
   is
      Ignored : constant Projects.Id :=
        Projects.Create (Store, Title, Description, Time);
      pragma Unreferenced (Ignored);
   begin
      null;
   end Add;

   procedure Open_Listed is
      Session : Viewer.Session;
   begin
      --  A click on a listed project opens it: the second latest here.
      Viewer.Open (Session, "", Default_Width, Default_Height);
      for I in 1 .. 3 loop
         Viewer.Add_Project
           (Session, "Episode" & Natural'Image (I), Hour * Long_Integer (I));
      end loop;
      Click_On (Session, 100.0, Row_Y (2));
      Goldens.Check_Text
        ("listed-screen", "PROJECT",
         Viewer.Screens'Image (Viewer.Screen (Session)));
      Goldens.Check_Text
        ("listed-project", "2",
         Projects.Id'Image (Viewer.Current_Project (Session))
           (2 .. Projects.Id'Image (Viewer.Current_Project (Session))'Last));

      Click_On (Session, Close_X, Close_Y);
      Goldens.Check_Text
        ("listed-closed", "HOME",
         Viewer.Screens'Image (Viewer.Screen (Session)));
      --  A new project is a project of its own.
      Click_On (Session, Actions_X, New_Y);
      Goldens.Check_Text
        ("listed-new-project", "4",
         Projects.Id'Image (Viewer.Current_Project (Session))
           (2 .. Projects.Id'Image (Viewer.Current_Project (Session))'Last));
   end Open_Listed;

   procedure Stored is
      File   : constant String := Goldens.Scratch ("projects.db");
      Store  : Projects.Store;
      Recent : Projects.Recent_List;
   begin
      if Ada.Directories.Exists (File) then
         Ada.Directories.Delete_File (File);
      end if;
      Projects.Open (Store, File);
      Add (Store, "Old", "first", 100);
      Add (Store, "Same time, later", Time => 300);
      Add (Store, "Same time", Time => 300);
      Add (Store, "Middle", Time => 200);
      Projects.Recent (Store, Recent);
      Goldens.Check_Text
        ("projects-order", "Same time,Same time, later,Middle,Old,",
         Titles (Recent));
      Goldens.Check_Text
        ("projects-description", "first",
         Projects.Descriptions.To_String (Recent.Items (4).Description));
      Goldens.Check_Text
        ("projects-times", " 100 100",
         Recent.Items (4).Created_At'Image
        & Recent.Items (4).Updated_At'Image);

      --  Updating one puts it first.
      Projects.Touch (Store, Recent.Items (4).Key, 400);
      Projects.Recent (Store, Recent);
      Goldens.Check_Text
        ("projects-touched", "Old,Same time,Same time, later,Middle,",
         Titles (Recent));

      Projects.Rename (Store, Recent.Items (1).Key, "Renamed", 450);
      Projects.Recent (Store, Recent);
      Goldens.Check_Text
        ("projects-renamed", "Renamed,Same time,Same time, later,Middle,",
         Titles (Recent));
      Projects.Rename (Store, Recent.Items (1).Key, "Old", 400);

      --  Only five are listed.
      Add (Store, "Five", Time => 500);
      Add (Store, "Six", Time => 600);
      Projects.Recent (Store, Recent);
      Goldens.Check_Text
        ("projects-limit", "Six,Five,Old,Same time,Same time, later,",
         Titles (Recent));

      --  Deleted, one is gone, and the next takes its place.
      Projects.Delete (Store, Recent.Items (1).Key);
      Projects.Recent (Store, Recent);
      Goldens.Check_Text
        ("projects-deleted",
         "Five,Old,Same time,Same time, later,Middle,", Titles (Recent));
      Projects.Delete (Store, 9999);  --  none such
   end Stored;

   procedure Kept is
      File   : constant String := Goldens.Scratch ("kept.db");
      Recent : Projects.Recent_List;
   begin
      if Ada.Directories.Exists (File) then
         Ada.Directories.Delete_File (File);
      end if;
      declare
         Store : Projects.Store;
      begin
         Projects.Open (Store, File);
         Add (Store, "Kept", Time => 100);
      end;
      --  Opened again, in a folder that is made.
      declare
         Store : Projects.Store;
      begin
         Projects.Open (Store, File);
         Projects.Recent (Store, Recent);
         Goldens.Check_Text ("projects-kept", "Kept,", Titles (Recent));
      end;
   end Kept;

   type Test_Procedure is access procedure;

   Ran : Natural := 0;

   procedure Run (Name : String; Test : not null Test_Procedure) is
   begin
      if Filter = "" or else Ada.Strings.Fixed.Index (Name, Filter) > 0 then
         Test.all;
         Ran := Ran + 1;
      end if;
   end Run;
begin
   Run ("document-loading", Document_Tests.Loading'Access);
   Run ("document-splicing", Document_Tests.Splicing'Access);
   Run ("document-ids", Document_Tests.Ids'Access);
   Run ("document-kinds", Document_Tests.Kinds'Access);
   Run ("document-steps", Document_Tests.Steps'Access);
   Run ("document-joining-edits", Document_Tests.Joining_Edits'Access);
   Run ("document-units", Document_Tests.Units'Access);
   Run ("document-against-a-string",
        Document_Tests.Against_A_String'Access);
   Run ("document-mapping", Document_Tests.Mapping'Access);
   Run ("layout-lines-after-edits", Document_Tests.Lines_After_Edits'Access);

   Run ("canvas", Canvas_Starts'Access);
   Run ("canvas-1x", Canvas_Low_Density'Access);
   Run ("canvas-narrow", Canvas_Narrow'Access);
   Run ("canvas-resized", Canvas_Resized'Access);
   Run ("canvas-panned", Canvas_Panned'Access);
   Run ("canvas-zoomed", Canvas_Zoomed'Access);
   Run ("canvas-zoom-keys", Canvas_Zoom_Keys'Access);
   Run ("canvas-pinched", Canvas_Pinched'Access);
   Run ("canvas-dragged", Canvas_Dragged'Access);
   Run ("tools-shown", Tools_Shown'Access);
   Run ("tools-item-click", Tools_Item_Click'Access);
   Run ("items-words", Item_Tests.Counting_Words'Access);
   Run ("items-stored", Item_Tests.Stored'Access);
   Run ("items-added", Item_Tests.Added'Access);
   Run ("items-typing", Item_Tests.Typing'Access);
   Run ("items-dictating", Item_Tests.Dictating'Access);
   Run ("items-dictating-empty", Item_Tests.Dictating_Into_Empty'Access);
   Run ("items-title", Item_Tests.Titling'Access);
   Run ("items-moving", Item_Tests.Moving'Access);
   Run ("items-sizing", Item_Tests.Sizing'Access);
   Run ("items-smallest", Item_Tests.Smallest'Access);
   Run ("items-minimizing", Item_Tests.Minimizing'Access);
   Run ("items-closing", Item_Tests.Closing'Access);
   Run ("items-list", Item_Tests.Listing'Access);
   Run ("items-removing", Item_Tests.Removing'Access);
   Run ("items-revealing", Item_Tests.Revealing'Access);
   Run ("items-dock-scrolling", Item_Tests.Scrolling_Dock'Access);
   Run ("items-list-scrolling", Item_Tests.Scrolling_List'Access);
   Run ("items-panning-zooming", Item_Tests.Panning_And_Zooming'Access);
   Run ("items-raising", Item_Tests.Raising'Access);
   Run ("items-repainting", Item_Tests.Repainting'Access);
   Run ("items-density", Item_Tests.Fractional_Density'Access);
   Run ("items-full", Item_Tests.Full'Access);
   Run ("items-kept", Item_Tests.Kept'Access);
   Run ("pictures-selecting", Picture_Tests.Selecting'Access);
   Run ("pictures-columns", Picture_Tests.Columns'Access);
   Run ("pictures-following", Picture_Tests.Following_The_Picture'Access);
   Run ("items-linking", Item_Tests.Linking'Access);
   Run ("items-link-editing", Item_Tests.Editing_Links'Access);
   Run ("sources-window", Item_Tests.Source_Windows'Access);
   Run ("sources-pages", Item_Tests.Source_Pages'Access);
   Run ("sources-words", Item_Tests.Source_Words'Access);
   Run ("home-empty", Home_Empty'Access);
   Run ("home-recent", Home_Recent'Access);
   Run ("home-settings", Home_Settings'Access);
   Run ("home-new-and-close", New_And_Close'Access);
   Run ("home-open-listed", Open_Listed'Access);
   Run ("home-rename", Renaming'Access);
   Run ("home-rename-cancel", Rename_Cancelled'Access);
   Run ("home-rename-enter", Rename_Entered'Access);
   Run ("home-delete", Deleting'Access);
   Run ("projects-stored", Stored'Access);
   Run ("projects-kept", Kept'Access);

   Run ("textarea-empty", Text_Area_Tests.Empty'Access);
   Run ("textarea-focused", Text_Area_Tests.Focused'Access);
   Run ("textarea-typing", Text_Area_Tests.Typing'Access);
   Run ("textarea-joining", Text_Area_Tests.Joining'Access);
   Run ("textarea-clusters", Text_Area_Tests.Clusters'Access);
   Run ("textarea-up-down", Text_Area_Tests.Up_And_Down'Access);
   Run ("textarea-end", Text_Area_Tests.Text_End'Access);
   Run ("textarea-scrolled", Text_Area_Tests.Scrolled'Access);
   Run ("textarea-clicked", Text_Area_Tests.Clicked'Access);
   Run ("textarea-escape", Text_Area_Tests.Escape'Access);
   Run ("textarea-zoomed", Text_Area_Tests.Zoomed'Access);
   Run ("textarea-select-keys", Text_Area_Tests.Selecting_Keys'Access);
   Run ("textarea-select-all", Text_Area_Tests.Select_All_And_Type'Access);
   Run ("textarea-paste", Text_Area_Tests.Copy_And_Paste'Access);
   Run ("textarea-cut-undo", Text_Area_Tests.Cut_And_Undo'Access);
   Run ("textarea-undo-typing", Text_Area_Tests.Undo_Typing'Access);
   Run ("textarea-words", Text_Area_Tests.Words'Access);
   Run ("textarea-dragged", Text_Area_Tests.Dragged'Access);
   Run ("textarea-bar", Text_Area_Tests.Scroll_Bar'Access);
   Run ("textarea-inactive-selection",
        Text_Area_Tests.Inactive_Selection'Access);
   Run ("textarea-blink", Text_Area_Tests.Blinking'Access);
   Run ("textarea-composing", Text_Area_Tests.Composing'Access);
   Run ("textarea-two-views", Text_Area_Tests.Two_Views'Access);
   Run ("textarea-long-paragraph", Text_Area_Tests.Long_Paragraph'Access);
   Run ("textarea-caret-box", Text_Area_Tests.Caret_Box_Kept'Access);

   Run ("field-typing", Field_Tests.Typing'Access);
   Run ("field-return", Field_Tests.Returning'Access);
   Run ("field-paste", Field_Tests.Pasting'Access);
   Run ("field-long", Field_Tests.Long_Line'Access);
   Run ("field-click", Field_Tests.Clicking'Access);
   Run ("field-up-down", Field_Tests.Up_And_Down'Access);

   Run ("widgets-layout", Widget_Tests.Layout'Access);
   Run ("widgets-idle", Widget_Tests.Idle'Access);
   Run ("widgets-buttons", Widget_Tests.Buttons'Access);
   Run ("widgets-focus", Widget_Tests.Focus'Access);
   Run ("widgets-damage", Widget_Tests.Damage'Access);
   Run ("widgets-retained", Widget_Tests.Retained'Access);
   Run ("widgets-resized", Widget_Tests.Resized'Access);
   Run ("widgets-walk", Widget_Tests.Tree_Walk'Access);
   Run ("widgets-caret", Widget_Tests.Caret_Only'Access);
   Run ("widgets-hiding", Widget_Tests.Hiding'Access);
   Run ("widgets-removing", Widget_Tests.Removing'Access);
   Run ("widgets-window", Widget_Tests.Window_Frame'Access);

   Ada.Text_IO.Put_Line
     (Ran'Image & " tests:" & Natural'Image (Goldens.Passed)
      & " checks passed," & Natural'Image (Goldens.Failed) & " failed");
   if Ran = 0 or else Goldens.Failed > 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Golden;
