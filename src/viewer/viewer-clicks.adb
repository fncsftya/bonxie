with Items;
with UI.Widgets;
with UI.Widgets.Grips;
with Viewer.Canvas_Items;
with Viewer.Deletion;
with Viewer.Listing;
with Viewer.Navigation;
with Viewer.Writing;
with Viewer.Recent;
with Viewer.Settings_View;

package body Viewer.Clicks is

   package Widgets renames UI.Widgets;
   package Buttons renames UI.Widgets.Buttons;
   package Grips renames UI.Widgets.Grips;
   package Text_Fields renames UI.Widgets.Text_Fields;

   use type Projects.Id;

   procedure Take (Item : in out Session) is
      Clicked : Boolean;
      Plus    : Boolean;
   begin
      --  Only the screen that is shown can have been clicked.
      case Item.Nav.Shown is
         when Home =>
            if Item.Prefs.Showing_Settings then
               Settings_View.Take (Item);
               return;
            end if;
            Buttons.Take_Click (Item.Home_View.New_Button, Clicked);
            if Clicked then
               Navigation.Enter_New (Item);
               return;
            end if;
            if Item.Confirm.Deleting /= 0 then
               Buttons.Take_Click (Item.Confirm.Confirm_Delete, Clicked);
               if Clicked then
                  Deletion.Delete_Confirmed (Item);
                  return;
               end if;
               Buttons.Take_Click (Item.Confirm.Confirm_Cancel, Clicked);
               if not Clicked then
                  Buttons.Take_Click (Item.Confirm.Dialog_Close, Clicked);
               end if;
               if Clicked then
                  Deletion.Close (Item);
               end if;
               return;
            end if;
            Buttons.Take_Click (Item.Home_View.Settings_Button, Clicked);
            if Clicked then
               Settings_View.Open (Item);
               return;
            end if;
            if Item.Home_View.Editing /= 0 then
               declare
                  Entered : Boolean;
               begin
                  Text_Fields.Take_Return (Item.Title_Edit.Edit_Field,
                                           Entered);
                  Buttons.Take_Click (Item.Home_View.Ok_Button, Clicked);
                  if Clicked or else Entered then
                     Recent.Accept_Rename (Item);
                     return;
                  end if;
               end;
               Buttons.Take_Click (Item.Home_View.Cancel_Button, Clicked);
               if Clicked then
                  Recent.Cancel_Edit (Item);
                  return;
               end if;
            end if;
            Grips.Take_Click (Item.Home_View.New_Card, Clicked);
            Buttons.Take_Click (Item.Home_View.New_Card_Plus, Plus);
            if Clicked or else Plus then
               Navigation.Enter_New (Item);
               return;
            end if;
            for I in Item.Home_View.Cards'Range loop
               if Widgets.Is_Shown (Item.Home_View.Cards (I).Panel) then
                  Grips.Take_Click (Item.Home_View.Cards (I).Peek, Clicked);
                  if not Clicked
                    and then Widgets.Is_Shown (Item.Home_View.Cards (I).Name)
                  then
                     Grips.Take_Click (Item.Home_View.Cards (I).Name, Clicked);
                  end if;
                  if Clicked then
                     Navigation.Enter (Item, Item.Home_View.Row_Keys (I));
                     return;
                  end if;
                  Buttons.Take_Click (Item.Home_View.Cards (I).Rename,
                                      Clicked);
                  if Clicked then
                     Recent.Begin_Rename (Item, I);
                     return;
                  end if;
                  Buttons.Take_Click (Item.Home_View.Cards (I).Delete,
                                      Clicked);
                  if Clicked then
                     Deletion.Confirm (Item, I);
                     return;
                  end if;
               end if;
            end loop;
         when Project =>
            if Item.Confirm.Deleting_Node.Kind /= Overview_Node then
               --  The dialog to confirm deleting a document or directory
               --  is all that takes clicks.
               Buttons.Take_Click (Item.Confirm.Confirm_Delete, Clicked);
               if Clicked then
                  Deletion.Delete_Confirmed (Item);
                  return;
               end if;
               Buttons.Take_Click (Item.Confirm.Confirm_Cancel, Clicked);
               if not Clicked then
                  Buttons.Take_Click (Item.Confirm.Dialog_Close, Clicked);
               end if;
               if Clicked then
                  Deletion.Close (Item);
               end if;
               return;
            end if;
            if Item.Item_List.Showing_List then
               --  The list is all that takes clicks.
               Listing.Take (Item);
               return;
            end if;
            Writing.Take_Context (Item, Clicked);
            if Clicked then
               return;
            end if;
            Navigation.Take_Rename (Item);
            Buttons.Take_Click (Item.Toolbar.Close_Button, Clicked);
            if Clicked then
               Navigation.Leave (Item);
               return;
            end if;
            Buttons.Take_Click (Item.Toolbar.Canvas_Tab, Clicked);
            if Clicked then
               Writing.Show (Item, Canvas);
               return;
            end if;
            Buttons.Take_Click (Item.Toolbar.Write_Tab, Clicked);
            if Clicked then
               Writing.Show (Item, Write);
               return;
            end if;
            Buttons.Take_Click (Item.Dock.Tool_Item, Clicked);
            if Clicked then
               if Item.Toolbar.Mode = Write then
                  Canvas_Items.Add (Item, Canvas_Items.Untitled_Document);
               else
                  Canvas_Items.Add (Item);
               end if;
               return;
            end if;
            Buttons.Take_Click (Item.Dock.Tool_Source, Clicked);
            if Clicked then
               Canvas_Items.Add
                 (Item, Canvas_Items.Untitled_Source, Items.Source);
               return;
            end if;
            Buttons.Take_Click (Item.Dock.Tool_List, Clicked);
            if Clicked then
               Listing.Open (Item);
               return;
            end if;
            Canvas_Items.Take (Item);
            if Item.Toolbar.Mode = Write then
               Writing.Take (Item);
            end if;
      end case;
   end Take;

end Viewer.Clicks;
