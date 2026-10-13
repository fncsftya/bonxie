with Items;
with UI.Widgets;
with UI.Widgets.Grips;
with Viewer.Canvas_Items;
with Viewer.Deletion;
with Viewer.Listing;
with Viewer.Navigation;
with Viewer.Writing;
with Viewer.Recent;

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
      case Item.Shown is
         when Home =>
            Buttons.Take_Click (Item.New_Button, Clicked);
            if Clicked then
               Navigation.Enter_New (Item);
               return;
            end if;
            if Item.Deleting /= 0 then
               Buttons.Take_Click (Item.Confirm_Delete, Clicked);
               if Clicked then
                  Deletion.Delete_Confirmed (Item);
                  return;
               end if;
               Buttons.Take_Click (Item.Confirm_Cancel, Clicked);
               if Clicked then
                  Deletion.Close (Item);
               end if;
               return;
            end if;
            --  Settings: nothing yet.
            Buttons.Take_Click (Item.Settings_Button, Clicked);
            if Item.Editing /= 0 then
               declare
                  Entered : Boolean;
               begin
                  Text_Fields.Take_Return (Item.Edit_Field, Entered);
                  Buttons.Take_Click (Item.Ok_Button, Clicked);
                  if Clicked or else Entered then
                     Recent.Accept_Rename (Item);
                     return;
                  end if;
               end;
               Buttons.Take_Click (Item.Cancel_Button, Clicked);
               if Clicked then
                  Recent.Cancel_Edit (Item);
                  return;
               end if;
            end if;
            Grips.Take_Click (Item.New_Card, Clicked);
            Buttons.Take_Click (Item.New_Card_Plus, Plus);
            if Clicked or else Plus then
               Navigation.Enter_New (Item);
               return;
            end if;
            for I in Item.Cards'Range loop
               if Widgets.Is_Shown (Item.Cards (I).Panel) then
                  Grips.Take_Click (Item.Cards (I).Peek, Clicked);
                  if not Clicked
                    and then Widgets.Is_Shown (Item.Cards (I).Name)
                  then
                     Grips.Take_Click (Item.Cards (I).Name, Clicked);
                  end if;
                  if Clicked then
                     Navigation.Enter (Item, Item.Row_Keys (I));
                     return;
                  end if;
                  Buttons.Take_Click (Item.Cards (I).Rename, Clicked);
                  if Clicked then
                     Recent.Begin_Rename (Item, I);
                     return;
                  end if;
                  Buttons.Take_Click (Item.Cards (I).Delete, Clicked);
                  if Clicked then
                     Deletion.Confirm (Item, I);
                     return;
                  end if;
               end if;
            end loop;
         when Project =>
            if Item.Showing_List then
               --  The list is all that takes clicks.
               Listing.Take (Item);
               return;
            end if;
            Buttons.Take_Click (Item.Close_Button, Clicked);
            if Clicked then
               Navigation.Leave (Item);
               return;
            end if;
            Buttons.Take_Click (Item.Canvas_Tab, Clicked);
            if Clicked then
               Writing.Show (Item, Canvas);
               return;
            end if;
            Buttons.Take_Click (Item.Write_Tab, Clicked);
            if Clicked then
               Writing.Show (Item, Write);
               return;
            end if;
            Buttons.Take_Click (Item.Tool_Item, Clicked);
            if Clicked then
               if Item.Mode = Write then
                  Canvas_Items.Add (Item, Canvas_Items.Untitled_Document);
               else
                  Canvas_Items.Add (Item);
               end if;
               return;
            end if;
            Buttons.Take_Click (Item.Tool_Source, Clicked);
            if Clicked then
               Canvas_Items.Add
                 (Item, Canvas_Items.Untitled_Source, Items.Source);
               return;
            end if;
            Buttons.Take_Click (Item.Tool_List, Clicked);
            if Clicked then
               Listing.Open (Item);
               return;
            end if;
            Canvas_Items.Take (Item);
            if Item.Mode = Write then
               Writing.Take (Item);
            end if;
      end case;
   end Take;

end Viewer.Clicks;
