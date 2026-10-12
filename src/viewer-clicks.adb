with UI.Widgets;
with Viewer.Deletion;
with Viewer.Navigation;
with Viewer.Recent;

package body Viewer.Clicks is

   package Widgets renames UI.Widgets;
   package Buttons renames UI.Widgets.Buttons;
   package Text_Fields renames UI.Widgets.Text_Fields;

   use type Projects.Id;

   procedure Take (Item : in out Session) is
      Clicked : Boolean;
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
            for I in Item.Recent_Rows'Range loop
               if Widgets.Is_Shown (Item.Recent_Rows (I)) then
                  Buttons.Take_Click (Item.Recent_Rows (I), Clicked);
                  if Clicked then
                     Navigation.Enter (Item, Item.Row_Keys (I));
                     return;
                  end if;
                  Buttons.Take_Click (Item.Rename_Buttons (I), Clicked);
                  if Clicked then
                     Recent.Begin_Rename (Item, I);
                     return;
                  end if;
                  Buttons.Take_Click (Item.Delete_Buttons (I), Clicked);
                  if Clicked then
                     Deletion.Confirm (Item, I);
                     return;
                  end if;
               end if;
            end loop;
         when Project =>
            Buttons.Take_Click (Item.Close_Button, Clicked);
            if Clicked then
               Navigation.Leave (Item);
            end if;
      end case;
   end Take;

end Viewer.Clicks;
