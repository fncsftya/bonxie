with Pomarine.Page_Builds;
with Preferences;
with SDL3.Events;
with Goldens;
with Projects;
with Viewer;
with Viewer.Home_Screen;
with Items;
with Viewer.Canvas_Windows;
with Viewer.Documents;
with Viewer.Outline_Screen;
with Viewer.Project_Screen;
with Viewer.Settings;

package body Outline_Tests is

   package Events renames SDL3.Events;
   package Home renames Viewer.Home_Screen;
   package Proj renames Viewer.Project_Screen;
   package Prefs renames Viewer.Settings;
   package Windows renames Viewer.Canvas_Windows;
   package Docs renames Viewer.Documents;
   package Outline renames Viewer.Outline_Screen;
   package Pictures renames Goldens.Images;

   procedure Check (Name : String; Expected, Actual : String)
     renames Goldens.Check_Text;

   Width  : constant := 720;
   Height : constant := 480;
   --  Of the window, in points; the toolbar is 44 high at the top.

   procedure Start (Session : in out Viewer.Session) is
   begin
      Viewer.Open (Session, "", Width, Height, 2.0);
      Home.New_Project (Session);
   end Start;

   procedure Type_In (Session : in out Viewer.Session; Text : String) is
   begin
      Viewer.Handle (Session, Events.Text_Event (Text));
   end Type_In;

   procedure Move_To
     (Session : in out Viewer.Session; X, Y : Float; Held : Boolean := False) is
   begin
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Move, Mouse_X => X,
                                Mouse_Y => Y, Left_Held => Held, others => <>));
   end Move_To;

   procedure Press (Session : in out Viewer.Session; X, Y : Float) is
   begin
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Down, Button => 1, Clicks => 1,
                                Mouse_X => X, Mouse_Y => Y, others => <>));
   end Press;

   procedure Release (Session : in out Viewer.Session; X, Y : Float) is
   begin
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Up, Button => 1, Clicks => 1,
                                Mouse_X => X, Mouse_Y => Y, others => <>));
   end Release;

   procedure Settle (Session : in out Viewer.Session) is
      Drawn : Pictures.Image;
   begin
      --  Drawn, as it is between a person's clicks: what was typed is kept.
      Viewer.Tick (Session, 0);
      Viewer.Render (Session, Drawn);
      Pomarine.Page_Builds.Wait_Until_Idle;
      Viewer.Handle (Session, (Kind => Events.Redraw, others => <>));
   end Settle;

   procedure Snap (Session : in out Viewer.Session; Name : String) is
      Drawn : Pictures.Image;
   begin
      Settle (Session);
      Viewer.Render (Session, Drawn);
      Goldens.Check (Name, Drawn);
   end Snap;

   function Titles (Session : Viewer.Session) return String is
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

   function Owners_Of (Session : Viewer.Session) return String is
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

   procedure Reopen (Session : in out Viewer.Session) is
      Key : constant Projects.Id := Proj.Current_Project (Session);
   begin
      Proj.Close_Project (Session);
      Home.Open_Project (Session, Key);
   end Reopen;

   procedure Starting is
      Session : Viewer.Session;
   begin
      Start (Session);
      --  A project opens to its outline, the first of the tabs.
      Check ("outline-mode", "OUTLINE", Viewer.Modes'Image (Proj.Mode (Session)));
      Check ("outline-none", "", Titles (Session));
      Snap (Session, "outline-empty");

      --  The tab last chosen is the one it opens to.
      Proj.Set_Mode (Session, Viewer.Write);
      Reopen (Session);
      Check ("outline-mode-write", "WRITE", Viewer.Modes'Image (Proj.Mode (Session)));
      Proj.Set_Mode (Session, Viewer.Canvas);
      Reopen (Session);
      Check ("outline-mode-canvas", "CANVAS", Viewer.Modes'Image (Proj.Mode (Session)));
      Proj.Set_Mode (Session, Viewer.Outline);
      Reopen (Session);
      Check ("outline-mode-outline", "OUTLINE", Viewer.Modes'Image (Proj.Mode (Session)));
   end Starting;

   procedure Sections is
      Session : Viewer.Session;
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

   procedure Form is
      Session : Viewer.Session;
   begin
      Start (Session);
      Check ("outline-form-title", "Untitled project", Outline.Project_Title (Session));
      Check ("outline-form-description", "", Outline.Project_Description (Session));
   end Form;

   procedure Generating is
      Session : Viewer.Session;
   begin
      Viewer.Open (Session, "", Width, Height, 2.0);
      --  Off, the button is too.
      Home.New_Project (Session);
      Check ("outline-generate-ai-off", "FALSE", Boolean'Image (Outline.Generate_Enabled (Session)));
      Snap (Session, "outline-generate-disabled");
      Proj.Close_Project (Session);

      Prefs.Open_Settings (Session);
      Prefs.Choose_AI_Enabled (Session, True);
      Prefs.Close_Settings (Session);
      Home.New_Project (Session);
      Check ("outline-generate-ai-on", "TRUE", Boolean'Image (Outline.Generate_Enabled (Session)));
      Snap (Session, "outline-generate-enabled");

      Proj.Close_Project (Session);
      Prefs.Open_Settings (Session);
      Prefs.Choose_Theme (Session, Preferences.Dark);
      Prefs.Close_Settings (Session);
      Home.New_Project (Session);
      Snap (Session, "outline-generate-dark");
   end Generating;

   procedure Replies is
      Session : Viewer.Session;
      Taken   : Boolean;

      Cafe : constant String :=
        "Caf" & Character'Val (16#C3#) & Character'Val (16#A9#) & " " & Character'Val (16#F0#)
        & Character'Val (16#9F#) & Character'Val (16#98#) & Character'Val (16#80#);
      --  "Café 😀", in UTF-8.

      procedure Reject (Reply : String) is
      begin
         Taken := Outline.Take_Reply (Session, Reply);
         Check ("outline-reply-invalid", "FALSE", Boolean'Image (Taken));
         Check ("outline-reply-unchanged", "Middle|", Titles (Session));
      end Reject;
   begin
      Start (Session);
      Outline.Add_Section (Session);
      Type_In (Session, "Middle");
      Settle (Session);

      --  What cannot be read changes nothing.
      Reject ("I cannot do that.");
      Reject ("{""sections"": []}");
      Reject ("{""sections"": [{""title"": ""Start""}, {""title"": ""Mid");
      Reject ("{""sections"": [{""name"": ""Start""}]}");
      Reject ("{""sections"": [""Start""]}");
      Reject ("{""sections"": [{""title"": ""   ""}]}");
      Reject ("{""sections"": [{""title"": ""A""},]}");

      --  What can: in the order given, with the section there kept, and
      --  words about the object, thoughts and fences passed over.
      Taken := Outline.Take_Reply
        (Session,
         "Here it is:" & ASCII.LF & "```json" & ASCII.LF
         & "{""sections"": [{""title"": ""Introduction""}, {""title"": ""middle"", ""x"": [1, {""y"": null}]},"
         & " {""title"": ""Caf\u00e9 \ud83d\ude00""}, {""title"": ""Introduction""}, {""title"": ""  End  ""}]}"
         & ASCII.LF & "```");
      Check ("outline-reply-valid", "TRUE", Boolean'Image (Taken));
      Check ("outline-reply-order", "Introduction|Middle|" & Cafe & "|End|", Titles (Session));
      Snap (Session, "outline-generated");

      --  A section the model leaves out goes last, and is not lost.
      Taken := Outline.Take_Reply (Session, "{""sections"": [{""title"": ""End""}, {""title"": ""Start""}]}");
      Check ("outline-reply-taken", "TRUE", Boolean'Image (Taken));
      Check ("outline-reply-omitted", "End|Start|Introduction|Middle|" & Cafe & "|", Titles (Session));
      Reopen (Session);
      Check ("outline-reply-kept", "End|Start|Introduction|Middle|" & Cafe & "|", Titles (Session));
   end Replies;

   procedure Linking is
      Session : Viewer.Session;

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

      Proj.Set_Mode (Session, Viewer.Canvas);
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
      Proj.Set_Mode (Session, Viewer.Write);
      Snap (Session, "link-write");
      Reopen (Session);
      Proj.Set_Mode (Session, Viewer.Outline);
      Check ("link-kept", "Opening,|Closing,||", Owners);
      Snap (Session, "outline-linked");

      --  Ticked again, it is let go.
      Proj.Set_Mode (Session, Viewer.Canvas);
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
      Proj.Set_Mode (Session, Viewer.Outline);
      Snap (Session, "outline-linked-dark");
      Proj.Set_Mode (Session, Viewer.Canvas);
      Outline.Open_Link_Menu (Session, 2);
      Snap (Session, "link-menu-dark");
   end Linking;

   procedure Sidebar is
      Session : Viewer.Session;
      Folder  : constant String := "/tmp/bonxie-sidebar-test";
   begin
      Start (Session);
      Proj.Set_Mode (Session, Viewer.Write);
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
      Check ("sidebar-narrowest", "150", Natural (Docs.Sidebar_Width (Session))'Image (2 .. 4));
      Snap (Session, "sidebar-narrow");

      --  What is kept with the settings.
      Check ("sidebar-none-kept", "0", Preferences.Load_Sidebar_Width (Folder & "-none")'Image (2 .. 2));
      Preferences.Save_Sidebar_Width (Folder, 333);
      Check ("sidebar-kept", "333", Preferences.Load_Sidebar_Width (Folder)'Image (2 .. 4));
   end Sidebar;

   procedure Tiers is
      Session : Viewer.Session;

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
      Proj.Set_Mode (Session, Viewer.Canvas);
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
      Proj.Set_Mode (Session, Viewer.Write);
      Snap (Session, "tiers-tree");

      --  The order is of the first tier (the sections and what is of none)
      --  and then of each section's own, and is the same one to read down.
      Check ("tiers-order", "Loose|Alpha|Bravo|Charlie|", Order);

      --  Within a section, a document is dragged above its neighbour;
      --  and the ghost is the row, under the pointer.
      Drag (267.0, 229.0, "tiers-ghost");
      Check ("tiers-reordered", "Loose|Bravo|Alpha|Charlie|", Order);
      Check ("tiers-owners", "Alpha,Bravo,||Charlie,|", Owners_Of (Session));

      --  A section cannot be dragged, nor can it come after a document.
      Drag (191.0, 380.0);
      Check ("tiers-section-fixed", "Loose|Bravo|Alpha|Charlie|", Order);

      --  Put among another section's, a document is made its own.
      Docs.Move_Document (Session, 4, 2);
      Check ("tiers-moved-in", "Loose|Charlie|Bravo|Alpha|", Order);
      Check ("tiers-moved-owners", "Alpha,Bravo,Charlie,|||", Owners_Of (Session));

      Reopen (Session);
      Proj.Set_Mode (Session, Viewer.Write);
      Check ("tiers-kept", "Loose|Charlie|Bravo|Alpha|", Order);
   end Tiers;

   procedure Section_Rows is
      Session : Viewer.Session;

      procedure Section (Name : String) is
      begin
         Outline.Add_Section (Session);
         Type_In (Session, Name);
         Settle (Session);
      end Section;

      procedure Click_Row (Y : Float; Button : Natural; Clicks : Natural) is
      begin
         Move_To (Session, 100.0, Y);
         Viewer.Handle
           (Session, Events.Event'(Kind => Events.Mouse_Down, Button => Button, Clicks => Clicks,
                                   Mouse_X => 100.0, Mouse_Y => Y, others => <>));
         Viewer.Handle
           (Session, Events.Event'(Kind => Events.Mouse_Up, Button => Button, Clicks => Clicks,
                                   Mouse_X => 100.0, Mouse_Y => Y, others => <>));
      end Click_Row;
   begin
      Start (Session);
      Section ("Beginning");
      Section ("End");
      Proj.Set_Mode (Session, Viewer.Write);
      Snap (Session, "write-section-rows");

      --  Right click: it can be renamed, not deleted.
      Click_Row (153.0, 3, 1);
      Snap (Session, "write-section-context");
      Click_Row (400.0, 1, 1);

      --  Pressed twice, it is renamed in place, and the name is the
      --  section's wherever it is shown.
      Click_Row (153.0, 1, 2);
      Type_In (Session, "Opening");
      Viewer.Handle (Session, Events.Event'(Kind => Events.Key_Down, Key => Events.Key_Return, others => <>));
      Settle (Session);
      Check ("section-renamed", "Opening|End|", Titles (Session));
      Snap (Session, "write-section-renamed");
      Reopen (Session);
      Check ("section-rename-kept", "Opening|End|", Titles (Session));
   end Section_Rows;

   procedure Writing_Sections is
      Session : Viewer.Session;

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
      Proj.Set_Mode (Session, Viewer.Canvas);
      Windows.Add_Item (Session, "Notes one");
      Windows.Add_Item (Session, "Loose");
      Windows.Add_Item (Session, "Notes two");
      Windows.Add_Item (Session, "Last words");
      --  Two documents are of the first section, one of the last, and the
      --  second, in between, of none; the middle section has none.
      Link (1, 1);
      Link (3, 1);
      Link (4, 3);
      Proj.Set_Mode (Session, Viewer.Write);
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
         Viewer.Handle
           (Session, Events.Event'(Kind => Events.Mouse_Wheel, Wheel_Y => -18.0, Mouse_X => 500.0,
                                   Mouse_Y => 300.0, others => <>));
         Snap (Session, "write-sections-down-" & Character'Val (Character'Pos ('0') + Step));
      end loop;
      Viewer.Handle
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
      Check ("write-section-owners", "Notes one,Notes two,|Untitled document,|Last words,|",
             Owners_Of (Session));
      Snap (Session, "write-sections-added");

      --  The button by the count of a section's documents writes another,
      --  last among them; a section with none has no such button.
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Wheel, Wheel_Y => 400.0, Mouse_X => 500.0,
                                Mouse_Y => 300.0, others => <>));
      Viewer.Handle
        (Session, Events.Event'(Kind => Events.Mouse_Wheel, Wheel_Y => -18.0, Mouse_X => 500.0,
                                Mouse_Y => 300.0, others => <>));
      Settle (Session);
      Move_To (Session, 664.0, 65.0);
      Press (Session, 664.0, 65.0);
      Release (Session, 664.0, 65.0);
      Check ("write-heading-added", "6", Docs.Document_Count (Session)'Image (2 .. 2));
      Snap (Session, "write-heading-added");
   end Writing_Sections;

   procedure Naming is
      Session : Viewer.Session;

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
      Proj.Set_Mode (Session, Viewer.Canvas);
      Windows.Add_Item (Session);
      Windows.Add_Item (Session, "Beta");
      Windows.Add_Item (Session, "Custom");

      --  Untitled, it takes the name of the section.
      Outline.Open_Link_Menu (Session, 1);
      Outline.Choose_Link_Row (Session, 2);
      Viewer.Tick (Session, 0);
      Check ("naming-untitled", "Alpha", Windows.Item_Title (Session, 1));
      --  Called as a section is, so too.
      Outline.Open_Link_Menu (Session, 2);
      Outline.Choose_Link_Row (Session, 4);
      Viewer.Tick (Session, 0);
      Check ("naming-matching", "Gamma", Windows.Item_Title (Session, 2));
      --  Called anything else, it is left.
      Outline.Open_Link_Menu (Session, 3);
      Outline.Choose_Link_Row (Session, 3);
      Viewer.Tick (Session, 0);
      Check ("naming-own", "Custom", Windows.Item_Title (Session, 3));
   end Naming;

   procedure Menu_Fitting is
      Session : Viewer.Session;

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
      Proj.Set_Mode (Session, Viewer.Canvas);
      Windows.Add_Item (Session, "Note");

      --  Near the foot of the window it opens up, as tall as there is room,
      --  with a bar at the right, and does not cover its button.
      Outline.Open_Link_Menu (Session, 1);
      Snap (Session, "link-menu-long-up");
      Viewer.Handle
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
