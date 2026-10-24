with Settings_VM;
with Confirm_VM;
with Home_VM;
with Nav_VM;
with Preferences;
with Pomarine.Widgets.Callbacks;
with Pomarine.Widgets.Editors.Callbacks;
with Viewer.Canvas_Items;
with Viewer.Deletion;
with Viewer.Listing;
with Viewer.Navigation;
with Viewer.Outlines;
with Viewer.Recent;
with Viewer.Settings_View;
with Viewer.Writing;

package body Viewer.Responses is

   use type Nav_VM.Layers;

   package Widgets renames Pomarine.Widgets;

   use type Widgets.Event_Kind;
   package Hooks is new Pomarine.Widgets.Callbacks (Session);
   package Editor_Hooks is new Pomarine.Widgets.Editors.Callbacks (Session);

   subtype Source_Widget is Widgets.Widget'Class;

   --  The home screen

   procedure Delete_Project
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Delete_Project
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
   begin
      Deletion.Confirm (Item, Event.Index);
   end Delete_Project;

   --  The dialog over the screens that asks before deleting a project, a
   --  document or directory, or the speech model's files

   --  The settings: while the dialog about the model's files is up, it is
   --  all that takes clicks.

   function Settings_Open (Item : Session) return Boolean is
     (Nav_VM.Layer (Item.Nav_Model.Model) = Nav_VM.Settings_Form);

   procedure Choose_Light
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Choose_Light
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      if Settings_Open (Item) then
         Settings_View.Choose_Appearance (Item, Preferences.Light);
      end if;
   end Choose_Light;

   procedure Choose_Dark
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Choose_Dark
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      if Settings_Open (Item) then
         Settings_View.Choose_Appearance (Item, Preferences.Dark);
      end if;
   end Choose_Dark;

   procedure Choose_System
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Choose_System
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      if Settings_Open (Item) then
         Settings_View.Choose_Appearance (Item, Preferences.System);
      end if;
   end Choose_System;

   procedure Toggle_VSync
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Toggle_VSync
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      if Settings_Open (Item) then
         Settings_View.Choose_VSync (Item, not Settings_VM.VSync (Item.Choices.Model));
      end if;
   end Toggle_VSync;

   --  A card of backgrounds is clicked, in its picture or its name: the one the widget is tagged with.
   procedure Choose_Card
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Choose_Card
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
   begin
      if Settings_Open (Item) then
         Settings_View.Choose_Background (Item, Preferences.Background_Modes'Val (Event.Index));
      end if;
   end Choose_Card;

   --  The button on a card that is painted: another picture, which is the one chosen.
   procedure Reseed_Card
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Reseed_Card
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
   begin
      if Settings_Open (Item) then
         Settings_View.Choose_Background (Item, Preferences.Background_Modes'Val (Event.Index));
         Settings_View.Reseed (Item);
      end if;
   end Reseed_Card;

   procedure Choose_MacOS
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Choose_MacOS
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      if Settings_Open (Item) then
         Settings_View.Choose (Item, Preferences.MacOS);
      end if;
   end Choose_MacOS;

   procedure Choose_Parakeet
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Choose_Parakeet
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      if Settings_Open (Item) then
         Settings_View.Choose (Item, Preferences.Parakeet);
      end if;
   end Choose_Parakeet;

   procedure Download_Model
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Download_Model
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      if Settings_Open (Item) then
         Settings_View.Download (Item);
      end if;
   end Download_Model;

   procedure Delete_Model
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Delete_Model
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      if Settings_Open (Item) then
         Settings_View.Ask_To_Delete (Item);
      end if;
   end Delete_Model;

   --  A project

   procedure Add_Document
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Add_Document
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      if View_Mode (Item) = Write then
         Canvas_Items.Add (Item, Canvas_Items.Untitled_Document);
      else
         Canvas_Items.Add (Item);
      end if;
   end Add_Document;

   procedure Add_Source
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Add_Source
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      Canvas_Items.Add (Item, Canvas_Items.Untitled_Source, Items.Source);
   end Add_Source;

   --  What the menu bar and the keys ask

   procedure Perform
     (Item  : in out Session;
      Event : Widgets.Widget_Event) is
   begin
      --  The home screen's: what was typed in the field for a title is the model's before a command
      --  reads it, and the dialog's answer is done.
      Recent.Sync (Item);
      if Home_Binding.Perform (Item.Home_Model.Model, Event) then
         Recent.Sync (Item);
         return;
      end if;
      if Outline_Binding.Is_Bound (Event) then
         if Event.Kind = Widgets.Click then
            Outlines.Do_Command (Item, Outline_Binding.What (Event), Event.Index);
         end if;
         return;
      end if;
      if Confirm_Binding.Is_Bound (Event) then
         if Event.Kind = Widgets.Click then
            Deletion.Answer (Item, Confirm_Binding.What (Event));
         end if;
         return;
      end if;
      if Nav_Binding.Is_Bound (Event) then
         if Event.Kind in Widgets.Click | Widgets.Submit then
            Navigation.Do_Command (Item, Nav_Binding.What (Event), Event.Index);
         end if;
         return;
      end if;
   end Perform;

   --  Giving them to the widgets

   procedure Install (Item : in out Session) is
      Start   : Home_Parts renames Item.Home_View;
      Prefs   : Settings_Parts renames Item.Prefs;
      Bar     : Toolbar_Parts renames Item.Toolbar;
      Pages   : Page_Parts renames Item.Page_View;

      procedure Hear
        (Part    : in out Widgets.Widget'Class;
         Kind    : Widgets.Event_Kind;
         Do_This : Hooks.Handler;
         Index   : Natural := 0) is
      begin
         if Index /= 0 then
            Widgets.Set_Tag (Part, Widgets.No_Tag, Index);
         end if;
         Hooks.On (Part, Kind, Item'Unchecked_Access, Do_This);
      end Hear;

      use all type Widgets.Event_Kind;
   begin
      --  The home screen (the buttons that are also in the menu bar are given
      --  their command too, to be as it says: see Viewer.Menus)
      for Card in Start.Cards'Range loop
         Home_Binding.Bind (Start.Cards (Card).Rename, Home_VM.Begin_Rename, Card);
      end loop;
      Home_Binding.Bind (Start.Ok_Button, Home_VM.Accept_Rename);
      Home_Binding.Bind (Start.Cancel_Button, Home_VM.Cancel_Rename);
      Home_Binding.Trigger (Item.Title_Edit.Edit_Field, Home_VM.Accept_Rename);
      Confirm_Binding.Bind (Item.Confirm.Confirm_Delete, Confirm_VM.Confirm);
      Confirm_Binding.Bind (Item.Confirm.Confirm_Cancel, Confirm_VM.Cancel);
      Confirm_Binding.Bind (Item.Confirm.Dialog_Close, Confirm_VM.Cancel);
      Nav_Binding.Trigger (Start.New_Button, Nav_VM.Start_Project);
      Nav_Binding.Trigger (Start.New_Card, Nav_VM.Start_Project);
      Nav_Binding.Trigger (Start.New_Card_Plus, Nav_VM.Start_Project);
      Nav_Binding.Trigger (Start.Settings_Button, Nav_VM.Open_Settings);
      for Card in Start.Cards'Range loop
         Nav_Binding.Trigger (Start.Cards (Card).Peek, Nav_VM.Open_Project, Card);
         Nav_Binding.Trigger (Start.Cards (Card).Name, Nav_VM.Open_Project, Card);
         Hear (Start.Cards (Card).Delete, Click, Delete_Project'Access, Card);
      end loop;

      --  The settings
      Nav_Binding.Bind (Prefs.Settings_Close, Nav_VM.Close_Settings);
      Hear (Prefs.Theme_Light, Change, Choose_Light'Access);
      Hear (Prefs.Theme_Dark, Change, Choose_Dark'Access);
      Hear (Prefs.Theme_System, Change, Choose_System'Access);
      for Mode in Prefs.Cards'Range loop
         Hear (Prefs.Cards (Mode).Peek, Click, Choose_Card'Access, Preferences.Background_Modes'Pos (Mode));
         Hear (Prefs.Cards (Mode).Pick, Click, Choose_Card'Access, Preferences.Background_Modes'Pos (Mode));
         if Mode in Preferences.Pictures then
            Hear (Prefs.Cards (Mode).Reseed, Click, Reseed_Card'Access, Preferences.Background_Modes'Pos (Mode));
         end if;
      end loop;
      Hear (Prefs.Model_Native, Change, Choose_MacOS'Access);
      Hear (Prefs.Model_Parakeet, Change, Choose_Parakeet'Access);
      Hear (Prefs.VSync_Switch, Change, Toggle_VSync'Access);
      Hear (Prefs.Download_Button, Click, Download_Model'Access);
      Hear (Prefs.Delete_Button, Click, Delete_Model'Access);

      --  A project: the bar, the tray, and the list of items
      Nav_Binding.Bind (Bar.Close_Button, Nav_VM.Leave_Project);
      Nav_Binding.Bind (Bar.Outline_Tab, Nav_VM.Show_Outline);
      Nav_Binding.Bind (Bar.Canvas_Tab, Nav_VM.Show_Canvas);
      Nav_Binding.Bind (Bar.Write_Tab, Nav_VM.Show_Writing);
      Nav_Binding.Bind (Bar.Publish_Tab, Nav_VM.Show_Publish);
      Nav_Binding.Bind (Item.Dock.Tool_List, Nav_VM.Open_List);
      Nav_Binding.Bind (Item.Item_List.List_Close, Nav_VM.Close_List);
      Hear (Item.Dock.Tool_Item, Click, Add_Document'Access);
      Hear (Item.Dock.Tool_Source, Click, Add_Source'Access);
      Hear (Item.Item_List.List_View, Click, Listing.Clicked'Access);
      Hear (Item.Item_List.List_View, Submit, Listing.Clicked'Access);
      Hear (Item.Item_List.List_View, Act, Listing.Acted'Access);

      Hear (Bar.Title_Area, Double_Click, Navigation.Title_Double_Clicked'Access);
      Hear (Bar.Title_Field, Submit, Navigation.Title_Ended'Access);
      Hear (Bar.Title_Field, Blur, Navigation.Title_Ended'Access);

      --  The writing view
      Hear (Pages.Docs_Add, Click, Writing.Add_Page_Clicked'Access);
      Hear (Pages.Docs_Folder, Click, Writing.Add_Folder_Clicked'Access);
      Hear (Pages.Menu, Choose, Writing.Source_Chosen'Access);
      Hear (Item.Context.Context_Menu, Choose, Writing.Context_Chosen'Access);
   end Install;

   procedure Listen_Section (Item : in out Session; Index : Positive) is
      use all type Widgets.Event_Kind;
   begin
      Widgets.Set_Tag (Item.Section_View.Heads (Index).Add, Widgets.No_Tag, Index);
      Hooks.On (Item.Section_View.Heads (Index).Add, Click, Item'Unchecked_Access, Writing.Section_Add_Clicked'Access);
      Widgets.Set_Tag (Item.Section_View.Heads (Index).Notes, Widgets.No_Tag, Index);
      Hooks.On
        (Item.Section_View.Heads (Index).Notes, Click, Item'Unchecked_Access, Writing.Section_Notes_Clicked'Access);
      Widgets.Set_Tag (Item.Section_View.Empties (Index).Add, Widgets.No_Tag, Index);
      Hooks.On
        (Item.Section_View.Empties (Index).Add, Click, Item'Unchecked_Access, Writing.Section_Add_Clicked'Access);
   end Listen_Section;

   procedure Listen_Slot (Item : in out Session; Which : Items.Slot) is
      use all type Widgets.Event_Kind;

      procedure Hear (Part : in out Widgets.Widget'Class; Kind : Widgets.Event_Kind; Do_This : Hooks.Handler) is
      begin
         Widgets.Set_Tag (Part, Widgets.No_Tag, Which);
         Hooks.On (Part, Kind, Item'Unchecked_Access, Do_This);
      end Hear;
   begin
      Hear (Item.Docs.Pages (Which).Sources_Button, Click, Writing.Sources_Clicked'Access);
      Hear (Item.Docs.Pages (Which).Mic_Button, Click, Writing.Dictate_Clicked'Access);
      Editor_Hooks.On_Tool (Item.Docs.Pages (Which).Text, Item'Unchecked_Access, Writing.Tool_Used'Access);
      Editor_Hooks.On_Follow (Item.Docs.Pages (Which).Text, Item'Unchecked_Access, Writing.Link_Followed'Access);
      Editor_Hooks.On_Ask_Link (Item.Docs.Pages (Which).Text, Item'Unchecked_Access, Writing.Link_Asked'Access);
      Hear (Item.Reading.Source_Rows (Which).Row, Click, Writing.Source_Row_Clicked'Access);
   end Listen_Slot;

end Viewer.Responses;
