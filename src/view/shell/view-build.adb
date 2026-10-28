with Writing_Sources_VM;
with Writing_VM.Actions;
with Publish_VM;
with Sidebar_VM;
with Site_Filter_VM;
with Sidebar_VM.Disk;
with View.Search;
with Backgrounds;
with Scripts;
with Items.Schema;
with Ada.Command_Line;
with Ada.Directories;
with Preferences;
with Grammar_VM.Stored;
with Home_VM.Stored;
with Canvas_VM;
with Confirm_VM;
with Canvas_VM.Stored;
with Nav_VM;
with Nav_VM.Stored;
with Pomarine.View_Models;
with Outline_VM.Stored;
with Settings_VM.Disk;
with Speech.Models;
with Icon_Set;
with Pomarine.Line_Texts;
with Pomarine.UI;
with Pomarine.Widgets;
with Pomarine.Widgets.Layouts;
with Pomarine.Widgets.Tooltips;
with View.Browsers;
with View.Canvas_Items;
with View.Links;
with View.Listing;
with View.Writing;
with View.Outlines;
with View.Recent;
with View.Style;
with View.Build.Dialogs;
with View.Build.Outline_View;
with View.Build.Settings_Form;
with View.Build.Shell_Views;
with View.Build.Write_View;

package body View.Build is

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
         return Ada.Directories.Containing_Directory (Ada.Command_Line.Command_Name);
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

   procedure Hide_Card_Plus (Item : in out Session);
   --  The new-project card declares its focus; its decorative plus is not a separate accessible control.

   procedure Hide_Card_Plus (Item : in out Session) is
   begin
      --  The plus in the card does what the card does: not a stop of its own,
      --  nor a button more to an assistive technology.
      Widgets.Hide_From_Accessibility
        (Pomarine.UI.Widget_Of (Screen_Of (Item, Home_Region).all, Item.Home_View.New_Card_Plus).all);
   end Hide_Card_Plus;

   procedure Make_Slot (Item : in out Session; Which : Items.Slot) is
      Slots : constant Natural := Which;
   begin
      Item.Models.Grow (Slots);
      Item.Windows.Grow (Slots);
      Item.Docs.Pages.Grow (Slots);
      Item.Reading.Readers.Grow (Slots);
      Item.Reading.Source_Rows.Grow (Slots);
      Item.Linking.Pins.Grow (Slots);
      Item.Linking.Pin_Left.Resize (Slots, [others => -1.0E9]);
      Item.Linking.Pin_Top.Resize (Slots, [others => -1.0E9]);
      Item.Reading.Reader_Sync.Resize (Slots, (others => <>));
      Item.Reading.Reader_Placed.Resize (Slots, False);
      Item.Page_View.Menu_Slots.Resize (Slots, 1);
      Item.Grammar_Checks.Documents.Resize (Slots, (others => <>));
      Shell_Views.Make_Window (Item, Which);
      Canvas_Items.Listen (Item, Which);
      Links.Make_Pins (Item, Which);
      Write_View.Make_Page (Item, Which);
      Write_View.Make_Source_Row (Item, Which);
      Write_View.Make_Reader (Item, Which);
      Buttons.Set_Focusable (Item.Docs.Pages (Which).Sources_Button, True);
      Grips.Set_Focusable (Item.Reading.Source_Rows (Which).Row, True);
      Writing.Listen_Slot (Item, Which);
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
      for Each in First .. Rows loop
         Write_View.Make_Tree_Row (Item, Each);
         Writing.Listen_Row (Item, Each);
      end loop;
   end Reserve_Rows;

   procedure Set_Up (Item : in out Session; Source : String; File_Name : String; Store_Path : String) is
   begin
      Projects.Open (Item.Nav.Store, Store_Path);
      Items.Schema.Prepare (Item.Nav.Store);
      Home_VM.Stored.Open (Item.Home_Model.Library, Item.Nav.Store'Unchecked_Access);
      Home_VM.Initialize
        (Item.Home_Model.Model, Item.Home_Model.Library'Unchecked_Access, Item.Dialog_Model.Model'Access);
      Grammar_VM.Stored.Open (Item.Grammar_Model.Library, Item.Nav.Store'Unchecked_Access);
      Grammar_VM.Initialize (Item.Grammar_Model.Model, Item.Grammar_Model.Library'Unchecked_Access);
      Outline_VM.Stored.Open (Item.Outline_Model.Library, Item.Nav.Store'Unchecked_Access);
      Outline_VM.Initialize (Item.Outline_Model.Model, Item.Outline_Model.Library'Unchecked_Access);
      Item.Outline_Reactions.Owner := Item'Unchecked_Access;
      Outline_VM.Observe (Item.Outline_Model.Model, Item.Outline_Reactions'Access);
      Item.Layout_Watcher.Owner := Item'Unchecked_Access;
      Item.Home_Reactions.Owner := Item'Unchecked_Access;
      Home_VM.Observe (Item.Home_Model.Model, Item.Home_Reactions'Access);
      Item.Confirm_Reactions.Owner := Item'Unchecked_Access;
      Confirm_VM.Observe (Item.Dialog_Model.Model, Item.Confirm_Reactions'Access);
      Scripts.Load (Item.Host.Script, Source, File_Name);
      Item.Settings_Reactions.Owner := Item'Unchecked_Access;
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
                  Item.Page_View.Sidebar_Wide := Float'Max (Sidebar_Least, Float'Min (Sidebar_Most, Float (Kept)));
               end if;
            end;
            Sidebar_VM.Disk.Open (Item.Page_View.Folds_Kept, Config);
            Settings_VM.Disk.Open (Choices.Files, Config);
            Settings_VM.Initialize
              (Choices.Model,
               Choices.Voice'Unchecked_Access,
               Choices.Files'Unchecked_Access,
               Config,
               Kept_Speech     => Preferences.Load_Speech_Model (Config),
               Kept_Theme      => Preferences.Load_Theme (Config),
               Kept_Background => Preferences.Load_Background (Config),
               Kept_VSync      => Preferences.Load_VSync (Config),
               Reactions       => Item.Settings_Reactions'Access);
            --  The system may have let go of the compiled model: have it
            --  ready, in the background, before it is wanted.
            if Preferences."=" (Settings_VM.Speech_Model (Choices.Model), Preferences.Parakeet) then
               Speech.Models.Preload (Preferences.Speech_Model_Directory (Config));
            end if;
         else
            --  Offscreen, the light theme, whatever the system's is.
            Settings_VM.Initialize
              (Choices.Model,
               Choices.Voice'Unchecked_Access,
               null,
               Config,
               Kept_Theme      => Preferences.Light,
               Kept_Background => Preferences.Fixed,
               Reactions       => Item.Settings_Reactions'Access);
         end if;
         Site_Filter_VM.Initialize (Choices.Filter, (if Persist then Config else ""));
      end;
      Nav_VM.Stored.Open (Item.Nav_Model.Library, Item.Nav.Store'Unchecked_Access);
      Nav_VM.Initialize
        (Item.Nav_Model.Model,
         Item.Nav_Model.Library'Unchecked_Access,
         Item.Home_Model.Model'Unchecked_Access,
         Item.Outline_Model.Model'Unchecked_Access,
         Item.Choices.Model'Unchecked_Access,
         Item.Dialog_Model.Model'Unchecked_Access);
      Sidebar_VM.Initialize
        (Item.Page_View.Folding,
         Item.Nav_Model.Model'Access,
         (if Settings_VM.Persists (Item.Choices.Model) then Item.Page_View.Folds_Kept'Access else null));
      Item.Source_Platform.Owner := Item'Unchecked_Access;
      Writing_Sources_VM.Initialize
        (Item.Reading.Sources,
         Item.Nav_Model.Model'Access,
         Item.Models'Unrestricted_Access,
         Item.Source_Platform'Access);
      Item.Writing_Platform.Owner := Item'Unchecked_Access;
      Writing_VM.Actions.Initialize
        (Item.Page_View.Actions,
         Item.Nav_Model.Model'Access,
         Item.Docs.Ordering'Unrestricted_Access,
         Item.Models'Unrestricted_Access,
         Item.Naming.Names'Unrestricted_Access,
         Item.Writing_Platform'Access);
      Item.Publishing_Platform.Owner := Item'Unchecked_Access;
      Publish_VM.Initialize
        (Item.Publish_View.Options,
         Item.Nav_Model.Model'Access,
         Item.Publishing_Platform'Access,
         Item.Publish_View.Files'Access);
      Item.Publish_Watcher.Owner := Item'Unchecked_Access;
      Pomarine.View_Models.See (Item.Publish_Watcher.Seen, Publish_VM.Version (Item.Publish_View.Options));
      Item.Sidebar_Watcher.Owner := Item'Unchecked_Access;
      Pomarine.View_Models.See (Item.Sidebar_Watcher.Seen, Sidebar_VM.Version (Item.Page_View.Folding));
      --  It is shown as it is built: at the home screen.
      declare
         Nav : Nav_Choices renames Item.Nav_Model;
      begin
         Pomarine.View_Models.See (Nav.Seen, Nav_VM.Version (Nav.Model));
         Pomarine.View_Models.See (Nav.Screens, Nav_VM.Screen_Version (Nav.Model));
         Pomarine.View_Models.See (Nav.Views, Nav_VM.Mode_Version (Nav.Model));
      end;
      Canvas_VM.Stored.Open (Item.Canvas_Model.Library, Item.Nav.Store'Unchecked_Access);
      Item.Room.Owner := Item'Unchecked_Access;
      Canvas_VM.Initialize
        (Item.Canvas_Model.Model,
         Item.Canvas_Model.Library'Unchecked_Access,
         Item.Room'Unchecked_Access,
         Item.Models'Unrestricted_Access);
      Item.Nav_Reactions.Owner := Item'Unchecked_Access;
      Nav_VM.Observe (Item.Nav_Model.Model, Item.Nav_Reactions'Access);
      Item.Item_List.View.Owner := Item'Unchecked_Access;
      Item_List_VM.Initialize
        (Item.Item_List.Model,
         Item.Canvas_Model.Model'Unchecked_Access,
         Item.Models'Unrestricted_Access,
         Item.Item_List.View'Unchecked_Access,
         Item.Nav_Model.Model'Access);
      Item.Judge.Owner := Item'Unchecked_Access;
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
      --  focusable in their declarations and the text fields.
      Widgets.Set_Tab_Navigation (Item.Root.Widgets, True);
      if Item.Shell.Windowed then
         --  Whether it is shown, and the colours to go with it, are for Apply_Theme.
         declare
            Config  : constant String := Settings_VM.Config_Directory (Item.Choices.Model);
            Persist : constant Boolean := Settings_VM.Persists (Item.Choices.Model);
            Saved   : constant Boolean := Persist and then Preferences.Has_Seed (Config);
            Seed    : constant Backgrounds.Seed_Numbers :=
              (if Saved then Preferences.Load_Seed (Config) else Backgrounds.New_Seed);
         begin
            Backgrounds.Set_Shader (Item.Host.Background, Share_Directory ("shaders") & "/backgrounds.metal", Seed);
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
      Pomarine.Widgets.Tooltips.Install (Item.Root.Widgets, Item.Root.Tip);
      if Item.Shell.Windowed then
         Shell_Views.Build_Header (Item);
      end if;
      Shell_Views.Build_Home (Item);
      Shell_Views.Build_Project (Item);
      Browsers.Build (Item);
      Write_View.Build_Write (Item);
      Shell_Views.Build_Publish (Item);
      Outline_View.Build_Outline (Item);
      Outlines.Listen_Description (Item);
      Shell_Views.Build_Tray (Item);
      Search.Build (Item);
      Settings_Form.Build_Settings (Item);
      Dialogs.Build_Modal (Item);
      Dialogs.Build_List (Item);
      Reserve_Sections (Item, 0);
      Reserve_Rows (Item);

      Hide_Card_Plus (Item);
      Widgets.Set_Listener (Item.Root.Widgets, Item.Replies'Unchecked_Access);
      Item.Replies.Owner := Item'Unchecked_Access;
      for Card of Item.Home_View.Cards loop
         declare
            Field : Text_Fields.Text_Field renames
              Pomarine.UI.Widget_Of (Screen_Of (Item, Home_Region).all, Card.Field).all;
         begin
            Text_Fields.Set_Shared (Field, Item.Host.Doc_Resources'Unchecked_Access);
            Text_Fields.Configure (Field, Pomarine.Line_Texts.Interface_Font, Edit_Size);
         end;
      end loop;

      --  It starts at the home screen.
      Widgets.Set_Visible (Project_Panel (Item).all, False);
      Widgets.Set_Visible (Item.Page_View.Write_View, False);
      Widgets.Set_Visible (Item.Outline_View.View, False);
      Widgets.Set_Visible (Pomarine.UI.Named (Screen_Of (Item, Confirm_Region).all, Confirm_Overlay).all, False);
      Widgets.Set_Visible (Listing.Overlay (Item).all, False);
      Widgets.Set_Visible (Item.Dock.Dock_Panel, False);
      Recent.Refresh (Item);
      --  Before any event: the widgets must know where they are.
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Set_Up;

end View.Build;
