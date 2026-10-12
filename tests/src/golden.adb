with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with Ada.Text_IO;
with SDL3.Events;
with Document_Tests;
with Field_Tests;
with Files;
with Goldens;
with Projects;
with Text_Area_Tests;
with Typeset.Samples;
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

   Sample : constant String := Typeset.Samples.Document (200);

   LF : constant Wide_Wide_Character := Wide_Wide_Character'Val (10);

   Em_Dash : constant String :=
     Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode
       ([Wide_Wide_Character'Val (16#2014#)]);

   Scripts : constant String :=
     Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode
       ("Accents: café, naïve, Ångström, smørrebrød." & LF
        & "Emoji keep their colours: 🐦 🌿 🎙️ 👍🏽" & LF
        & "Other scripts: Привет, こんにちは, 日本語のテキスト, مرحبا." & LF
        & "Typography: “quoted”, ‘single’, em—dash, en–dash, ½, …" & LF
        & LF
        & "After an empty paragraph, a long one that wraps across several "
        & "lines of the page, to see the lines break between words and the "
        & "paragraph's spacing after it, before the next. Bonxies are great "
        & "skuas, which nest on moorland in Shetland and Orkney and spend "
        & "the winter at sea.");
   --  In UTF-8, as documents are.

   --  Events

   function Key
     (Code : Events.Key_Code; Command : Boolean := False) return Events.Event
   is ((Kind => Events.Key_Down, Key => Code, Command => Command,
        others => <>));

   --  Shorthands

   Default_Width  : constant := 720;
   Default_Height : constant := 480;
   --  In points: the page, 640 wide, fits with a margin.

   function Wheel (Notches : Float) return Events.Event is
     ((Kind => Events.Mouse_Wheel, Wheel_Y => Notches,
       Mouse_X => Float (Default_Width / 2),
       Mouse_Y => Float (Default_Height / 2), others => <>));
   --  Over the text.

   function Click (X, Y : Float) return Events.Event is
     ((Kind => Events.Mouse_Down, Button => 1, Clicks => 1,
       Mouse_X => X, Mouse_Y => Y, others => <>));
   --  At X, Y points.

   procedure Press
     (Item  : in out Viewer.Session;
      Code  : Events.Key_Code;
      Times : Positive := 1;
      Command : Boolean := False;
      Shift : Boolean := False) is
   begin
      for K in 1 .. Times loop
         Viewer.Handle (Item, (Key (Code, Command) with delta Shift => Shift));
      end loop;
   end Press;

   procedure Zoom_In (Item : in out Viewer.Session; Times : Positive) is
   begin
      Press (Item, Events.Key_Equals, Times, Command => True);
   end Zoom_In;

   procedure Zoom_Out (Item : in out Viewer.Session; Times : Positive) is
   begin
      Press (Item, Events.Key_Minus, Times, Command => True);
   end Zoom_Out;

   procedure Show
     (Name    : String;
      Source  : String;
      Width   : Positive := Default_Width;
      Height  : Positive := Default_Height;
      Density : Float := 2.0)
   is
      Session : Viewer.Session;
      Drawn   : Images.Image;
   begin
      Viewer.Open (Session, Source, Width, Height, Density);
      Viewer.New_Project (Session);
      Viewer.Render (Session, Drawn);
      Goldens.Check (Name, Drawn);
   end Show;

   --  The tests

   procedure Empty is
   begin
      Show ("empty", "");
   end Empty;

   procedure Top_Of_Sample is
   begin
      Show ("sample", Sample);
   end Top_Of_Sample;

   procedure Low_Density is
   begin
      Show ("sample-1x", Sample, Density => 1.0);
   end Low_Density;

   procedure Narrow_Window is
   begin
      --  Narrower than the page, which so starts at the margin.
      Show ("narrow", Sample, Width => 300);
   end Narrow_Window;

   procedure Wide_Window is
   begin
      --  The page in the middle.
      Show ("wide", Sample, Width => 1000, Height => 300);
   end Wide_Window;

   procedure Other_Scripts is
   begin
      Show ("scripts", Scripts);
   end Other_Scripts;

   procedure Scrolled is
      Session : Viewer.Session;
      Drawn   : Images.Image;
   begin
      Viewer.Open (Session, Sample, Default_Width, Default_Height);
      Viewer.New_Project (Session);
      Press (Session, Events.Key_Page_Down, Times => 3);
      Viewer.Render (Session, Drawn);
      Goldens.Check ("page-down", Drawn);

      Press (Session, Events.Key_Down_Arrow, Times => 2);
      Viewer.Handle (Session, Wheel (-2.0));
      Viewer.Render (Session, Drawn);
      Goldens.Check ("arrows-and-wheel", Drawn);

      Press (Session, Events.Key_End);
      Viewer.Render (Session, Drawn);
      Goldens.Check ("end", Drawn);
   end Scrolled;

   procedure Back_Home is
      Fresh, Session : Viewer.Session;
      Expected, Drawn : Images.Image;
   begin
      --  Scrolling to the end lays out all between, which changes the
      --  page's height, but not the top of it.
      Viewer.Open (Fresh, Sample, Default_Width, Default_Height);
      Viewer.New_Project (Fresh);
      Viewer.Render (Fresh, Expected);

      Viewer.Open (Session, Sample, Default_Width, Default_Height);
      Viewer.New_Project (Session);
      Press (Session, Events.Key_End);
      Viewer.Render (Session, Drawn);
      Press (Session, Events.Key_Home);
      Viewer.Render (Session, Drawn);
      Goldens.Check_Same ("home-after-end", Expected, Drawn);
   end Back_Home;

   procedure Zoomed is
      Session : Viewer.Session;
      Drawn   : Images.Image;
   begin
      Viewer.Open (Session, Sample, Default_Width, Default_Height);
      Viewer.New_Project (Session);
      Zoom_In (Session, 4);
      Viewer.Render (Session, Drawn);
      Goldens.Check ("zooming-in", Drawn);
      --  Glyphs made at a nearby size, scaled.

      Viewer.Settle (Session);
      Viewer.Render (Session, Drawn);
      Goldens.Check ("zoomed-in", Drawn);

      Zoom_Out (Session, 10);
      Viewer.Settle (Session);
      Viewer.Render (Session, Drawn);
      Goldens.Check ("zoomed-out", Drawn);
   end Zoomed;

   procedure Resized is
      Session : Viewer.Session;
      Drawn   : Images.Image;
   begin
      Viewer.Open (Session, Sample, Default_Width, Default_Height);
      Viewer.New_Project (Session);
      Viewer.Render (Session, Drawn);
      Viewer.Resize (Session, 400, 600);
      Viewer.Render (Session, Drawn);
      Goldens.Check ("resized", Drawn);
   end Resized;

   procedure Atlas_Order (Settled : Boolean) is
      Fresh, Session : Viewer.Session;
      Expected, Drawn : Images.Image;
   begin
      --  The same glyphs, placed in the atlas in another order after
      --  others, must look the same: smoothing them, when scaled, must
      --  not take in their neighbours.
      Viewer.Open (Fresh, Sample, Default_Width, Default_Height);
      Viewer.New_Project (Fresh);
      Zoom_In (Fresh, 3);
      if Settled then
         Viewer.Settle (Fresh);
      end if;
      Viewer.Render (Fresh, Expected);

      Viewer.Open (Session, Sample, Default_Width, Default_Height);
      Viewer.New_Project (Session);
      Zoom_In (Session, 3);
      if Settled then
         Viewer.Settle (Session);
      end if;
      Press (Session, Events.Key_End);
      Viewer.Render (Session, Drawn);
      Press (Session, Events.Key_Page_Up, Times => 5);
      Viewer.Render (Session, Drawn);
      Press (Session, Events.Key_Home);
      Viewer.Render (Session, Drawn);
      Goldens.Check_Same
        ((if Settled then "atlas-order-settled" else "atlas-order-zooming"),
         Expected, Drawn);
   end Atlas_Order;

   procedure Atlas_Order_Settled is
   begin
      Atlas_Order (Settled => True);
   end Atlas_Order_Settled;

   procedure Atlas_Order_Zooming is
   begin
      Atlas_Order (Settled => False);
   end Atlas_Order_Zooming;

   procedure Edited is
      Session : Viewer.Session;
      Drawn   : Images.Image;
   begin
      --  The text area has the focus to start with.
      Viewer.Open (Session, Sample, Default_Width, Default_Height);
      Viewer.New_Project (Session);
      Press (Session, Events.Key_Delete, Times => 3);
      Viewer.Handle (Session, Events.Text_Event ("Skua"));
      Press (Session, Events.Key_Return);
      Viewer.Render (Session, Drawn);
      Goldens.Check ("edited", Drawn);
      Goldens.Check_Text
        ("edited-text",
         "Skua" & ASCII.LF & Sample (Sample'First + 3 .. Sample'Last),
         Viewer.Text (Session));
   end Edited;

   procedure Unfocused is
      Session : Viewer.Session;
      Drawn   : Images.Image;
   begin
      --  A click on the toolbar takes the focus from the text area, which
      --  then no longer takes typing.
      Viewer.Open (Session, "Bonxie", Default_Width, Default_Height);
      Viewer.New_Project (Session);
      Viewer.Handle (Session, Click (100.0, Float (Default_Height - 10)));
      Viewer.Handle (Session, Events.Text_Event ("Skua"));
      Viewer.Render (Session, Drawn);
      Goldens.Check ("unfocused", Drawn);
      Goldens.Check_Text ("unfocused-text", "Bonxie", Viewer.Text (Session));

      --  A click in it gives it back.
      Viewer.Handle (Session, Click (200.0, 100.0));
      Viewer.Handle (Session, Events.Text_Event ("Skua"));
      Goldens.Check_Text
        ("refocused-text", "BonxieSkua", Viewer.Text (Session));
   end Unfocused;

   procedure Saved is
      File    : constant String := Goldens.Scratch ("saved.txt");
      Session : Viewer.Session;
   begin
      Viewer.Open
        (Session, "Bonxie", Default_Width, Default_Height,
         File_Name => File);
      Viewer.New_Project (Session);
      Goldens.Check_Text ("saved-title-loaded", "saved.txt",
                          Viewer.Title (Session));
      Press (Session, Events.Key_Down_Arrow, Command => True);
      Viewer.Handle (Session, Events.Text_Event (" skua"));
      Goldens.Check_Text (Name => "saved-title-edited",
                          Expected => "saved.txt " & Em_Dash & " Edited",
                          Actual => Viewer.Title (Session));

      Press (Session, Events.Key_S, Command => True);
      Goldens.Check_Text ("saved-title-saved", "saved.txt",
                          Viewer.Title (Session));
      Goldens.Check_Text ("saved-file", "Bonxie skua", Files.Read (File));

      --  Undone, it is not as saved; redone, it is again.
      Press (Session, Events.Key_Z, Command => True);
      Goldens.Check_Text ("saved-title-undone",
                          "saved.txt " & Em_Dash & " Edited",
                          Viewer.Title (Session));
      Press (Session, Events.Key_Z, Command => True, Shift => True);
      Goldens.Check_Text ("saved-title-redone", "saved.txt",
                          Viewer.Title (Session));
   end Saved;

   procedure Clipboard is
      Session : Viewer.Session;
   begin
      --  Its own clipboard, offscreen.
      Viewer.Open (Session, "Great skua", Default_Width, Default_Height);
      Viewer.New_Project (Session);
      Press (Session, Events.Key_A, Command => True);
      Press (Session, Events.Key_C, Command => True);
      Press (Session, Events.Key_Down_Arrow, Command => True);
      Press (Session, Events.Key_V, Command => True);
      Goldens.Check_Text
        ("clipboard-text", "Great skuaGreat skua", Viewer.Text (Session));
   end Clipboard;

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

   Run ("empty", Empty'Access);
   Run ("sample", Top_Of_Sample'Access);
   Run ("sample-1x", Low_Density'Access);
   Run ("narrow", Narrow_Window'Access);
   Run ("wide", Wide_Window'Access);
   Run ("scripts", Other_Scripts'Access);
   Run ("scrolled", Scrolled'Access);
   Run ("home-after-end", Back_Home'Access);
   Run ("zoomed", Zoomed'Access);
   Run ("resized", Resized'Access);
   Run ("atlas-order-settled", Atlas_Order_Settled'Access);
   Run ("atlas-order-zooming", Atlas_Order_Zooming'Access);
   Run ("edited", Edited'Access);
   Run ("unfocused", Unfocused'Access);
   Run ("saved", Saved'Access);
   Run ("clipboard", Clipboard'Access);
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
