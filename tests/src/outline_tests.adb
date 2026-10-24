with Pomarine.Page_Builds;
with Pomarine.Themes;
with Section_Colour_Pickers;
with Preferences;
with Pomarine.Events;
with Goldens;
with Projects;
with View;
with View.Home_Screen;
with Items;
with View.Canvas_Windows;
with View.Documents;
with View.Outline_Screen;
with View.Project_Screen;
with View.Settings;

package body Outline_Tests is

   package Events renames Pomarine.Events;
   package Home renames View.Home_Screen;
   package Proj renames View.Project_Screen;
   package Prefs renames View.Settings;
   package Windows renames View.Canvas_Windows;
   package Docs renames View.Documents;
   package Outline renames View.Outline_Screen;
   package Pictures renames Goldens.Images;

   procedure Check (Name : String; Expected, Actual : String)
     renames Goldens.Check_Text;

   Width  : constant := 720;
   Height : constant := 480;
   --  Of the window, in points; the toolbar is 44 high at the top.

   procedure Start (Session : in out View.Session) is
   begin
      View.Open (Session, "", Width, Height, 2.0);
      Home.New_Project (Session);
   end Start;

   procedure Type_In (Session : in out View.Session; Text : String) is
   begin
      View.Handle (Session, Events.Text_Event (Text));
   end Type_In;

   procedure Move_To
     (Session : in out View.Session; X, Y : Float; Held : Boolean := False) is
   begin
      View.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Move, Mouse_X => X,
                                Mouse_Y => Y, Left_Held => Held, others => <>));
   end Move_To;

   procedure Press (Session : in out View.Session; X, Y : Float) is
   begin
      View.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Down, Button => 1, Clicks => 1,
                                Mouse_X => X, Mouse_Y => Y, others => <>));
   end Press;

   procedure Release (Session : in out View.Session; X, Y : Float) is
   begin
      View.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Up, Button => 1, Clicks => 1,
                                Mouse_X => X, Mouse_Y => Y, others => <>));
   end Release;

   procedure Settle (Session : in out View.Session) is
      Drawn : Pictures.Image;
   begin
      --  Drawn, as it is between a person's clicks: what was typed is kept.
      View.Tick (Session, 0);
      View.Render (Session, Drawn);
      Pomarine.Page_Builds.Wait_Until_Idle;
      View.Handle (Session, (Kind => Events.Redraw, others => <>));
   end Settle;

   procedure Snap (Session : in out View.Session; Name : String) is
      Drawn : Pictures.Image;
   begin
      Settle (Session);
      View.Render (Session, Drawn);
      Goldens.Check (Name, Drawn);
   end Snap;

   function Titles (Session : View.Session) return String is
      Result : String (1 .. 4096);
      Last   : Natural := 0;
   begin
      for Row in 1 .. Outline.Section_Count (Session) loop
         declare
            Title : constant String := Outline.Section_Title (Session, Row);
         begin
            Result (Last + 1 .. Last + Title'Length + 1) := Title & "|";
            Last := Last + Title'Length + 1;
         end;
      end loop;
      return Result (1 .. Last);
   end Titles;

   function Owners_Of (Session : View.Session) return String is
      Result : String (1 .. 512);
      Last   : Natural := 0;
   begin
      for Row in 1 .. Outline.Section_Count (Session) loop
         declare
            Owner : constant String := Outline.Section_Item (Session, Row) & "|";
         begin
            Result (Last + 1 .. Last + Owner'Length) := Owner;
            Last := Last + Owner'Length;
         end;
      end loop;
      return Result (1 .. Last);
   end Owners_Of;

   procedure Reopen (Session : in out View.Session) is
      Key : constant Projects.Id := Proj.Current_Project (Session);
   begin
      Proj.Close_Project (Session);
      Home.Open_Project (Session, Key);
   end Reopen;

   procedure Starting is
      Session : View.Session;
   begin
      Start (Session);
      --  A project opens to its outline, the first of the tabs.
      Check ("outline-mode", "OUTLINE", View.Modes'Image (Proj.Mode (Session)));
      Check ("outline-none", "", Titles (Session));
      Snap (Session, "outline-empty");

      --  The tab last chosen is the one it opens to.
      Proj.Set_Mode (Session, View.Write);
      Reopen (Session);
      Check ("outline-mode-write", "WRITE", View.Modes'Image (Proj.Mode (Session)));
      Proj.Set_Mode (Session, View.Canvas);
      Reopen (Session);
      Check ("outline-mode-canvas", "CANVAS", View.Modes'Image (Proj.Mode (Session)));
      Proj.Set_Mode (Session, View.Outline);
      Reopen (Session);
      Check ("outline-mode-outline", "OUTLINE", View.Modes'Image (Proj.Mode (Session)));
   end Starting;

   procedure Colours is
      Session : View.Session;
      Saved : Natural;
      Before_Slider : Natural;

      procedure Click (X, Y : Float) is
      begin
         Move_To (Session, X, Y);
         Press (Session, X, Y);
         Release (Session, X, Y);
         Settle (Session);
      end Click;
   begin
      declare
         Picker : Section_Colour_Pickers.Picker;
         Theme : constant Pomarine.Themes.Theme := Pomarine.Themes.Light;
         type Colour_Array is array (Positive range <>) of Pomarine.Themes.Color;
         Samples : constant Colour_Array := [(0, 0, 0, 255), (255, 255, 255, 255), (17, 139, 203, 255)];
         use type Pomarine.Themes.Color;
      begin
         for Sample of Samples loop
            Section_Colour_Pickers.Set_Colour (Picker, Sample);
            Check ("outline-colour-exact-rgb",
                   Natural'Image (12 + Natural (Sample.Red) * 65536
                     + Natural (Sample.Green) * 256 + Natural (Sample.Blue)),
                   Section_Colour_Pickers.Colour (Picker)'Image);
            Check ("outline-colour-fixed-roundtrip", "TRUE",
                   Boolean'Image (Theme (Pomarine.Themes.Fixed (Sample)) = Sample));
         end loop;
      end;
      Start (Session);
      Outline.Add_Section (Session);
      Type_In (Session, "Colour choice");
      Settle (Session);
      Move_To (Session, 414.0, 122.0);
      Snap (Session, "outline-colour-hover");
      Click (414.0, 122.0);
      Snap (Session, "outline-colour-picker");
      Click (550.0, 310.0);
      Click (460.0, 390.0);
      Check ("outline-colour-cancel", " 0", Outline.Section_Colour (Session, 1)'Image);
      Click (414.0, 122.0);
      Click (550.0, 310.0);
      Click (640.0, 250.0);
      Snap (Session, "outline-colour-selected");
      Click (590.0, 390.0);
      Saved := Outline.Section_Colour (Session, 1);
      Check ("outline-colour-unrestricted", "TRUE", Boolean'Image (Saved >= 12));
      Click (414.0, 122.0);
      Click (590.0, 390.0);
      Check ("outline-colour-unchanged-ok", Saved'Image, Outline.Section_Colour (Session, 1)'Image);
      Reopen (Session);
      Check ("outline-colour-kept", Saved'Image, Outline.Section_Colour (Session, 1)'Image);
      Before_Slider := Saved;
      Click (414.0, 122.0);
      Click (640.0, 180.0);
      Click (590.0, 390.0);
      Check ("outline-colour-slider", "TRUE",
             Boolean'Image (Outline.Section_Colour (Session, 1) /= Before_Slider));
      Snap (Session, "outline-colour-kept");
   end Colours;

   procedure Sections is
      Session : View.Session;
   begin
      Start (Session);
      Outline.Add_Section (Session);
      Type_In (Session, "Beginning");
      Settle (Session);
      Outline.Add_Section (Session);
      Type_In (Session, "Middle");
      Settle (Session);
      Outline.Add_Section (Session);
      Type_In (Session, "End");
      Settle (Session);
      Check ("outline-added", "Beginning|Middle|End|", Titles (Session));
      Snap (Session, "outline-sections");

      Outline.Move_Section (Session, 3, 1);
      Check ("outline-moved", "End|Beginning|Middle|", Titles (Session));
      Snap (Session, "outline-moved");
      Outline.Move_Section (Session, 1, 2);
      Check ("outline-moved-down", "Beginning|End|Middle|", Titles (Session));

      --  Dragged by the handle of the first, over the second, and let go
      --  below the last: with a ghost of it under the pointer.
      Move_To (Session, 385.0, 122.0);
      Press (Session, 385.0, 122.0);
      Move_To (Session, 385.0, 150.0, Held => True);
      Move_To (Session, 385.0, 235.0, Held => True);
      Snap (Session, "outline-dragging");
      Release (Session, 385.0, 235.0);
      Settle (Session);
      Check ("outline-dragged", "End|Middle|Beginning|", Titles (Session));
      Outline.Move_Section (Session, 3, 1);
      Check ("outline-dragged-back", "Beginning|End|Middle|", Titles (Session));

      Outline.Remove_Section (Session, 2);
      Check ("outline-removed", "Beginning|Middle|", Titles (Session));

      --  Kept, in that order.
      Reopen (Session);
      Check ("outline-kept", "Beginning|Middle|", Titles (Session));
      Outline.Move_Section (Session, 2, 1);
      Reopen (Session);
      Check ("outline-order-kept", "Middle|Beginning|", Titles (Session));
   end Sections;

   procedure Many_Sections is
      Session : View.Session;
      Many    : constant := 90;
      Long    : constant String (1 .. 300) := [others => 'w'];
   begin
      Start (Session);
      for Each in 1 .. Many - 1 loop
         Outline.Add_Section (Session);
      end loop;
      --  A long title is not cut.
      Outline.Add_Section (Session);
      for Part in 0 .. 2 loop
         Type_In (Session, Long (Part * 100 + 1 .. Part * 100 + 100));
      end loop;
      Settle (Session);
      Check ("outline-many", Natural'Image (Many), Natural'Image (Outline.Section_Count (Session)));
      Reopen (Session);
      Check ("outline-many-kept", Natural'Image (Many), Natural'Image (Outline.Section_Count (Session)));
      Check ("outline-long-title", Natural'Image (Long'Length),
             Natural'Image (Outline.Section_Title (Session, Many)'Length));
   end Many_Sections;

   procedure Form is
      Session : View.Session;
   begin
      Start (Session);
      Check ("outline-form-title", "Untitled project", Outline.Project_Title (Session));
      Check ("outline-form-description", "", Outline.Project_Description (Session));
   end Form;

   procedure Notes is
      Session : View.Session;
   begin
      Start (Session);
      Outline.Add_Section (Session);
      Type_In (Session, "Beginning");
      Settle (Session);
      Outline.Add_Section (Session);
      Type_In (Session, "End");
      Settle (Session);
      Check ("outline-notes-hidden", "FALSE", Boolean'Image (Outline.Notes_Shown (Session, 1)));
      Check ("outline-notes-none", "", Outline.Section_Notes (Session, 1));
      Snap (Session, "outline-notes-closed");

      --  Shown, and typed in, they are kept.
      Outline.Toggle_Notes (Session, 1);
      Check ("outline-notes-shown", "TRUE", Boolean'Image (Outline.Notes_Shown (Session, 1)));
      Type_In (Session, "- Open with a story");
      Settle (Session);
      Check ("outline-notes-typed", "- Open with a story", Outline.Section_Notes (Session, 1));
      Snap (Session, "outline-notes-open");

      --  Hidden, they are still kept; they go with the section.
      Outline.Toggle_Notes (Session, 1);
      Check ("outline-notes-hid", "FALSE", Boolean'Image (Outline.Notes_Shown (Session, 1)));
      Outline.Move_Section (Session, 1, 2);
      Check ("outline-notes-moved", "- Open with a story", Outline.Section_Notes (Session, 2));
      Check ("outline-notes-moved-away", "", Outline.Section_Notes (Session, 1));
      Reopen (Session);
      Check ("outline-notes-kept", "- Open with a story", Outline.Section_Notes (Session, 2));
      --  A section that has notes shows them when the project is opened.
      Check ("outline-notes-kept-shown", "TRUE", Boolean'Image (Outline.Notes_Shown (Session, 2)));
      Check ("outline-notes-kept-empty", "FALSE", Boolean'Image (Outline.Notes_Shown (Session, 1)));

   end Notes;

   procedure Linking is
      Session : View.Session;

      function Rows return String is
         Result : String (1 .. 64);
         Last   : Natural := 0;
      begin
         for Row in 2 .. Outline.Link_Menu_Rows (Session) loop
            Last := Last + 1;
            Result (Last) :=
              (if Outline.Link_Menu_Row_Checked (Session, Row) then 'x'
               elsif Outline.Link_Menu_Row_Enabled (Session, Row) then '.'
               else '-');
         end loop;
         return Result (1 .. Last);
      end Rows;

      function Owners return String is (Owners_Of (Session));
   begin
      Start (Session);
      Outline.Add_Section (Session);
      Type_In (Session, "Beginning");
      Settle (Session);
      Outline.Add_Section (Session);
      Type_In (Session, "Middle");
      Settle (Session);
      Outline.Add_Section (Session);
      Type_In (Session, "End");
      Settle (Session);
      --  Each is given a colour of its own.
      Check ("link-colours", " 0 1 2",
             Outline.Section_Colour (Session, 1)'Image & Outline.Section_Colour (Session, 2)'Image
             & Outline.Section_Colour (Session, 3)'Image);
      Snap (Session, "outline-unlinked");

      Proj.Set_Mode (Session, View.Canvas);
      Windows.Add_Item (Session, "Closing");
      Windows.Add_Item (Session, "Opening");

      --  Every section is in the menu.
      Outline.Open_Link_Menu (Session, 2);
      Check ("link-menu-rows", "...", Rows);
      Snap (Session, "link-menu");
      Outline.Choose_Link_Row (Session, 2);
      Check ("link-owners", "Opening,|||", Owners);

      --  A section has as many items as are linked to it.
      Outline.Open_Link_Menu (Session, 1);
      Check ("link-menu-shared", "...", Rows);
      Outline.Choose_Link_Row (Session, 2);
      Check ("link-shared", "Closing,Opening,|||", Owners);
      --  And an item is of one: it is moved.
      Outline.Open_Link_Menu (Session, 1);
      Check ("link-menu-own-first", "x....", Rows);
      Outline.Choose_Link_Row (Session, 3);
      Check ("link-moved", "Opening,|Closing,||", Owners);
      Settle (Session);
      Snap (Session, "link-canvas");

      --  Ticked for its own, with a row to take the link away: the boxes,
      --  a line, and that.
      Outline.Open_Link_Menu (Session, 2);
      Check ("link-menu-own", "x....", Rows);
      Snap (Session, "link-menu-own");
      Outline.Open_Link_Menu (Session, 2);

      --  Kept, and shown in the writing view.
      Proj.Set_Mode (Session, View.Write);
      Snap (Session, "link-write");
      Reopen (Session);
      Proj.Set_Mode (Session, View.Outline);
      Check ("link-kept", "Opening,|Closing,||", Owners);
      Snap (Session, "outline-linked");

      --  Ticked again, it is let go.
      Proj.Set_Mode (Session, View.Canvas);
      Outline.Open_Link_Menu (Session, 2);
      Outline.Choose_Link_Row (Session, 2);
      Check ("link-let-go", "|Closing,||", Owners);

      --  The colours are softer on the dark theme.
      Outline.Open_Link_Menu (Session, 2);
      Outline.Choose_Link_Row (Session, 2);
      declare
         Key : constant Projects.Id := Proj.Current_Project (Session);
      begin
         Proj.Close_Project (Session);
         Prefs.Open_Settings (Session);
         Prefs.Choose_Theme (Session, Preferences.Dark);
         Prefs.Close_Settings (Session);
         Home.Open_Project (Session, Key);
      end;
      Proj.Set_Mode (Session, View.Outline);
      Snap (Session, "outline-linked-dark");
      Proj.Set_Mode (Session, View.Canvas);
      Outline.Open_Link_Menu (Session, 2);
      Snap (Session, "link-menu-dark");
   end Linking;

   procedure Sidebar is
      Session : View.Session;
      Folder  : constant String := "/tmp/bonxie-sidebar-test";
   begin
      Start (Session);
      Proj.Set_Mode (Session, View.Write);
      Check ("sidebar-begins", "206", Natural (Docs.Sidebar_Width (Session))'Image (2 .. 4));
      --  Its edge is dragged, and the pages have what is left.
      Move_To (Session, 209.0, 400.0);
      Press (Session, 209.0, 400.0);
      Move_To (Session, 250.0, 400.0, Held => True);
      Move_To (Session, 309.0, 400.0, Held => True);
      Snap (Session, "sidebar-wide");
      Release (Session, 309.0, 400.0);
      Check ("sidebar-wider", "306", Natural (Docs.Sidebar_Width (Session))'Image (2 .. 4));
      --  Not narrower than it can be used.
      Press (Session, 309.0, 400.0);
      Move_To (Session, 100.0, 400.0, Held => True);
      Move_To (Session, 0.0, 400.0, Held => True);
      Release (Session, 0.0, 400.0);
      Check ("sidebar-narrowest", "200", Natural (Docs.Sidebar_Width (Session))'Image (2 .. 4));
      Snap (Session, "sidebar-narrow");

      --  What is kept with the settings.
      Check ("sidebar-none-kept", "0", Preferences.Load_Sidebar_Width (Folder & "-none")'Image (2 .. 2));
      Preferences.Save_Sidebar_Width (Folder, 333);
      Check ("sidebar-kept", "333", Preferences.Load_Sidebar_Width (Folder)'Image (2 .. 4));
   end Sidebar;

   procedure Tiers is
      Session : View.Session;

      procedure Section (Name : String) is
      begin
         Outline.Add_Section (Session);
         Type_In (Session, Name);
         Settle (Session);
      end Section;

      function Order return String is
         Result : String (1 .. 256);
         Last   : Natural := 0;
      begin
         for Row in 1 .. Docs.Document_Count (Session) loop
            declare
               Name : constant String := Docs.Document_Title (Session, Row) & "|";
            begin
               Result (Last + 1 .. Last + Name'Length) := Name;
               Last := Last + Name'Length;
            end;
         end loop;
         return Result (1 .. Last);
      end Order;

      procedure Drag (From_Y, To_Y : Float; Name : String := "") is
      begin
         Move_To (Session, 120.0, From_Y);
         Press (Session, 120.0, From_Y);
         Move_To (Session, 140.0, (From_Y + To_Y) / 2.0, Held => True);
         Move_To (Session, 160.0, To_Y, Held => True);
         if Name /= "" then
            Snap (Session, Name);
         end if;
         Release (Session, 120.0, To_Y);
         Settle (Session);
      end Drag;
   begin
      Start (Session);
      Section ("Beginning");
      Section ("Middle");
      Section ("End");
      Proj.Set_Mode (Session, View.Canvas);
      Windows.Add_Item (Session, "Alpha");
      Windows.Add_Item (Session, "Loose");
      Windows.Add_Item (Session, "Bravo");
      Windows.Add_Item (Session, "Charlie");
      Outline.Open_Link_Menu (Session, 1);
      Outline.Choose_Link_Row (Session, 2);
      Outline.Open_Link_Menu (Session, 3);
      Outline.Choose_Link_Row (Session, 2);
      Outline.Open_Link_Menu (Session, 4);
      Outline.Choose_Link_Row (Session, 4);
      Proj.Set_Mode (Session, View.Write);
      Snap (Session, "tiers-tree");

      --  The order is of the first tier (the sections and what is of none)
      --  and then of each section's own, and is the same one to read down.
      Check ("tiers-order", "Loose|Alpha|Bravo|Charlie|", Order);

      --  Within a section, a document is dragged above its neighbour;
      --  and the ghost is the row, under the pointer.
      Drag (327.0, 289.0, "tiers-ghost");
      Check ("tiers-reordered", "Loose|Bravo|Alpha|Charlie|", Order);
      Check ("tiers-owners", "Alpha,Bravo,||Charlie,|", Owners_Of (Session));

      --  A section cannot be dragged, nor can it come after a document.
      Drag (251.0, 440.0);
      Check ("tiers-section-fixed", "Loose|Bravo|Alpha|Charlie|", Order);

      --  Put among another section's, a document is made its own.
      Docs.Move_Document (Session, 4, 2);
      Check ("tiers-moved-in", "Loose|Charlie|Bravo|Alpha|", Order);
      Check ("tiers-moved-owners", "Alpha,Bravo,Charlie,|||", Owners_Of (Session));

      Reopen (Session);
      Proj.Set_Mode (Session, View.Write);
      Check ("tiers-kept", "Loose|Charlie|Bravo|Alpha|", Order);
   end Tiers;

   procedure Section_Rows is
      Session : View.Session;

      procedure Section (Name : String) is
      begin
         Outline.Add_Section (Session);
         Type_In (Session, Name);
         Settle (Session);
      end Section;

      procedure Click_Row (Y : Float; Button : Natural; Clicks : Natural) is
      begin
         Move_To (Session, 100.0, Y);
         View.Handle
           (Session, Events.Event'(Kind => Events.Mouse_Down, Button => Button, Clicks => Clicks,
                                   Mouse_X => 100.0, Mouse_Y => Y, others => <>));
         View.Handle
           (Session, Events.Event'(Kind => Events.Mouse_Up, Button => Button, Clicks => Clicks,
                                   Mouse_X => 100.0, Mouse_Y => Y, others => <>));
      end Click_Row;
   begin
      Start (Session);
      Section ("Beginning");
      Section ("End");
      Proj.Set_Mode (Session, View.Write);
      Snap (Session, "write-section-rows");

      --  Right click: it can be renamed, not deleted.
      Click_Row (239.0, 3, 1);
      Snap (Session, "write-section-context");
      Click_Row (400.0, 1, 1);

      --  Pressed twice, it is renamed in place, and the name is the
      --  section's wherever it is shown.
      Click_Row (239.0, 1, 2);
      Type_In (Session, "Opening");
      View.Handle (Session, Events.Event'(Kind => Events.Key_Down, Key => Events.Key_Return, others => <>));
      Settle (Session);
      Check ("section-renamed", "Opening|End|", Titles (Session));
      Snap (Session, "write-section-renamed");
      Reopen (Session);
      Check ("section-rename-kept", "Opening|End|", Titles (Session));
   end Section_Rows;

   procedure Write_Notes is
      Session : View.Session;
      X, Y    : Float;

      procedure Click_Notes (Row : Positive) is
      begin
         Outline.Write_Notes_Point (Session, Row, X, Y);
         Move_To (Session, X, Y);
         Press (Session, X, Y);
         Release (Session, X, Y);
         Settle (Session);
      end Click_Notes;
   begin
      Start (Session);
      Outline.Add_Section (Session);
      Type_In (Session, "Beginning");
      Settle (Session);
      Outline.Add_Section (Session);
      Type_In (Session, "End");
      Settle (Session);
      Proj.Set_Mode (Session, View.Canvas);
      Windows.Add_Item (Session, "First words");
      Outline.Open_Link_Menu (Session, 1);
      Outline.Choose_Link_Row (Session, 2);
      Proj.Set_Mode (Session, View.Write);
      Settle (Session);
      Snap (Session, "write-notes-closed");

      --  Shown after the heading and before the documents, and typed in.
      Click_Notes (1);
      Check ("write-notes-shown", "TRUE", Boolean'Image (Outline.Notes_Shown (Session, 1)));
      Type_In (Session, "- Open with a story");
      Settle (Session);
      Check ("write-notes-typed", "- Open with a story", Outline.Section_Notes (Session, 1));
      Snap (Session, "write-notes-open");

      --  Put away, they are still kept.
      Click_Notes (1);
      Check ("write-notes-hidden", "FALSE", Boolean'Image (Outline.Notes_Shown (Session, 1)));
      Snap (Session, "write-notes-one-hidden");

      --  A section with no documents shows them above its button.
      View.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Wheel, Wheel_Y => -400.0, Mouse_X => 500.0,
                                Mouse_Y => 300.0, others => <>));
      Settle (Session);
      Click_Notes (2);
      Type_In (Session, "Wrap up");
      Settle (Session);
      Check ("write-notes-second", "Wrap up", Outline.Section_Notes (Session, 2));
      Snap (Session, "write-notes-empty-section");

      Reopen (Session);
      Check ("write-notes-kept", "- Open with a story", Outline.Section_Notes (Session, 1));
      Check ("write-notes-kept-second", "Wrap up", Outline.Section_Notes (Session, 2));
      --  Not being typed in, the notes have no outline of their own.
      View.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Wheel, Wheel_Y => 600.0, Mouse_X => 500.0,
                                Mouse_Y => 300.0, others => <>));
      Snap (Session, "write-notes-reopened");
   end Write_Notes;

   procedure Writing_Sections is
      Session : View.Session;

      procedure Section (Name : String) is
      begin
         Outline.Add_Section (Session);
         Type_In (Session, Name);
         Settle (Session);
      end Section;

      procedure Link (Slot : Positive; Row : Positive) is
      begin
         Outline.Open_Link_Menu (Session, Items.Slot (Slot));
         Outline.Choose_Link_Row (Session, Row + 1);
      end Link;
   begin
      Start (Session);
      Section ("Beginning");
      Section ("Middle");
      Section ("End");
      Proj.Set_Mode (Session, View.Canvas);
      Windows.Add_Item (Session, "Notes one");
      Windows.Add_Item (Session, "Loose");
      Windows.Add_Item (Session, "Notes two");
      Windows.Add_Item (Session, "Last words");
      --  Two documents are of the first section, one of the last, and the
      --  second, in between, of none; the middle section has none.
      Link (1, 1);
      Link (3, 1);
      Link (4, 3);
      Proj.Set_Mode (Session, View.Write);
      Snap (Session, "write-sections");
      --  What is on a page, in the sections, is used: the text takes the
      --  pointer and what is typed, and so do the buttons of its bar.
      Move_To (Session, 450.0, 300.0);
      Press (Session, 450.0, 300.0);
      Release (Session, 450.0, 300.0);
      Type_In (Session, "x");
      Check ("write-sections-text", "x", Windows.Item_Text (Session, 2));
      Move_To (Session, 460.0, 116.0);
      Press (Session, 460.0, 116.0);
      Release (Session, 460.0, 116.0);
      Check ("write-sections-button", "TRUE", Outline.Link_Menu_Open (Session)'Image);
      Press (Session, 600.0, 400.0);
      Release (Session, 600.0, 400.0);
      for Step in 1 .. 4 loop
         View.Handle
           (Session, Events.Event'(Kind => Events.Mouse_Wheel, Wheel_Y => -17.0, Mouse_X => 500.0,
                                   Mouse_Y => 300.0, others => <>));
         Snap (Session, "write-sections-down-" & Character'Val (Character'Pos ('0') + Step));
      end loop;
      View.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Wheel, Wheel_Y => 200.0, Mouse_X => 500.0,
                                Mouse_Y => 300.0, others => <>));

      --  Order is the documents' own: moving one changes where the
      --  documents that are of none come, but not which section is first.
      Docs.Move_Document (Session, 2, 4);
      Snap (Session, "write-sections-moved");
      Docs.Move_Document (Session, 4, 2);

      --  The button of a section with none writes one, of it.
      Docs.Add_For_Section (Session, 2);
      Check ("write-section-added", "5", Docs.Document_Count (Session)'Image (2 .. 2));
      Check ("write-section-owners", "Notes one,Notes two,|Middle,|Last words,|",
             Owners_Of (Session));
      Snap (Session, "write-sections-added");

      --  The button by the count of a section's documents writes another,
      --  last among them; a section with none has no such button.
      View.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Wheel, Wheel_Y => 400.0, Mouse_X => 500.0,
                                Mouse_Y => 300.0, others => <>));
      View.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Wheel, Wheel_Y => -17.0, Mouse_X => 500.0,
                                Mouse_Y => 300.0, others => <>));
      Settle (Session);
      Move_To (Session, 664.0, 65.0);
      Press (Session, 664.0, 65.0);
      Release (Session, 664.0, 65.0);
      Check ("write-heading-added", "6", Docs.Document_Count (Session)'Image (2 .. 2));
      Snap (Session, "write-heading-added");

   end Writing_Sections;

   procedure Section_Folders is
      Session : View.Session;

      function Y (Row : Positive) return Float is
        (200.5 + Float (Row - 1) * 38.0);

      procedure Drag (From, Into : Positive) is
      begin
         Move_To (Session, 100.0, Y (From));
         Press (Session, 100.0, Y (From));
         Move_To (Session, 102.0, Y (From), Held => True);
         Move_To (Session, 100.0, Y (Into), Held => True);
         Release (Session, 100.0, Y (Into));
         Settle (Session);
      end Drag;

      procedure Context_Folder (Row : Positive; Offset : Float) is
      begin
         View.Handle
           (Session, Events.Event'(Kind => Events.Mouse_Down, Button => 3, Clicks => 1,
                                   Mouse_X => 100.0, Mouse_Y => Y (Row), others => <>));
         View.Handle
           (Session, Events.Event'(Kind => Events.Mouse_Up, Button => 3, Clicks => 1,
                                   Mouse_X => 100.0, Mouse_Y => Y (Row), others => <>));
         Settle (Session);
         if Offset = 43.0 then
            Snap (Session, (if Row = 1 then "write-overview-folder-menu" else "write-folder-menu"));
         end if;
         Check ("folder-context-open", "TRUE", Docs.Context_Open (Session)'Image);
         View.Handle
           (Session, Events.Event'(Kind => Events.Key_Down, Key => Events.Key_Escape, others => <>));
         Check ("folder-context-escape", "FALSE", Docs.Context_Open (Session)'Image);
         View.Handle
           (Session, Events.Event'(Kind => Events.Mouse_Down, Button => 3, Clicks => 1,
                                   Mouse_X => 100.0, Mouse_Y => Y (Row), others => <>));
         View.Handle
           (Session, Events.Event'(Kind => Events.Mouse_Up, Button => 3, Clicks => 1,
                                   Mouse_X => 100.0, Mouse_Y => Y (Row), others => <>));
         Settle (Session);
         Press (Session, 140.0, Y (Row) + Offset);
         Release (Session, 140.0, Y (Row) + Offset);
         if Offset = 43.0 then
            View.Handle
              (Session, Events.Event'(Kind => Events.Key_Down, Key => Events.Key_Return, others => <>));
         end if;
         Settle (Session);
      end Context_Folder;

      procedure Folder (Name : String) is
      begin
         Docs.Add_Directory (Session, Name);
         View.Handle
           (Session, Events.Event'(Kind => Events.Key_Down, Key => Events.Key_Return, others => <>));
         Settle (Session);
      end Folder;
   begin
      Start (Session);
      Outline.Add_Section (Session);
      Type_In (Session, "Part");
      Settle (Session);
      Proj.Set_Mode (Session, View.Canvas);
      Windows.Add_Item (Session, "Draft");
      Proj.Set_Mode (Session, View.Write);
      Folder ("Research");
      Folder ("Other");
      --  Overview, loose document, section, and the two ordinary folders.
      Docs.Move_Document_To (Session, 1, 2);
      --  Overview, section, Research, Draft, Other.
      Drag (3, 2);
      Check ("folder-in-section", " 1", Docs.Directory_Parent (Session, 2)'Image);
      Check ("folder-section-links", "Draft,|", Owners_Of (Session));
      Reopen (Session);
      Check ("folder-parent-kept", " 1", Docs.Directory_Parent (Session, 2)'Image);
      Check ("folder-document-kept", "Research",
             Docs.Directory_Title (Session, Docs.Document_Directory (Session, 1)));
      Docs.Show_Directory (Session, 1);
      Folder ("Created inside");
      Check ("folder-created-in-section", " 1", Docs.Directory_Parent (Session, 4)'Image);
      Docs.Show_Directory (Session, 0);
      Settle (Session);
      --  Move the folder and its document out by dropping on Overview.
      Drag (3, 1);
      Check ("folder-outside-section", " 0", Docs.Directory_Parent (Session, 2)'Image);
      Check ("folder-unlinked-documents", "|", Owners_Of (Session));
      Reopen (Session);
      Check ("folder-outside-kept", "|", Owners_Of (Session));
      --  Ordinary folders can enter other folders, but never their descendants.
      Drag (4, 5);
      Check ("folder-nested", " 4", Docs.Directory_Parent (Session, 3)'Image);
      Drag (4, 6);
      Check ("folder-cycle-rejected", " 0", Docs.Directory_Parent (Session, 4)'Image);
      Drag (4, 3);
      Check ("folder-deep-section-link", "Draft,|", Owners_Of (Session));
      Reopen (Session);
      Check ("folder-deep-kept", "Draft,|", Owners_Of (Session));
      Check ("folder-grandchild-kept", " 3", Docs.Directory_Parent (Session, 4)'Image);
      Snap (Session, "write-nested-folders");

      --  Context creation uses the row clicked, even with another folder shown.
      Docs.Show_Directory (Session, 3);
      Context_Folder (1, 43.0);
      Check ("folder-overview-context", " 0", Docs.Directory_Parent (Session, 5)'Image);
      Context_Folder (4, 43.0);
      Check ("folder-folder-context", " 3", Docs.Directory_Parent (Session, 6)'Image);
      Reopen (Session);
      Check ("folder-context-kept", " 6", Docs.Directory_Count (Session)'Image);
      Context_Folder (4, 17.0);
      Check ("folder-add-document", " 2", Docs.Document_Count (Session)'Image);
      Check ("folder-document-target", " 3", Docs.Document_Directory (Session, 2)'Image);
      Context_Folder (1, 17.0);
      Check ("overview-add-document", " 3", Docs.Document_Count (Session)'Image);
      Check ("overview-document-target", " 0", Docs.Document_Directory (Session, 3)'Image);
   end Section_Folders;

   procedure Folder_Operations is
      Session : View.Session;
      Check_X, Check_Y, Delete_X, Delete_Y : Float;

      function Y (Row : Positive) return Float is
        (200.5 + Float (Row - 1) * 38.0);

      procedure Drag (From, Into : Positive; Offset : Float := 0.0) is
      begin
         Move_To (Session, 100.0, Y (From));
         Press (Session, 100.0, Y (From));
         Move_To (Session, 102.0, Y (From), Held => True);
         Move_To (Session, 100.0, Y (Into) + Offset, Held => True);
         Release (Session, 100.0, Y (Into) + Offset);
         Settle (Session);
      end Drag;

      procedure Click (X, Y : Float) is
      begin
         Move_To (Session, X, Y);
         Press (Session, X, Y);
         Release (Session, X, Y);
         Settle (Session);
      end Click;

      procedure Folder (Name : String) is
      begin
         Docs.Add_Directory (Session, Name);
         View.Handle
           (Session, Events.Event'(Kind => Events.Key_Down, Key => Events.Key_Return, others => <>));
         Settle (Session);
      end Folder;

      procedure Put (Name : String; Dir : Positive) is
      begin
         for Rank in 1 .. Docs.Document_Count (Session) loop
            if Docs.Document_Title (Session, Rank) = Name then
               Docs.Move_Document_To (Session, Rank, Dir);
               exit;
            end if;
         end loop;
         Settle (Session);
      end Put;

      procedure Ask (Dir : Positive) is
      begin
         Docs.Ask_Delete_Directory (Session, Dir);
         Docs.Deletion_Points (Session, Check_X, Check_Y, Delete_X, Delete_Y);
         Check ("folder-delete-default", "FALSE", Docs.Delete_Documents_Checked (Session)'Image);
      end Ask;
   begin
      View.Open (Session, "", Width, 640, 2.0);
      Home.New_Project (Session);
      Proj.Set_Mode (Session, View.Canvas);
      Windows.Add_Item (Session, "Alpha");
      Windows.Add_Item (Session, "Bravo");
      Windows.Add_Item (Session, "Outside");
      Proj.Set_Mode (Session, View.Write);
      Folder ("Outer");
      Folder ("Child");
      Folder ("Grandchild");
      Drag (5, 3, -8.0);
      Check ("folder-before-sibling-document", " 3", Docs.Directory_Row (Session, 1)'Image);
      Drag (3, 5, 8.0);
      Check ("folder-after-sibling-document", " 5", Docs.Directory_Row (Session, 1)'Image);
      Drag (7, 6);
      Drag (6, 5);
      Put ("Alpha", 1);
      Put ("Bravo", 3);
      --  The child folder also moves among documents inside Outer.
      Drag (4, 7, 8.0);
      Check ("folder-after-nested-sibling", " 5", Docs.Directory_Row (Session, 2)'Image);
      Check ("folder-sibling-parent-unchanged", " 1", Docs.Directory_Parent (Session, 2)'Image);
      Drag (5, 4, -8.0);
      Check ("folder-before-nested-sibling", " 4", Docs.Directory_Row (Session, 2)'Image);
      --  Overview, Outside, Outer and its subtree: move it before Outside.
      Drag (3, 2, -8.0);
      Check ("folder-block-before-document", " 2", Docs.Directory_Row (Session, 1)'Image);
      Reopen (Session);
      Check ("folder-sibling-order-kept", " 2", Docs.Directory_Row (Session, 1)'Image);
      Check ("folder-nested-sibling-order-kept", " 3", Docs.Directory_Row (Session, 2)'Image);
      Docs.Show_Directory (Session, 3);
      Ask (1);
      Snap (Session, "write-delete-folder-default");
      Click (Check_X, Check_Y);
      Check ("folder-delete-checkbox", "TRUE", Docs.Delete_Documents_Checked (Session)'Image);
      View.Handle
        (Session, Events.Event'(Kind => Events.Key_Down, Key => Events.Key_Escape, others => <>));
      Check ("folder-delete-cancel-subtree", " 3", Docs.Directory_Count (Session)'Image);
      Check ("folder-delete-cancel-documents", " 3", Docs.Document_Count (Session)'Image);
      Ask (1);
      Click (Delete_X, Delete_Y);
      Check ("folder-subtree-removed", " 0", Docs.Directory_Count (Session)'Image);
      Check ("folder-deleted-view-reset", " 0", Docs.Shown_Directory (Session)'Image);
      Check ("folder-subtree-documents-kept", " 3", Docs.Document_Count (Session)'Image);
      for Rank in 1 .. Docs.Document_Count (Session) loop
         Check ("folder-kept-document-at-root", " 0", Docs.Document_Directory (Session, Rank)'Image);
      end loop;
      Reopen (Session);
      Check ("folder-subtree-deletion-kept", " 0", Docs.Directory_Count (Session)'Image);
      Check ("folder-documents-retained-kept", " 3", Docs.Document_Count (Session)'Image);

      Folder ("Outer");
      Folder ("Child");
      Folder ("Grandchild");
      Drag (7, 6);
      Drag (6, 5);
      Put ("Alpha", 1);
      Put ("Bravo", 3);
      Ask (1);
      Click (Check_X, Check_Y);
      Snap (Session, "write-delete-folder-documents");
      Click (Delete_X, Delete_Y);
      Check ("folder-subtree-and-documents-removed", " 0", Docs.Directory_Count (Session)'Image);
      Check ("folder-outside-document-retained", " 1", Docs.Document_Count (Session)'Image);
      Check ("folder-outside-document-title", "Outside", Docs.Document_Title (Session, 1));
      Reopen (Session);
      Check ("folder-subtree-and-documents-kept", " 0", Docs.Directory_Count (Session)'Image);
      Check ("folder-document-deletions-kept", " 1", Docs.Document_Count (Session)'Image);
   end Folder_Operations;

   procedure Naming is
      Session : View.Session;

      procedure Section (Name : String) is
      begin
         Outline.Add_Section (Session);
         Type_In (Session, Name);
         Settle (Session);
      end Section;
   begin
      Start (Session);
      Section ("Alpha");
      Section ("Beta");
      Section ("Gamma");
      Proj.Set_Mode (Session, View.Canvas);
      Windows.Add_Item (Session);
      Windows.Add_Item (Session, "Beta");
      Windows.Add_Item (Session, "Custom");

      --  Untitled, it takes the name of the section.
      Outline.Open_Link_Menu (Session, 1);
      Outline.Choose_Link_Row (Session, 2);
      View.Tick (Session, 0);
      Check ("naming-untitled", "Alpha", Windows.Item_Title (Session, 1));
      --  Called as a section is, so too.
      Outline.Open_Link_Menu (Session, 2);
      Outline.Choose_Link_Row (Session, 4);
      View.Tick (Session, 0);
      Check ("naming-matching", "Gamma", Windows.Item_Title (Session, 2));
      --  Called anything else, it is left.
      Outline.Open_Link_Menu (Session, 3);
      Outline.Choose_Link_Row (Session, 3);
      View.Tick (Session, 0);
      Check ("naming-own", "Custom", Windows.Item_Title (Session, 3));
   end Naming;

   procedure Menu_Fitting is
      Session : View.Session;

      procedure Section (Name : String) is
      begin
         Outline.Add_Section (Session);
         Type_In (Session, Name);
         Settle (Session);
      end Section;
   begin
      Start (Session);
      Section ("A section with a title far too long to fit in the menu it is in");
      for Number in 2 .. 12 loop
         Section ("Section" & Number'Image);
      end loop;
      Proj.Set_Mode (Session, View.Canvas);
      Windows.Add_Item (Session, "Note");

      --  Near the foot of the window it opens up, as tall as there is room,
      --  with a bar at the right, and does not cover its button.
      Outline.Open_Link_Menu (Session, 1);
      Snap (Session, "link-menu-long-up");
      View.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Wheel, Wheel_Y => -3.0, Mouse_X => 400.0,
                                Mouse_Y => 100.0, others => <>));
      Snap (Session, "link-menu-scrolled");
      Outline.Open_Link_Menu (Session, 1);

      --  With the window dragged up, it opens down.
      Move_To (Session, 350.0, 177.0);
      Press (Session, 350.0, 177.0);
      Move_To (Session, 350.0, 140.0, Held => True);
      Move_To (Session, 350.0, 77.0, Held => True);
      Release (Session, 350.0, 77.0);
      Settle (Session);
      Outline.Open_Link_Menu (Session, 1);
      Snap (Session, "link-menu-long-down");
   end Menu_Fitting;

end Outline_Tests;
