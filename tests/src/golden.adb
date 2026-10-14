with Ada.Command_Line;
with Ada.Directories;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with SDL3.Cursors;
with SDL3.Events;
with Document_Tests;
with Downloads;
with Field_Tests;
with Goldens;
with Item_Tests;
with Picture_Tests;
with Preferences;
with Projects;
with Sheet_Tests;
with Text_Area_Tests;
with Widget_Tests;
with Viewer;
with Viewer.Canvas_Camera;
with Viewer.Home_Screen;
with Viewer.Project_Screen;
with Viewer.Settings;
with Write_Tests;

--  Draws the viewer, and a text area by itself, in various setups and
--  compares what they draw with golden images: golden [part of a test's
--  name]. See Goldens.
procedure Golden is

   package Events renames SDL3.Events;
   package Camera renames Viewer.Canvas_Camera;
   package Home renames Viewer.Home_Screen;
   package Proj renames Viewer.Project_Screen;
   package Settings renames Viewer.Settings;
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
   --  In points. The toolbar takes 44 of the height, at the top.

   Canvas_Top : constant Float := 44.0;
   --  Below the toolbar.

   Tools_Item_X : constant Float := 299.5;
   Tools_Item_Y : constant Float := 440.5;
   --  In points: the middle of Add Document, in the tray over the foot of
   --  the canvas.

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
      Home.New_Project (Item);
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
        ("canvas-mode", "CANVAS", Viewer.Modes'Image (Proj.Mode (Session)));
      --  The origin in the middle, at a zoom of 1.
      Goldens.Check_Text
        ("canvas-origin", " 360 218",
         Whole (Camera.Canvas_Origin_X (Session))
         & Whole (Camera.Canvas_Origin_Y (Session)));
      Goldens.Check_Text
        ("canvas-first-zoom", " 100", Percent (Camera.Canvas_Zoom (Session)));
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
        ("canvas-panned-origin", " 384 266",
         Whole (Camera.Canvas_Origin_X (Session))
         & Whole (Camera.Canvas_Origin_Y (Session)));
      Goldens.Check_Text
        ("canvas-panned-zoom", " 100", Percent (Camera.Canvas_Zoom (Session)));
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
        (Whole ((500.0 - Camera.Canvas_Origin_X (Session))
                / Camera.Canvas_Zoom (Session))
         & Whole ((300.0 - Canvas_Top - Camera.Canvas_Origin_Y (Session))
                  / Camera.Canvas_Zoom (Session)));
   begin
      Start (Session);
      Goldens.Check_Text ("canvas-zoom-before", " 140 38", Under_Pointer);

      --  Command with the wheel zooms about the pointer, which keeps what
      --  is under it.
      Viewer.Handle
        (Session, Wheel (0.0, 3.0, 500.0, 300.0, Command => True));
      Goldens.Check_Text
        ("canvas-zoom-in", " 133", Percent (Camera.Canvas_Zoom (Session)));
      Goldens.Check_Text ("canvas-zoom-kept", " 140 38", Under_Pointer);
      Viewer.Render (Session, Drawn);
      Goldens.Check ("canvas-zoomed-in", Drawn);

      Viewer.Handle
        (Session, Wheel (0.0, -8.0, 500.0, 300.0, Command => True));
      Goldens.Check_Text
        ("canvas-zoom-out", " 62", Percent (Camera.Canvas_Zoom (Session)));
      Goldens.Check_Text ("canvas-zoom-out-kept", " 140 38", Under_Pointer);
      Viewer.Render (Session, Drawn);
      Goldens.Check ("canvas-zoomed-out", Drawn);
   end Canvas_Zoomed;

   procedure Canvas_Zoom_Keys is
      Session : Viewer.Session;
   begin
      Start (Session);
      Press (Session, Events.Key_Equals, Times => 2, Command => True);
      Goldens.Check_Text
        ("canvas-keys-in", " 121", Percent (Camera.Canvas_Zoom (Session)));
      Press (Session, Events.Key_Minus, Times => 4, Command => True);
      Goldens.Check_Text
        ("canvas-keys-out", " 83", Percent (Camera.Canvas_Zoom (Session)));
      Press (Session, Events.Key_0, Command => True);
      Goldens.Check_Text
        ("canvas-keys-reset", " 100", Percent (Camera.Canvas_Zoom (Session)));
      --  About the middle.
      Goldens.Check_Text
        ("canvas-keys-origin", " 360 218",
         Whole (Camera.Canvas_Origin_X (Session))
         & Whole (Camera.Canvas_Origin_Y (Session)));

      --  Within limits.
      Press (Session, Events.Key_Equals, Times => 100, Command => True);
      Goldens.Check_Text
        ("canvas-keys-most", " 800", Percent (Camera.Canvas_Zoom (Session)));
      Press (Session, Events.Key_Minus, Times => 200, Command => True);
      Goldens.Check_Text
        ("canvas-keys-least", " 10", Percent (Camera.Canvas_Zoom (Session)));
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
        ("canvas-pinch-in", " 150", Percent (Camera.Canvas_Zoom (Session)));
      Viewer.Handle
        (Session,
         (Kind => Events.Pinch, Scale => 0.5, Mouse_X => 360.0,
          Mouse_Y => 208.0, others => <>));
      Goldens.Check_Text
        ("canvas-pinch-out", " 75", Percent (Camera.Canvas_Zoom (Session)));
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
        ("canvas-left-drag", " 360 218",
         Whole (Camera.Canvas_Origin_X (Session))
         & Whole (Camera.Canvas_Origin_Y (Session)));

      --  The middle button does, with the move cursor while it does.
      Viewer.Handle (Session, Press_Button (2, 300.0, 200.0));
      Goldens.Check_Text ("canvas-cursor-panning", "MOVE", Cursor);
      Viewer.Handle (Session, Pointer_At (340.0, 230.0));
      Viewer.Handle (Session, Pointer_At (350.0, 210.0));
      Goldens.Check_Text
        ("canvas-middle-drag", " 410 228",
         Whole (Camera.Canvas_Origin_X (Session))
         & Whole (Camera.Canvas_Origin_Y (Session)));
      Goldens.Check_Text ("canvas-cursor-still-panning", "MOVE", Cursor);
      Viewer.Render (Session, Drawn);
      Goldens.Check ("canvas-middle-dragged", Drawn);
      Viewer.Handle (Session, Release_Button (2, 350.0, 210.0));
      Goldens.Check_Text ("canvas-cursor-let-go", "DEFAULT", Cursor);

      --  Let go, it follows the pointer no more.
      Viewer.Handle (Session, Pointer_At (400.0, 300.0));
      Goldens.Check_Text
        ("canvas-after-drag", " 410 228",
         Whole (Camera.Canvas_Origin_X (Session))
         & Whole (Camera.Canvas_Origin_Y (Session)));
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

   --  The home screen is tested in a window Home_Width wide and
   --  Home_Height high, as a window opens: room for two columns of cards.
   Home_Width  : constant := 1000;
   Home_Height : constant := 800;

   --  Where the buttons are, in points: in the sidebar at the left of the
   --  home screen, and at the left of the toolbar of a project.
   Actions_X : constant Float := 109.0;
   New_Y     : constant Float := 103.0;
   Settings_Y : constant Float := Float (Home_Height) - 37.0;
   Close_X   : constant Float := 58.0;
   Close_Y   : constant Float := 22.0;

   function Card_Left (Row : Positive) return Float is
     (263.0 + Float ((Row - 1) mod 2) * 352.0);
   function Card_Top (Row : Positive) return Float is
     (85.0 + Float ((Row - 1) / 2) * 234.0);
   --  Of a project's card, in points: two to a row, below the title.

   function Open_X (Row : Positive) return Float is (Card_Left (Row) + 165.0);
   function Open_Y (Row : Positive) return Float is (Card_Top (Row) + 70.0);
   --  The middle of the picture of its canvas, which opens it.

   function Info_Y (Row : Positive) return Float is (Card_Top (Row) + 173.5);
   function Rename_X (Row : Positive) return Float is
     (Card_Left (Row) + 257.5);
   function Delete_X (Row : Positive) return Float is
     (Card_Left (Row) + 296.5);
   function Ok_X (Row : Positive) return Float is (Card_Left (Row) + 216.0);
   function Cancel_X (Row : Positive) return Float is
     (Card_Left (Row) + 280.0);
   --  Of the buttons below the picture, and of the field's in their place.

   procedure Move_Away (Item : in out Viewer.Session) is
   begin
      Viewer.Handle (Item, Events.Event'(Kind => Events.Mouse_Move,
                                         Mouse_X => 1.0, Mouse_Y => 1.0,
                                         others => <>));
   end Move_Away;

   procedure With_Three (Session : in out Viewer.Session) is
   begin
      Viewer.Open (Session, "", Home_Width, Home_Height);
      for I in 1 .. 3 loop
         Home.Add_Project
           (Session, "Episode" & Natural'Image (I), Hour * Long_Integer (I));
      end loop;
   end With_Three;

   procedure Renaming is
      Session : Viewer.Session;
      Drawn   : Images.Image;
   begin
      With_Three (Session);
      Click_On (Session, Rename_X (2), Info_Y (2));
      Goldens.Check_Text
        ("rename-started", "TRUE",
         Boolean'Image (Home.Is_Renaming (Session)));
      Viewer.Render (Session, Drawn);
      Goldens.Check ("rename-field", Drawn);

      --  The title is selected, to type over.
      Viewer.Handle (Session, Events.Text_Event ("Renamed"));
      Viewer.Render (Session, Drawn);
      Goldens.Check ("rename-typed", Drawn);
      Click_On (Session, Ok_X (2), Info_Y (2));
      Goldens.Check_Text
        ("rename-done", "FALSE",
         Boolean'Image (Home.Is_Renaming (Session)));
      Goldens.Check_Text ("rename-first", "Renamed",
                          Home.Row_Title (Session, 1));
      Goldens.Check_Text ("rename-second", "Episode 3",
                          Home.Row_Title (Session, 2));
      Goldens.Check_Text ("rename-third", "Episode 1",
                          Home.Row_Title (Session, 3));
      Move_Away (Session);
      Viewer.Render (Session, Drawn);
      Goldens.Check ("rename-list", Drawn);

      --  Clicking the project's button opens that project.
      Click_On (Session, Open_X (1), Open_Y (1));
      Goldens.Check_Text
        ("rename-opened", "PROJECT",
         Viewer.Screens'Image (Viewer.Screen (Session)));
      --  Its title is on the toolbar.
      Viewer.Render (Session, Drawn);
      Goldens.Check ("project-title", Drawn);
   end Renaming;

   --  The dialog to confirm a deletion, in a window Home_Width wide and
   --  Home_Height high: in the middle.
   Dialog_Delete_X : constant Float := 584.0;
   Dialog_Cancel_X : constant Float := 480.0;
   Dialog_Buttons_Y : constant Float := 452.5;

   procedure Deleting is
      Session : Viewer.Session;
      Drawn   : Images.Image;
   begin
      With_Three (Session);
      Click_On (Session, Delete_X (2), Info_Y (2));
      Goldens.Check_Text
        ("delete-asks", "TRUE",
         Boolean'Image (Home.Is_Confirming (Session)));
      Viewer.Render (Session, Drawn);
      Goldens.Check ("delete-dialog", Drawn);

      --  The screen behind takes no clicks, nor keys.
      Click_On (Session, Open_X (1), Open_Y (1));
      Goldens.Check_Text
        ("delete-modal-screen", "HOME",
         Viewer.Screens'Image (Viewer.Screen (Session)));
      Click_On (Session, Delete_X (3), Info_Y (3));
      Goldens.Check_Text
        ("delete-modal-same", "TRUE",
         Boolean'Image (Home.Is_Confirming (Session)));

      --  Cancel keeps it.
      Click_On (Session, Dialog_Cancel_X, Dialog_Buttons_Y);
      Goldens.Check_Text
        ("delete-cancelled", "FALSE",
         Boolean'Image (Home.Is_Confirming (Session)));
      Goldens.Check_Text ("delete-cancelled-title", "Episode 2",
                          Home.Row_Title (Session, 2));
      Move_Away (Session);
      Viewer.Render (Session, Drawn);
      Goldens.Check ("delete-after-cancel", Drawn);

      --  So does Escape.
      Click_On (Session, Delete_X (2), Info_Y (2));
      Viewer.Handle (Session, Key (Events.Key_Escape));
      Goldens.Check_Text
        ("delete-escaped", "FALSE",
         Boolean'Image (Home.Is_Confirming (Session)));
      Goldens.Check_Text ("delete-escaped-title", "Episode 2",
                          Home.Row_Title (Session, 2));

      --  Delete removes it.
      Click_On (Session, Delete_X (2), Info_Y (2));
      Click_On (Session, Dialog_Delete_X, Dialog_Buttons_Y);
      Goldens.Check_Text
        ("delete-done", "FALSE",
         Boolean'Image (Home.Is_Confirming (Session)));
      Goldens.Check_Text ("delete-first", "Episode 3",
                          Home.Row_Title (Session, 1));
      Goldens.Check_Text ("delete-second", "Episode 1",
                          Home.Row_Title (Session, 2));
      Goldens.Check_Text ("delete-third", "", Home.Row_Title (Session, 3));
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
      Click_On (Session, Rename_X (1), Info_Y (1));
      Viewer.Handle (Session, Events.Text_Event ("Nope"));
      Click_On (Session, Cancel_X (1), Info_Y (1));
      Goldens.Check_Text
        ("cancel-renaming", "FALSE",
         Boolean'Image (Home.Is_Renaming (Session)));
      Goldens.Check_Text ("cancel-title", "Episode 3",
                          Home.Row_Title (Session, 1));
      Move_Away (Session);
      Viewer.Render (Session, After);
      Goldens.Check_Same ("cancel-same", Before, After);

      --  Another renamed after, and the first is not.
      Click_On (Session, Rename_X (1), Info_Y (1));
      Click_On (Session, Rename_X (3), Info_Y (3));
      Goldens.Check_Text
        ("cancel-other", "TRUE",
         Boolean'Image (Home.Is_Renaming (Session)));
      Viewer.Render (Session, After);
      Goldens.Check ("rename-other-row", After);
   end Rename_Cancelled;

   procedure Rename_Entered is
      Session : Viewer.Session;
   begin
      --  Return accepts, as OK does.
      With_Three (Session);
      Click_On (Session, Rename_X (3), Info_Y (3));
      Viewer.Handle (Session, Events.Text_Event ("  Pilot  "));
      Viewer.Handle (Session, Key (Events.Key_Return));
      Goldens.Check_Text ("enter-renaming", "FALSE",
                          Boolean'Image (Home.Is_Renaming (Session)));
      Goldens.Check_Text ("enter-title", "Pilot",
                          Home.Row_Title (Session, 1));

      --  Nothing is not a title.
      Click_On (Session, Rename_X (1), Info_Y (1));
      Viewer.Handle (Session, Key (Events.Key_Backspace));
      Click_On (Session, Ok_X (1), Info_Y (1));
      Goldens.Check_Text ("empty-renaming", "TRUE",
                          Boolean'Image (Home.Is_Renaming (Session)));
      Goldens.Check_Text ("empty-title", "Pilot",
                          Home.Row_Title (Session, 1));

      --  Opening another project, or leaving, stops it.
      Click_On (Session, Actions_X, New_Y);
      Click_On (Session, Close_X, Close_Y);
      Goldens.Check_Text ("left-renaming", "FALSE",
                          Boolean'Image (Home.Is_Renaming (Session)));
   end Rename_Entered;

   procedure Home_Empty is
      Session : Viewer.Session;
      Drawn   : Images.Image;
   begin
      Viewer.Open (Session, "", Home_Width, Home_Height);
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
      Viewer.Open (Session, "", Home_Width, Home_Height);
      for I in 1 .. 7 loop
         Home.Add_Project
           (Session, "Episode" & Natural'Image (I), Hour * Long_Integer (I));
      end loop;
      Viewer.Render (Session, Drawn);
      Goldens.Check ("home-recent", Drawn);
   end Home_Recent;

   --  The settings, in the same window: Close is at the right of the bar
   --  across the top, and the radios of Speech's Model are in the form,
   --  which is as wide as a page in the writing view.
   Settings_Close_X : constant Float := Float (Home_Width) - 52.0;
   Settings_Close_Y : constant Float := 22.0;
   Model_X          : constant Float := 160.0;
   --  Display's radios come first in the form, then Speech's, which is
   --  set apart from them by Heading_Top.
   Light_Y          : constant Float := 189.0;
   Dark_Y           : constant Float := 225.0;
   System_Y         : constant Float := 261.0;
   Native_Y         : constant Float := 377.0;
   Parakeet_Y       : constant Float := 413.0;

   procedure Home_Settings is
      use type Preferences.Speech_Models;
      use type Preferences.Theme_Choices;
      Session : Viewer.Session;
      Drawn   : Images.Image;
   begin
      Viewer.Open (Session, "", Home_Width, Home_Height);
      Click_On (Session, Actions_X, Settings_Y);
      Goldens.Check_Text
        ("settings-open", "TRUE",
         Boolean'Image (Settings.Is_Settings_Open (Session)));
      Goldens.Check_Text
        ("settings-stays-home", "HOME",
         Viewer.Screens'Image (Viewer.Screen (Session)));
      Viewer.Render (Session, Drawn);
      Goldens.Check ("settings-macos", Drawn);

      --  Dark draws the whole window in the dark theme, and Light goes
      --  back to it.
      Click_On (Session, Model_X, Dark_Y);
      Goldens.Check_Text
        ("settings-dark-chosen", "TRUE",
         Boolean'Image (Settings.Theme_Choice (Session) = Preferences.Dark
                        and then Settings.Is_Dark (Session)));
      Viewer.Render (Session, Drawn);
      Goldens.Check ("settings-dark", Drawn);

      Click_On (Session, Model_X, Light_Y);
      Goldens.Check_Text
        ("settings-light-chosen", "TRUE",
         Boolean'Image (Settings.Theme_Choice (Session) = Preferences.Light
                        and then not Settings.Is_Dark (Session)));

      --  System follows the machine, which is not drawn here: Light again.
      Click_On (Session, Model_X, System_Y);
      Goldens.Check_Text
        ("settings-system-chosen", "TRUE",
         Boolean'Image (Settings.Theme_Choice (Session) = Preferences.System));
      Click_On (Session, Model_X, Light_Y);

      --  Parakeet's file is to be fetched, if it is not there.
      Click_On (Session, Model_X, Parakeet_Y);
      Goldens.Check_Text
        ("settings-parakeet-chosen", "TRUE",
         Boolean'Image
           (Settings.Speech_Model (Session) = Preferences.Parakeet));
      Viewer.Render (Session, Drawn);
      Goldens.Check ("settings-parakeet", Drawn);

      Click_On (Session, Model_X, Native_Y);
      Goldens.Check_Text
        ("settings-macos-chosen", "TRUE",
         Boolean'Image (Settings.Speech_Model (Session) = Preferences.MacOS));

      --  Escape and Close both leave.
      Viewer.Handle (Session, Key (Events.Key_Escape));
      Goldens.Check_Text
        ("settings-escaped", "FALSE",
         Boolean'Image (Settings.Is_Settings_Open (Session)));
      Click_On (Session, Actions_X, Settings_Y);
      Click_On (Session, Settings_Close_X, Settings_Close_Y);
      Goldens.Check_Text
        ("settings-closed", "FALSE",
         Boolean'Image (Settings.Is_Settings_Open (Session)));
   end Home_Settings;

   procedure Fetching is
      use type Downloads.States;
      Folder : constant String := "/tmp/bonxie-download-test";
      Source : constant String := Folder & "/source.bin";
      Target : constant String := Folder & "/made/here/model.gguf";
      Bytes  : constant := 3_000_000;

      procedure Wait is
      begin
         for Try in 1 .. 200 loop
            exit when Downloads.State /= Downloads.Running;
            delay 0.05;
         end loop;
      end Wait;
   begin
      if Ada.Directories.Exists (Folder) then
         Ada.Directories.Delete_Tree (Folder);
      end if;
      Ada.Directories.Create_Path (Folder);
      declare
         File : Ada.Streams.Stream_IO.File_Type;
         Data : constant Ada.Streams.Stream_Element_Array (1 .. Bytes) :=
           [others => 7];
      begin
         Ada.Streams.Stream_IO.Create
           (File, Ada.Streams.Stream_IO.Out_File, Source);
         Ada.Streams.Stream_IO.Write (File, Data);
         Ada.Streams.Stream_IO.Close (File);
      end;

      Goldens.Check_Text
        ("downloads-idle", "IDLE", Downloads.States'Image (Downloads.State));
      Downloads.Start ("file://" & Source, Target);
      Goldens.Check_Text
        ("downloads-started", "TRUE",
         Boolean'Image (Downloads.State = Downloads.Running));
      Wait;
      Goldens.Check_Text
        ("downloads-done", "DONE",
         Downloads.States'Image (Downloads.State));
      Goldens.Check_Text
        ("downloads-fraction", "TRUE",
         Boolean'Image (Downloads.Fraction = 1.0));
      Goldens.Check_Text
        ("downloads-size", Integer'Image (Bytes),
         Ada.Directories.File_Size'Image (Ada.Directories.Size (Target)));
      Goldens.Check_Text
        ("downloads-no-part", "FALSE",
         Boolean'Image (Ada.Directories.Exists (Target & ".part")));

      Downloads.Reset;
      Downloads.Start ("file://" & Folder & "/nothing.bin", Target & "2");
      Wait;
      Goldens.Check_Text
        ("downloads-failed", "FAILED",
         Downloads.States'Image (Downloads.State));
      Goldens.Check_Text
        ("downloads-failed-leaves-nothing", "FALSE",
         Boolean'Image (Ada.Directories.Exists (Target & "2")));
      Downloads.Reset;
      Ada.Directories.Delete_Tree (Folder);
   end Fetching;

   --  The dark theme over the home screen, and a new project's screen.
   procedure Dark_Screens is
      Session : Viewer.Session;
      Drawn   : Images.Image;
   begin
      Viewer.Open (Session, "Bonxie", Home_Width, Home_Height);
      Home.Add_Project (Session, "Episode 1", Hour);
      Settings.Choose_Theme (Session, Preferences.Dark);
      Viewer.Render (Session, Drawn);
      Goldens.Check ("home-dark", Drawn);

      Click_On (Session, Actions_X, New_Y);
      Viewer.Render (Session, Drawn);
      Goldens.Check ("project-dark", Drawn);
   end Dark_Screens;

   --  The choices are kept in one file, each on its own line, so that
   --  saving one keeps the others.
   procedure Preferences_Kept is
      Config : constant String := "/tmp/bonxie-preferences-test";
      use type Preferences.Speech_Models;
      use type Preferences.Theme_Choices;
   begin
      if Ada.Directories.Exists (Config) then
         Ada.Directories.Delete_Tree (Config);
      end if;
      Goldens.Check_Text
        ("preferences-none", "SYSTEM",
         Preferences.Theme_Choices'Image (Preferences.Load_Theme (Config)));

      Preferences.Save_Speech_Model (Config, Preferences.Parakeet);
      Preferences.Save_Theme (Config, Preferences.Dark);
      Goldens.Check_Text
        ("preferences-dark-kept", "TRUE",
         Boolean'Image (Preferences.Load_Theme (Config) = Preferences.Dark
                        and then Preferences.Load_Speech_Model (Config)
                                 = Preferences.Parakeet));

      Preferences.Save_Speech_Model (Config, Preferences.MacOS);
      Goldens.Check_Text
        ("preferences-speech-kept", "TRUE",
         Boolean'Image (Preferences.Load_Theme (Config) = Preferences.Dark
                        and then Preferences.Load_Speech_Model (Config)
                                 = Preferences.MacOS));

      Preferences.Save_Theme (Config, Preferences.System);
      Goldens.Check_Text
        ("preferences-system-kept", "TRUE",
         Boolean'Image (Preferences.Load_Theme (Config) = Preferences.System
                        and then Preferences.Load_Speech_Model (Config)
                                 = Preferences.MacOS));
      Ada.Directories.Delete_Tree (Config);
   end Preferences_Kept;

   procedure New_And_Close is
      Session : Viewer.Session;
      Drawn   : Images.Image;
   begin
      Viewer.Open (Session, "Bonxie", Home_Width, Home_Height);
      Home.Add_Project (Session, "Episode 1", Hour);
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
      Viewer.Open (Session, "", Home_Width, Home_Height);
      for I in 1 .. 3 loop
         Home.Add_Project
           (Session, "Episode" & Natural'Image (I), Hour * Long_Integer (I));
      end loop;
      Click_On (Session, Open_X (2), Open_Y (2));
      Goldens.Check_Text
        ("listed-screen", "PROJECT",
         Viewer.Screens'Image (Viewer.Screen (Session)));
      Goldens.Check_Text
        ("listed-project", "2",
         Projects.Id'Image (Proj.Current_Project (Session))
           (2 .. Projects.Id'Image (Proj.Current_Project (Session))'Last));

      Click_On (Session, Close_X, Close_Y);
      Goldens.Check_Text
        ("listed-closed", "HOME",
         Viewer.Screens'Image (Viewer.Screen (Session)));
      --  A new project is a project of its own.
      Click_On (Session, Actions_X, New_Y);
      Goldens.Check_Text
        ("listed-new-project", "4",
         Projects.Id'Image (Proj.Current_Project (Session))
           (2 .. Projects.Id'Image (Proj.Current_Project (Session))'Last));
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
   Run ("items-dictating-live", Item_Tests.Dictating_Live'Access);
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
   Run ("write-pages", Write_Tests.Pages'Access);
   Run ("write-ordering", Write_Tests.Ordering'Access);
   Run ("write-dragging", Write_Tests.Dragging'Access);
   Run ("write-directories", Write_Tests.Directories'Access);
   Run ("write-context-menus", Write_Tests.Context_Menus'Access);
   Run ("write-context-elsewhere",
        Write_Tests.Context_Menus_Elsewhere'Access);
   Run ("write-context-on-canvas",
        Write_Tests.Context_Menus_On_Canvas'Access);
   Run ("write-adding", Write_Tests.Adding'Access);
   Run ("write-linked-sources", Write_Tests.Linked_Sources'Access);
   Run ("write-typing", Write_Tests.Typing'Access);
   Run ("write-sources", Write_Tests.Sources'Access);
   Run ("write-marks", Write_Tests.Sharing_Marks'Access);
   Run ("home-empty", Home_Empty'Access);
   Run ("home-recent", Home_Recent'Access);
   Run ("home-settings", Home_Settings'Access);
   Run ("home-dark", Dark_Screens'Access);
   Run ("preferences-kept", Preferences_Kept'Access);
   Run ("downloads-fetching", Fetching'Access);
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
   Run ("sheet-board", Sheet_Tests.Board'Access);
   Run ("sheet-states", Sheet_Tests.States'Access);
   Run ("sheet-behaviour", Sheet_Tests.Behaviour'Access);

   Ada.Text_IO.Put_Line
     (Ran'Image & " tests:" & Natural'Image (Goldens.Passed)
      & " checks passed," & Natural'Image (Goldens.Failed) & " failed");
   if Ran = 0 or else Goldens.Failed > 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Golden;
