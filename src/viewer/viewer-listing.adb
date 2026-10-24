with Icon_Set;
with Pomarine.Widgets.Lists;
with Nav_VM;
with Viewer.Navigation;

package body Viewer.Listing is

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

   procedure Refresh (Item : in out Session) is
   begin
      Item_List_VM.Refresh (Item.Item_List.Model);
      if not Pomarine.View_Models.Changed (Item.Item_List.Seen, Item_List_VM.Version (Item.Item_List.Model)) then
         return;
      end if;
      Widgets.Set_Visible (Item.Item_List.List_None, Item_List_VM.Count (Item.Item_List.Model) = 0);
      Widgets.Set_Visible (Item.Item_List.List_View, Item_List_VM.Count (Item.Item_List.Model) > 0);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Refresh;

   procedure Show_List (Item : in out Session) is
   begin
      --  What is typed in is not for the list, but the keys are: the
      --  list has the focus.
      Widgets.Clear_Focus (Item.Root.Widgets);
      Widgets.Set_Visible (Item.Item_List.List_Overlay, True);
      Refresh (Item);
      Lists.Select_Row (Item.Item_List.List_View, 0);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      Widgets.Set_Focus_Scope (Item.Root.Widgets, Item.Item_List.List_Border);
      if Item_List_VM.Count (Item.Item_List.Model) > 0 then
         Widgets.Focus (Item.Item_List.List_View);
      end if;
   end Show_List;

   procedure Hide_List (Item : in out Session) is
   begin
      Widgets.Clear_Focus_Scope (Item.Root.Widgets);
      Widgets.Clear_Focus (Item.Root.Widgets);
      Widgets.Set_Visible (Item.Item_List.List_Overlay, False);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Hide_List;

   procedure Open (Item : in out Session) is
   begin
      Navigation.Do_Command (Item, Nav_VM.Open_List);
   end Open;

   procedure Close (Item : in out Session) is
   begin
      Navigation.Do_Command (Item, Nav_VM.Close_List);
   end Close;

   procedure Clicked
     (Item   : in out Session;
      Source : in out Pomarine.Widgets.Widget'Class;
      Event  : Pomarine.Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
      Row : constant Natural := Lists.Selected (Item.Item_List.List_View);
   begin
      if Items_Listed (Item) and then Row in 1 .. Item_List_VM.Count (Item.Item_List.Model) then
         Close (Item);
         if Item_List_VM.Can_Execute (Item.Item_List.Model, Item_List_VM.Reveal, Row) then
            Item_List_VM.Execute (Item.Item_List.Model, Item_List_VM.Reveal, Row);
         end if;
      end if;
   end Clicked;

   procedure Acted
     (Item   : in out Session;
      Source : in out Pomarine.Widgets.Widget'Class;
      Event  : Pomarine.Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
   begin
      if not Items_Listed (Item) or else Event.Row not in 1 .. Item_List_VM.Count (Item.Item_List.Model) then
         return;
      end if;
      declare
         What : constant Item_List_VM.Command :=
           (if Event.Action = Show_Or_Hide then Item_List_VM.Toggle_Shown else Item_List_VM.Remove);
      begin
         if Item_List_VM.Can_Execute (Item.Item_List.Model, What, Event.Row) then
            Item_List_VM.Execute (Item.Item_List.Model, What, Event.Row);
            Refresh (Item);
         end if;
      end;
   end Acted;

end Viewer.Listing;
