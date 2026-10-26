with Nav_VM;
with Preferences;
with Pomarine.UI;
with Pomarine.Widgets.Callbacks;
with Pomarine.Widgets.Editors.Callbacks;
with View.Canvas_Items;
with View.Deletion;
with View.Listing;
with View.Navigation;
with View.Settings_View;
with View.Writing;

package body View.Responses is

   use type Nav_VM.Layers;

   package Widgets renames Pomarine.Widgets;
   package UI renames Pomarine.UI;

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
      if Is_Nav_Tag (Event.Tag) then
         if Event.Kind in Widgets.Click | Widgets.Submit then
            Navigation.Do_Command (Item, Command_Of (Event.Tag), Event.Index);
         end if;
         return;
      end if;
   end Perform;

   --  Giving them to the widgets

   procedure Install (Item : in out Session) is
      Start   : Home_Parts renames Item.Home_View;
      Prefs   : Settings_Parts renames Item.Prefs;
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
      --  their command too, to be as it says: see View.Menus)
      for Card in Start.Cards'Range loop
         Hear (UI.Widget_Of (Item.Forms (Home_Region).Screen.all, Start.Cards (Card).Delete).all, Click,
               Delete_Project'Access, Card);
      end loop;

      --  The settings
      for Mode in Prefs.Cards'Range loop
         Hear (Prefs.Cards (Mode).Peek, Click, Choose_Card'Access, Preferences.Background_Modes'Pos (Mode));
         Hear (Prefs.Cards (Mode).Pick, Click, Choose_Card'Access, Preferences.Background_Modes'Pos (Mode));
         if Mode in Preferences.Pictures then
            Hear (Prefs.Cards (Mode).Reseed, Click, Reseed_Card'Access, Preferences.Background_Modes'Pos (Mode));
         end if;
      end loop;

      --  A project: the bar, the tray, and the list of items
      Hear (Pomarine.UI.Widget_Of (Item.Forms (Tray_Region).Screen.all, Item.Dock.Tool_Item).all, Click,
            Add_Document'Access);
      Hear (Pomarine.UI.Widget_Of (Item.Forms (Tray_Region).Screen.all, Item.Dock.Tool_Source).all, Click,
            Add_Source'Access);
      Hear (Item.Item_List.List_View, Click, Listing.Clicked'Access);
      Hear (Item.Item_List.List_View, Submit, Listing.Clicked'Access);
      Hear (Item.Item_List.List_View, Act, Listing.Acted'Access);

      --  The writing view
      Hear (Pages.Docs_Add, Click, Writing.Add_Page_Clicked'Access);
      Hear (Pages.Docs_Folder, Click, Writing.Add_Folder_Clicked'Access);
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

end View.Responses;
