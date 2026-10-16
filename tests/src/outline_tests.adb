with Pomarine.Page_Builds;
with Preferences;
with SDL3.Events;
with Goldens;
with Projects;
with Viewer;
with Viewer.Home_Screen;
with Viewer.Canvas_Windows;
with Viewer.Outline_Screen;
with Viewer.Project_Screen;
with Viewer.Settings;

package body Outline_Tests is

   package Events renames SDL3.Events;
   package Home renames Viewer.Home_Screen;
   package Proj renames Viewer.Project_Screen;
   package Prefs renames Viewer.Settings;
   package Windows renames Viewer.Canvas_Windows;
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
      Viewer.Tick (Session, Events.Ticks);
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

      function Owners return String is
         Result : String (1 .. 256);
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
      end Owners;
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
      Windows.Add_Item (Session, "Middle");
      Windows.Add_Item (Session, "Opening");

      --  Every section is in the menu, none taken.
      Outline.Open_Link_Menu (Session, 2);
      Check ("link-menu-rows", "...", Rows);
      Snap (Session, "link-menu");
      Outline.Choose_Link_Row (Session, 2);
      Check ("link-owners", "Opening|||", Owners);

      --  Faint for the other item.
      Outline.Open_Link_Menu (Session, 1);
      Check ("link-menu-taken", "-..", Rows);
      Outline.Choose_Link_Row (Session, 2);
      Check ("link-taken-unchanged", "Opening|||", Owners);
      Outline.Choose_Link_Row (Session, 3);
      Check ("link-second", "Opening|Middle||", Owners);
      Settle (Session);
      Snap (Session, "link-canvas");

      --  Ticked for its own, with a row to take the link away: the boxes,
      --  a line, and that.
      Outline.Open_Link_Menu (Session, 2);
      Check ("link-menu-own", "x-...", Rows);
      Snap (Session, "link-menu-own");
      Outline.Open_Link_Menu (Session, 2);

      --  Kept, and shown in the writing view.
      Proj.Set_Mode (Session, Viewer.Write);
      Snap (Session, "link-write");
      Reopen (Session);
      Proj.Set_Mode (Session, Viewer.Outline);
      Check ("link-kept", "Opening|Middle||", Owners);
      Snap (Session, "outline-linked");

      --  Ticked again, it is let go.
      Proj.Set_Mode (Session, Viewer.Canvas);
      Outline.Open_Link_Menu (Session, 2);
      Outline.Choose_Link_Row (Session, 2);
      Check ("link-let-go", "|Middle||", Owners);

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
      Viewer.Tick (Session, Events.Ticks);
      Check ("naming-untitled", "Alpha", Windows.Item_Title (Session, 1));
      --  Called as a section is, so too.
      Outline.Open_Link_Menu (Session, 2);
      Outline.Choose_Link_Row (Session, 4);
      Viewer.Tick (Session, Events.Ticks);
      Check ("naming-matching", "Gamma", Windows.Item_Title (Session, 2));
      --  Called anything else, it is left.
      Outline.Open_Link_Menu (Session, 3);
      Outline.Choose_Link_Row (Session, 3);
      Viewer.Tick (Session, Events.Ticks);
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
