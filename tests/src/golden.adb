with Adaptive_Themes;
with Backgrounds;
with Ada.Characters.Handling;
with Ada.Command_Line;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with SDL3.Cursors;
with Pomarine.Events;
with SDL3.Windows.Renderers;
with Downloads;
with Files;
with Gestures; use Gestures;
with Goldens;
with Item_Tests;
with Layout_Tests;
with Outline_Tests;
with Pomarine.Themes;
with Preferences;
with Grammar_VM_Tests;
with Home_Tests;
with Home_VM_Tests;
with Outline_Screen_Tests;
with Canvas_VM_Tests;
with Item_List_VM_Tests;
with Search_VM_Tests;
with Writing_VM_Tests;
with Editor_VM_Tests;
with Export_Tests;
with Item_Model_Tests;
with Item_Control_VM_Tests;
with Reader_Binding_Tests;
with Nav_Tests;
with Browser_VM_Tests;
with Site_Filter_Tests;
with Nav_VM_Tests;
with Outline_VM_Tests;
with Settings_Tests;
with Settings_VM_Tests;
with Update_VM_Tests;
with Projects;
with Speech.Jobs;
with View;
with View.Canvas_Camera;
with View.Home_Screen;
with View.Project_Screen;
with View.Settings;
with Write_Tests;
with Grammar_Tests;

--  Draws the viewer, and a text area by itself, in various setups and
--  compares what they draw with golden images: golden [part of a test's
--  name]. See Goldens.

