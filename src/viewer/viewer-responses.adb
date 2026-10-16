with Pomarine.Widgets.Callbacks;
with Pomarine.Widgets.Switches;
with Viewer.Canvas_Items;
with Viewer.Deletion;
with Viewer.Listing;
with Viewer.Navigation;
with Viewer.Recent;
with Viewer.Settings_View;
with Viewer.Writing;

package body Viewer.Responses is

   package Widgets renames Pomarine.Widgets;
   package Switches renames Pomarine.Widgets.Switches;
   package Hooks is new Pomarine.Widgets.Callbacks (Session);

   use type Projects.Id;

   subtype Source_Widget is Widgets.Widget'Class;

   --  The home screen

   procedure Start_Project
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Start_Project
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      if Item.Nav.Shown = Home then
         Navigation.Enter_New (Item);
      end if;
   end Start_Project;

   procedure Open_Settings
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Open_Settings
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      if Item.Nav.Shown = Home and then not Item.Prefs.Showing_Settings then
         Settings_View.Open (Item);
      end if;
   end Open_Settings;

   procedure Open_Project
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Open_Project
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
   begin
      if Item.Nav.Shown = Home then
         Navigation.Enter (Item, Item.Home_View.Row_Keys (Event.Index));
      end if;
   end Open_Project;

   procedure Rename_Project
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Rename_Project
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
   begin
      Recent.Begin_Rename (Item, Event.Index);
   end Rename_Project;

   procedure Delete_Project
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Delete_Project
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
   begin
      Deletion.Confirm (Item, Event.Index);
   end Delete_Project;

   procedure Accept_Rename
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Accept_Rename
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      if Item.Home_View.Editing /= 0 then
         Recent.Accept_Rename (Item);
      end if;
   end Accept_Rename;

   procedure Cancel_Rename
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Cancel_Rename
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      if Item.Home_View.Editing /= 0 then
         Recent.Cancel_Edit (Item);
      end if;
   end Cancel_Rename;

   --  The dialog over the screens that asks before deleting a project, a
   --  document or directory, or the speech model's files

   procedure Confirm_Deletion
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Confirm_Deletion
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      if Item.Nav.Shown = Home and then Item.Prefs.Showing_Settings then
         if Item.Confirm.Deleting_Model then
            Settings_View.Delete_Files (Item);
         end if;
      elsif (Item.Nav.Shown = Home and then Item.Confirm.Deleting /= 0)
        or else (Item.Nav.Shown = Project
                 and then Item.Confirm.Deleting_Node.Kind /= Overview_Node)
      then
         Deletion.Delete_Confirmed (Item);
      end if;
   end Confirm_Deletion;

   procedure Cancel_Deletion
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Cancel_Deletion
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      if Item.Nav.Shown = Home and then Item.Prefs.Showing_Settings then
         if Item.Confirm.Deleting_Model then
            Deletion.Close (Item);
         end if;
      elsif (Item.Nav.Shown = Home and then Item.Confirm.Deleting /= 0)
        or else (Item.Nav.Shown = Project
                 and then Item.Confirm.Deleting_Node.Kind /= Overview_Node)
      then
         Deletion.Close (Item);
      end if;
   end Cancel_Deletion;

   --  The settings: while the dialog about the model's files is up, it is
   --  all that takes clicks.

   function Settings_Open (Item : Session) return Boolean is
     (Item.Prefs.Showing_Settings and then not Item.Confirm.Deleting_Model);

   procedure Close_Settings
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Close_Settings
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      if Settings_Open (Item) then
         Settings_View.Close (Item);
      end if;
   end Close_Settings;

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

   procedure Switch_AI
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Switch_AI
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Event);
   begin
      if Settings_Open (Item) then
         Settings_View.Enable_AI (Item, Switches.Is_On (Switches.Switch (Source)));
      end if;
   end Switch_AI;

   procedure Open_AI_Models
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Open_AI_Models
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      if Settings_Open (Item) then
         Settings_View.Toggle_AI_Menu (Item);
      end if;
   end Open_AI_Models;

   procedure Choose_AI_Model
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Choose_AI_Model
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
   begin
      if Settings_Open (Item) then
         Settings_View.Choose_AI_Model (Item, Event.Row);
      end if;
   end Choose_AI_Model;

   procedure Test_AI_Model
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Test_AI_Model
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      if Settings_Open (Item) then
         Settings_View.Test_AI (Item);
      end if;
   end Test_AI_Model;

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

   procedure Leave_Project
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Leave_Project
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      if Item.Nav.Shown = Project then
         Navigation.Leave (Item);
      end if;
   end Leave_Project;

   procedure Show_Outline
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Show_Outline
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      Writing.Show (Item, Outline);
   end Show_Outline;

   procedure Show_Canvas
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Show_Canvas
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      Writing.Show (Item, Canvas);
   end Show_Canvas;

   procedure Show_Writing
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Show_Writing
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      Writing.Show (Item, Write);
   end Show_Writing;

   procedure Add_Document
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Add_Document
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      if Item.Toolbar.Mode = Write then
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

   procedure Open_List
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Open_List
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      Listing.Open (Item);
   end Open_List;

   procedure Close_List
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event);

   procedure Close_List
     (Item : in out Session; Source : in out Source_Widget; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      if Item.Item_List.Showing_List then
         Listing.Close (Item);
      end if;
   end Close_List;

   --  What the menu bar and the keys ask

   procedure Perform
     (Item  : in out Session;
      Event : Widgets.Widget_Event) is
   begin
      if not Commands.Is_Bound (Event) then
         return;
      end if;
      case Commands.What (Event) is
         when Start_Project => Start_Project (Item, Item.Root.Window_Panel, Event);
         when Open_Settings => Open_Settings (Item, Item.Root.Window_Panel, Event);
         when Leave_Project => Leave_Project (Item, Item.Root.Window_Panel, Event);
         when Show_Outline  => Show_Outline (Item, Item.Root.Window_Panel, Event);
         when Show_Canvas   => Show_Canvas (Item, Item.Root.Window_Panel, Event);
         when Show_Writing  => Show_Writing (Item, Item.Root.Window_Panel, Event);
         when Open_List     => Open_List (Item, Item.Root.Window_Panel, Event);
      end case;
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
      Commands.Bind (Start.New_Button, Start_Project);
      Commands.Bind (Start.New_Card, Start_Project);
      Commands.Bind (Start.New_Card_Plus, Start_Project);
      Commands.Bind (Start.Settings_Button, Open_Settings);
      Hear (Start.New_Button, Click, Start_Project'Access);
      Hear (Start.New_Card, Click, Start_Project'Access);
      Hear (Start.New_Card_Plus, Click, Start_Project'Access);
      Hear (Start.Settings_Button, Click, Open_Settings'Access);
      Hear (Start.Ok_Button, Click, Accept_Rename'Access);
      Hear (Start.Cancel_Button, Click, Cancel_Rename'Access);
      Hear (Item.Title_Edit.Edit_Field, Submit, Accept_Rename'Access);
      for Card in Start.Cards'Range loop
         Hear (Start.Cards (Card).Peek, Click, Open_Project'Access, Card);
         Hear (Start.Cards (Card).Name, Click, Open_Project'Access, Card);
         Hear (Start.Cards (Card).Rename, Click, Rename_Project'Access, Card);
         Hear (Start.Cards (Card).Delete, Click, Delete_Project'Access, Card);
      end loop;

      --  The dialog that asks before deleting
      Hear (Item.Confirm.Confirm_Delete, Click, Confirm_Deletion'Access);
      Hear (Item.Confirm.Confirm_Cancel, Click, Cancel_Deletion'Access);
      Hear (Item.Confirm.Dialog_Close, Click, Cancel_Deletion'Access);

      --  The settings
      Hear (Prefs.Settings_Close, Click, Close_Settings'Access);
      Hear (Prefs.Theme_Light, Change, Choose_Light'Access);
      Hear (Prefs.Theme_Dark, Change, Choose_Dark'Access);
      Hear (Prefs.Theme_System, Change, Choose_System'Access);
      Hear (Prefs.AI_Enable, Change, Switch_AI'Access);
      Hear (Prefs.AI_Select, Click, Open_AI_Models'Access);
      Hear (Prefs.AI_Menu, Choose, Choose_AI_Model'Access);
      Hear (Prefs.AI_Test_Button, Click, Test_AI_Model'Access);
      Hear (Prefs.Model_Native, Change, Choose_MacOS'Access);
      Hear (Prefs.Model_Parakeet, Change, Choose_Parakeet'Access);
      Hear (Prefs.Download_Button, Click, Download_Model'Access);
      Hear (Prefs.Delete_Button, Click, Delete_Model'Access);

      --  A project: the bar, the tray, and the list of items
      Commands.Bind (Bar.Close_Button, Leave_Project);
      Commands.Bind (Bar.Outline_Tab, Show_Outline);
      Commands.Bind (Bar.Canvas_Tab, Show_Canvas);
      Commands.Bind (Bar.Write_Tab, Show_Writing);
      Commands.Bind (Item.Dock.Tool_List, Open_List);
      Hear (Bar.Close_Button, Click, Leave_Project'Access);
      Hear (Bar.Outline_Tab, Click, Show_Outline'Access);
      Hear (Bar.Canvas_Tab, Click, Show_Canvas'Access);
      Hear (Bar.Write_Tab, Click, Show_Writing'Access);
      Hear (Item.Dock.Tool_Item, Click, Add_Document'Access);
      Hear (Item.Dock.Tool_Source, Click, Add_Source'Access);
      Hear (Item.Dock.Tool_List, Click, Open_List'Access);
      Hear (Item.Item_List.List_Close, Click, Close_List'Access);
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
      for Each in Item.Section_View.Heads'Range loop
         Hear (Item.Section_View.Heads (Each).Add, Click, Writing.Section_Add_Clicked'Access, Each);
      end loop;
      for Each in Item.Section_View.Heads'Range loop
         Hear (Item.Section_View.Heads (Each).Notes, Click, Writing.Section_Notes_Clicked'Access, Each);
      end loop;
      for Each in Item.Section_View.Empties'Range loop
         Hear (Item.Section_View.Empties (Each).Add, Click, Writing.Section_Add_Clicked'Access, Each);
      end loop;
      for Rank in Items.Slot loop
         Hear (Item.Docs.Pages (Rank).Sources_Button, Click, Writing.Sources_Clicked'Access, Rank);
         Hear (Item.Docs.Pages (Rank).Mic_Button, Click, Writing.Dictate_Clicked'Access, Rank);
         Hear (Item.Reading.Source_Rows (Rank).Row, Click, Writing.Source_Row_Clicked'Access, Rank);
      end loop;
   end Install;

end Viewer.Responses;
