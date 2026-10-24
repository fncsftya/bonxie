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

   function Image (Value : Boolean) return String is (Value'Image);

   function Can (Model : Nav_VM.View_Model; What : Nav_VM.Command; Index : Natural := 0) return String is
     (Image (Nav_VM.Can_Execute (Model, What, Index)));

   function Number (Value : Integer) return String is (Value'Image (2 .. Value'Image'Last));

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
        (Where.Model, Where.Kept'Access, Where.Recent'Access, Where.Outline'Access, Where.Settings'Access,
         Where.Dialog'Access);
   end Prepare;

   function Where_Is (Model : Nav_VM.View_Model) return String is
     (Nav_VM.Screen (Model)'Image & " " & Nav_VM.Mode (Model)'Image & " "
      & Number (Integer (Nav_VM.Project_Key (Model))) & " '" & Nav_VM.Name (Model) & "'");

   procedure Opening is
      Where : aliased Setting;
      Model : Nav_VM.View_Model renames Where.Model;
      Seen  : Parts.Version_Number;
   begin
      Prepare (Where);
      Check ("nav-vm-first", "HOME CANVAS 0 '' PLAIN", Where_Is (Model) & " " & Nav_VM.Layer (Model)'Image);
      Check ("nav-vm-home-commands", "TRUE TRUE TRUE FALSE FALSE FALSE FALSE FALSE",
             Can (Model, Start_Project) & " "
             & Can (Model, Open_Project, 1) & " "
             & Can (Model, Open_Settings) & " "
             & Can (Model, Leave_Project) & " "
             & Can (Model, Show_Writing) & " "
             & Can (Model, Open_List) & " "
             & Can (Model, Begin_Rename) & " "
             & Image (Nav_VM.Takes_Gestures (Model)));
      Check ("nav-vm-no-such-row", "FALSE TRUE",
             Can (Model, Open_Project, 3) & " "
             & Can (Model, Open_Project));

      --  A project of the list: the latest is the first row.
      Seen := Nav_VM.Screen_Version (Model);
      Nav_VM.Execute (Model, Open_Project, 2);
      Check ("nav-vm-opened", "PROJECT CANVAS 1 'Great skua' TRUE TRUE",
             Where_Is (Model) & " " & Image (Nav_VM.Screen_Version (Model) /= Seen) & " "
             & Image (Nav_VM.Takes_Gestures (Model)));
      Check ("nav-vm-project-commands", "FALSE FALSE TRUE TRUE TRUE FALSE",
             Can (Model, Start_Project) & " "
             & Can (Model, Open_Settings) & " "
             & Can (Model, Leave_Project) & " "
             & Can (Model, Show_Writing) & " "
             & Can (Model, Begin_Rename) & " "
             & Can (Model, Close_List));

      Seen := Nav_VM.Screen_Version (Model);
      Nav_VM.Execute (Model, Leave_Project);
      Check ("nav-vm-left", "HOME CANVAS 0 '' TRUE",
             Where_Is (Model) & " " & Image (Nav_VM.Screen_Version (Model) /= Seen));
      Check ("nav-vm-left-outline", "FALSE", Image (Outline_VM.Is_Entered (Where.Outline)));

      --  A new project, as the database would have it.
      Nav_VM.Execute (Model, Start_Project);
      Check ("nav-vm-started", "PROJECT CANVAS 1 'Great skua' 1",
             Where_Is (Model) & " " & Number (Where.Kept.Made));
   end Opening;

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
      Check ("nav-vm-view-writing", "WRITE TRUE 2 1",
             Nav_VM.Mode (Model)'Image & " " & Image (Nav_VM.Mode_Version (Model) /= Seen) & " "
             & Number (Where.Kept.Tabs (1)) & " " & Number (Where.Kept.Left));
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
      Check ("nav-vm-rename-off", "FALSE FALSE FALSE TRUE",
             Image (Nav_VM.Is_Renaming (Model)) & " " & Can (Model, Accept_Rename) & " "
             & Can (Model, Cancel_Rename) & " " & Can (Model, Begin_Rename));
      Seen := Nav_VM.Renaming_Version (Model);
      Nav_VM.Execute (Model, Begin_Rename);
      Check ("nav-vm-rename-begun", "TRUE Great skua TRUE TRUE FALSE",
             Image (Nav_VM.Is_Renaming (Model)) & " " & Nav_VM.Draft (Model) & " "
             & Image (Nav_VM.Renaming_Version (Model) /= Seen) & " "
             & Can (Model, Accept_Rename) & " " & Can (Model, Begin_Rename));

      --  Typing is a change of the draft, not of the renaming.
      Seen := Nav_VM.Renaming_Version (Model);
      Nav_VM.Set_Draft (Model, "  Arctic skua ");
      Check ("nav-vm-rename-typed", "FALSE Great skua",
             Image (Nav_VM.Renaming_Version (Model) /= Seen) & " " & Nav_VM.Name (Model));
      Nav_VM.Execute (Model, Accept_Rename);
      Check ("nav-vm-rename-accepted", "FALSE 'Arctic skua' 1",
             Image (Nav_VM.Is_Renaming (Model)) & " '" & Nav_VM.Name (Model) & "' " & Number (Where.Sections.Writes));

      --  Not left without a name.
      Nav_VM.Execute (Model, Begin_Rename);
      Nav_VM.Set_Draft (Model, "   ");
      Nav_VM.Execute (Model, Accept_Rename);
      Check ("nav-vm-rename-blank", "FALSE 'Arctic skua' 1",
             Image (Nav_VM.Is_Renaming (Model)) & " '" & Nav_VM.Name (Model) & "' " & Number (Where.Sections.Writes));

      Nav_VM.Execute (Model, Begin_Rename);
      Nav_VM.Set_Draft (Model, "Pomarine skua");
      Nav_VM.Execute (Model, Cancel_Rename);
      Check ("nav-vm-rename-cancelled", "FALSE 'Arctic skua' 1",
             Image (Nav_VM.Is_Renaming (Model)) & " '" & Nav_VM.Name (Model) & "' " & Number (Where.Sections.Writes));

      --  Leaving does not lose a name that was being typed.
      Nav_VM.Execute (Model, Begin_Rename);
      Nav_VM.Set_Draft (Model, "Long-tailed skua");
      Nav_VM.Execute (Model, Leave_Project);
      Check ("nav-vm-rename-on-leaving", "FALSE HOME 'Long-tailed skua'",
             Image (Nav_VM.Is_Renaming (Model)) & " " & Nav_VM.Screen (Model)'Image & " '"
             & Projects.Titles.To_String (Where.Sections.Title) & "'");
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
      Check ("nav-vm-settings", "SETTINGS_FORM TRUE TRUE FALSE FALSE FALSE",
             Nav_VM.Layer (Model)'Image & " " & Image (Settings_VM.Is_Showing (Where.Settings)) & " "
             & Image (Nav_VM.Layer_Version (Model) /= Seen) & " " & Can (Model, Open_Settings) & " "
             & Can (Model, Start_Project) & " " & Can (Model, Open_Project, 1));
      Check ("nav-vm-settings-close", "TRUE TRUE", Can (Model, Close_Settings) & " "
             & Can (Model, Dismiss));

      --  The dialog over the settings is all that is asked.
      Confirm_VM.Ask_Model (Where.Dialog, "483.0 MB");
      Check ("nav-vm-model-dialog", "MODEL_DIALOG FALSE TRUE",
             Nav_VM.Layer (Model)'Image & " " & Can (Model, Close_Settings) & " "
             & Can (Model, Dismiss));
      Nav_VM.Execute (Model, Dismiss);
      Check ("nav-vm-model-dialog-away", "SETTINGS_FORM FALSE",
             Nav_VM.Layer (Model)'Image & " " & Image (Confirm_VM.Is_Asking (Where.Dialog)));
      Nav_VM.Execute (Model, Dismiss);
      Check ("nav-vm-settings-away", "PLAIN FALSE FALSE", Nav_VM.Layer (Model)'Image & " "
            & Image (Settings_VM.Is_Showing (Where.Settings)) & " " & Can (Model, Dismiss));

      --  A dialog over the home screen.
      Confirm_VM.Ask_Project (Where.Dialog, 1, "Episode 2");
      Check ("nav-vm-delete-dialog", "DELETING FALSE FALSE FALSE",
             Nav_VM.Layer (Model)'Image & " " & Can (Model, Start_Project) & " "
             & Can (Model, Open_Settings) & " " & Can (Model, Open_Project, 1));
      Nav_VM.Execute (Model, Dismiss);
      Check ("nav-vm-delete-dialog-away", "PLAIN TRUE", Nav_VM.Layer (Model)'Image & " "
            & Can (Model, Start_Project));

      --  The list of items over a project.
      Nav_VM.Open (Model, 1);
      Check ("nav-vm-project-plain", "TRUE TRUE",
             Image (Nav_VM.Takes_Gestures (Model)) & " " & Image (Nav_VM.Takes_Search (Model)));
      Nav_VM.Execute (Model, Open_List);
      Seen := Nav_VM.Layer_Version (Model);
      Nav_VM.Execute (Model, Open_List);
      Check ("nav-vm-list", "ITEM_LIST TRUE FALSE FALSE FALSE FALSE",
             Nav_VM.Layer (Model)'Image & " " & Image (Nav_VM.Is_Listing (Model)) & " "
             & Image (Nav_VM.Layer_Version (Model) /= Seen) & " " & Image (Nav_VM.Takes_Gestures (Model)) & " "
             & Image (Nav_VM.Takes_Search (Model)) & " " & Can (Model, Begin_Rename));
      Nav_VM.Execute (Model, Dismiss);
      Check ("nav-vm-list-away", "PLAIN FALSE TRUE",
             Nav_VM.Layer (Model)'Image & " " & Image (Nav_VM.Is_Listing (Model)) & " "
             & Image (Nav_VM.Takes_Gestures (Model)));

      --  Search is not for the outline or the publish view.
      Nav_VM.Execute (Model, Show_Outline);
      Check ("nav-vm-search-outline", "TRUE FALSE",
             Image (Nav_VM.Takes_Gestures (Model)) & " " & Image (Nav_VM.Takes_Search (Model)));
      Nav_VM.Execute (Model, Show_Writing);
      Check ("nav-vm-search-writing", "TRUE", Image (Nav_VM.Takes_Search (Model)));

      --  Leaving puts the list away.
      Nav_VM.Execute (Model, Open_List);
      Nav_VM.Execute (Model, Leave_Project);
      Check ("nav-vm-list-left", "FALSE PLAIN", Image (Nav_VM.Is_Listing (Model)) & " " & Nav_VM.Layer (Model)'Image);
   end Layers;

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
         Check ("nav-vm-stored-opened", "PROJECT 'Great skua' CANVAS",
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
         Check ("nav-vm-stored-new", "PROJECT 'Untitled project' TRUE",
               Nav_VM.Screen (Model)'Image & " '" & Nav_VM.Name (Model) & "' "
               & Image (Nav_VM.Project_Key (Model) /= Existing));
      end;
   end Stored;

end Nav_VM_Tests;
