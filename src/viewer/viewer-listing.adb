with UI.Themes;
with UI.Icons;
with UI.Widgets;
with Viewer.Canvas_Items;
with Viewer.Style;

package body Viewer.Listing is

   package Widgets renames UI.Widgets;
   package Buttons renames UI.Widgets.Buttons;
   package Labels renames UI.Widgets.Labels;
   package Grips renames UI.Widgets.Grips;
   package Scrollers renames UI.Widgets.Scrollers;
   package Windows renames Items.Windows;

   use type Items.States;

   No_Title : constant String := "(untitled)";

   procedure Refresh (Item : in out Session) is
      Slots : Canvas_Items.Slot_List (1 .. Items.Capacity);
      Found : Natural;
   begin
      Canvas_Items.Order (Item, Slots, Found);
      for Row in Items.Slot loop
         if Row <= Found then
            declare
               Which   : constant Items.Slot := Slots (Row);
               Details : constant Items.Info :=
                 Windows.Details (Item.Windows (Which));
               Typed   : constant String :=
                 Projects.Titles.To_String (Details.Title);
               Name    : constant String :=
                 (if Typed = "" then No_Title else Typed);
               Closed  : constant Boolean := Details.State = Items.Closed;
            begin
               Item.Item_List.Row_Slots (Row) := Which;
               --  Cut to fit the label.
               Labels.Set_Text
                 (Item.Item_List.List_Rows (Row).Caption,
                  Name (Name'First ..
                        Name'First - 1
                        + Natural'Min (Name'Length, Labels.Text_Capacity)));
               Labels.Set_Ink
                 (Item.Item_List.List_Rows (Row).Caption,
                  (if Closed then Style.Closed_Ink
                   else UI.Themes.Foreground));
               --  What a click does: show it if it is closed.
               Buttons.Set_Label
                 (Item.Item_List.List_Rows (Row).Toggle,
                  (if Closed then "Show" else "Hide"));
               Buttons.Set_Icon
                 (Item.Item_List.List_Rows (Row).Toggle,
                  (if Closed then UI.Icons.Show else UI.Icons.Hide));
            end;
         end if;
         Widgets.Set_Visible (Item.Item_List.List_Rows (Row).Panel,
                              Row <= Found);
      end loop;
      Widgets.Set_Visible (Item.Item_List.List_None, Found = 0);
      --  Fewer rows may need less scrolling.
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      Scrollers.Scroll_To
        (Item.Item_List.List_Scroll,
         Scrollers.Offset (Item.Item_List.List_Scroll));
   end Refresh;

   procedure Open (Item : in out Session) is
   begin
      Item.Item_List.Showing_List := True;
      --  What is typed in is not for the list.
      Widgets.Clear_Focus (Item.Root.Widgets);
      Widgets.Set_Visible (Item.Item_List.List_Overlay, True);
      Refresh (Item);
      Scrollers.Scroll_To (Item.Item_List.List_Scroll, 0.0);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Open;

   procedure Close (Item : in out Session) is
   begin
      Item.Item_List.Showing_List := False;
      Widgets.Set_Visible (Item.Item_List.List_Overlay, False);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Close;

   procedure Take (Item : in out Session) is
      Clicked : Boolean;
   begin
      Buttons.Take_Click (Item.Item_List.List_Close, Clicked);
      if Clicked then
         Close (Item);
         return;
      end if;
      for Row in Items.Slot loop
         if Widgets.Is_Shown (Item.Item_List.List_Rows (Row).Panel) then
            declare
               Which : constant Items.Slot := Item.Item_List.Row_Slots (Row);
            begin
               Grips.Take_Click (Item.Item_List.List_Rows (Row).Name, Clicked);
               if Clicked then
                  Close (Item);
                  Canvas_Items.Reveal (Item, Which);
                  return;
               end if;
               Buttons.Take_Click (Item.Item_List.List_Rows (Row).Toggle,
                                   Clicked);
               if Clicked then
                  Canvas_Items.Set_State
                    (Item, Which,
                     (if Windows.Details (Item.Windows (Which)).State
                         = Items.Closed
                      then Items.Open else Items.Closed));
                  Refresh (Item);
                  return;
               end if;
               Buttons.Take_Click (Item.Item_List.List_Rows (Row).Remove,
                                   Clicked);
               if Clicked then
                  Canvas_Items.Remove (Item, Which);
                  Refresh (Item);
                  return;
               end if;
            end;
         end if;
      end loop;
   end Take;

end Viewer.Listing;
