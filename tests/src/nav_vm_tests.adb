with Naming_VM;
with Writing_Sources_VM;
with Writing_VM.Actions;
with Writing_VM.Trees;
with Items.Directories;
with Publish_VM_Fakes;
with Publish_VM.Disk;
with Long_Texts;
with Files;
with Publish_VM;
with Sidebar_VM;
with Sidebar_VM.Disk;
with Preferences;
with Ada.Assertions;
with Ada.Strings.Unbounded;
with Canvas_VM;
with Canvas_VM_Fakes;
with Item_List_VM;
with Items.Models.Tables;
with Confirm_VM;
with Goldens;
with Home_VM;
with Home_VM_Fakes;
with Nav_VM;
with Nav_VM.Stored;
with Nav_VM_Fakes;
with Outline_VM;
with Outline_VM.Stored;
with Outline_VM_Fakes;
with Items.Schema;
with Pomarine.View_Models;
with Projects;
with Settings_VM;
with Settings_VM_Fakes;

package body Nav_VM_Tests is

   package Parts renames Pomarine.View_Models;

   use type Parts.Version_Number;
   use type Projects.Id;
   use all type Nav_VM.Command;

   procedure Check (Name : String; Expected, Actual : String) renames Goldens.Check_Text;

   function Image (Value : Boolean) return String
   is (Value'Image);

   function Can (Model : Nav_VM.View_Model; What : Nav_VM.Command; Index : Natural := 0) return String
   is (Image (Nav_VM.Can_Execute (Model, What, Index)));

   function Number (Value : Integer) return String
   is (Value'Image (2 .. Value'Image'Last));

   --  A home screen of two projects, an outline that has the opened one's title, and the settings and
   --  the dialog that are over them.
   type Setting is limited record
      Projects : aliased Home_VM_Fakes.Few;
      Recent   : aliased Home_VM.View_Model;
      Sections : aliased Outline_VM_Fakes.Kept;
      Outline  : aliased Outline_VM.View_Model;
      Voice    : aliased Settings_VM_Fakes.Pretend;
      Saved    : aliased Settings_VM_Fakes.Notes;
      Settings : aliased Settings_VM.View_Model;
      Dialog   : aliased Confirm_VM.View_Model;
      Kept     : aliased Nav_VM_Fakes.Few;
      Model    : aliased Nav_VM.View_Model;
   end record;

   procedure Prepare (Where : aliased in out Setting);

   procedure Prepare (Where : aliased in out Setting) is
   begin
      Home_VM_Fakes.Add (Where.Projects, "Episode 1");
      Home_VM_Fakes.Add (Where.Projects, "Episode 2");
      Home_VM.Initialize (Where.Recent, Where.Projects'Access);
      Outline_VM.Initialize (Where.Outline, Where.Sections'Access);
      Settings_VM.Initialize (Where.Settings, Where.Voice'Access, Where.Saved'Access, "/nowhere");
      Nav_VM.Initialize
        (Where.Model,
         Where.Kept'Access,
         Where.Recent'Access,
         Where.Outline'Access,
         Where.Settings'Access,
         Where.Dialog'Access);
   end Prepare;

   function Where_Is (Model : Nav_VM.View_Model) return String
   is (Nav_VM.Screen (Model)'Image
       & " "
       & Nav_VM.Mode (Model)'Image
       & " "
       & Number (Integer (Nav_VM.Project_Key (Model)))
       & " '"
       & Nav_VM.Name (Model)
       & "'");

   procedure Opening is
      Where : aliased Setting;
      Model : Nav_VM.View_Model renames Where.Model;
      Seen  : Parts.Version_Number;
   begin
      Prepare (Where);
      Check ("nav-vm-first", "HOME CANVAS 0 '' PLAIN", Where_Is (Model) & " " & Nav_VM.Layer (Model)'Image);
      Check
        ("nav-vm-home-commands",
         "TRUE TRUE TRUE FALSE FALSE FALSE FALSE FALSE",
         Can (Model, Start_Project)
         & " "
         & Can (Model, Open_Project, 1)
         & " "
         & Can (Model, Open_Settings)
         & " "
         & Can (Model, Leave_Project)
         & " "
         & Can (Model, Show_Writing)
         & " "
         & Can (Model, Open_List)
         & " "
         & Can (Model, Begin_Rename)
         & " "
         & Image (Nav_VM.Takes_Gestures (Model)));
      Check ("nav-vm-no-such-row", "FALSE TRUE", Can (Model, Open_Project, 3) & " " & Can (Model, Open_Project));

      --  A project of the list: the latest is the first row.
      Seen := Nav_VM.Screen_Version (Model);
      Nav_VM.Execute (Model, Open_Project, 2);
      Check
        ("nav-vm-opened",
         "PROJECT CANVAS 1 'Great skua' TRUE TRUE",
         Where_Is (Model)
         & " "
         & Image (Nav_VM.Screen_Version (Model) /= Seen)
         & " "
         & Image (Nav_VM.Takes_Gestures (Model)));
      Check
        ("nav-vm-project-commands",
         "FALSE FALSE TRUE TRUE TRUE FALSE",
         Can (Model, Start_Project)
         & " "
         & Can (Model, Open_Settings)
         & " "
         & Can (Model, Leave_Project)
         & " "
         & Can (Model, Show_Writing)
         & " "
         & Can (Model, Begin_Rename)
         & " "
         & Can (Model, Close_List));

      Seen := Nav_VM.Screen_Version (Model);
      Nav_VM.Execute (Model, Leave_Project);
      Check
        ("nav-vm-left",
         "HOME CANVAS 0 '' TRUE",
         Where_Is (Model) & " " & Image (Nav_VM.Screen_Version (Model) /= Seen));
      Check ("nav-vm-left-outline", "FALSE", Image (Outline_VM.Is_Entered (Where.Outline)));

      --  A new project, as the database would have it.
      Nav_VM.Execute (Model, Start_Project);
      Check ("nav-vm-started", "PROJECT CANVAS 1 'Great skua' 1", Where_Is (Model) & " " & Number (Where.Kept.Made));
   end Opening;

   type View_Commands is array (Positive range <>) of Nav_VM.Command;

   Each_View : constant View_Commands := [Show_Writing, Show_Outline, Show_Publish, Show_Canvas];

   procedure Browser is
      Where : aliased Setting;
      Model : Nav_VM.View_Model renames Where.Model;
      Seen  : Parts.Version_Number;
   begin
      Prepare (Where);
      Check ("nav-vm-browser-home", "FALSE", Can (Model, Toggle_Browser));
      Nav_VM.Open (Model, 1);
      Check
        ("nav-vm-browser-closed",
         "TRUE FALSE FALSE",
         Can (Model, Toggle_Browser)
         & " "
         & Image (Nav_VM.Browser_Open (Model))
         & " "
         & Image (Nav_VM.Browser_Shown (Model)));
      Seen := Nav_VM.Version (Model);
      Nav_VM.Execute (Model, Toggle_Browser);
      Check
        ("nav-vm-browser-opened",
         "TRUE TRUE TRUE",
         Image (Nav_VM.Browser_Open (Model))
         & " "
         & Image (Nav_VM.Browser_Shown (Model))
         & " "
         & Image (Nav_VM.Version (Model) /= Seen));

      --  Kept as the views change, and there in each of them.
      for View of Each_View loop
         Nav_VM.Execute (Model, View);
         Check
           ("nav-vm-browser-" & Nav_VM.Mode (Model)'Image,
            "TRUE TRUE TRUE",
            Image (Nav_VM.Browser_Open (Model))
            & " "
            & Image (Nav_VM.Browser_Shown (Model))
            & " "
            & Can (Model, Toggle_Browser));
      end loop;

      --  Not while a layer is over the screen; away at the home screen, and still asked for after.
      Nav_VM.Execute (Model, Open_List);
      Check ("nav-vm-browser-over", "FALSE", Can (Model, Toggle_Browser));
      Nav_VM.Execute (Model, Close_List);
      Nav_VM.Execute (Model, Leave_Project);
      Check
        ("nav-vm-browser-left",
         "TRUE FALSE",
         Image (Nav_VM.Browser_Open (Model)) & " " & Image (Nav_VM.Browser_Shown (Model)));
      Nav_VM.Open (Model, 1);
      Check ("nav-vm-browser-kept", "TRUE", Image (Nav_VM.Browser_Shown (Model)));
      Nav_VM.Execute (Model, Toggle_Browser);
      Check
        ("nav-vm-browser-closed-again",
         "FALSE FALSE",
         Image (Nav_VM.Browser_Open (Model)) & " " & Image (Nav_VM.Browser_Shown (Model)));
   end Browser;

   procedure Views is
      Where : aliased Setting;
      Model : Nav_VM.View_Model renames Where.Model;
      Seen  : Parts.Version_Number;
   begin
      Prepare (Where);
      Nav_VM.Open (Model, 1);
      Check ("nav-vm-view-first", "CANVAS 0", Nav_VM.Mode (Model)'Image & Where.Kept.Left'Image);
      Seen := Nav_VM.Mode_Version (Model);
      Nav_VM.Execute (Model, Show_Writing);
      Check
        ("nav-vm-view-writing",
         "WRITE TRUE 2 1",
         Nav_VM.Mode (Model)'Image
         & " "
         & Image (Nav_VM.Mode_Version (Model) /= Seen)
         & " "
         & Number (Where.Kept.Tabs (1))
         & " "
         & Number (Where.Kept.Left));
      --  The one shown is not a change.
      Seen := Nav_VM.Mode_Version (Model);
      Nav_VM.Execute (Model, Show_Writing);
      Check ("nav-vm-view-again", "FALSE", Image (Nav_VM.Mode_Version (Model) /= Seen));
      Nav_VM.Execute (Model, Show_Outline);
      Check ("nav-vm-view-outline", "OUTLINE 0", Nav_VM.Mode (Model)'Image & Where.Kept.Tabs (1)'Image);
      Nav_VM.Execute (Model, Show_Publish);
      Check ("nav-vm-view-publish", "PUBLISH 3", Nav_VM.Mode (Model)'Image & Where.Kept.Tabs (1)'Image);

      --  Leaving goes back to the canvas; opening it again, the view it was left at.
      Nav_VM.Execute (Model, Leave_Project);
      Nav_VM.Open (Model, 1);
      Check ("nav-vm-view-reopened", "CANVAS", Nav_VM.Mode (Model)'Image);
      Nav_VM.Restore_Mode (Model);
      Check ("nav-vm-view-restored", "PUBLISH 3", Nav_VM.Mode (Model)'Image & Where.Kept.Tabs (1)'Image);
      Check ("nav-vm-view-not-kept-again", "4", Number (Where.Kept.Left));

      --  A view that is not one of the tabs is not believed.
      Where.Kept.Tabs (1) := 9;
      Nav_VM.Execute (Model, Leave_Project);
      Nav_VM.Open (Model, 1);
      Nav_VM.Restore_Mode (Model);
      Check ("nav-vm-view-too-far", "PUBLISH", Nav_VM.Mode (Model)'Image);
   end Views;

   procedure Renaming is
      Where : aliased Setting;
      Model : Nav_VM.View_Model renames Where.Model;
      Seen  : Parts.Version_Number;
   begin
      Prepare (Where);
      Nav_VM.Open (Model, 1);
      Check
        ("nav-vm-rename-off",
         "FALSE FALSE FALSE TRUE",
         Image (Nav_VM.Is_Renaming (Model))
         & " "
         & Can (Model, Accept_Rename)
         & " "
         & Can (Model, Cancel_Rename)
         & " "
         & Can (Model, Begin_Rename));
      Seen := Nav_VM.Renaming_Version (Model);
      Nav_VM.Execute (Model, Begin_Rename);
      Check
        ("nav-vm-rename-begun",
         "TRUE Great skua TRUE TRUE FALSE",
         Image (Nav_VM.Is_Renaming (Model))
         & " "
         & Nav_VM.Draft (Model)
         & " "
         & Image (Nav_VM.Renaming_Version (Model) /= Seen)
         & " "
         & Can (Model, Accept_Rename)
         & " "
         & Can (Model, Begin_Rename));

      --  Typing is a change of the draft, not of the renaming.
      Seen := Nav_VM.Renaming_Version (Model);
      Nav_VM.Set_Draft (Model, "  Arctic skua ");
      Check
        ("nav-vm-rename-typed",
         "FALSE Great skua",
         Image (Nav_VM.Renaming_Version (Model) /= Seen) & " " & Nav_VM.Name (Model));
      Nav_VM.Execute (Model, Accept_Rename);
      Check
        ("nav-vm-rename-accepted",
         "FALSE 'Arctic skua' 1",
         Image (Nav_VM.Is_Renaming (Model)) & " '" & Nav_VM.Name (Model) & "' " & Number (Where.Sections.Writes));

      --  Not left without a name.
      Nav_VM.Execute (Model, Begin_Rename);
      Nav_VM.Set_Draft (Model, "   ");
      Nav_VM.Execute (Model, Accept_Rename);
      Check
        ("nav-vm-rename-blank",
         "FALSE 'Arctic skua' 1",
         Image (Nav_VM.Is_Renaming (Model)) & " '" & Nav_VM.Name (Model) & "' " & Number (Where.Sections.Writes));

      Nav_VM.Execute (Model, Begin_Rename);
      Nav_VM.Set_Draft (Model, "Pomarine skua");
      Nav_VM.Execute (Model, Cancel_Rename);
      Check
        ("nav-vm-rename-cancelled",
         "FALSE 'Arctic skua' 1",
         Image (Nav_VM.Is_Renaming (Model)) & " '" & Nav_VM.Name (Model) & "' " & Number (Where.Sections.Writes));

      --  Leaving does not lose a name that was being typed.
      Nav_VM.Execute (Model, Begin_Rename);
      Nav_VM.Set_Draft (Model, "Long-tailed skua");
      Nav_VM.Execute (Model, Leave_Project);
      Check
        ("nav-vm-rename-on-leaving",
         "FALSE HOME 'Long-tailed skua'",
         Image (Nav_VM.Is_Renaming (Model))
         & " "
         & Nav_VM.Screen (Model)'Image
         & " '"
         & Projects.Titles.To_String (Where.Sections.Title)
         & "'");
   end Renaming;

   procedure Layers is
      Where : aliased Setting;
      Model : Nav_VM.View_Model renames Where.Model;
      Seen  : Parts.Version_Number;
   begin
      Prepare (Where);

      --  The settings take the home screen's place.
      Seen := Nav_VM.Layer_Version (Model);
      Nav_VM.Execute (Model, Open_Settings);
      Check
        ("nav-vm-settings",
         "SETTINGS_FORM TRUE TRUE FALSE FALSE FALSE",
         Nav_VM.Layer (Model)'Image
         & " "
         & Image (Settings_VM.Is_Showing (Where.Settings))
         & " "
         & Image (Nav_VM.Layer_Version (Model) /= Seen)
         & " "
         & Can (Model, Open_Settings)
         & " "
         & Can (Model, Start_Project)
         & " "
         & Can (Model, Open_Project, 1));
      Check ("nav-vm-settings-close", "TRUE TRUE", Can (Model, Close_Settings) & " " & Can (Model, Dismiss));

      --  The dialog over the settings is all that is asked.
      Confirm_VM.Ask_Model (Where.Dialog, "483.0 MB");
      Check
        ("nav-vm-model-dialog",
         "MODEL_DIALOG FALSE TRUE",
         Nav_VM.Layer (Model)'Image & " " & Can (Model, Close_Settings) & " " & Can (Model, Dismiss));
      Nav_VM.Execute (Model, Dismiss);
      Check
        ("nav-vm-model-dialog-away",
         "SETTINGS_FORM FALSE",
         Nav_VM.Layer (Model)'Image & " " & Image (Confirm_VM.Is_Asking (Where.Dialog)));
      Nav_VM.Execute (Model, Dismiss);
      Check
        ("nav-vm-settings-away",
         "PLAIN FALSE FALSE",
         Nav_VM.Layer (Model)'Image
         & " "
         & Image (Settings_VM.Is_Showing (Where.Settings))
         & " "
         & Can (Model, Dismiss));

      --  A dialog over the home screen.
      Confirm_VM.Ask_Project (Where.Dialog, 1, "Episode 2");
      Check
        ("nav-vm-delete-dialog",
         "DELETING FALSE FALSE FALSE",
         Nav_VM.Layer (Model)'Image
         & " "
         & Can (Model, Start_Project)
         & " "
         & Can (Model, Open_Settings)
         & " "
         & Can (Model, Open_Project, 1));
      Nav_VM.Execute (Model, Dismiss);
      Check ("nav-vm-delete-dialog-away", "PLAIN TRUE", Nav_VM.Layer (Model)'Image & " " & Can (Model, Start_Project));

      --  The list of items over a project.
      Nav_VM.Open (Model, 1);
      Check
        ("nav-vm-project-plain",
         "TRUE TRUE",
         Image (Nav_VM.Takes_Gestures (Model)) & " " & Image (Nav_VM.Takes_Search (Model)));
      Nav_VM.Execute (Model, Open_List);
      Seen := Nav_VM.Layer_Version (Model);
      Nav_VM.Execute (Model, Open_List);
      Check
        ("nav-vm-list",
         "ITEM_LIST TRUE FALSE FALSE FALSE FALSE",
         Nav_VM.Layer (Model)'Image
         & " "
         & Image (Nav_VM.Is_Listing (Model))
         & " "
         & Image (Nav_VM.Layer_Version (Model) /= Seen)
         & " "
         & Image (Nav_VM.Takes_Gestures (Model))
         & " "
         & Image (Nav_VM.Takes_Search (Model))
         & " "
         & Can (Model, Begin_Rename));
      Nav_VM.Execute (Model, Dismiss);
      Check
        ("nav-vm-list-away",
         "PLAIN FALSE TRUE",
         Nav_VM.Layer (Model)'Image
         & " "
         & Image (Nav_VM.Is_Listing (Model))
         & " "
         & Image (Nav_VM.Takes_Gestures (Model)));

      --  Search is not for the outline or the publish view.
      Nav_VM.Execute (Model, Show_Outline);
      Check
        ("nav-vm-search-outline",
         "TRUE FALSE",
         Image (Nav_VM.Takes_Gestures (Model)) & " " & Image (Nav_VM.Takes_Search (Model)));
      Nav_VM.Execute (Model, Show_Writing);
      Check ("nav-vm-search-writing", "TRUE", Image (Nav_VM.Takes_Search (Model)));

      --  Leaving puts the list away.
      Nav_VM.Execute (Model, Open_List);
      Nav_VM.Execute (Model, Leave_Project);
      Check ("nav-vm-list-left", "FALSE PLAIN", Image (Nav_VM.Is_Listing (Model)) & " " & Nav_VM.Layer (Model)'Image);
   end Layers;

   type Creation_Effects is limited new Nav_VM.Effects with record
      Before, After : Natural := 0;
      Last          : Nav_VM.Command := Nav_VM.Dismiss;
      Index         : Natural := 0;
   end record;

   overriding
   procedure Going_To_Execute (Self : in out Creation_Effects; What : Nav_VM.Command; Index : Natural);
   overriding
   procedure Executed (Self : in out Creation_Effects; What : Nav_VM.Command; Index : Natural);

   overriding
   procedure Going_To_Execute (Self : in out Creation_Effects; What : Nav_VM.Command; Index : Natural) is
      pragma Unreferenced (What, Index);
   begin
      Self.Before := @ + 1;
   end Going_To_Execute;

   overriding
   procedure Executed (Self : in out Creation_Effects; What : Nav_VM.Command; Index : Natural) is
   begin
      Self.After := @ + 1;
      Self.Last := What;
      Self.Index := Index;
   end Executed;

   procedure Creating is
      Where   : aliased Setting;
      Model   : Nav_VM.View_Model renames Where.Model;
      Effects : aliased Creation_Effects;
      Seen    : Parts.Version_Number;
   begin
      Prepare (Where);
      Check
        ("nav-vm-create-home",
         "FALSE FALSE FALSE",
         Can (Model, Add_Document) & " " & Can (Model, Add_Source) & " " & Can (Model, Add_Folder));
      Nav_VM.Execute (Model, Open_Project, 1);
      for What in Add_Document .. Add_Source loop
         Nav_VM.Observe (Model, Effects'Access);
         Seen := Nav_VM.Version (Model);
         Nav_VM.Execute (Model, What);
         Check
           ("nav-vm-create-" & What'Image,
            "TRUE TRUE",
            Image (Effects.Last = What and then Effects.Before = Effects.After)
            & " "
            & Image (Nav_VM.Version (Model) = Seen));
      end loop;
      Check ("nav-vm-create-effects", "2 2", Number (Effects.Before) & " " & Number (Effects.After));
      Nav_VM.Observe (Model, null);
      Nav_VM.Execute (Model, Open_List);
      Check
        ("nav-vm-create-list",
         "FALSE FALSE FALSE",
         Can (Model, Add_Document) & " " & Can (Model, Add_Source) & " " & Can (Model, Add_Folder));
      Nav_VM.Observe (Model, Effects'Access);
      begin
         Nav_VM.Execute (Model, Add_Source);
         Check ("nav-vm-create-contract", "raised", "not raised");
      exception
         when Ada.Assertions.Assertion_Error =>
            Check ("nav-vm-create-contract", "raised", "raised");
      end;
      Check ("nav-vm-create-refused-effects", "2 2", Number (Effects.Before) & " " & Number (Effects.After));
      Nav_VM.Observe (Model, null);
      Nav_VM.Execute (Model, Close_List);
      Confirm_VM.Ask_Project (Where.Dialog, 1, "Episode 1");
      Check
        ("nav-vm-create-dialog",
         "FALSE FALSE FALSE",
         Can (Model, Add_Document) & " " & Can (Model, Add_Source) & " " & Can (Model, Add_Folder));
      Confirm_VM.Execute (Where.Dialog, Confirm_VM.Cancel);
      for What in Show_Outline .. Show_Publish loop
         Nav_VM.Execute (Model, What);
         Check
           ("nav-vm-create-mode-" & What'Image,
            (case What is
               when Show_Canvas  => "TRUE TRUE FALSE",
               when Show_Writing => "TRUE FALSE TRUE",
               when others       => "FALSE FALSE FALSE"),
            Can (Model, Add_Document) & " " & Can (Model, Add_Source) & " " & Can (Model, Add_Folder));
      end loop;
      Nav_VM.Execute (Model, Show_Writing);
      Nav_VM.Observe (Model, Effects'Access);
      Seen := Nav_VM.Version (Model);
      Nav_VM.Execute (Model, Add_Document);
      Check
        ("nav-vm-create-writing-document",
         "TRUE TRUE",
         Image (Effects.Last = Add_Document) & " " & Image (Nav_VM.Version (Model) = Seen));
      Nav_VM.Execute (Model, Add_Folder);
      Check
        ("nav-vm-create-writing-folder",
         "TRUE TRUE 4 4",
         Image (Effects.Last = Add_Folder)
         & " "
         & Image (Nav_VM.Version (Model) = Seen)
         & " "
         & Number (Effects.Before)
         & " "
         & Number (Effects.After));
      Nav_VM.Observe (Model, null);
      Nav_VM.Execute (Model, Open_List);
      Check ("nav-vm-create-writing-modal", "FALSE FALSE", Can (Model, Add_Document) & " " & Can (Model, Add_Folder));
   end Creating;

   procedure Writing_Sections is
      Where    : aliased Setting;
      Model    : Nav_VM.View_Model renames Where.Model;
      Effects  : aliased Creation_Effects;
      Seen     : Parts.Version_Number;
      Rejected : Boolean := False;
   begin
      Prepare (Where);
      Outline_VM_Fakes.Put (Where.Sections, "First");
      Outline_VM_Fakes.Put (Where.Sections, "Second");
      Check
        ("nav-vm-sections-home",
         "FALSE FALSE",
         Can (Model, Add_Document, 1) & " " & Can (Model, Toggle_Section_Notes, 1));
      Nav_VM.Execute (Model, Open_Project, 1);
      Check
        ("nav-vm-sections-canvas",
         "FALSE FALSE",
         Can (Model, Add_Document, 1) & " " & Can (Model, Toggle_Section_Notes, 1));
      Nav_VM.Execute (Model, Show_Writing);
      Check
        ("nav-vm-sections-rows",
         "TRUE TRUE FALSE FALSE TRUE FALSE",
         Can (Model, Add_Document, 1)
         & " "
         & Can (Model, Add_Document, 2)
         & " "
         & Can (Model, Add_Document, 3)
         & " "
         & Can (Model, Toggle_Section_Notes, 0)
         & " "
         & Can (Model, Toggle_Section_Notes, 2)
         & " "
         & Can (Model, Toggle_Section_Notes, 3));
      Nav_VM.Observe (Model, Effects'Access);
      Seen := Nav_VM.Version (Model);
      Nav_VM.Execute (Model, Add_Document, 2);
      Check
        ("nav-vm-sections-add-effect",
         "TRUE 2 TRUE",
         Image (Effects.Last = Add_Document)
         & " "
         & Number (Effects.Index)
         & " "
         & Image (Nav_VM.Version (Model) = Seen));
      Nav_VM.Execute (Model, Toggle_Section_Notes, 1);
      Check
        ("nav-vm-sections-notes-open",
         "TRUE FALSE 1",
         Image (Outline_VM.Is_Open (Where.Outline, 1))
         & " "
         & Image (Outline_VM.Is_Open (Where.Outline, 2))
         & " "
         & Number (Effects.Index));
      Nav_VM.Execute (Model, Toggle_Section_Notes, 1);
      Check ("nav-vm-sections-notes-closed", "FALSE", Image (Outline_VM.Is_Open (Where.Outline, 1)));
      Nav_VM.Observe (Model, null);
      Nav_VM.Execute (Model, Open_List);
      Check
        ("nav-vm-sections-modal",
         "FALSE FALSE",
         Can (Model, Add_Document, 1) & " " & Can (Model, Toggle_Section_Notes, 1));
      Nav_VM.Observe (Model, Effects'Access);
      begin
         Nav_VM.Execute (Model, Add_Document, 1);
      exception
         when Ada.Assertions.Assertion_Error =>
            Rejected := True;
      end;
      Check
        ("nav-vm-sections-contract",
         "TRUE 3 3",
         Image (Rejected) & " " & Number (Effects.Before) & " " & Number (Effects.After));
      Nav_VM.Observe (Model, null);
      Nav_VM.Execute (Model, Close_List);
      Outline_VM.Execute (Where.Outline, Outline_VM.Remove_Section, 2);
      Check
        ("nav-vm-sections-removed",
         "FALSE FALSE",
         Can (Model, Add_Document, 2) & " " & Can (Model, Toggle_Section_Notes, 2));
   end Writing_Sections;

   type List_Surface is limited new Item_List_VM.Surface with record
      Canvas      : access Canvas_VM.View_Model;
      Navigation  : access Nav_VM.View_Model;
      Was_Listing : Boolean := False;
   end record;
   overriding
   procedure Apply (Self : in out List_Surface; What : Canvas_VM.Command; Slot : Items.Slot);
   overriding
   procedure Apply (Self : in out List_Surface; What : Canvas_VM.Command; Slot : Items.Slot) is
   begin
      Self.Was_Listing := Nav_VM.Is_Listing (Self.Navigation.all);
      Canvas_VM.Execute (Self.Canvas.all, What, Slot);
   end Apply;

   procedure List_Commands is
      Where    : aliased Setting;
      Kept     : aliased Canvas_VM_Fakes.Few;
      Slots    : aliased Items.Models.Tables.Table;
      Room     : aliased Canvas_VM_Fakes.Room;
      Canvas   : aliased Canvas_VM.View_Model;
      Surface  : aliased List_Surface;
      List     : Item_List_VM.View_Model;
      Slot     : Items.Slot;
      Rejected : Boolean := False;
   begin
      Prepare (Where);
      Room.Models := Slots'Unchecked_Access;
      Canvas_VM.Initialize (Canvas, Kept'Unchecked_Access, Room'Unchecked_Access, Slots'Unchecked_Access);
      Surface.Canvas := Canvas'Unchecked_Access;
      Surface.Navigation := Where.Model'Unchecked_Access;
      Canvas_VM.Enter (Canvas);
      Canvas_VM.Add (Canvas, "First", Items.Note, Slot);
      Item_List_VM.Initialize
        (List, Canvas'Unchecked_Access, Slots'Unchecked_Access, Surface'Unchecked_Access, Where.Model'Access);
      Item_List_VM.Refresh (List);
      Check ("item-list-vm-home", "FALSE", Image (Item_List_VM.Can_Execute (List, Item_List_VM.Reveal, 1)));
      Nav_VM.Execute (Where.Model, Open_Project, 1);
      Check ("item-list-vm-closed", "FALSE", Image (Item_List_VM.Can_Execute (List, Item_List_VM.Remove, 1)));
      Nav_VM.Execute (Where.Model, Open_List);
      Item_List_VM.Execute (List, Item_List_VM.Toggle_Shown, 1);
      Check
        ("item-list-vm-toggle-stays",
         "TRUE TRUE TRUE",
         Image (Surface.Was_Listing)
         & " "
         & Image (Nav_VM.Is_Listing (Where.Model))
         & " "
         & Image (Item_List_VM.Is_Closed (List, 1)));
      Confirm_VM.Ask_Project (Where.Dialog, 1, "Episode 1");
      Check
        ("item-list-vm-under-dialog",
         "FALSE FALSE",
         Image (Item_List_VM.Can_Execute (List, Item_List_VM.Remove, 1))
         & " "
         & Image (Item_List_VM.Can_Execute (List, Item_List_VM.Reveal)));
      Confirm_VM.Execute (Where.Dialog, Confirm_VM.Cancel);
      Item_List_VM.Execute (List, Item_List_VM.Reveal, 1);
      Check
        ("item-list-vm-reveal-closes-first",
         "FALSE FALSE TRUE",
         Image (Surface.Was_Listing)
         & " "
         & Image (Nav_VM.Is_Listing (Where.Model))
         & " "
         & Image (Canvas_VM.Raised (Canvas) = Slot));
      begin
         Item_List_VM.Execute (List, Item_List_VM.Remove, 1);
      exception
         when Ada.Assertions.Assertion_Error =>
            Rejected := True;
      end;
      Check
        ("item-list-vm-hidden-contract", "TRUE TRUE", Image (Rejected) & " " & Image (Canvas_VM.Count (Canvas) = 1));
   end List_Commands;

   type Fold_Store is limited new Sidebar_VM.Store with record
      Value  : Sidebar_VM.Open_Sections := [True, False, True];
      Writes : Natural := 0;
      Fails  : Boolean := False;
   end record;
   overriding
   function Load (Self : Fold_Store) return Sidebar_VM.Open_Sections
   is (Self.Value);
   overriding
   procedure Save (Self : in out Fold_Store; Value : Sidebar_VM.Open_Sections);
   overriding
   procedure Save (Self : in out Fold_Store; Value : Sidebar_VM.Open_Sections) is
   begin
      Self.Writes := @ + 1;
      if Self.Fails then
         raise Program_Error with "preferences unavailable";
      end if;
      Self.Value := Value;
   end Save;

   type Source_Surface is limited new Writing_Sources_VM.Effects with record
      Slot, Calls : Natural := 0;
   end record;
   overriding
   procedure Toggle_Source (Self : in out Source_Surface; Slot : Items.Slot);
   overriding
   procedure Toggle_Source (Self : in out Source_Surface; Slot : Items.Slot) is
   begin
      Self.Slot := Slot;
      Self.Calls := @ + 1;
   end Toggle_Source;

   procedure Source_Commands is
      package S renames Writing_Sources_VM;
      Where   : aliased Setting;
      Models  : aliased Items.Models.Tables.Table;
      Surface : aliased Source_Surface;
      Model   : S.View_Model;
      Seen    : Parts.Version_Number;
      Refused : Boolean := False;
   begin
      Prepare (Where);
      S.Initialize (Model, Where.Model'Access, Models'Access, Surface'Access);
      Models.Grow (3);
      Items.Models.Assign (Models (1), (Key => 1, Kind => Items.Source, others => <>), "");
      Items.Models.Assign (Models (2), (Key => 2, Kind => Items.Source, others => <>), "");
      Items.Models.Assign (Models (3), (Key => 3, others => <>), "");
      Check
        ("writing-sources-add-rules",
         "TRUE FALSE FALSE",
         Image (S.Can_Add (Model, 1)) & " " & Image (S.Can_Add (Model, 3)) & " " & Image (S.Can_Add (Model, 4)));
      S.Add (Model, 1);
      S.Add (Model, 2);
      Check
        ("writing-sources-order",
         "2 1 2 FALSE",
         Number (S.Count (Model))
         & " "
         & Number (S.Slot_At (Model, 1))
         & " "
         & Number (S.Slot_At (Model, 2))
         & " "
         & Image (S.Can_Add (Model, 1)));
      Check ("writing-sources-home", "FALSE", Image (S.Can_Execute (Model, S.Toggle_Source, 1)));
      Nav_VM.Execute (Where.Model, Open_Project, 1);
      for What in Show_Outline .. Show_Publish loop
         Nav_VM.Execute (Where.Model, What);
         Check
           ("writing-sources-mode-" & What'Image,
            Image (What = Show_Writing),
            Image (S.Can_Execute (Model, S.Toggle_Source, 1)));
      end loop;
      Nav_VM.Execute (Where.Model, Show_Writing);
      Check
        ("writing-sources-row-limits",
         "FALSE FALSE",
         Image (S.Can_Execute (Model, S.Toggle_Source, 0)) & " " & Image (S.Can_Execute (Model, S.Toggle_Source, 3)));
      Seen := S.Version (Model);
      S.Execute (Model, S.Toggle_Source, 2);
      Check
        ("writing-sources-effect",
         "2 1 TRUE",
         Number (Surface.Slot) & " " & Number (Surface.Calls) & " " & Image (S.Version (Model) = Seen));
      S.Remove (Model, 1);
      S.Execute (Model, S.Toggle_Source, 1);
      Check
        ("writing-sources-removed-row",
         "1 2 1",
         Number (S.Count (Model)) & " " & Number (Surface.Slot) & " " & Number (S.Row_Of (Model, 2)));
      Seen := S.Version (Model);
      S.Remove (Model, 1);
      Check ("writing-sources-remove-no-change", "TRUE", Image (S.Version (Model) = Seen));
      Nav_VM.Execute (Where.Model, Open_List);
      Check ("writing-sources-modal", "FALSE", Image (S.Can_Execute (Model, S.Toggle_Source, 1)));
      begin
         S.Execute (Model, S.Toggle_Source, 1);
      exception
         when Ada.Assertions.Assertion_Error =>
            Refused := True;
      end;
      Check ("writing-sources-contract", "TRUE 2", Image (Refused) & " " & Number (Surface.Calls));
      Nav_VM.Execute (Where.Model, Close_List);
      Items.Models.Release (Models (2));
      Check ("writing-sources-released", "FALSE", Image (S.Can_Execute (Model, S.Toggle_Source, 1)));
      Items.Models.Assign (Models (2), (Key => 20, Kind => Items.Source, others => <>), "");
      Check ("writing-sources-reused-slot", "FALSE", Image (S.Can_Execute (Model, S.Toggle_Source, 1)));
      S.Remove (Model, 2);
      S.Add (Model, 2);
      S.Execute (Model, S.Toggle_Source, 1);
      Check
        ("writing-sources-new-identity",
         "TRUE 3",
         Image (S.Can_Execute (Model, S.Toggle_Source, 1)) & " " & Number (Surface.Calls));
      S.Reset (Model);
      Seen := S.Version (Model);
      S.Reset (Model);
      Check
        ("writing-sources-empty",
         "0 FALSE TRUE",
         Number (S.Count (Model))
         & " "
         & Image (S.Can_Execute (Model, S.Toggle_Source, 1))
         & " "
         & Image (S.Version (Model) = Seen));
      --  User-created sources have growing storage, independent of the widget pool size.
      Models.Grow (300);
      for Slot in 4 .. 300 loop
         Items.Models.Assign (Models (Slot), (Key => Items.Id (Slot), Kind => Items.Source, others => <>), "");
         S.Add (Model, Slot);
      end loop;
      Check
        ("writing-sources-growing",
         "297 300",
         Number (S.Count (Model)) & " " & Number (S.Slot_At (Model, S.Count (Model))));
   end Source_Commands;

   procedure Link_Offers is
      package S renames Writing_Sources_VM;
      Where   : aliased Setting;
      Models  : aliased Items.Models.Tables.Table;
      Surface : aliased Source_Surface;
      Model   : S.View_Model;
      Heard   : Long_Texts.Text;

      procedure Hear (Title, Address : String) is
      begin
         Ada.Strings.Unbounded.Append (Heard, Title & "=" & Address & ";");
      end Hear;

      function Offered return String is
      begin
         Heard := Long_Texts.Null_Text;
         S.Offer_Links (Model, Hear'Access);
         return Long_Texts.To_String (Heard);
      end Offered;
   begin
      Prepare (Where);
      S.Initialize (Model, Where.Model'Access, Models'Access, Surface'Access);
      Models.Grow (5);
      Items.Models.Assign
        (Models (1),
         (Key => 1, Kind => Items.Source, Origin => Items.Remote, Title => Long_Texts.To_Text ("One"), others => <>),
         "https://one.example");
      Items.Models.Assign
        (Models (2),
         (Key => 2, Kind => Items.Source, Origin => Items.Local, Title => Long_Texts.To_Text ("Local"), others => <>),
         "https://local.example");
      Items.Models.Assign
        (Models (3),
         (Key    => 3,
          Kind   => Items.Source,
          Origin => Items.Remote,
          Title  => Long_Texts.To_Text ("Not an address"),
          others => <>),
         "just some words");
      Items.Models.Assign
        (Models (4),
         (Key => 4, Kind => Items.Source, Origin => Items.Remote, Title => Long_Texts.To_Text ("Two"), others => <>),
         "https://two.example");
      Check ("link-offers-none", "", Offered);
      for Slot in 1 .. 4 loop
         S.Add (Model, Slot);
      end loop;
      Check ("link-offers-web-pages", "One=https://one.example;Two=https://two.example;", Offered);
      S.Remove (Model, 1);
      Check ("link-offers-follow-rows", "Two=https://two.example;", Offered);
      Items.Models.Release (Models (4));
      Check ("link-offers-released", "", Offered);
   end Link_Offers;

   type Page_Surface is limited new Writing_VM.Actions.Effects with record
      Rank, Slot, Calls, Tool, Linked, Asked, Titled, Ended, Row, Renamed, Names, Sources, Menu : Natural := 0;
   end record;
   overriding
   procedure Open_Sources (Self : in out Page_Surface; Rank : Positive);
   overriding
   procedure Toggle_Dictation (Self : in out Page_Surface; Slot : Items.Slot);
   overriding
   procedure Use_Tool (Self : in out Page_Surface; Rank : Positive; Tool : Positive);
   overriding
   procedure Follow_Link (Self : in out Page_Surface; Rank : Positive);
   overriding
   procedure Ask_Link (Self : in out Page_Surface; Rank : Positive);
   overriding
   procedure Begin_Page_Title (Self : in out Page_Surface; Rank : Positive);
   overriding
   procedure Open_Section_Menu (Self : in out Page_Surface; Rank : Positive);
   overriding
   procedure End_Page_Title (Self : in out Page_Surface; Rank : Positive);
   overriding
   procedure Select_Row (Self : in out Page_Surface; Row : Positive);
   overriding
   procedure Rename_Row (Self : in out Page_Surface; Row : Positive);
   overriding
   procedure End_Name_Edit (Self : in out Page_Surface);
   overriding
   procedure End_Source_Name_Edit (Self : in out Page_Surface);
   overriding
   procedure Begin_Page_Title (Self : in out Page_Surface; Rank : Positive) is
   begin
      Self.Titled := Rank;
      Self.Calls := @ + 1;
   end Begin_Page_Title;
   overriding
   procedure End_Page_Title (Self : in out Page_Surface; Rank : Positive) is
   begin
      Self.Ended := Rank;
      Self.Calls := @ + 1;
   end End_Page_Title;
   overriding
   procedure Select_Row (Self : in out Page_Surface; Row : Positive) is
   begin
      Self.Row := Row;
      Self.Calls := @ + 1;
   end Select_Row;
   overriding
   procedure Rename_Row (Self : in out Page_Surface; Row : Positive) is
   begin
      Self.Renamed := Row;
      Self.Calls := @ + 1;
   end Rename_Row;
   overriding
   procedure End_Name_Edit (Self : in out Page_Surface) is
   begin
      Self.Names := @ + 1;
      Self.Calls := @ + 1;
   end End_Name_Edit;
   overriding
   procedure End_Source_Name_Edit (Self : in out Page_Surface) is
   begin
      Self.Sources := @ + 1;
      Self.Calls := @ + 1;
   end End_Source_Name_Edit;
   overriding
   procedure Open_Section_Menu (Self : in out Page_Surface; Rank : Positive) is
   begin
      Self.Menu := Rank;
      Self.Calls := @ + 1;
   end Open_Section_Menu;
   overriding
   procedure Use_Tool (Self : in out Page_Surface; Rank : Positive; Tool : Positive) is
   begin
      Self.Rank := Rank;
      Self.Tool := Tool;
      Self.Calls := @ + 1;
   end Use_Tool;
   overriding
   procedure Follow_Link (Self : in out Page_Surface; Rank : Positive) is
   begin
      Self.Linked := Rank;
      Self.Calls := @ + 1;
   end Follow_Link;
   overriding
   procedure Ask_Link (Self : in out Page_Surface; Rank : Positive) is
   begin
      Self.Asked := Rank;
      Self.Calls := @ + 1;
   end Ask_Link;
   overriding
   procedure Open_Sources (Self : in out Page_Surface; Rank : Positive) is
   begin
      Self.Rank := Rank;
      Self.Calls := @ + 1;
   end Open_Sources;
   overriding
   procedure Toggle_Dictation (Self : in out Page_Surface; Slot : Items.Slot) is
   begin
      Self.Slot := Slot;
      Self.Calls := @ + 1;
   end Toggle_Dictation;

   procedure Page_Commands is
      package A renames Writing_VM.Actions;
      package T renames Writing_VM.Trees;
      Where   : aliased Setting;
      Tree    : aliased T.Tree_Model;
      Models  : aliased Items.Models.Tables.Table;
      Surface : aliased Page_Surface;
      Names   : aliased Naming_VM.Model;
      Model   : A.Page_Model;
      Dirs    : Items.Directories.Directory_List;
      Docs    : T.Documents;
      Refused : Boolean := False;
   begin
      Prepare (Where);
      Models.Grow (2);
      Items.Models.Assign (Models (1), (Key => 1, others => <>), "");
      Items.Models.Assign (Models (2), (Key => 2, others => <>), "");
      Docs.Append ((Slot => 1, others => <>));
      Docs.Append ((Slot => 2, others => <>));
      T.Arrange (Tree, Dirs, Docs);
      A.Initialize (Model, Where.Model'Access, Tree'Access, Models'Access, Names'Access, Surface'Access);
      Check ("page-vm-home", "FALSE", Image (A.Can_Execute (Model, A.Open_Sources, 1)));
      Nav_VM.Execute (Where.Model, Open_Project, 1);
      for What in Show_Outline .. Show_Publish loop
         Nav_VM.Execute (Where.Model, What);
         Check
           ("page-vm-mode-" & What'Image,
            Image (What = Show_Writing),
            Image (A.Can_Execute (Model, A.Toggle_Dictation, 1)));
      end loop;
      Nav_VM.Execute (Where.Model, Show_Writing);
      Check
        ("page-vm-ranks",
         "FALSE TRUE FALSE",
         Image (A.Can_Execute (Model, A.Open_Sources, 0))
         & " "
         & Image (A.Can_Execute (Model, A.Open_Sources, 2))
         & " "
         & Image (A.Can_Execute (Model, A.Open_Sources, 3)));
      A.Execute (Model, A.Open_Sources, 2);
      A.Execute (Model, A.Toggle_Dictation, 1);
      Check
        ("page-vm-effects",
         "2 1 2",
         Number (Surface.Rank) & " " & Number (Surface.Slot) & " " & Number (Surface.Calls));
      --  The editor's own events: a tool is told with its page, the links by the page.
      Check
        ("page-vm-tool-ranks",
         "FALSE TRUE TRUE FALSE",
         Image (A.Can_Execute (Model, A.Use_Tool, 0))
         & " "
         & Image (A.Can_Execute (Model, A.Use_Tool, A.Tool_Index (2, 8)))
         & " "
         & Image (A.Can_Execute (Model, A.Use_Tool, A.Tool_Index (1, 1)))
         & " "
         & Image (A.Can_Execute (Model, A.Use_Tool, A.Tool_Index (3, 1))));
      A.Execute (Model, A.Use_Tool, A.Tool_Index (2, 3));
      A.Execute (Model, A.Follow_Link, 1);
      A.Execute (Model, A.Ask_Link, 2);
      Check
        ("page-vm-editor-effects",
         "2 3 1 2 5",
         Number (Surface.Rank)
         & " "
         & Number (Surface.Tool)
         & " "
         & Number (Surface.Linked)
         & " "
         & Number (Surface.Asked)
         & " "
         & Number (Surface.Calls));
      --  Rows are of the tree, whatever they are of; the end of a page title is of any page widget, and of
      --  the writing view only the rest are.
      declare
         Rows : constant Natural := T.Count (Tree);
      begin
         Check
           ("page-vm-row-ranges",
            "FALSE TRUE FALSE TRUE",
            Image (A.Can_Execute (Model, A.Select_Row, 0))
            & " "
            & Image (A.Can_Execute (Model, A.Select_Row, Rows))
            & " "
            & Image (A.Can_Execute (Model, A.Rename_Row, Rows + 1))
            & " "
            & Image (A.Can_Execute (Model, A.Rename_Row, 1)));
         --  The ends are of what is being edited, and of nothing else.
         Check
           ("page-vm-nothing-to-end",
            "FALSE FALSE FALSE TRUE",
            Image (A.Can_Execute (Model, A.End_Name_Edit))
            & " "
            & Image (A.Can_Execute (Model, A.End_Source_Name_Edit))
            & " "
            & Image (A.Can_Execute (Model, A.End_Page_Title, 2))
            & " "
            & Image (A.Can_Execute (Model, A.Begin_Page_Title, 2)));
         Naming_VM.Begin_Title (Names, 2);
         Naming_VM.Begin_Directory (Names, 1);
         Naming_VM.Begin_Source (Names, 1);
         Check
           ("page-vm-something-to-end",
            "TRUE TRUE TRUE FALSE",
            Image (A.Can_Execute (Model, A.End_Name_Edit))
            & " "
            & Image (A.Can_Execute (Model, A.End_Source_Name_Edit))
            & " "
            & Image (A.Can_Execute (Model, A.End_Page_Title, 2))
            & " "
            & Image (A.Can_Execute (Model, A.Begin_Page_Title, 2)));
         A.Execute (Model, A.Select_Row, Rows);
         A.Execute (Model, A.Rename_Row, 1);
         Naming_VM.End_Title (Names, 2);
         A.Execute (Model, A.Begin_Page_Title, 2);
         Naming_VM.Begin_Title (Names, 2);
         A.Execute (Model, A.End_Page_Title, 2);
         A.Execute (Model, A.End_Name_Edit);
         A.Execute (Model, A.End_Source_Name_Edit);
         Check
           ("page-vm-name-effects",
            Number (Rows) & " 1 2 2 1 1 6",
            Number (Surface.Row)
            & " "
            & Number (Surface.Renamed)
            & " "
            & Number (Surface.Titled)
            & " "
            & Number (Surface.Ended)
            & " "
            & Number (Surface.Names)
            & " "
            & Number (Surface.Sources)
            & " "
            & Number (Surface.Calls - 5));
      end;
      Check
        ("page-vm-section-menu",
         "FALSE TRUE FALSE",
         Image (A.Can_Execute (Model, A.Open_Section_Menu, 0))
         & " "
         & Image (A.Can_Execute (Model, A.Open_Section_Menu, 2))
         & " "
         & Image (A.Can_Execute (Model, A.Open_Section_Menu, 3)));
      A.Execute (Model, A.Open_Section_Menu, 2);
      Check ("page-vm-section-menu-effect", "2", Number (Surface.Menu));
      Surface.Calls := Surface.Calls - 1;
      Check
        ("page-vm-name-indexes",
         "FALSE FALSE FALSE FALSE",
         Image (A.Can_Execute (Model, A.End_Name_Edit, 1))
         & " "
         & Image (A.Can_Execute (Model, A.End_Source_Name_Edit, 1))
         & " "
         & Image (A.Can_Execute (Model, A.End_Page_Title, 0))
         & " "
         & Image (A.Can_Execute (Model, A.End_Page_Title, 3)));
      Surface.Calls := 2;
      Docs.Clear;
      Docs.Append ((Slot => 2, others => <>));
      Docs.Append ((Slot => 1, others => <>));
      T.Arrange (Tree, Dirs, Docs);
      A.Execute (Model, A.Toggle_Dictation, 1);
      Check ("page-vm-reordered", "2", Number (Surface.Slot));
      Items.Models.Set_Dictation (Models (2), Items.Models.Transcribing);
      Check
        ("page-vm-transcribing",
         "FALSE TRUE",
         Image (A.Can_Execute (Model, A.Toggle_Dictation, 1)) & " " & Image (A.Can_Execute (Model, A.Open_Sources, 1)));
      Items.Models.Set_Dictation (Models (2), Items.Models.Listening);
      Check ("page-vm-stoppable", "TRUE", Image (A.Can_Execute (Model, A.Toggle_Dictation, 1)));
      Nav_VM.Execute (Where.Model, Open_List);
      Check
        ("page-vm-modal",
         "FALSE FALSE",
         Image (A.Can_Execute (Model, A.Open_Sources, 1)) & " " & Image (A.Can_Execute (Model, A.Toggle_Dictation, 1)));
      begin
         A.Execute (Model, A.Open_Sources, 1);
      exception
         when Ada.Assertions.Assertion_Error =>
            Refused := True;
      end;
      Check ("page-vm-contract", "TRUE 3", Image (Refused) & " " & Number (Surface.Calls));
      Nav_VM.Execute (Where.Model, Close_List);
      Items.Models.Release (Models (2));
      Check ("page-vm-released", "FALSE", Image (A.Can_Execute (Model, A.Open_Sources, 1)));
      Items.Models.Assign (Models (2), (Key => 3, Kind => Items.Source, others => <>), "");
      Check ("page-vm-reused-source", "FALSE", Image (A.Can_Execute (Model, A.Open_Sources, 1)));
      T.Reset (Tree);
      Check ("page-vm-empty", "FALSE", Image (A.Can_Execute (Model, A.Open_Sources, 1)));
   end Page_Commands;

   procedure Naming is
      package N renames Naming_VM;
      Names : N.Model;
   begin
      Check
        ("naming-vm-none",
         "0 0 0 FALSE FALSE",
         Number (N.Directory (Names))
         & " "
         & Number (N.Document (Names))
         & " "
         & Number (N.Source (Names))
         & " "
         & Image (N.Is_Renaming_Name (Names))
         & " "
         & Image (N.Is_Titling (Names, 1)));
      N.Begin_Directory (Names, 3);
      N.Begin_Source (Names, 7);
      Check
        ("naming-vm-begun",
         "3 0 7 TRUE",
         Number (N.Directory (Names))
         & " "
         & Number (N.Document (Names))
         & " "
         & Number (N.Source (Names))
         & " "
         & Image (N.Is_Renaming_Name (Names)));
      N.End_Directory (Names);
      N.Begin_Document (Names, 2);
      Check
        ("naming-vm-document",
         "0 2 TRUE",
         Number (N.Directory (Names)) & " " & Number (N.Document (Names)) & " " & Image (N.Is_Renaming_Name (Names)));
      N.End_Document (Names);
      Check ("naming-vm-ended", "FALSE 7", Image (N.Is_Renaming_Name (Names)) & " " & Number (N.Source (Names)));

      --  Titles are of the page's rank, and grow with the pages.
      N.Begin_Title (Names, 40);
      Check
        ("naming-vm-titles",
         "TRUE FALSE FALSE",
         Image (N.Is_Titling (Names, 40))
         & " "
         & Image (N.Is_Titling (Names, 39))
         & " "
         & Image (N.Is_Titling (Names, 41)));
      N.Begin_Title (Names, 2);
      N.End_Title (Names, 40);
      N.End_Title (Names, 99);
      Check
        ("naming-vm-title-ended",
         "FALSE TRUE",
         Image (N.Is_Titling (Names, 40)) & " " & Image (N.Is_Titling (Names, 2)));
      N.Reset (Names);
      Check
        ("naming-vm-reset",
         "0 0 0 TRUE",
         Number (N.Directory (Names))
         & " "
         & Number (N.Document (Names))
         & " "
         & Number (N.Source (Names))
         & " "
         & Image (N.Is_Titling (Names, 2)));
   end Naming;

   procedure Sidebar is
      package F renames Sidebar_VM;
      Where   : aliased Setting;
      Kept    : aliased Fold_Store;
      Model   : F.View_Model;
      Seen    : Parts.Version_Number;
      Refused : Boolean := False;
   begin
      Prepare (Where);
      F.Initialize (Model, Where.Model'Access, Kept'Access);
      Check
        ("sidebar-vm-loaded",
         "TRUE FALSE TRUE",
         Image (F.Is_Open (Model, F.Edit))
         & " "
         & Image (F.Is_Open (Model, F.Documents))
         & " "
         & Image (F.Is_Open (Model, F.Sources)));
      Seen := F.Version (Model);
      F.Initialize (Model, Where.Model'Access, Kept'Access);
      Check ("sidebar-vm-same-load", "TRUE", Image (F.Version (Model) = Seen));
      Check ("sidebar-vm-home", "FALSE", Image (F.Can_Execute (Model, F.Toggle_Edit)));
      Nav_VM.Execute (Where.Model, Open_Project, 1);
      for What in Show_Outline .. Show_Publish loop
         Nav_VM.Execute (Where.Model, What);
         Check
           ("sidebar-vm-mode-" & What'Image, Image (What = Show_Writing), Image (F.Can_Execute (Model, F.Toggle_Edit)));
      end loop;
      Nav_VM.Execute (Where.Model, Show_Writing);
      Check ("sidebar-vm-invalid-index", "FALSE", Image (F.Can_Execute (Model, F.Toggle_Edit, 1)));
      for What in F.Command loop
         Seen := F.Version (Model);
         F.Execute (Model, What);
         Check ("sidebar-vm-changed-" & What'Image, "TRUE", Image (F.Version (Model) /= Seen));
      end loop;
      Check
        ("sidebar-vm-saved",
         "FALSE TRUE FALSE 3",
         Image (Kept.Value (F.Edit))
         & " "
         & Image (Kept.Value (F.Documents))
         & " "
         & Image (Kept.Value (F.Sources))
         & " "
         & Number (Kept.Writes));
      Nav_VM.Execute (Where.Model, Open_List);
      Seen := F.Version (Model);
      begin
         F.Execute (Model, F.Toggle_Edit);
      exception
         when Ada.Assertions.Assertion_Error =>
            Refused := True;
      end;
      Check
        ("sidebar-vm-refused",
         "TRUE TRUE 3",
         Image (Refused) & " " & Image (F.Version (Model) = Seen) & " " & Number (Kept.Writes));
      Nav_VM.Execute (Where.Model, Close_List);
      Confirm_VM.Ask_Project (Where.Dialog, 1, "Episode 1");
      Check ("sidebar-vm-dialog", "FALSE", Image (F.Can_Execute (Model, F.Toggle_Edit)));
      Confirm_VM.Execute (Where.Dialog, Confirm_VM.Cancel);
      Kept.Fails := True;
      F.Execute (Model, F.Toggle_Edit);
      Check
        ("sidebar-vm-save-failed",
         "TRUE FALSE 4",
         Image (F.Is_Open (Model, F.Edit)) & " " & Image (Kept.Value (F.Edit)) & " " & Number (Kept.Writes));
      F.Initialize (Model, Where.Model'Access);
      Check
        ("sidebar-vm-memory",
         "TRUE TRUE TRUE",
         Image (F.Is_Open (Model, F.Edit))
         & " "
         & Image (F.Is_Open (Model, F.Documents))
         & " "
         & Image (F.Is_Open (Model, F.Sources)));
      declare
         Config     : constant String := "/tmp/bonxie-sidebar-vm";
         Fold_Files : aliased F.Disk.File_Store;
         Reopened   : F.View_Model;
      begin
         F.Disk.Open (Fold_Files, Config);
         F.Disk.Save (Fold_Files, [False, True, False]);
         F.Initialize (Reopened, Where.Model'Access, Fold_Files'Access);
         F.Execute (Reopened, F.Toggle_Documents);
         Check
           ("sidebar-vm-disk",
            "FALSE FALSE FALSE",
            Image (Preferences.Load_Section_Open (Config, "edit"))
            & " "
            & Image (Preferences.Load_Section_Open (Config, "documents"))
            & " "
            & Image (Preferences.Load_Section_Open (Config, "sources")));
      end;
   end Sidebar;

   procedure Publishing is
      package P renames Publish_VM;
      Where         : aliased Setting;
      Model         : P.View_Model;
      Seen, Content : Parts.Version_Number;
      Refused       : Boolean := False;
   begin
      Prepare (Where);
      P.Initialize (Model, Where.Model'Access);
      Check
        ("publish-vm-initial",
         "FALSE FALSE FALSE FALSE",
         Image (P.Section_Headings (Model))
         & " "
         & Image (P.Document_Headings (Model))
         & " "
         & Image (P.Has_Format (Model))
         & " "
         & Image (P.Format_Open (Model)));
      Check ("publish-vm-home", "FALSE", Image (P.Can_Execute (Model, P.Toggle_Format)));
      Nav_VM.Execute (Where.Model, Open_Project, 1);
      for What in Show_Outline .. Show_Publish loop
         Nav_VM.Execute (Where.Model, What);
         Check
           ("publish-vm-mode-" & What'Image,
            Image (What = Show_Publish),
            Image
              (P.Can_Execute (Model, P.Toggle_Section_Headings)
               and then P.Can_Execute (Model, P.Toggle_Document_Headings)
               and then P.Can_Execute (Model, P.Toggle_Format)));
      end loop;
      Seen := P.Version (Model);
      begin
         P.Execute (Model, P.Choose_Format, 1);
      exception
         when Ada.Assertions.Assertion_Error =>
            Refused := True;
      end;
      Check ("publish-vm-closed-contract", "TRUE TRUE", Image (Refused) & " " & Image (P.Version (Model) = Seen));
      P.Execute (Model, P.Toggle_Section_Headings);
      P.Execute (Model, P.Toggle_Document_Headings);
      Check
        ("publish-vm-headings",
         "TRUE TRUE TRUE",
         Image (P.Section_Headings (Model))
         & " "
         & Image (P.Document_Headings (Model))
         & " "
         & Image (P.Content_Version (Model) /= Seen));
      Content := P.Content_Version (Model);
      P.Execute (Model, P.Toggle_Format);
      Check
        ("publish-vm-menu",
         "TRUE TRUE TRUE FALSE TRUE FALSE",
         Image (P.Format_Open (Model))
         & " "
         & Image (P.Content_Version (Model) = Content)
         & " "
         & Image (P.Can_Execute (Model, P.Choose_Format, 1))
         & " "
         & Image (P.Can_Execute (Model, P.Choose_Format))
         & " "
         & Image (P.Can_Execute (Model, P.Choose_Format, 2))
         & " "
         & Image (P.Can_Execute (Model, P.Toggle_Format, 1)));
      P.Execute (Model, P.Choose_Format, 1);
      Check
        ("publish-vm-chosen",
         "TRUE FALSE TRUE",
         Image (P.Has_Format (Model))
         & " "
         & Image (P.Format_Open (Model))
         & " "
         & Image (P.Content_Version (Model) /= Content));
      Content := P.Content_Version (Model);
      P.Execute (Model, P.Toggle_Format);
      P.Execute (Model, P.Choose_Format, 1);
      Check ("publish-vm-rechoose-no-content-change", "TRUE", Image (P.Content_Version (Model) = Content));
      P.Execute (Model, P.Toggle_Format);
      Nav_VM.Execute (Where.Model, Open_List);
      Check
        ("publish-vm-modal",
         "FALSE FALSE TRUE",
         Image (P.Can_Execute (Model, P.Toggle_Document_Headings))
         & " "
         & Image (P.Can_Execute (Model, P.Choose_Format, 1))
         & " "
         & Image (P.Can_Execute (Model, P.Close_Format)));
      P.Execute (Model, P.Close_Format);
      Nav_VM.Execute (Where.Model, Close_List);
      Confirm_VM.Ask_Project (Where.Dialog, 1, "Episode 1");
      Check ("publish-vm-dialog", "FALSE", Image (P.Can_Execute (Model, P.Toggle_Format)));
      Confirm_VM.Execute (Where.Dialog, Confirm_VM.Cancel);
      P.Execute (Model, P.Toggle_Format);
      P.Execute (Model, P.Toggle_Format);
      Check
        ("publish-vm-select-closes",
         "FALSE TRUE",
         Image (P.Format_Open (Model)) & " " & Image (P.Content_Version (Model) = Content));
      P.Execute (Model, P.Toggle_Format);
      Nav_VM.Execute (Where.Model, Show_Writing);
      P.Execute (Model, P.Close_Format);
      Nav_VM.Execute (Where.Model, Show_Publish);
      Check
        ("publish-vm-return",
         "FALSE TRUE TRUE TRUE",
         Image (P.Format_Open (Model))
         & " "
         & Image (P.Has_Format (Model))
         & " "
         & Image (P.Section_Headings (Model))
         & " "
         & Image (P.Document_Headings (Model)));
   end Publishing;

   procedure Publishing_Formats is
      package P renames Publish_VM;
      use type P.Formats;
      Where    : aliased Setting;
      Platform : aliased Publish_VM_Fakes.Platform;
      Kept     : aliased Publish_VM_Fakes.Store;
      Model    : P.View_Model;
      Content  : Parts.Version_Number;
      Names    : Ada.Strings.Unbounded.Unbounded_String;
      Source   : Ada.Strings.Unbounded.Unbounded_String;

      procedure Choose (Which : P.Formats) is
      begin
         P.Execute (Model, P.Toggle_Format);
         P.Execute (Model, P.Choose_Format, P.Formats'Pos (Which) + 1);
      end Choose;
   begin
      Prepare (Where);
      P.Initialize (Model, Where.Model'Access, Platform'Access, Kept'Access);
      Nav_VM.Execute (Where.Model, Open_Project, 1);
      Nav_VM.Execute (Where.Model, Show_Publish);
      P.Execute (Model, P.Toggle_Format);
      Check
        ("publish-formats-rows",
         "TRUE FALSE FALSE",
         Image (P.Can_Execute (Model, P.Choose_Format, 7))
         & " "
         & Image (P.Can_Execute (Model, P.Choose_Format, 8))
         & " "
         & Image (P.Can_Execute (Model, P.Choose_Format)));
      P.Execute (Model, P.Close_Format);
      for Each in P.Formats loop
         Choose (Each);
         Ada.Strings.Unbounded.Append
           (Names,
            P.Label (Each)
            & "."
            & P.Extension (Each)
            & (if P.Format (Model) = Each then " " else "? ")
            & (if P.Source_Shown (Model) then "source " else "file ")
            & (if P.Can_Execute (Model, P.Copy) then "copy|" else "nocopy|"));
         Ada.Strings.Unbounded.Append (Source, Image (P.Has_Source (Each)) & " ");
      end loop;
      Check
        ("publish-formats-each",
         "Markdown.md source copy|Plain text.txt source copy|HTML.html source copy|EPUB e-book.epub file nocopy|"
         & "OpenDocument (.odt).odt file nocopy|Word (.docx).docx file nocopy|PDF.pdf file nocopy|",
         Ada.Strings.Unbounded.To_String (Names));
      Check
        ("publish-formats-text", "TRUE TRUE TRUE FALSE FALSE FALSE FALSE ", Ada.Strings.Unbounded.To_String (Source));
      Content := P.Content_Version (Model);
      Choose (P.PDF);
      Check ("publish-formats-same-no-change", "TRUE", Image (P.Content_Version (Model) = Content));
      Choose (P.HTML);
      Check ("publish-formats-change", "TRUE", Image (P.Content_Version (Model) /= Content));
      Platform.Words := Long_Texts.To_Text ("words");
      Choose (P.DOCX);
      P.Execute (Model, P.Export);
      Platform.State := P.Chosen;
      Platform.Path := Long_Texts.To_Text ("/tmp/essay");
      P.Poll (Model);
      Check
        ("publish-formats-exported",
         "Word (.docx) /tmp/essay.docx words as Word (.docx)",
         P.Label (Platform.Asked) & " " & Long_Texts.To_String (Kept.Path) & " " & Long_Texts.To_String (Kept.Words));
      Choose (P.EPUB);
      P.Execute (Model, P.Export);
      Choose (P.PDF);
      Platform.State := P.Chosen;
      Platform.Path := Long_Texts.To_Text ("/tmp/book");
      P.Poll (Model);
      Check
        ("publish-formats-chosen-while-asking",
         "EPUB e-book /tmp/book.epub PDF",
         P.Label (Platform.Asked) & " " & Long_Texts.To_String (Kept.Path) & " " & P.Label (P.Format (Model)));
   end Publishing_Formats;

   procedure Publishing_Output is
      package P renames Publish_VM;
      Where         : aliased Setting;
      Platform      : aliased Publish_VM_Fakes.Platform;
      Kept          : aliased Publish_VM_Fakes.Store;
      Model         : P.View_Model;
      Seen, Content : Parts.Version_Number;
      Refused       : Boolean := False;
      Large         : constant String (1 .. 200_000) := [others => 'x'];
      Long_Path     : constant String := "/tmp/" & String'(1 .. 6_000 => 'p');
   begin
      Prepare (Where);
      P.Initialize (Model, Where.Model'Access, Platform'Access, Kept'Access);
      Check
        ("publish-output-home",
         "FALSE FALSE",
         Image (P.Can_Execute (Model, P.Export)) & " " & Image (P.Can_Execute (Model, P.Copy)));
      Nav_VM.Execute (Where.Model, Open_Project, 1);
      Nav_VM.Execute (Where.Model, Show_Publish);
      Check
        ("publish-output-no-format",
         "FALSE FALSE",
         Image (P.Can_Execute (Model, P.Export)) & " " & Image (P.Can_Execute (Model, P.Copy)));
      P.Execute (Model, P.Toggle_Format);
      P.Execute (Model, P.Choose_Format, 1);
      Platform.Export_Ready := False;
      Platform.Copy_Ready := False;
      Check
        ("publish-output-capabilities",
         "FALSE FALSE",
         Image (P.Can_Execute (Model, P.Export)) & " " & Image (P.Can_Execute (Model, P.Copy)));
      Platform.Export_Ready := True;
      Platform.Copy_Ready := True;
      Platform.Words := Long_Texts.To_Text (Large);
      P.Execute (Model, P.Export);
      Seen := P.Version (Model);
      Content := P.Content_Version (Model);
      Check
        ("publish-output-pending",
         "TRUE FALSE TRUE 1",
         Image (P.Export_Pending (Model))
         & " "
         & Image (P.Can_Execute (Model, P.Export))
         & " "
         & Image (P.Can_Execute (Model, P.Copy))
         & " "
         & Number (Platform.Requests));
      begin
         P.Execute (Model, P.Export);
      exception
         when Ada.Assertions.Assertion_Error =>
            Refused := True;
      end;
      P.Poll (Model);
      Check
        ("publish-output-waiting",
         "TRUE TRUE 1",
         Image (Refused) & " " & Image (P.Version (Model) = Seen) & " " & Number (Platform.Requests));
      --  Completion must retain the captured content even after leaving its project.
      Platform.Words := Long_Texts.To_Text ("another project's preview");
      Nav_VM.Execute (Where.Model, Leave_Project);
      Platform.Path := Long_Texts.To_Text (Long_Path);
      Platform.State := P.Chosen;
      P.Poll (Model);
      Check
        ("publish-output-snapshot",
         "TRUE TRUE TRUE 1",
         Image (not P.Export_Pending (Model))
         & " "
         & Image (Long_Texts.To_String (Kept.Words) = Large)
         & " "
         & Image (Long_Texts.To_String (Kept.Path) = Long_Path & ".md")
         & " "
         & Number (Kept.Writes));
      Seen := P.Version (Model);
      P.Poll (Model);
      Check
        ("publish-output-consumed-once",
         "TRUE 1 2",
         Image (P.Version (Model) = Seen) & " " & Number (Kept.Writes) & " " & Number (Platform.Results));
      Nav_VM.Execute (Where.Model, Open_Project, 1);
      Nav_VM.Execute (Where.Model, Show_Publish);
      P.Execute (Model, P.Export);
      Platform.State := P.Cancelled;
      P.Poll (Model);
      Check
        ("publish-output-cancelled",
         "FALSE TRUE 1",
         Image (P.Export_Pending (Model)) & " " & Image (P.Can_Execute (Model, P.Export)) & " " & Number (Kept.Writes));
      P.Execute (Model, P.Export);
      Platform.Path := Long_Texts.Null_Text;
      Platform.State := P.Chosen;
      P.Poll (Model);
      Check ("publish-output-empty-path", "FALSE 1", Image (P.Export_Pending (Model)) & " " & Number (Kept.Writes));
      P.Execute (Model, P.Export);
      Platform.Path := Long_Texts.To_Text ("/tmp/export.md");
      Platform.State := P.Chosen;
      Kept.Fails := True;
      P.Poll (Model);
      Check
        ("publish-output-write-failed",
         "FALSE TRUE 2",
         Image (P.Export_Pending (Model)) & " " & Image (P.Can_Execute (Model, P.Export)) & " " & Number (Kept.Writes));
      Kept.Fails := False;
      P.Execute (Model, P.Export);
      Platform.State := P.Chosen;
      P.Poll (Model);
      Check ("publish-output-retry", "FALSE 3", Image (P.Export_Pending (Model)) & " " & Number (Kept.Writes));
      Check
        ("publish-output-extensions",
         "TRUE",
         Image
           (P.File_Name ("/tmp/folder.with.dot/export", P.Markdown) = "/tmp/folder.with.dot/export.md"
            and then P.File_Name ("/tmp/export.txt", P.Markdown) = "/tmp/export.txt"
            and then P.File_Name ("/tmp/book", P.EPUB) = "/tmp/book.epub"
            and then P.File_Name ("/tmp/book.md", P.PDF) = "/tmp/book.md"));
      Platform.Accept_Copy := False;
      Seen := P.Version (Model);
      P.Execute (Model, P.Copy);
      Check
        ("publish-output-copy-failed",
         "Copy to Clipboard -1 TRUE",
         P.Copy_Caption (Model) & " " & P.Copy_Remaining (Model)'Image & " " & Image (P.Version (Model) = Seen));
      Platform.Accept_Copy := True;
      Platform.Words := Long_Texts.To_Text (Large);
      P.Execute (Model, P.Copy);
      Check
        ("publish-output-copy",
         "Copied 2500 TRUE TRUE",
         P.Copy_Caption (Model)
         & " "
         & Number (P.Copy_Remaining (Model))
         & " "
         & Image (Long_Texts.To_String (Platform.Board) = Large)
         & " "
         & Image (P.Content_Version (Model) = Content));
      Seen := P.Version (Model);
      P.Execute (Model, P.Copy);
      Check ("publish-output-copy-same-time", "TRUE", Image (P.Version (Model) = Seen));
      Platform.Time := 2_599;
      P.Poll (Model);
      Check
        ("publish-output-copy-before-expiry",
         "Copied 1 TRUE",
         P.Copy_Caption (Model) & " " & Number (P.Copy_Remaining (Model)) & " " & Image (P.Version (Model) = Seen));
      P.Execute (Model, P.Copy);
      Platform.Time := 2_600;
      P.Poll (Model);
      Check
        ("publish-output-copy-renewed",
         "Copied 2499",
         P.Copy_Caption (Model) & " " & Number (P.Copy_Remaining (Model)));
      Platform.Time := 5_099;
      Check ("publish-output-copy-due", "0", Number (P.Copy_Remaining (Model)));
      P.Poll (Model);
      Check
        ("publish-output-copy-expired",
         "Copy to Clipboard -1",
         P.Copy_Caption (Model) & " " & P.Copy_Remaining (Model)'Image);
      Seen := P.Version (Model);
      P.Poll (Model);
      Check ("publish-output-no-change", "TRUE", Image (P.Version (Model) = Seen));
      Platform.Copy_Delay := 3_000;
      P.Execute (Model, P.Copy);
      Check ("publish-output-confirmed-after-copy", "2500", Number (P.Copy_Remaining (Model)));
      Platform.Copy_Delay := 0;
      Nav_VM.Execute (Where.Model, Open_List);
      Check
        ("publish-output-modal",
         "FALSE FALSE",
         Image (P.Can_Execute (Model, P.Export)) & " " & Image (P.Can_Execute (Model, P.Copy)));
      Nav_VM.Execute (Where.Model, Close_List);
      declare
         Without_Store, Without_Platform : P.View_Model;
      begin
         P.Initialize (Without_Store, Where.Model'Access, Platform'Access);
         P.Initialize (Without_Platform, Where.Model'Access);
         P.Execute (Without_Store, P.Toggle_Format);
         P.Execute (Without_Store, P.Choose_Format, 1);
         P.Execute (Without_Platform, P.Toggle_Format);
         P.Execute (Without_Platform, P.Choose_Format, 1);
         Check
           ("publish-output-missing-dependencies",
            "FALSE TRUE FALSE FALSE",
            Image (P.Can_Execute (Without_Store, P.Export))
            & " "
            & Image (P.Can_Execute (Without_Store, P.Copy))
            & " "
            & Image (P.Can_Execute (Without_Platform, P.Export))
            & " "
            & Image (P.Can_Execute (Without_Platform, P.Copy)));
      end;
      declare
         Disk : P.Disk.File_Store;
         Path : constant String := "/tmp/bonxie-publish-vm-output.md";
      begin
         P.Disk.Save (Disk, Path, "# Output" & ASCII.LF & Large & ASCII.LF);
         Check ("publish-output-disk", "TRUE", Image (Files.Read (Path) = "# Output" & ASCII.LF & Large & ASCII.LF));
      end;
   end Publishing_Output;

   procedure Stored is
      Store    : aliased Projects.Store;
      Outlines : aliased Outline_VM.Stored.Sections_Kept;
      Kept     : aliased Nav_VM.Stored.Projects_Kept;
      Recent   : aliased Home_VM.View_Model;
      Outline  : aliased Outline_VM.View_Model;
      Voice    : aliased Settings_VM_Fakes.Pretend;
      Saved    : aliased Settings_VM_Fakes.Notes;
      Settings : aliased Settings_VM.View_Model;
      Dialog   : aliased Confirm_VM.View_Model;
      Model    : Nav_VM.View_Model;
      Existing : Projects.Id;
   begin
      Projects.Open (Store, Projects.Memory);
      Items.Schema.Prepare (Store);
      Existing := Projects.Create (Store, "Great skua");
      Outline_VM.Stored.Open (Outlines, Store'Access);
      Outline_VM.Initialize (Outline, Outlines'Access);
      Nav_VM.Stored.Open (Kept, Store'Access);
      Settings_VM.Initialize (Settings, Voice'Access, Saved'Access, "/nowhere");
      declare
         Library : aliased Home_VM_Fakes.Few;
      begin
         Home_VM.Initialize (Recent, Library'Access);
         Nav_VM.Initialize (Model, Kept'Access, Recent'Access, Outline'Access, Settings'Access, Dialog'Access);

         --  A project of the database, its name as it was kept, and the view it was left at.
         Nav_VM.Open (Model, Existing);
         Check
           ("nav-vm-stored-opened",
            "PROJECT 'Great skua' CANVAS",
            Nav_VM.Screen (Model)'Image & " '" & Nav_VM.Name (Model) & "' " & Nav_VM.Mode (Model)'Image);
         Nav_VM.Execute (Model, Show_Writing);
         Nav_VM.Execute (Model, Begin_Rename);
         Nav_VM.Set_Draft (Model, "Arctic skua");
         Nav_VM.Execute (Model, Accept_Rename);
         Nav_VM.Execute (Model, Leave_Project);
         Check ("nav-vm-stored-kept", "2", Number (Projects.Tab (Store, Existing)));
         declare
            Found  : Boolean;
            Result : Projects.Project;
         begin
            Projects.Find (Store, Existing, Found, Result);
            Check ("nav-vm-stored-renamed", "Arctic skua", Projects.Titles.To_String (Result.Title));
         end;
         Nav_VM.Open (Model, Existing);
         Nav_VM.Restore_Mode (Model);
         Check ("nav-vm-stored-restored", "WRITE", Nav_VM.Mode (Model)'Image);
         Nav_VM.Execute (Model, Leave_Project);

         --  A new one, untitled.
         Nav_VM.Execute (Model, Start_Project);
         Check
           ("nav-vm-stored-new",
            "PROJECT 'Untitled project' TRUE",
            Nav_VM.Screen (Model)'Image
            & " '"
            & Nav_VM.Name (Model)
            & "' "
            & Image (Nav_VM.Project_Key (Model) /= Existing));
      end;
   end Stored;

end Nav_VM_Tests;
