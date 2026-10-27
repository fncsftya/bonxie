with Icon_Set;
with Pomarine.UI;
with Pomarine.Widgets.Lists;

package body View.Listing is

   package Widgets renames Pomarine.Widgets;
   package Lists renames Pomarine.Widgets.Lists;
   package Models renames Pomarine.Models;

   Show_Or_Hide : constant := 1;
   Remove       : constant := 2;
   --  Which button of a row is which.

   procedure Describe
     (Item    : Session;
      Row     : Positive;
      Content : out Pomarine.Models.Row_Content)
   is
      Closed : constant Boolean := Item_List_VM.Is_Closed (Item.Item_List.Model, Row);
   begin
      Content := (others => <>);
      Models.Set_Text (Content, Item_List_VM.Title (Item.Item_List.Model, Row));
      Content.Dimmed := Closed;
      --  What a click does: show it if it is closed.
      Models.Set_Action
        (Content, Show_Or_Hide,
         (if Closed then Icon_Set.Show else Icon_Set.Hide), (if Closed then "Show" else "Hide"));
      Models.Set_Action (Content, Remove, Icon_Set.Delete, "Remove", Danger => True);
   end Describe;

   function Overlay (Item : Session) return access Pomarine.Widgets.Widget'Class is
     (Pomarine.UI.Named (Item.Forms (List_Region).Screen.all, List_Overlay));

   procedure Refresh (Item : in out Session) is
   begin
      Item_List_VM.Refresh (Item.Item_List.Model);
      if not Pomarine.View_Models.Changed (Item.Item_List.Seen, Item_List_VM.Version (Item.Item_List.Model)) then
         return;
      end if;
      --  The words that say there are none, or the list, are the view's.
      Pomarine.UI.Synchronize (Item.Forms (List_Region).Screen.all);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Refresh;

   procedure Show_List (Item : in out Session) is
   begin
      --  What is typed in is not for the list, but the keys are: the
      --  list has the focus.
      Widgets.Clear_Focus (Item.Root.Widgets);
      Widgets.Set_Visible (Overlay (Item).all, True);
      Refresh (Item);
      Lists.Select_Row (Item.Item_List.List_View, 0);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      Widgets.Set_Focus_Scope
        (Item.Root.Widgets, Pomarine.UI.Named (Item.Forms (List_Region).Screen.all, List_Border).all);
      if Item_List_VM.Count (Item.Item_List.Model) > 0 then
         Widgets.Focus (Item.Item_List.List_View);
      end if;
   end Show_List;

   procedure Hide_List (Item : in out Session) is
   begin
      Widgets.Clear_Focus_Scope (Item.Root.Widgets);
      Widgets.Clear_Focus (Item.Root.Widgets);
      Widgets.Set_Visible (Overlay (Item).all, False);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Hide_List;

end View.Listing;
