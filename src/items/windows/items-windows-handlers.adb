with Word_Tools;
with Pomarine.Widgets.Frames.Handlers;
with Items.Windows.Displays;

package body Items.Windows.Handlers is

   package Widgets renames Pomarine.Widgets;
   package Frames renames Pomarine.Widgets.Frames;

   package Frame_Hooks is new Pomarine.Widgets.Frames.Handlers (Window);

   procedure Say (Item : in out Window; Action : Actions);
   --  Tell the application what a button asked for, if it listens.

   procedure Say (Item : in out Window; Action : Actions) is
   begin
      if Item.Said /= null then
         Item.Said (Item.Said_Self, Item.Said_Proc, Item.Said_Which, Action);
      end if;
   end Say;

   procedure Begin_Edit (Item : in out Window);
   --  Make the title a field, with all of it selected, to type over.

   procedure Begin_Edit (Item : in out Window) is
   begin
      Frames.Begin_Title_Edit (Item.Chrome);
   end Begin_Edit;

   procedure End_Edit (Item : in out Window);
   --  Make the title text again, as it has been edited.

   procedure End_Edit (Item : in out Window) is
   begin
      Items.Models.Refresh (Item.Model.all);
      Displays.Show_Title (Item);
      Frames.End_Title_Edit (Item.Chrome);
   end End_Edit;

   procedure Dragged
     (Item : in out Window; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);
   --  The title bar was dragged: move it, as the application says.

   procedure Dragged
     (Item : in out Window; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From);
   begin
      Item.Dragged := (Across => Event.Across, Down => Event.Down, Still => True);
      Say (Item, Moved);
   end Dragged;

   procedure Corner_Dragged
     (Item : in out Window; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);
   --  The corner was dragged: size it, as the application says (not under the least).

   procedure Corner_Dragged
     (Item : in out Window; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From);
   begin
      Item.Dragged := (Across => Event.Across, Down => Event.Down, Still => Frames.Is_Sizing (Item.Chrome));
      Say (Item, Sized);
   end Corner_Dragged;

   procedure Perform (Item : in out Window; What : Item_Window_VM.Command; Index : Natural) is
   begin
      case What is
         when Item_Window_VM.Begin_Title_Edit =>
            if not Frames.Is_Editing_Title (Item.Chrome) then
               Begin_Edit (Item);
            end if;
         when Item_Window_VM.Accept_Title =>
            if Frames.Is_Editing_Title (Item.Chrome) then
               End_Edit (Item);
            end if;
         when Item_Window_VM.Minimize_Window => Say (Item, Minimize);
         when Item_Window_VM.Restore_Window => Say (Item, Restore);
         when Item_Window_VM.Close_Window => Say (Item, Close);
         when Item_Window_VM.Capture => Say (Item, Capture);
         when Item_Window_VM.Choose_Link => Say (Item, Choose_Link);
         when Item_Window_VM.Choose_File => Say (Item, Choose_File);
         when Item_Window_VM.Previous_Page => Say (Item, Previous_Page);
         when Item_Window_VM.Next_Page => Say (Item, Next_Page);
         when Item_Window_VM.Speak => Say (Item, Speak);
         when Item_Window_VM.Link_To_Outline => Say (Item, Link_To_Outline);
         when Item_Window_VM.Use_Tool => Word_Tools.Use_Tool (Item.Body_Text, Index);
         when Item_Window_VM.Follow_Link => Word_Tools.Follow (Item.Body_Text);
         when Item_Window_VM.Toggle_Zoom =>
            Widgets.Set_Visible (Item.Zoom_Menu, not Widgets.Is_Visible (Item.Zoom_Menu));
            Widgets.Raise_To_Front (Item.Zoom_Menu);
         when Item_Window_VM.Zoom_Preset => Widgets.Set_Visible (Item.Zoom_Menu, False);
         when Item_Window_VM.Use_Pointer | Item_Window_VM.Use_Marker | Item_Window_VM.Use_Eraser => null;
      end case;
   end Perform;

   procedure Listen (Item : in out Window) is
      use all type Widgets.Event_Kind;
   begin
      Frame_Hooks.On (Item.Chrome, Move, Item'Unrestricted_Access, Dragged'Access);
      Frame_Hooks.On (Item.Chrome, Resize, Item'Unrestricted_Access, Corner_Dragged'Access);
   end Listen;

end Items.Windows.Handlers;