procedure Golden is

   package Events renames Pomarine.Events;
   package Camera renames View.Canvas_Camera;
   package Home renames View.Home_Screen;
   package Proj renames View.Project_Screen;
   package Settings renames View.Settings;
   package Images renames Goldens.Images;

   Filter : constant String := (if Ada.Command_Line.Argument_Count > 0 then Ada.Command_Line.Argument (1) else "");

   --  Events

   function Key (Code : Events.Key_Code; Command : Boolean := False) return Events.Event
   is ((Kind => Events.Key_Down, Key => Code, Command => Command, others => <>));

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

   function Wheel (Across, Down : Float; X, Y : Float; Command : Boolean := False) return Events.Event
   is ((Kind    => Events.Mouse_Wheel,
        Wheel_X => Across,
        Wheel_Y => Down,
        Mouse_X => X,
        Mouse_Y => Y,
        Command => Command,
        others  => <>));

   function Click (X, Y : Float) return Events.Event
   is ((Kind => Events.Mouse_Down, Button => 1, Clicks => 1, Mouse_X => X, Mouse_Y => Y, others => <>));
   --  At X, Y points.

   function Pointer_At (X, Y : Float; Held : Boolean := False) return Events.Event
   is ((Kind => Events.Mouse_Move, Mouse_X => X, Mouse_Y => Y, Left_Held => Held, others => <>));

   function Press_Button (Which : Natural; X, Y : Float) return Events.Event
   is ((Kind => Events.Mouse_Down, Button => Which, Clicks => 1, Mouse_X => X, Mouse_Y => Y, others => <>));

   function Release_Button (Which : Natural; X, Y : Float) return Events.Event
   is ((Kind => Events.Mouse_Up, Button => Which, Clicks => 1, Mouse_X => X, Mouse_Y => Y, others => <>));

   function Whole (Value : Float) return String
   is (Integer'Image (Integer (Float'Rounding (Value))));
   --  To the nearest whole number, to compare as text.

   function Percent (Value : Float) return String
   is (Whole (Value * 100.0));

   procedure Press
     (Item : in out View.Session; Code : Events.Key_Code; Times : Positive := 1; Command : Boolean := False) is
   begin
      for K in 1 .. Times loop
         View.Handle (Item, Key (Code, Command));
      end loop;
   end Press;

   procedure Start
     (Item    : in out View.Session;
      Width   : Positive := Default_Width;
      Height  : Positive := Default_Height;
      Density : Float := 2.0) is
   begin
      View.Open (Item, "", Width, Height, Density);
      Home.New_Project (Item);
      View.Project_Screen.Set_Mode (Item, View.Canvas);
   end Start;
   --  A project, at its canvas.

   procedure Show
     (Name : String; Width : Positive := Default_Width; Height : Positive := Default_Height; Density : Float := 2.0)
   is
      Session : View.Session;
      Drawn   : Images.Image;
   begin
      Start (Session, Width, Height, Density);
      View.Render (Session, Drawn);
      Goldens.Check (Name, Drawn);
   end Show;

   --  The canvas

   procedure Canvas_Starts is
      Session : View.Session;
      Drawn   : Images.Image;
   begin
      Start (Session);
      View.Render (Session, Drawn);
      Goldens.Check ("canvas", Drawn);
      Goldens.Check_Text ("canvas-mode", "CANVAS", View.Modes'Image (Proj.Mode (Session)));
      --  The origin in the middle, at a zoom of 1.
      Goldens.Check_Text
        ("canvas-origin",
         " 360 218",
         Whole (Camera.Canvas_Origin_X (Session)) & Whole (Camera.Canvas_Origin_Y (Session)));
      Goldens.Check_Text ("canvas-first-zoom", " 100", Percent (Camera.Canvas_Zoom (Session)));
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
      Session : View.Session;
      Drawn   : Images.Image;
   begin
      Start (Session);
      View.Render (Session, Drawn);
      View.Resize (Session, 400, 600);
      View.Render (Session, Drawn);
      Goldens.Check ("canvas-resized", Drawn);
   end Canvas_Resized;

   procedure Canvas_Panned is
      Session : View.Session;
      Drawn   : Images.Image;
   begin
      --  The wheel, or two fingers on a trackpad, pans by 24 points a
      --  notch: down by Y, and left by X.
      Start (Session);
      View.Handle (Session, Wheel (-1.0, 2.0, 400.0, 300.0));
      Goldens.Check_Text
        ("canvas-panned-origin",
         " 384 266",
         Whole (Camera.Canvas_Origin_X (Session)) & Whole (Camera.Canvas_Origin_Y (Session)));
      Goldens.Check_Text ("canvas-panned-zoom", " 100", Percent (Camera.Canvas_Zoom (Session)));
      View.Render (Session, Drawn);
      Goldens.Check ("canvas-panned", Drawn);

      --  As far as it goes.
      View.Handle (Session, Wheel (0.0, -1000.0, 400.0, 300.0));
      View.Render (Session, Drawn);
      Goldens.Check ("canvas-panned-far", Drawn);
   end Canvas_Panned;

   procedure Canvas_Zoomed is
      Session : View.Session;
      Drawn   : Images.Image;

      function Under_Pointer return String
      is (Whole ((500.0 - Camera.Canvas_Origin_X (Session)) / Camera.Canvas_Zoom (Session))
          & Whole ((300.0 - Canvas_Top - Camera.Canvas_Origin_Y (Session)) / Camera.Canvas_Zoom (Session)));
   begin
      Start (Session);
      Goldens.Check_Text ("canvas-zoom-before", " 140 38", Under_Pointer);

      --  Command with the wheel zooms about the pointer, which keeps what
      --  is under it.
      View.Handle (Session, Wheel (0.0, 3.0, 500.0, 300.0, Command => True));
      Goldens.Check_Text ("canvas-zoom-in", " 133", Percent (Camera.Canvas_Zoom (Session)));
      Goldens.Check_Text ("canvas-zoom-kept", " 140 38", Under_Pointer);
      View.Render (Session, Drawn);
      Goldens.Check ("canvas-zoomed-in", Drawn);

      View.Handle (Session, Wheel (0.0, -8.0, 500.0, 300.0, Command => True));
      Goldens.Check_Text ("canvas-zoom-out", " 62", Percent (Camera.Canvas_Zoom (Session)));
      Goldens.Check_Text ("canvas-zoom-out-kept", " 140 38", Under_Pointer);
      View.Render (Session, Drawn);
      Goldens.Check ("canvas-zoomed-out", Drawn);
   end Canvas_Zoomed;

   procedure Canvas_Zoom_Keys is
      Session : View.Session;
   begin
      Start (Session);
      Press (Session, Events.Key_Equals, Times => 2, Command => True);
      Goldens.Check_Text ("canvas-keys-in", " 121", Percent (Camera.Canvas_Zoom (Session)));
      Press (Session, Events.Key_Minus, Times => 4, Command => True);
      Goldens.Check_Text ("canvas-keys-out", " 83", Percent (Camera.Canvas_Zoom (Session)));
      Press (Session, Events.Key_0, Command => True);
      Goldens.Check_Text ("canvas-keys-reset", " 100", Percent (Camera.Canvas_Zoom (Session)));
      --  About the middle.
      Goldens.Check_Text
        ("canvas-keys-origin",
         " 360 218",
         Whole (Camera.Canvas_Origin_X (Session)) & Whole (Camera.Canvas_Origin_Y (Session)));

      --  Within limits.
      Press (Session, Events.Key_Equals, Times => 100, Command => True);
      Goldens.Check_Text ("canvas-keys-most", " 800", Percent (Camera.Canvas_Zoom (Session)));
      Press (Session, Events.Key_Minus, Times => 200, Command => True);
      Goldens.Check_Text ("canvas-keys-least", " 10", Percent (Camera.Canvas_Zoom (Session)));
   end Canvas_Zoom_Keys;

   procedure Canvas_Pinched is
      Session : View.Session;
   begin
      Start (Session);
      View.Handle (Session, (Kind => Events.Pinch, Scale => 1.5, Mouse_X => 360.0, Mouse_Y => 208.0, others => <>));
      Goldens.Check_Text ("canvas-pinch-in", " 150", Percent (Camera.Canvas_Zoom (Session)));
      View.Handle (Session, (Kind => Events.Pinch, Scale => 0.5, Mouse_X => 360.0, Mouse_Y => 208.0, others => <>));
      Goldens.Check_Text ("canvas-pinch-out", " 75", Percent (Camera.Canvas_Zoom (Session)));
   end Canvas_Pinched;

   procedure Canvas_Dragged is
      Session : View.Session;
      Drawn   : Images.Image;

      function Cursor return String
      is (SDL3.Cursors.Kind'Image (View.Cursor (Session)));
   begin
      Start (Session);
      View.Handle (Session, Pointer_At (300.0, 200.0));
      Goldens.Check_Text ("canvas-cursor-idle", "DEFAULT", Cursor);

      --  The left button does not pan.
      View.Handle (Session, Click (300.0, 200.0));
      View.Handle (Session, Pointer_At (340.0, 230.0, Held => True));
      View.Handle (Session, Release_Button (1, 340.0, 230.0));
      Goldens.Check_Text
        ("canvas-left-drag",
         " 360 218",
         Whole (Camera.Canvas_Origin_X (Session)) & Whole (Camera.Canvas_Origin_Y (Session)));

      --  The middle button does, with the move cursor while it does.
      View.Handle (Session, Press_Button (2, 300.0, 200.0));
      Goldens.Check_Text ("canvas-cursor-panning", "MOVE", Cursor);
      View.Handle (Session, Pointer_At (340.0, 230.0));
      View.Handle (Session, Pointer_At (350.0, 210.0));
      Goldens.Check_Text
        ("canvas-middle-drag",
         " 410 228",
         Whole (Camera.Canvas_Origin_X (Session)) & Whole (Camera.Canvas_Origin_Y (Session)));
      Goldens.Check_Text ("canvas-cursor-still-panning", "MOVE", Cursor);
      View.Render (Session, Drawn);
      Goldens.Check ("canvas-middle-dragged", Drawn);
      View.Handle (Session, Release_Button (2, 350.0, 210.0));
      Goldens.Check_Text ("canvas-cursor-let-go", "DEFAULT", Cursor);

      --  Let go, it follows the pointer no more.
      View.Handle (Session, Pointer_At (400.0, 300.0));
      Goldens.Check_Text
        ("canvas-after-drag",
         " 410 228",
         Whole (Camera.Canvas_Origin_X (Session)) & Whole (Camera.Canvas_Origin_Y (Session)));
   end Canvas_Dragged;

   --  The tools bar

   procedure Tools_Shown is
      Session : View.Session;
      Hovered : Images.Image;
   begin
      Start (Session);
      View.Handle (Session, Pointer_At (Tools_Item_X, Tools_Item_Y));
      View.Render (Session, Hovered);
      Goldens.Check ("tools-item-hovered", Hovered);
   end Tools_Shown;

   procedure Tools_Item_Click is
      Session : View.Session;
   begin
      --  A click on the item does nothing yet.
      Start (Session);
      View.Handle (Session, Pointer_At (Tools_Item_X, Tools_Item_Y));
      View.Handle (Session, Click (Tools_Item_X, Tools_Item_Y));
      View.Handle (Session, Release_Button (1, Tools_Item_X, Tools_Item_Y));
      Goldens.Check_Text ("tools-item-clicked", "PROJECT", View.Screens'Image (View.Screen (Session)));
      Goldens.Check_Text ("tools-item-cursor", "POINTER", SDL3.Cursors.Kind'Image (View.Cursor (Session)));
   end Tools_Item_Click;

   --  The screens

   Hour : constant := 3600;

   function Titles (Item : Projects.Recent_List) return String is
      Result : String (1 .. 1024);
      Last   : Natural := 0;
   begin
      for I in 1 .. Item.Count loop
         declare
            Name : constant String := Projects.Titles.To_String (Item.Items (I).Title) & ",";
         begin
            Result (Last + 1 .. Last + Name'Length) := Name;
            Last := Last + Name'Length;
         end;
      end loop;
      return Result (1 .. Last);
   end Titles;

   --  The home screen is tested in a window Home_Width wide and
   --  Home_Height high, as a window opens: room for two columns of cards.
   Home_Width  : constant := 1000;
   Home_Height : constant := 800;

   --  Where the buttons are, in points: in the sidebar at the left of the
   --  home screen, and at the left of the toolbar of a project.
   Actions_X  : constant Float := 109.0;
   New_Y      : constant Float := 103.0;
   Settings_Y : constant Float := Float (Home_Height) - 37.0;
   Close_X    : constant Float := 58.0;
   Close_Y    : constant Float := 22.0;

   function Card_Left (Row : Positive) return Float
   is (263.0 + Float ((Row - 1) mod 2) * 352.0);
   function Card_Top (Row : Positive) return Float
   is (85.0 + Float ((Row - 1) / 2) * 234.0);
   --  Of a project's card, in points: two to a row, below the title.

   function Open_X (Row : Positive) return Float
   is (Card_Left (Row) + 165.0);
   function Open_Y (Row : Positive) return Float
   is (Card_Top (Row) + 70.0);
   --  The middle of the picture of its canvas, which opens it.

   function Info_Y (Row : Positive) return Float
   is (Card_Top (Row) + 173.5);
   function Rename_X (Row : Positive) return Float
   is (Card_Left (Row) + 257.5);
   function Delete_X (Row : Positive) return Float
   is (Card_Left (Row) + 296.5);
   function Ok_X (Row : Positive) return Float
   is (Card_Left (Row) + 216.0);
   function Cancel_X (Row : Positive) return Float
   is (Card_Left (Row) + 280.0);
   --  Of the buttons below the picture, and of the field's in their place.

   procedure Move_Away (Item : in out View.Session) is
   begin
      View.Handle (Item, Events.Event'(Kind => Events.Mouse_Move, Mouse_X => 1.0, Mouse_Y => 1.0, others => <>));
   end Move_Away;

   procedure With_Three (Session : in out View.Session) is
   begin
      View.Open (Session, "", Home_Width, Home_Height);
      for I in 1 .. 3 loop
         Home.Add_Project (Session, "Episode" & Natural'Image (I), Hour * Long_Integer (I));
      end loop;
   end With_Three;

   procedure Renaming is
      Session : View.Session;
      Drawn   : Images.Image;
   begin
      With_Three (Session);
      Click_On (Session, Rename_X (2), Info_Y (2));
      Goldens.Check_Text ("rename-started", "TRUE", Boolean'Image (Home.Is_Renaming (Session)));
      View.Render (Session, Drawn);
      Goldens.Check ("rename-field", Drawn);

      --  The title is selected, to type over.
      View.Handle (Session, Events.Text_Event ("Renamed"));
      View.Render (Session, Drawn);
      Goldens.Check ("rename-typed", Drawn);
      Click_On (Session, Ok_X (2), Info_Y (2));
      Goldens.Check_Text ("rename-done", "FALSE", Boolean'Image (Home.Is_Renaming (Session)));
      Goldens.Check_Text ("rename-first", "Renamed", Home.Row_Title (Session, 1));
      Goldens.Check_Text ("rename-second", "Episode 3", Home.Row_Title (Session, 2));
      Goldens.Check_Text ("rename-third", "Episode 1", Home.Row_Title (Session, 3));
      Move_Away (Session);
      View.Render (Session, Drawn);
      Goldens.Check ("rename-list", Drawn);

      --  Clicking the project's button opens that project.
      Click_On (Session, Open_X (1), Open_Y (1));
      Goldens.Check_Text ("rename-opened", "PROJECT", View.Screens'Image (View.Screen (Session)));
      --  Its title is on the toolbar.
      View.Render (Session, Drawn);
      Goldens.Check ("project-title", Drawn);
   end Renaming;

   --  The dialog to confirm a deletion, in a window Home_Width wide and
   --  Home_Height high: in the middle.
   Dialog_Delete_X  : constant Float := 584.0;
   Dialog_Cancel_X  : constant Float := 480.0;
   Dialog_Buttons_Y : constant Float := 452.5;

   procedure Deleting is
      Session : View.Session;
      Drawn   : Images.Image;
   begin
      With_Three (Session);
      Click_On (Session, Delete_X (2), Info_Y (2));
      Goldens.Check_Text ("delete-asks", "TRUE", Boolean'Image (Home.Is_Confirming (Session)));
      View.Render (Session, Drawn);
      Goldens.Check ("delete-dialog", Drawn);

      --  The screen behind takes no clicks, nor keys.
      Click_On (Session, Open_X (1), Open_Y (1));
      Goldens.Check_Text ("delete-modal-screen", "HOME", View.Screens'Image (View.Screen (Session)));
      Click_On (Session, Delete_X (3), Info_Y (3));
      Goldens.Check_Text ("delete-modal-same", "TRUE", Boolean'Image (Home.Is_Confirming (Session)));

      --  Cancel keeps it.
      Click_On (Session, Dialog_Cancel_X, Dialog_Buttons_Y);
      Goldens.Check_Text ("delete-cancelled", "FALSE", Boolean'Image (Home.Is_Confirming (Session)));
      Goldens.Check_Text ("delete-cancelled-title", "Episode 2", Home.Row_Title (Session, 2));
      Move_Away (Session);
      View.Render (Session, Drawn);
      Goldens.Check ("delete-after-cancel", Drawn);

      --  So does Escape.
      Click_On (Session, Delete_X (2), Info_Y (2));
      View.Handle (Session, Key (Events.Key_Escape));
      Goldens.Check_Text ("delete-escaped", "FALSE", Boolean'Image (Home.Is_Confirming (Session)));
      Goldens.Check_Text ("delete-escaped-title", "Episode 2", Home.Row_Title (Session, 2));

      --  Delete removes it.
      Click_On (Session, Delete_X (2), Info_Y (2));
      Click_On (Session, Dialog_Delete_X, Dialog_Buttons_Y);
      Goldens.Check_Text ("delete-done", "FALSE", Boolean'Image (Home.Is_Confirming (Session)));
      Goldens.Check_Text ("delete-first", "Episode 3", Home.Row_Title (Session, 1));
      Goldens.Check_Text ("delete-second", "Episode 1", Home.Row_Title (Session, 2));
      Goldens.Check_Text ("delete-third", "", Home.Row_Title (Session, 3));
      Move_Away (Session);
      View.Render (Session, Drawn);
      Goldens.Check ("delete-list", Drawn);
   end Deleting;

   procedure Rename_Cancelled is
      Session       : View.Session;
      Before, After : Images.Image;
   begin
      With_Three (Session);
      Move_Away (Session);
      View.Render (Session, Before);
      Click_On (Session, Rename_X (1), Info_Y (1));
      View.Handle (Session, Events.Text_Event ("Nope"));
      Click_On (Session, Cancel_X (1), Info_Y (1));
      Goldens.Check_Text ("cancel-renaming", "FALSE", Boolean'Image (Home.Is_Renaming (Session)));
      Goldens.Check_Text ("cancel-title", "Episode 3", Home.Row_Title (Session, 1));
      Move_Away (Session);
      View.Render (Session, After);
      Goldens.Check_Same ("cancel-same", Before, After);

      --  Another renamed after, and the first is not.
      Click_On (Session, Rename_X (1), Info_Y (1));
      Click_On (Session, Rename_X (3), Info_Y (3));
      Goldens.Check_Text ("cancel-other", "TRUE", Boolean'Image (Home.Is_Renaming (Session)));
      View.Render (Session, After);
      Goldens.Check ("rename-other-row", After);
   end Rename_Cancelled;

   procedure Rename_Entered is
      Session : View.Session;
   begin
      --  Return accepts, as OK does.
      With_Three (Session);
      Click_On (Session, Rename_X (3), Info_Y (3));
      View.Handle (Session, Events.Text_Event ("  Pilot  "));
      View.Handle (Session, Key (Events.Key_Return));
      Goldens.Check_Text ("enter-renaming", "FALSE", Boolean'Image (Home.Is_Renaming (Session)));
      Goldens.Check_Text ("enter-title", "Pilot", Home.Row_Title (Session, 1));

      --  Nothing is not a title.
      Click_On (Session, Rename_X (1), Info_Y (1));
      View.Handle (Session, Key (Events.Key_Backspace));
      Click_On (Session, Ok_X (1), Info_Y (1));
      Goldens.Check_Text ("empty-renaming", "TRUE", Boolean'Image (Home.Is_Renaming (Session)));
      Goldens.Check_Text ("empty-title", "Pilot", Home.Row_Title (Session, 1));

      --  Opening another project, or leaving, stops it.
      Click_On (Session, Actions_X, New_Y);
      Click_On (Session, Close_X, Close_Y);
      Goldens.Check_Text ("left-renaming", "FALSE", Boolean'Image (Home.Is_Renaming (Session)));
   end Rename_Entered;

   procedure Home_Empty is
      Session : View.Session;
      Drawn   : Images.Image;
   begin
      View.Open (Session, "", Home_Width, Home_Height);
      Goldens.Check_Text ("home-is-first", "HOME", View.Screens'Image (View.Screen (Session)));
      Goldens.Check_Text ("home-title", "bonxie", View.Title (Session));
      View.Render (Session, Drawn);
      Goldens.Check ("home-empty", Drawn);
   end Home_Empty;

   procedure Home_Recent is
      Session : View.Session;
      Drawn   : Images.Image;
   begin
      --  The five latest, the latest first.
      View.Open (Session, "", Home_Width, Home_Height);
      for I in 1 .. 7 loop
         Home.Add_Project (Session, "Episode" & Natural'Image (I), Hour * Long_Integer (I));
      end loop;
      View.Render (Session, Drawn);
      Goldens.Check ("home-recent", Drawn);
   end Home_Recent;

   --  The settings, in the same window: Close is at the right of the bar
   --  across the top, and the radios of Speech's Model are in the form,
   --  which is as wide as a page in the writing view.
   Settings_Close_X : constant Float := 48.0;
   --  The back button, at the left of the bar.
   Settings_Close_Y : constant Float := 22.0;
   Model_X          : constant Float := 160.0;
   --  Display's radios come first in the form, then Speech's, which is
   --  set apart from them by Heading_Top.
   Light_Y          : constant Float := 189.0;
   Dark_Y           : constant Float := 225.0;
   System_Y         : constant Float := 261.0;
   --  Then Background's: cards side by side, in a row that is scrolled across, each a picture over a
   --  foot with its name, and those that are painted with the button to paint another.
   Fixed_Card_X     : constant Float := 150.0;
   Water_Card_X     : constant Float := 530.0;
   Card_Y           : constant Float := 400.0;
   Reseed_X         : constant Float := 622.0;
   Reseed_Y         : constant Float := 492.0;
   Native_Y         : constant Float := 636.0;
   Parakeet_Y       : constant Float := 672.0;

   procedure Home_Settings is
      use type Preferences.Speech_Models;
      use type Preferences.Theme_Choices;
      use type Preferences.Background_Modes;
      Session : View.Session;
      Drawn   : Images.Image;
   begin
      View.Open (Session, "", Home_Width, Home_Height);
      Click_On (Session, Actions_X, Settings_Y);
      Goldens.Check_Text ("settings-open", "TRUE", Boolean'Image (Settings.Is_Settings_Open (Session)));
      Goldens.Check_Text ("settings-stays-home", "HOME", View.Screens'Image (View.Screen (Session)));
      View.Render (Session, Drawn);
      Goldens.Check ("settings-macos", Drawn);

      --  Dark draws the whole window in the dark theme, and Light goes
      --  back to it.
      Click_On (Session, Model_X, Dark_Y);
      Goldens.Check_Text
        ("settings-dark-chosen",
         "TRUE",
         Boolean'Image (Settings.Theme_Choice (Session) = Preferences.Dark and then Settings.Is_Dark (Session)));
      View.Render (Session, Drawn);
      Goldens.Check ("settings-dark", Drawn);

      Click_On (Session, Model_X, Light_Y);
      Goldens.Check_Text
        ("settings-light-chosen",
         "TRUE",
         Boolean'Image (Settings.Theme_Choice (Session) = Preferences.Light and then not Settings.Is_Dark (Session)));

      --  System follows the machine, which is not drawn here: Light again.
      Click_On (Session, Model_X, System_Y);
      Goldens.Check_Text
        ("settings-system-chosen", "TRUE", Boolean'Image (Settings.Theme_Choice (Session) = Preferences.System));
      Click_On (Session, Model_X, Light_Y);

      --  The watercolour is for a window, which has a painting to go with it: offscreen, it is chosen
      --  and kept, and the theme's own colours are drawn all the same. Its card is clicked in its
      --  picture or in its foot.
      Goldens.Check_Text
        ("settings-background-default",
         "FIXED",
         Preferences.Background_Modes'Image (Settings.Background_Choice (Session)));
      Click_On (Session, Water_Card_X, Card_Y);
      Goldens.Check_Text
        ("settings-watercolour-chosen",
         "TRUE",
         Boolean'Image
           (Settings.Background_Choice (Session) = Preferences.Watercolour
            and then not Settings.Is_Adaptive (Session)));
      View.Render (Session, Drawn);
      Goldens.Check ("settings-watercolour-chosen-offscreen", Drawn);
      Click_On (Session, Fixed_Card_X, Card_Y);
      Goldens.Check_Text
        ("settings-fixed-chosen", "TRUE", Boolean'Image (Settings.Background_Choice (Session) = Preferences.Fixed));

      --  The others are in the row, past its end: each is chosen by name, and the row is scrolled to it.
      for Mode in Preferences.Background_Modes loop
         if Mode /= Preferences.Gallery then
            Settings.Choose_Background (Session, Mode);
            Goldens.Check_Text
              ("settings-chose-" & Ada.Characters.Handling.To_Lower (Preferences.Background_Modes'Image (Mode)),
               "TRUE",
               Boolean'Image (Settings.Background_Choice (Session) = Mode));
         end if;
      end loop;
      Settings.Choose_Background (Session, Preferences.Bauhaus);
      View.Render (Session, Drawn);
      Goldens.Check ("settings-bauhaus-chosen-offscreen", Drawn);
      Settings.Choose_Background (Session, Preferences.Ink_Wash);
      View.Render (Session, Drawn);
      Goldens.Check ("settings-ink-wash-chosen-offscreen", Drawn);
      Settings.Choose_Background (Session, Preferences.Fixed);

      --  Parakeet's file is to be fetched, if it is not there.
      Click_On (Session, Model_X, Parakeet_Y);
      Goldens.Check_Text
        ("settings-parakeet-chosen", "TRUE", Boolean'Image (Settings.Speech_Model (Session) = Preferences.Parakeet));
      View.Render (Session, Drawn);
      Goldens.Check ("settings-parakeet", Drawn);

      Click_On (Session, Model_X, Native_Y);
      Goldens.Check_Text
        ("settings-macos-chosen", "TRUE", Boolean'Image (Settings.Speech_Model (Session) = Preferences.MacOS));

      --  Escape and Close both leave.
      View.Handle (Session, Key (Events.Key_Escape));
      Goldens.Check_Text ("settings-escaped", "FALSE", Boolean'Image (Settings.Is_Settings_Open (Session)));
      Click_On (Session, Actions_X, Settings_Y);
      Click_On (Session, Settings_Close_X, Settings_Close_Y);
      Goldens.Check_Text ("settings-closed", "FALSE", Boolean'Image (Settings.Is_Settings_Open (Session)));
   end Home_Settings;

   --  The button on the watercolour's card paints another, and chooses it. Which is the clock's, so
   --  nothing here is drawn for a golden.
   procedure Home_Reseed is
      use type Preferences.Background_Modes;
      Session : View.Session;
   begin
      View.Open (Session, "", Home_Width, Home_Height);
      Click_On (Session, Actions_X, Settings_Y);
      declare
         Before : constant Natural := Settings.Watercolour_Seed (Session);
      begin
         Click_On (Session, Reseed_X, Reseed_Y);
         Goldens.Check_Text
           ("settings-reseeded",
            "TRUE",
            Boolean'Image
              (Settings.Watercolour_Seed (Session) /= Before
               and then Settings.Background_Choice (Session) = Preferences.Watercolour));
         Click_On (Session, Fixed_Card_X, Card_Y);
         Goldens.Check_Text
           ("settings-fixed-again",
            "TRUE",
            Boolean'Image
              (Settings.Background_Choice (Session) = Preferences.Fixed
               and then Settings.Watercolour_Seed (Session) /= Before));
         for Mode in Preferences.Pictures loop
            declare
               Seed : constant Natural := Settings.Watercolour_Seed (Session);
            begin
               Settings.Reseed_Background (Session, Mode);
               Goldens.Check_Text
                 ("settings-reseeded-" & Ada.Characters.Handling.To_Lower (Preferences.Background_Modes'Image (Mode)),
                  "TRUE",
                  Boolean'Image
                    (Settings.Background_Choice (Session) = Mode and then Settings.Watercolour_Seed (Session) /= Seed));
            end;
         end loop;
      end;
   end Home_Reseed;

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
         Data : constant Ada.Streams.Stream_Element_Array (1 .. Bytes) := [others => 7];
      begin
         Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Source);
         Ada.Streams.Stream_IO.Write (File, Data);
         Ada.Streams.Stream_IO.Close (File);
      end;

      Goldens.Check_Text ("downloads-idle", "IDLE", Downloads.States'Image (Downloads.State));
      Downloads.Start ("file://" & Source, Target);
      Goldens.Check_Text ("downloads-started", "TRUE", Boolean'Image (Downloads.State = Downloads.Running));
      Wait;
      Goldens.Check_Text ("downloads-done", "DONE", Downloads.States'Image (Downloads.State));
      Goldens.Check_Text ("downloads-fraction", "TRUE", Boolean'Image (Downloads.Fraction = 1.0));
      Goldens.Check_Text
        ("downloads-size", Integer'Image (Bytes), Ada.Directories.File_Size'Image (Ada.Directories.Size (Target)));
      Goldens.Check_Text ("downloads-no-part", "FALSE", Boolean'Image (Ada.Directories.Exists (Target & ".part")));

      Downloads.Reset;
      Downloads.Start ("file://" & Folder & "/nothing.bin", Target & "2");
      Wait;
      Goldens.Check_Text ("downloads-failed", "FAILED", Downloads.States'Image (Downloads.State));
      Goldens.Check_Text
        ("downloads-failed-leaves-nothing", "FALSE", Boolean'Image (Ada.Directories.Exists (Target & "2")));
      Downloads.Reset;
      Ada.Directories.Delete_Tree (Folder);
   end Fetching;

   --  The dark theme over the home screen, and a new project's screen.
   procedure Dark_Screens is
      Session : View.Session;
      Drawn   : Images.Image;
   begin
      View.Open (Session, "Bonxie", Home_Width, Home_Height);
      Home.Add_Project (Session, "Episode 1", Hour);
      Settings.Choose_Theme (Session, Preferences.Dark);
      View.Render (Session, Drawn);
      Goldens.Check ("home-dark", Drawn);

      Click_On (Session, Actions_X, New_Y);
      View.Render (Session, Drawn);
      Goldens.Check ("project-dark", Drawn);
   end Dark_Screens;

   --  The choices are kept in one file, each on its own line, so that
   --  saving one keeps the others.
   procedure Preferences_Kept is
      Config : constant String := "/tmp/bonxie-preferences-test";
      use type Preferences.Speech_Models;
      use type Preferences.Theme_Choices;
      use type Preferences.Background_Modes;
   begin
      if Ada.Directories.Exists (Config) then
         Ada.Directories.Delete_Tree (Config);
      end if;
      Goldens.Check_Text
        ("preferences-none", "SYSTEM", Preferences.Theme_Choices'Image (Preferences.Load_Theme (Config)));

      Preferences.Save_Speech_Model (Config, Preferences.Parakeet);
      Preferences.Save_Theme (Config, Preferences.Dark);
      Goldens.Check_Text
        ("preferences-dark-kept",
         "TRUE",
         Boolean'Image
           (Preferences.Load_Theme (Config) = Preferences.Dark
            and then Preferences.Load_Speech_Model (Config) = Preferences.Parakeet));

      Preferences.Save_Speech_Model (Config, Preferences.MacOS);
      Goldens.Check_Text
        ("preferences-speech-kept",
         "TRUE",
         Boolean'Image
           (Preferences.Load_Theme (Config) = Preferences.Dark
            and then Preferences.Load_Speech_Model (Config) = Preferences.MacOS));

      Preferences.Save_Theme (Config, Preferences.System);
      Goldens.Check_Text
        ("preferences-system-kept",
         "TRUE",
         Boolean'Image
           (Preferences.Load_Theme (Config) = Preferences.System
            and then Preferences.Load_Speech_Model (Config) = Preferences.MacOS));

      --  The background is its own choice: Adaptive when none was made, and saving it keeps the theme.
      Goldens.Check_Text
        ("preferences-background-none",
         "WATERCOLOUR",
         Preferences.Background_Modes'Image (Preferences.Load_Background (Config)));
      for Mode in Preferences.Background_Modes loop
         Preferences.Save_Background (Config, Mode);
         Goldens.Check_Text
           ("preferences-" & Ada.Characters.Handling.To_Lower (Preferences.Background_Modes'Image (Mode)) & "-kept",
            "TRUE",
            Boolean'Image (Preferences.Load_Background (Config) = Mode));
      end loop;
      Preferences.Save_Background (Config, Preferences.Fixed);
      Goldens.Check_Text
        ("preferences-fixed-kept",
         "TRUE",
         Boolean'Image
           (Preferences.Load_Background (Config) = Preferences.Fixed
            and then Preferences.Load_Theme (Config) = Preferences.System));
      Preferences.Save_Background (Config, Preferences.Watercolour);
      Goldens.Check_Text
        ("preferences-watercolour-kept",
         "TRUE",
         Boolean'Image
           (Preferences.Load_Background (Config) = Preferences.Watercolour
            and then Preferences.Load_Theme (Config) = Preferences.System));

      --  VSync is off when none was chosen, and is kept beside the others.
      Goldens.Check_Text ("preferences-vsync-none", "FALSE", Boolean'Image (Preferences.Load_VSync (Config)));
      Preferences.Save_VSync (Config, True);
      Goldens.Check_Text
        ("preferences-vsync-on-kept",
         "TRUE",
         Boolean'Image
           (Preferences.Load_VSync (Config)
            and then Preferences.Load_Theme (Config) = Preferences.System
            and then Preferences.Load_Background (Config) = Preferences.Watercolour));
      Preferences.Save_VSync (Config, False);
      Goldens.Check_Text ("preferences-vsync-off-kept", "FALSE", Boolean'Image (Preferences.Load_VSync (Config)));

      --  Which watercolour is kept too, whole: it is the same picture on every run. A word that is not a
      --  number is no seed.
      Goldens.Check_Text ("preferences-seed-none", "FALSE", Boolean'Image (Preferences.Has_Seed (Config)));
      Preferences.Save_Seed (Config, 14_591_295);
      Preferences.Save_Seed (Config, Preferences.Seed_Limit - 1);
      Goldens.Check_Text
        ("preferences-seed-kept",
         "TRUE",
         Boolean'Image
           (Preferences.Has_Seed (Config)
            and then Preferences.Load_Seed (Config) = Preferences.Seed_Limit - 1
            and then Preferences.Load_Background (Config) = Preferences.Watercolour
            and then Preferences.Load_Theme (Config) = Preferences.System));
      Preferences.Save_Seed (Config, 0);
      Goldens.Check_Text
        ("preferences-seed-zero",
         "TRUE",
         Boolean'Image (Preferences.Has_Seed (Config) and then Preferences.Load_Seed (Config) = 0));
      Files.Write (Config & "/settings", "watercolour_seed=twelve" & ASCII.LF);
      Goldens.Check_Text ("preferences-seed-garbled", "FALSE", Boolean'Image (Preferences.Has_Seed (Config)));
      Files.Write (Config & "/settings", "background=adaptive" & ASCII.LF);
      Goldens.Check_Text
        ("preferences-adaptive-is-watercolour",
         "WATERCOLOUR",
         Preferences.Background_Modes'Image (Preferences.Load_Background (Config)));
      Ada.Directories.Delete_Tree (Config);
   end Preferences_Kept;

   --  The colours that go with a painting, whatever hue it is made in, read as well as the theme's
   --  own: text on each surface it is drawn on, and light text on the dark bars, keep 97% of the
   --  contrast they have in the library's themes (the rest is the rounding of a colour to bytes), and what means
   --  something in itself does not move.
   procedure Adaptive_Palettes is
      package Themes renames Pomarine.Themes;
      use type Themes.Color;
      use type SDL3.Windows.Renderers.Color_Component;
      Steps  : constant := 48;
      Worst  : Float := Float'Last;
      Moved  : Boolean := True;
      Stayed : Boolean := True;
      Tinted : Boolean := True;

      procedure Check_Against (Base, Made : Themes.Palette; Dark : Boolean) is
         Bar : constant Themes.Theme := Themes.Make (Made);

         procedure Read (Ink, Surface : Themes.Color; Was : Themes.Color; Was_Surface : Themes.Color) is
            Kept : constant Float :=
              Adaptive_Themes.Contrast (Ink, Surface) / Adaptive_Themes.Contrast (Was, Was_Surface);
         begin
            Worst := Float'Min (Worst, Kept);
         end Read;
      begin
         Read (Made.Foreground, Made.Background, Base.Foreground, Base.Background);
         Read (Made.Foreground, Made.Page, Base.Foreground, Base.Page);
         Read (Made.Foreground, Made.Face, Base.Foreground, Base.Face);
         Read (Made.Foreground, Made.Face_Hover, Base.Foreground, Base.Face_Hover);
         Read (Made.Foreground, Made.Face_Pressed, Base.Foreground, Base.Face_Pressed);
         Read (Made.Foreground, Made.Tint, Base.Foreground, Base.Tint);
         Read (Themes.Soft_White, Made.Bar, Themes.Soft_White, Base.Bar);
         Read (Bar (Themes.Bar_Ink), Bar (Themes.Bar), Themes.Soft_White, Base.Bar);
         Stayed :=
           Stayed
           and then Made.Primary = Base.Primary
           and then Made.Danger = Base.Danger
           and then Made.Accent = Base.Accent
           and then Made.Focus = Base.Focus
           and then Made.Dark = Dark;
      end Check_Against;
   begin
      for Dark in Boolean loop
         declare
            Base : constant Themes.Palette := (if Dark then Themes.Dark_Palette else Themes.Light_Palette);
         begin
            for Strength of Adaptive_Themes.Strengths_Array'([0.35, 0.6, 1.0]) loop
               for Step in 0 .. Steps - 1 loop
                  declare
                     Hue  : constant Adaptive_Themes.Hues := Float (Step) / Float (Steps);
                     Made : constant Themes.Palette := Adaptive_Themes.Palette_For (Dark, Hue, Strength);
                  begin
                     Check_Against (Base, Made, Dark);
                  end;
               end loop;
            end loop;
            Moved :=
              Moved
              and then Adaptive_Themes.Palette_For (Dark, 0.0).Background
                       /= Adaptive_Themes.Palette_For (Dark, 0.5).Background;
            --  A grey of a hue is not grey: its channels differ.
            declare
               Back : constant Themes.Color := Adaptive_Themes.Palette_For (Dark, 0.9).Background;
            begin
               Tinted := Tinted and then Back.Red /= Back.Green and then Back.Green /= Back.Blue;
            end;
         end;
      end loop;
      --  The pictures and the choices of background are the same list, but for the plain one, and every
      --  picture has a hue to tint with and keeps to what it may take of it.
      declare
         Same  : Boolean := True;
         Tints : Boolean := True;
      begin
         for Mode in Preferences.Pictures loop
            declare
               Style : constant Backgrounds.Styles :=
                 Backgrounds.Styles'Val (Preferences.Background_Modes'Pos (Mode) - 1);
            begin
               Same := Same and then Backgrounds.Styles'Image (Style) = Preferences.Background_Modes'Image (Mode);
               Tints := Tints and then Backgrounds.Tint_Strength (Style) in 0.2 .. 1.0;
            end;
         end loop;
         Goldens.Check_Text ("adaptive-styles-match-choices", "TRUE", Boolean'Image (Same and then Tints));
         --  Bold colours tint the greys at least as much as soft ones, and muted ones least; always in range.
         declare
            Ordered : Boolean := True;
         begin
            for Style in Backgrounds.Styles loop
               declare
                  Soft : constant Float := Backgrounds.Tint_Strength (Style, Backgrounds.Pastel);
               begin
                  Ordered :=
                    Ordered
                    and then Backgrounds.Tint_Strength (Style, Backgrounds.Vivid) >= Soft
                    and then Backgrounds.Tint_Strength (Style, Backgrounds.Rich) >= Soft
                    and then Backgrounds.Tint_Strength (Style, Backgrounds.Muted) < Soft
                    and then Backgrounds.Tint_Strength (Style) = Soft;
               end;
            end loop;
            Goldens.Check_Text ("adaptive-mood-tint-order", "TRUE", Boolean'Image (Ordered));
         end;
      end;
      Goldens.Check_Text ("adaptive-text-reads", "TRUE", Boolean'Image (Worst > 0.97));
      Goldens.Check_Text ("adaptive-hue-moves-greys", "TRUE", Boolean'Image (Moved and then Tinted));
      Goldens.Check_Text ("adaptive-meanings-stay", "TRUE", Boolean'Image (Stayed));
      --  Each hue is where the wheel says: red, yellow, green, cyan, blue and magenta, at mid grey.
      declare
         Grey    : constant Themes.Color := (16#80#, 16#80#, 16#80#, 255);
         function At_Hue (Sixth : Natural) return Themes.Color
         is (Adaptive_Themes.Retint (Grey, Float (Sixth) / 6.0, 0.9));
         Red     : constant Themes.Color := At_Hue (0);
         Yellow  : constant Themes.Color := At_Hue (1);
         Green   : constant Themes.Color := At_Hue (2);
         Cyan    : constant Themes.Color := At_Hue (3);
         Blue    : constant Themes.Color := At_Hue (4);
         Magenta : constant Themes.Color := At_Hue (5);
      begin
         Goldens.Check_Text
           ("adaptive-hue-on-the-wheel",
            "TRUE",
            Boolean'Image
              (Red.Red > Red.Green
               and then Red.Red > Red.Blue
               and then Yellow.Blue < Yellow.Red
               and then Yellow.Blue < Yellow.Green
               and then abs (Integer (Yellow.Red) - Integer (Yellow.Green)) < 8
               and then Green.Green > Green.Red
               and then Green.Green > Green.Blue
               and then Cyan.Red < Cyan.Green
               and then Cyan.Red < Cyan.Blue
               and then abs (Integer (Cyan.Green) - Integer (Cyan.Blue)) < 8
               and then Blue.Blue > Blue.Red
               and then Blue.Blue > Blue.Green
               and then Magenta.Green < Magenta.Red
               and then Magenta.Green < Magenta.Blue
               and then abs (Integer (Magenta.Red) - Integer (Magenta.Blue)) < 8));
      end;
      Goldens.Check_Text
        ("adaptive-retint-keeps-brightness",
         "TRUE",
         Boolean'Image
           (abs (Adaptive_Themes.Luminance (Adaptive_Themes.Retint ((16#A9#, 16#B1#, 16#AD#, 255), 0.15, 0.3))
                 - Adaptive_Themes.Luminance ((16#A9#, 16#B1#, 16#AD#, 255)))
            < 0.01));
      Goldens.Check_Text
        ("adaptive-contrast-extremes",
         "TRUE",
         Boolean'Image
           (abs (Adaptive_Themes.Contrast ((0, 0, 0, 255), (255, 255, 255, 255)) - 21.0) < 0.01
            and then Adaptive_Themes.Contrast ((9, 9, 9, 255), (9, 9, 9, 255)) = 1.0));
   end Adaptive_Palettes;

   procedure New_And_Close is
      Session : View.Session;
      Drawn   : Images.Image;
   begin
      View.Open (Session, "Bonxie", Home_Width, Home_Height);
      Home.Add_Project (Session, "Episode 1", Hour);
      Click_On (Session, Actions_X, New_Y);
      Goldens.Check_Text ("new-project-screen", "PROJECT", View.Screens'Image (View.Screen (Session)));
      View.Render (Session, Drawn);
      Goldens.Check ("project-screen", Drawn);

      Click_On (Session, Close_X, Close_Y);
      Goldens.Check_Text ("close-project-screen", "HOME", View.Screens'Image (View.Screen (Session)));
      View.Render (Session, Drawn);
      Goldens.Check ("home-after-close", Drawn);
   end New_And_Close;

   procedure Keyboard_Only is
      Session : View.Session;
      Drawn   : Images.Image;
   begin
      With_Three (Session);

      --  The dialog that asks before deleting has the focus on Cancel, so
      --  that Return keeps the project.
      Click_On (Session, Delete_X (3), Info_Y (3));
      Goldens.Check_Text ("keys-delete-asks", "TRUE", Boolean'Image (Home.Is_Confirming (Session)));
      --  A click gave it no ring, a key does.
      Press (Session, Events.Key_Tab, Times => 3);
      View.Render (Session, Drawn);
      Goldens.Check ("keys-dialog-ring", Drawn);
      Press (Session, Events.Key_Return);
      Goldens.Check_Text
        ("keys-delete-return-keeps",
         "FALSE Episode 1",
         Boolean'Image (Home.Is_Confirming (Session)) & " " & Home.Row_Title (Session, 3));

      --  Tab goes round the dialog only: Cancel, Delete, and the button to
      --  close it, and round again: three presses are back at Cancel, and
      --  none of them reach the screen behind.
      Click_On (Session, Delete_X (3), Info_Y (3));
      Press (Session, Events.Key_Tab, Times => 3);
      Press (Session, Events.Key_Return);
      Goldens.Check_Text
        ("keys-delete-tab-round",
         "FALSE Episode 1",
         Boolean'Image (Home.Is_Confirming (Session)) & " " & Home.Row_Title (Session, 3));
      Goldens.Check_Text ("keys-delete-still-home", "HOME", View.Screens'Image (View.Screen (Session)));

      --  One Tab on from Cancel is Delete, which Return does.
      Click_On (Session, Delete_X (3), Info_Y (3));
      Press (Session, Events.Key_Tab);
      Press (Session, Events.Key_Return);
      Goldens.Check_Text
        ("keys-delete-done",
         "FALSE Episode 2",
         Boolean'Image (Home.Is_Confirming (Session)) & " " & Home.Row_Title (Session, 2));

      --  Tab reaches the first of the screen's buttons, New Project, and
      --  Return presses it; and, on the project, Tab and Return its button
      --  back.
      Press (Session, Events.Key_Tab);
      View.Render (Session, Drawn);
      Goldens.Check ("keys-home-ring", Drawn);
      Press (Session, Events.Key_Return);
      Goldens.Check_Text ("keys-new-project", "PROJECT", View.Screens'Image (View.Screen (Session)));
      Press (Session, Events.Key_Tab);
      Press (Session, Events.Key_Return);
      Goldens.Check_Text ("keys-back-home", "HOME", View.Screens'Image (View.Screen (Session)));
   end Keyboard_Only;

   procedure Add (Store : in out Projects.Store; Title : String; Description : String := ""; Time : Projects.Seconds) is
      Ignored : constant Projects.Id := Projects.Create (Store, Title, Description, Time);
      pragma Unreferenced (Ignored);
   begin
      null;
   end Add;

   procedure Open_Listed is
      Session : View.Session;
   begin
      --  A click on a listed project opens it: the second latest here.
      View.Open (Session, "", Home_Width, Home_Height);
      for I in 1 .. 3 loop
         Home.Add_Project (Session, "Episode" & Natural'Image (I), Hour * Long_Integer (I));
      end loop;
      Click_On (Session, Open_X (2), Open_Y (2));
      Goldens.Check_Text ("listed-screen", "PROJECT", View.Screens'Image (View.Screen (Session)));
      Goldens.Check_Text
        ("listed-project",
         "2",
         Projects.Id'Image (Proj.Current_Project (Session))
           (2 .. Projects.Id'Image (Proj.Current_Project (Session))'Last));

      Click_On (Session, Close_X, Close_Y);
      Goldens.Check_Text ("listed-closed", "HOME", View.Screens'Image (View.Screen (Session)));
      --  A new project is a project of its own.
      Click_On (Session, Actions_X, New_Y);
      Goldens.Check_Text
        ("listed-new-project",
         "4",
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
      Goldens.Check_Text ("projects-order", "Same time,Same time, later,Middle,Old,", Titles (Recent));
      Goldens.Check_Text
        ("projects-description", "first", Projects.Descriptions.To_String (Recent.Items (4).Description));
      Goldens.Check_Text
        ("projects-times", " 100 100", Recent.Items (4).Created_At'Image & Recent.Items (4).Updated_At'Image);

      --  Updating one puts it first.
      Projects.Touch (Store, Recent.Items (4).Key, 400);
      Projects.Recent (Store, Recent);
      Goldens.Check_Text ("projects-touched", "Old,Same time,Same time, later,Middle,", Titles (Recent));

      Projects.Rename (Store, Recent.Items (1).Key, "Renamed", 450);
      Projects.Recent (Store, Recent);
      Goldens.Check_Text ("projects-renamed", "Renamed,Same time,Same time, later,Middle,", Titles (Recent));
      Projects.Rename (Store, Recent.Items (1).Key, "Old", 400);

      --  Only five are listed.
      Add (Store, "Five", Time => 500);
      Add (Store, "Six", Time => 600);
      Projects.Recent (Store, Recent);
      Goldens.Check_Text ("projects-limit", "Six,Five,Old,Same time,Same time, later,", Titles (Recent));

      --  Deleted, one is gone, and the next takes its place.
      Projects.Delete (Store, Recent.Items (1).Key);
      Projects.Recent (Store, Recent);
      Goldens.Check_Text ("projects-deleted", "Five,Old,Same time,Same time, later,Middle,", Titles (Recent));
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
   Run ("items-search", Item_Tests.Searching'Access);
   Run ("sources-search", Item_Tests.Search_Sources'Access);
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
   Run ("items-list-keys", Item_Tests.Keyboard_List'Access);
   Run ("items-revealing", Item_Tests.Revealing'Access);
   Run ("items-dock-scrolling", Item_Tests.Scrolling_Dock'Access);
   Run ("items-list-scrolling", Item_Tests.Scrolling_List'Access);
   Run ("items-panning-zooming", Item_Tests.Panning_And_Zooming'Access);
   Run ("items-raising", Item_Tests.Raising'Access);
   Run ("items-repainting", Item_Tests.Repainting'Access);
   Run ("items-density", Item_Tests.Fractional_Density'Access);
   Run ("items-full", Item_Tests.Full'Access);
   Run ("items-long-title", Item_Tests.Long_Title'Access);
   Run ("items-many-marks-and-words", Item_Tests.Many_Marks_And_Words'Access);
   Run ("items-kept", Item_Tests.Kept'Access);
   Run ("layout-columns", Layout_Tests.Columns'Access);
   Run ("items-linking", Item_Tests.Linking'Access);
   Run ("items-link-editing", Item_Tests.Editing_Links'Access);
   Run ("browser-pane", Item_Tests.Browser_Pane'Access);
   Run ("sources-window", Item_Tests.Source_Windows'Access);
   Run ("sources-pages", Item_Tests.Source_Pages'Access);
   Run ("sources-words", Item_Tests.Source_Words'Access);
   Run ("sources-documents", Item_Tests.Source_Documents'Access);
   Run ("sources-files", Item_Tests.Source_Files'Access);
   Run ("outline-starting", Outline_Tests.Starting'Access);
   Run ("outline-colours", Outline_Tests.Colours'Access);
   Run ("outline-sections", Outline_Tests.Sections'Access);
   Run ("outline-many-sections", Outline_Tests.Many_Sections'Access);
   Run ("outline-form", Outline_Tests.Form'Access);
   Run ("outline-notes", Outline_Tests.Notes'Access);
   Run ("outline-write-notes", Outline_Tests.Write_Notes'Access);
   Run ("outline-linking", Outline_Tests.Linking'Access);
   Run ("outline-naming", Outline_Tests.Naming'Access);
   Run ("outline-sidebar", Outline_Tests.Sidebar'Access);
   Run ("outline-tiers", Outline_Tests.Tiers'Access);
   Run ("outline-section-rows", Outline_Tests.Section_Rows'Access);
   Run ("outline-folder-operations", Outline_Tests.Folder_Operations'Access);
   Run ("outline-section-folders", Outline_Tests.Section_Folders'Access);
   Run ("outline-writing-sections", Outline_Tests.Writing_Sections'Access);
   Run ("outline-menu-fitting", Outline_Tests.Menu_Fitting'Access);
   Run ("write-source-documents", Write_Tests.Source_Documents'Access);
   Run ("write-search", Write_Tests.Searching'Access);
   Run ("write-pages", Write_Tests.Pages'Access);
   Run ("write-grammar", Grammar_Tests.Checking'Access);
   Run ("write-grammar-rules", Grammar_Tests.Rules'Access);
   Run ("write-grammar-rule-cards", Grammar_Tests.Rule_Cards'Access);
   Run ("write-grammar-entry-by-name", Grammar_Tests.Entry_By_Name'Access);
   Run ("write-ordering", Write_Tests.Ordering'Access);
   Run ("write-dragging", Write_Tests.Dragging'Access);
   Run ("write-directories", Write_Tests.Directories'Access);
   Run ("write-many-directories", Write_Tests.Many_Directories'Access);
   Run ("write-context-menus", Write_Tests.Context_Menus'Access);
   Run ("write-context-elsewhere", Write_Tests.Context_Menus_Elsewhere'Access);
   Run ("write-context-on-canvas", Write_Tests.Context_Menus_On_Canvas'Access);
   Run ("write-adding", Write_Tests.Adding'Access);
   Run ("write-linked-sources", Write_Tests.Linked_Sources'Access);
   Run ("write-typing", Write_Tests.Typing'Access);
   Run ("write-word-tools", Write_Tests.Word_Tools'Access);
   Run ("write-thesaurus", Write_Tests.Thesaurus'Access);
   Run ("write-publishing", Write_Tests.Publishing'Access);
   Run ("write-markdown", Write_Tests.Markdown'Access);
   Run ("write-sources", Write_Tests.Sources'Access);
   Run ("write-marks", Write_Tests.Sharing_Marks'Access);
   Run ("home-empty", Home_Empty'Access);
   Run ("home-recent", Home_Recent'Access);
   Run ("home-settings", Home_Settings'Access);
   Run ("home-settings-reseed", Home_Reseed'Access);
   Run ("home-by-name", Home_Tests.By_Name'Access);
   Run ("outline-by-name", Outline_Screen_Tests.By_Name'Access);
   Run ("settings-by-name", Settings_Tests.By_Name'Access);
   Run ("settings-gallery-cache", Settings_Tests.Gallery_Cache'Access);
   Run ("settings-gallery-colours", Settings_Tests.Colour_Sampling'Access);
   Run ("settings-browser-filter", Settings_Tests.Browser_Filter'Access);
   Run ("settings-vm-commands", Settings_VM_Tests.Command_Rules'Access);
   Run ("settings-vm-pictures", Settings_VM_Tests.New_Pictures'Access);
   Run ("settings-vm-keeping", Settings_VM_Tests.Keeping'Access);
   Run ("settings-vm-downloading", Settings_VM_Tests.Downloading'Access);
   Run ("settings-vm-sizes", Settings_VM_Tests.Sizes'Access);
   Run ("update-vm-checking", Update_VM_Tests.Checking'Access);
   Run ("update-vm-offering", Update_VM_Tests.Offering'Access);
   Run ("update-vm-installing", Update_VM_Tests.Installing'Access);
   Run ("update-vm-starting", Update_VM_Tests.Starting'Access);
   Run ("item-controls-by-name", Item_List_VM_Tests.Window_Controls_By_Name'Access);
   Run ("menu-vm-rules", Item_Control_VM_Tests.Menu_Rules'Access);
   Run ("item-window-vm-rules", Item_Control_VM_Tests.Window_Rules'Access);
   Run ("reader-controls-by-name", Reader_Binding_Tests.By_Name'Access);
   Run ("reader-vm-rules", Item_Control_VM_Tests.Reader_Rules'Access);
   Run ("item-model-notes", Item_Model_Tests.Notes'Access);
   Run ("item-model-placing", Item_Model_Tests.Placing'Access);
   Run ("item-model-sources", Item_Model_Tests.Sources'Access);
   Run ("item-model-writing", Item_Model_Tests.Writing'Access);
   Run ("editor-by-name", Editor_VM_Tests.By_Name'Access);
   Run ("editor-vm-placement", Editor_VM_Tests.Placement'Access);
   Run ("editor-vm-live", Editor_VM_Tests.Live_Text'Access);
   Run ("editor-vm-interrupted", Editor_VM_Tests.Interrupted'Access);
   Run ("editor-vm-boundaries", Editor_VM_Tests.Boundaries'Access);
   Run ("publish-by-name", Writing_VM_Tests.Publishing_By_Name'Access);
   Run ("writing-sidebar-by-name", Writing_VM_Tests.Sidebar_By_Name'Access);
   Run ("writing-sections-by-name", Writing_VM_Tests.Sections_By_Name'Access);
   Run ("writing-by-name", Writing_VM_Tests.By_Name'Access);
   Run ("writing-vm-ordering", Writing_VM_Tests.Ordering'Access);
   Run ("writing-vm-navigation", Writing_VM_Tests.Navigation'Access);
   Run ("search-vm-lifecycle", Search_VM_Tests.Lifecycle'Access);
   Run ("search-by-name", Search_VM_Tests.By_Name'Access);
   Run ("item-list-by-name", Item_List_VM_Tests.By_Name'Access);
   Run ("item-list-vm-rows-actions", Item_List_VM_Tests.Rows_And_Actions'Access);
   Run ("canvas-vm-entering", Canvas_VM_Tests.Entering'Access);
   Run ("canvas-vm-adding", Canvas_VM_Tests.Adding'Access);
   Run ("canvas-vm-showing", Canvas_VM_Tests.Showing'Access);
   Run ("canvas-vm-camera", Canvas_VM_Tests.Camera'Access);
   Run ("canvas-vm-handling", Canvas_VM_Tests.Handling'Access);
   Run ("canvas-vm-linking", Canvas_VM_Tests.Linking'Access);
   Run ("canvas-vm-stored", Canvas_VM_Tests.Stored'Access);
   Run ("nav-create-by-name", Nav_Tests.Creating'Access);
   Run ("nav-by-name", Nav_Tests.By_Name'Access);
   Run ("nav-vm-opening", Nav_VM_Tests.Opening'Access);
   Run ("nav-vm-views", Nav_VM_Tests.Views'Access);
   Run ("nav-vm-browser", Nav_VM_Tests.Browser'Access);
   Run ("browser-vm-address", Browser_VM_Tests.Addresses'Access);
   Run ("browser-vm-going", Browser_VM_Tests.Going'Access);
   Run ("browser-vm-keeping", Browser_VM_Tests.Keeping'Access);
   Run ("browser-vm-no-page", Browser_VM_Tests.Without_A_Page'Access);
   Run ("site-filter-bases", Site_Filter_Tests.Bases'Access);
   Run ("site-filter-rules", Site_Filter_Tests.Rules_Permit'Access);
   Run ("site-filter-vm", Site_Filter_Tests.Editing'Access);
   Run ("nav-vm-renaming", Nav_VM_Tests.Renaming'Access);
   Run ("nav-vm-layers", Nav_VM_Tests.Layers'Access);
   Run ("nav-vm-writing-sections", Nav_VM_Tests.Writing_Sections'Access);
   Run ("nav-vm-creating", Nav_VM_Tests.Creating'Access);
   Run ("item-list-vm-layers", Nav_VM_Tests.List_Commands'Access);
   Run ("export-plain", Export_Tests.Plain'Access);
   Run ("export-html", Export_Tests.HTML'Access);
   Run ("export-epub", Export_Tests.Epub'Access);
   Run ("export-odt", Export_Tests.Odt'Access);
   Run ("export-docx", Export_Tests.Docx'Access);
   Run ("export-pdf", Export_Tests.Pdf'Access);
   Run ("publish-formats-vm", Nav_VM_Tests.Publishing_Formats'Access);
   Run ("publish-output-vm", Nav_VM_Tests.Publishing_Output'Access);
   Run ("publish-vm", Nav_VM_Tests.Publishing'Access);
   Run ("writing-sources-vm", Nav_VM_Tests.Source_Commands'Access);
   Run ("writing-link-offers", Nav_VM_Tests.Link_Offers'Access);
   Run ("naming-vm", Nav_VM_Tests.Naming'Access);
   Run ("writing-page-vm", Nav_VM_Tests.Page_Commands'Access);
   Run ("sidebar-vm", Nav_VM_Tests.Sidebar'Access);
   Run ("nav-vm-stored", Nav_VM_Tests.Stored'Access);
   Run ("home-vm-listing", Home_VM_Tests.Listing'Access);
   Run ("home-vm-renaming", Home_VM_Tests.Renaming'Access);
   Run ("home-vm-deleting", Home_VM_Tests.Deleting'Access);
   Run ("home-vm-stored", Home_VM_Tests.Stored'Access);
   Run ("confirm-vm-asking", Home_VM_Tests.Asking'Access);
   Run ("outline-vm-entering", Outline_VM_Tests.Entering'Access);
   Run ("outline-vm-changing", Outline_VM_Tests.Changing'Access);
   Run ("outline-vm-typing", Outline_VM_Tests.Typing'Access);
   Run ("outline-vm-stored", Outline_VM_Tests.Stored'Access);
   Run ("grammar-vm-rules", Grammar_VM_Tests.Rule_List'Access);
   Run ("grammar-vm-entry", Grammar_VM_Tests.Entry_Form'Access);
   Run ("grammar-vm-cards", Grammar_VM_Tests.Card_Actions'Access);
   Run ("grammar-vm-stored", Grammar_VM_Tests.Stored'Access);
   Run ("view-models-no-widgets", Settings_VM_Tests.No_Widgets'Access);
   Run ("home-dark", Dark_Screens'Access);
   Run ("preferences-kept", Preferences_Kept'Access);
   Run ("adaptive-palettes", Adaptive_Palettes'Access);
   Run ("downloads-fetching", Fetching'Access);
   Run ("home-new-and-close", New_And_Close'Access);
   Run ("home-open-listed", Open_Listed'Access);
   Run ("home-rename", Renaming'Access);
   Run ("home-rename-cancel", Rename_Cancelled'Access);
   Run ("home-rename-enter", Rename_Entered'Access);
   Run ("home-delete", Deleting'Access);
   Run ("home-keys", Keyboard_Only'Access);
   Run ("projects-stored", Stored'Access);
   Run ("projects-kept", Kept'Access);

   Ada.Text_IO.Put_Line
     (Ran'Image
      & " tests:"
      & Natural'Image (Goldens.Passed)
      & " checks passed,"
      & Natural'Image (Goldens.Failed)
      & " failed");
   if Ran = 0 or else Goldens.Failed > 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
   Speech.Jobs.Shutdown;  --  or the tasks that listen would keep it from ending
exception
   --  Said here: left unhandled, it ends with no message, as the tasks that listen hold it up.
   when Failure : others =>
      Ada.Text_IO.Put_Line ("FAIL  unhandled: " & Ada.Exceptions.Exception_Information (Failure));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      Speech.Jobs.Shutdown;
end Golden;
