with Icon_Set;
with Pomarine.Widgets.Lists;
with Viewer.Canvas_Items;

package body Viewer.Listing is

   package Widgets renames Pomarine.Widgets;
   package Lists renames Pomarine.Widgets.Lists;
   package Models renames Pomarine.Models;
   package Windows renames Items.Windows;

   use type Items.States;

   No_Title : constant String := "(untitled)";

   Show_Or_Hide : constant := 1;
   Remove       : constant := 2;
   --  Which button of a row is which.

   procedure Describe
     (Item    : Session;
      Row     : Positive;
      Content : out Pomarine.Models.Row_Content)
   is
      Which   : constant Items.Slot := Item.Item_List.Row_Slots (Row);
      Details : constant Items.Info := Windows.Details (Item.Windows (Which));
      Typed   : constant String := Projects.Titles.To_String (Details.Title);
      Closed  : constant Boolean := Details.State = Items.Closed;
   begin
      Content := (others => <>);
      Models.Set_Text (Content, (if Typed = "" then No_Title else Typed));
      Content.Dimmed := Closed;
      --  What a click does: show it if it is closed.
      Models.Set_Action
        (Content, Show_Or_Hide,
         (if Closed then Icon_Set.Show else Icon_Set.Hide), (if Closed then "Show" else "Hide"));
      Models.Set_Action (Content, Remove, Icon_Set.Delete, "Remove", Danger => True);
   end Describe;

   procedure Refresh (Item : in out Session) is
      Slots : Canvas_Items.Slot_List (1 .. Items.Capacity);
      Found : Natural;
   begin
      Canvas_Items.Order (Item, Slots, Found);
      for Row in 1 .. Found loop
         Item.Item_List.Row_Slots (Row) := Slots (Row);
      end loop;
      Item.Item_List.List_Rows.Found := Found;
      Item.Item_List.List_Rows.Changed := Item.Item_List.List_Rows.Changed + 1;
      Widgets.Set_Visible (Item.Item_List.List_None, Found = 0);
      Widgets.Set_Visible (Item.Item_List.List_View, Found > 0);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Refresh;

   procedure Open (Item : in out Session) is
   begin
      Item.Item_List.Showing_List := True;
      --  What is typed in is not for the list, but the keys are: the
      --  list has the focus.
      Widgets.Clear_Focus (Item.Root.Widgets);
      Widgets.Set_Visible (Item.Item_List.List_Overlay, True);
      Refresh (Item);
      Lists.Select_Row (Item.Item_List.List_View, 0);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      Widgets.Set_Focus_Scope (Item.Root.Widgets, Item.Item_List.List_Border);
      if Item.Item_List.List_Rows.Found > 0 then
         Widgets.Focus (Item.Item_List.List_View);
      end if;
   end Open;

   procedure Close (Item : in out Session) is
   begin
      Item.Item_List.Showing_List := False;
      Widgets.Clear_Focus_Scope (Item.Root.Widgets);
      Widgets.Clear_Focus (Item.Root.Widgets);
      Widgets.Set_Visible (Item.Item_List.List_Overlay, False);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Close;

   procedure Clicked
     (Item   : in out Session;
      Source : in out Pomarine.Widgets.Widget'Class;
      Event  : Pomarine.Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
      Row : constant Natural := Lists.Selected (Item.Item_List.List_View);
   begin
      if Item.Item_List.Showing_List and then Row in 1 .. Item.Item_List.List_Rows.Found then
         declare
            Which : constant Items.Slot := Item.Item_List.Row_Slots (Row);
         begin
            Close (Item);
            Canvas_Items.Reveal (Item, Which);
         end;
      end if;
   end Clicked;

   procedure Acted
     (Item   : in out Session;
      Source : in out Pomarine.Widgets.Widget'Class;
      Event  : Pomarine.Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
   begin
      if not Item.Item_List.Showing_List or else Event.Row not in 1 .. Item.Item_List.List_Rows.Found then
         return;
      end if;
      declare
         Which : constant Items.Slot := Item.Item_List.Row_Slots (Event.Row);
      begin
         if Event.Action = Show_Or_Hide then
            Canvas_Items.Set_State
              (Item, Which,
               (if Windows.Details (Item.Windows (Which)).State = Items.Closed
                then Items.Open else Items.Closed));
         else
            Canvas_Items.Remove (Item, Which);
         end if;
         Refresh (Item);
      end;
   end Acted;

end Viewer.Listing;
