with Viewer.Search;
with Backgrounds;
with Scripts;
with Items.Schema;
with Ada.Command_Line;
with Ada.Directories;
with Preferences;
with Grammar_VM.Stored;
with Home_VM.Stored;
with Outline_VM.Stored;
with Settings_VM.Disk;
with Speech.Models;
with Icon_Set;
with Pomarine.Line_Texts;
with Pomarine.Widgets;
with Pomarine.Widgets.Layouts;
with Viewer.Canvas_Items;
with Viewer.Links;
with Viewer.Section_Links;
with Viewer.Writing;
with Viewer.Outlines;
with Viewer.Responses;
with Viewer.Recent;
with Viewer.Style;
with Viewer.Build.Dialogs;
with Viewer.Build.Outline_View;
with Viewer.Build.Settings_Form;
with Viewer.Build.Shell_Views;
with Viewer.Build.Write_View;

package body Viewer.Build is

   package Widgets renames Pomarine.Widgets;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Text_Fields renames Pomarine.Widgets.Text_Fields;
   package Grips renames Pomarine.Widgets.Grips;

   use Style;
   use Pomarine.Widgets.Layouts;

   function Share_Directory (Folder : String) return String;
   --  Where the files of Folder in share/bonxie are: beside the
   --  executable's folder, as installed or built in place; or from the
   --  current directory, as the tests run in a folder of the project.
   --  "" if none is found.

   function Share_Directory (Folder : String) return String is
      Share : constant String := "share/bonxie/" & Folder;

      function Program_Folder return String is
      begin
         return Ada.Directories.Containing_Directory
                  (Ada.Command_Line.Command_Name);
      exception
         when Ada.Directories.Use_Error | Ada.Directories.Name_Error =>
            return ".";
      end Program_Folder;

      Beside : constant String := Program_Folder & "/../" & Share;
   begin
      if Ada.Directories.Exists (Beside) then
         return Beside;
      elsif Ada.Directories.Exists (Share) then
         return Share;
      elsif Ada.Directories.Exists ("../" & Share) then
         return "../" & Share;
      else
         return "";
      end if;
   end Share_Directory;

   procedure Make_Tab_Stops (Item : in out Session);
   --  Let Tab reach the buttons, and the cards that are clicked, as it
   --  does the fields: in the order they are in, which is the order of the
   --  screen. A click on one does not take the focus from a field.

   procedure Make_Tab_Stops (Item : in out Session) is
      procedure Stop (Part : in out Buttons.Button) is
      begin
         Buttons.Set_Focusable (Part, True);
      end Stop;

      procedure Stop (Part : in out Grips.Grip) is
      begin
         Grips.Set_Focusable (Part, True);
      end Stop;
   begin
      Stop (Item.Home_View.New_Button);
      Stop (Item.Home_View.Settings_Button);
      Stop (Item.Home_View.New_Card);
      Widgets.Set_Accessible_Name (Item.Home_View.New_Card, "New project");
      --  The plus in the card does what the card does: not a stop of its own,
      --  nor a button more to an assistive technology.
      Widgets.Hide_From_Accessibility (Item.Home_View.New_Card_Plus);
      Stop (Item.Home_View.Ok_Button);
      Stop (Item.Home_View.Cancel_Button);
      for Each of Item.Home_View.Cards loop
         Stop (Each.Peek);
         Stop (Each.Rename);
         Stop (Each.Delete);
      end loop;
      Stop (Item.Confirm.Dialog_Close);
      Stop (Item.Confirm.Confirm_Cancel);
      Stop (Item.Confirm.Confirm_Delete);
      Stop (Item.Prefs.Settings_Close);
      Stop (Item.Dock.Tool_Item);
      Stop (Item.Dock.Tool_Source);
      Stop (Item.Dock.Tool_List);
      Stop (Item.Item_List.List_Close);
      Stop (Item.Page_View.Docs_Add);
      Stop (Item.Page_View.Docs_Folder);
   end Make_Tab_Stops;

   procedure Make_Slot (Item : in out Session; Which : Items.Slot) is
      Slots : constant Natural := Which;
   begin
      Item.Windows.Grow (Slots);
      Item.Docs.Pages.Grow (Slots);
      Item.Reading.Readers.Grow (Slots);
      Item.Reading.Source_Rows.Grow (Slots);
      Item.Linking.Pins.Grow (Slots);
      Item.Linking.Pin_Left.Resize (Slots, [others => -1.0E9]);
      Item.Linking.Pin_Top.Resize (Slots, [others => -1.0E9]);
      Item.Docs.Doc_Dir.Resize (Slots, 0);
      Item.Reading.Reader_Sync.Resize (Slots, (others => <>));
      Item.Reading.Reader_Placed.Resize (Slots, False);
      Item.Reading.Write_Order.Resize (Slots, 1);
      Item.Reading.Source_Order.Resize (Slots, 1);
      Item.Page_View.Menu_Slots.Resize (Slots, 1);
      Item.Item_List.Row_Slots.Resize (Slots, 1);
      Item.Grammar_Checks.Documents.Resize (Slots, (others => <>));
      Shell_Views.Make_Window (Item, Which);
      Canvas_Items.Listen (Item, Which);
      Links.Make_Pins (Item, Which);
      Write_View.Make_Page (Item, Which);
      Write_View.Make_Source_Row (Item, Which);
      Write_View.Make_Reader (Item, Which);
      Buttons.Set_Focusable (Item.Docs.Pages (Which).Sources_Button, True);
      Grips.Set_Focusable (Item.Reading.Source_Rows (Which).Row, True);
      Responses.Listen_Slot (Item, Which);
      Writing.Listen_Slot (Item, Which);
      Section_Links.Listen_Page (Item, Which);
   end Make_Slot;
   --  The widgets of one more item.

   procedure Make_Section (Item : in out Session; Index : Positive) is
   begin
      Item.Outline_View.Blocks.Grow (Index);
      Item.Section_View.Heads.Grow (Index);
      Item.Section_View.Notes.Grow (Index);
      Item.Section_View.Empties.Grow (Index);
      Item.Section_Menu.Rows.Resize (Index + 1, 0);
      Outline_View.Make_Block (Item, Index);
      Outlines.Listen_Block (Item, Index);
      Write_View.Make_Section (Item, Index);
      Responses.Listen_Section (Item, Index);
      --  One more mark than there are sections: before the first, and after each.
      Item.Section_View.Gaps.Grow (Index + 1);
      Write_View.Make_Gap (Item, Index);
   end Make_Section;
   --  The widgets of one more section.

   procedure Reserve_Items (Item : in out Session; Count : Natural) is
   begin
      for Which in Item.Windows.Count + 1 .. Count loop
         Make_Slot (Item, Which);
      end loop;
      Reserve_Rows (Item);
   end Reserve_Items;

   procedure Reserve_Sections (Item : in out Session; Count : Natural) is
   begin
      if Item.Section_View.Gaps.Count = 0 then
         --  The mark before the first section is there with none.
         Item.Section_View.Gaps.Grow (1);
         Write_View.Make_Gap (Item, 0);
      end if;
      for Index in Item.Section_View.Heads.Count + 1 .. Count loop
         Make_Section (Item, Index);
      end loop;
   end Reserve_Sections;

   procedure Reserve_Rows (Item : in out Session) is
      First : constant Natural := Item.Docs.Doc_Rows.Count + 1;
      Rows  : constant Natural := 1 + Item.Docs.Dirs.Count + Item.Windows.Count;
   begin
      if Rows < First then
         return;
      end if;
      Item.Docs.Doc_Rows.Grow (Rows);
      Item.Docs.Tree.Resize (Rows, (others => <>));
      for Each in First .. Rows loop
         Write_View.Make_Tree_Row (Item, Each);
         Writing.Listen_Row (Item, Each);
      end loop;
   end Reserve_Rows;

   procedure Set_Up
     (Item       : in out Session;
      Source     : String;
      File_Name  : String;
      Store_Path : String)
   is
   begin
      Projects.Open (Item.Nav.Store, Store_Path);
      Items.Schema.Prepare (Item.Nav.Store);
      Home_VM.Stored.Open (Item.Home_Model.Library, Item.Nav.Store'Unchecked_Access);
      Home_VM.Initialize (Item.Home_Model.Model, Item.Home_Model.Library'Unchecked_Access);
      Grammar_VM.Stored.Open (Item.Grammar_Model.Library, Item.Nav.Store'Unchecked_Access);
      Grammar_VM.Initialize (Item.Grammar_Model.Model, Item.Grammar_Model.Library'Unchecked_Access);
      Outline_VM.Stored.Open (Item.Outline_Model.Library, Item.Nav.Store'Unchecked_Access);
      Outline_VM.Initialize (Item.Outline_Model.Model, Item.Outline_Model.Library'Unchecked_Access);
      Outline_Binding.Observe (Item.Outline_Model.Judge, Item.Outline_Model.Model'Unchecked_Access);
      Home_Binding.Observe (Item.Home_Model.Judge, Item.Home_Model.Model'Unchecked_Access);
      Confirm_Binding.Observe (Item.Dialog_Model.Judge, Item.Dialog_Model.Model'Unchecked_Access);
      Scripts.Load (Item.Host.Script, Source, File_Name);
      declare
         Config  : constant String := Preferences.Config_Directory (Store_Path);
         Persist : constant Boolean := Store_Path /= Projects.Memory;
         Choices : Settings_Choices renames Item.Choices;
      begin
         Settings_VM.Disk.Open (Choices.Voice, Preferences.Speech_Model_Directory (Config));
         if Persist then
            declare
               Kept : constant Natural := Preferences.Load_Sidebar_Width (Config);
            begin
               if Kept /= 0 then
                  Item.Page_View.Sidebar_Wide :=
                    Float'Max (Sidebar_Least, Float'Min (Sidebar_Most, Float (Kept)));
               end if;
            end;
            Item.Page_View.Edit_Open := Preferences.Load_Section_Open (Config, "edit");
            Item.Page_View.Docs_Open := Preferences.Load_Section_Open (Config, "documents");
            Item.Page_View.Sources_Open := Preferences.Load_Section_Open (Config, "sources");
            Settings_VM.Disk.Open (Choices.Files, Config);
            Settings_VM.Initialize
              (Choices.Model, Choices.Voice'Unchecked_Access, Choices.Files'Unchecked_Access, Config,
               Kept_Speech => Preferences.Load_Speech_Model (Config),
               Kept_Theme => Preferences.Load_Theme (Config),
               Kept_Background => Preferences.Load_Background (Config),
               Kept_VSync => Preferences.Load_VSync (Config));
            --  The system may have let go of the compiled model: have it
            --  ready, in the background, before it is wanted.
            if Preferences."=" (Settings_VM.Speech_Model (Choices.Model), Preferences.Parakeet) then
               Speech.Models.Preload (Preferences.Speech_Model_Directory (Config));
            end if;
         else
            --  Offscreen, the light theme, whatever the system's is.
            Settings_VM.Initialize
              (Choices.Model, Choices.Voice'Unchecked_Access, null, Config,
               Kept_Theme => Preferences.Light, Kept_Background => Preferences.Fixed);
         end if;
      end;
      Item.Judge.Owner := Item'Unchecked_Access;
      Binding.Observe (Item.Choices.Judge, Item.Choices.Model'Unchecked_Access);
      Widgets.Set_Validator (Item.Root.Widgets, Item.Judge'Unchecked_Access);
      Widgets.Set_Density (Item.Root.Widgets, Item.Shell.Density);
      Widgets.Set_Line_Texts (Item.Root.Widgets, Item.Host.Lines);
      Widgets.Set_Icons (Item.Root.Widgets, Item.Host.Pictures);
      Icon_Set.Install (Item.Host.Pictures, Share_Directory ("icons"));
      if Item.Shell.Windowed then
         Widgets.Set_Clipboard (Item.Root.Widgets, Item.Shell.System_Board);
      else
         Widgets.Set_Clipboard (Item.Root.Widgets, Item.Shell.Own_Board);
      end if;

      --  Tab and Shift+Tab move the focus between the controls made
      --  focusable (see Make_Tab_Stops) and the text fields.
      Widgets.Set_Tab_Navigation (Item.Root.Widgets, True);
      if Item.Shell.Windowed then
         --  Whether it is shown, and the colours to go with it, are for Apply_Theme.
         declare
            Config : constant String := Settings_VM.Config_Directory (Item.Choices.Model);
            Persist : constant Boolean := Settings_VM.Persists (Item.Choices.Model);
            Saved  : constant Boolean := Persist and then Preferences.Has_Seed (Config);
            Seed   : constant Backgrounds.Seed_Numbers :=
              (if Saved then Preferences.Load_Seed (Config) else Backgrounds.New_Seed);
         begin
            Backgrounds.Set_Shader
              (Item.Host.Background, Share_Directory ("shaders") & "/backgrounds.metal", Seed);
            --  The first picture is kept, so that it is this one next time.
            if Persist and then not Saved then
               Preferences.Save_Seed (Config, Seed);
            end if;
         exception
            when others =>
               null;  --  the picture holds for now; it is not worth a crash
         end;
      end if;
      Widgets.Set_Root (Item.Root.Widgets, Item.Root.Window_Panel);
      Set_Layout (Item.Root.Window_Panel, Flow => Column);
      if Item.Shell.Windowed then
         Shell_Views.Build_Header (Item);
      end if;
      Shell_Views.Build_Home (Item);
      Shell_Views.Build_Project (Item);
      Write_View.Build_Write (Item);
      Shell_Views.Build_Publish (Item);
      Outline_View.Build_Outline (Item);
      Shell_Views.Build_Tray (Item);
      Search.Build (Item);
      Settings_Form.Build_Settings (Item);
      Dialogs.Build_Modal (Item);
      Dialogs.Build_List (Item);
      Reserve_Sections (Item, 0);
      Reserve_Rows (Item);

      Responses.Install (Item);
      Make_Tab_Stops (Item);
      Widgets.Set_Listener (Item.Root.Widgets, Item.Replies'Unchecked_Access);
      Item.Replies.Owner := Item'Unchecked_Access;
      Buttons.Configure (Item.Home_View.Ok_Button, Buttons.Looks ("OK", Buttons.Primary));
      Buttons.Set_Label (Item.Home_View.Cancel_Button, "Cancel");
      Text_Fields.Set_Shared
        (Item.Title_Edit.Edit_Field, Item.Host.Doc_Resources'Unchecked_Access);
      Text_Fields.Configure
        (Item.Title_Edit.Edit_Field, Pomarine.Line_Texts.Interface_Font, Edit_Size);

      --  It starts at the home screen.
      Widgets.Set_Visible (Item.Toolbar.Project_Panel, False);
      Widgets.Set_Visible (Item.Page_View.Write_View, False);
      Widgets.Set_Visible (Item.Outline_View.View, False);
      Widgets.Set_Visible (Item.Confirm.Overlay, False);
      Widgets.Set_Visible (Item.Item_List.List_Overlay, False);
      Widgets.Set_Visible (Item.Dock.Dock_Panel, False);
      Recent.Refresh (Item);
      --  Before any event: the widgets must know where they are.
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Set_Up;

end Viewer.Build;
