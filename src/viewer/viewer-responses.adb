with Viewer.Canvas_Items;
with Viewer.Deletion;
with Viewer.Listing;
with Viewer.Navigation;
with Viewer.Recent;
with Viewer.Settings_View;
with Viewer.Writing;

package body Viewer.Responses is

   use type Projects.Id;

   procedure Respond_To_Dialog (Item : in out Session; What : Command);
   --  The answer of the dialog over the screens that asks before deleting
   --  a project, a document or directory, or the speech model's files.

   procedure Respond_To_Dialog (Item : in out Session; What : Command) is
   begin
      if Item.Nav.Shown = Home and then Item.Prefs.Showing_Settings then
         if Item.Confirm.Deleting_Model then
            Settings_View.Respond (Item, What);
         end if;
      elsif (Item.Nav.Shown = Home and then Item.Confirm.Deleting /= 0)
        or else (Item.Nav.Shown = Project
                 and then Item.Confirm.Deleting_Node.Kind /= Overview_Node)
      then
         case What is
            when Confirm_Deletion => Deletion.Delete_Confirmed (Item);
            when others           => Deletion.Close (Item);
         end case;
      end if;
   end Respond_To_Dialog;

   procedure Respond
     (Item  : in out Session;
      Event : Pomarine.Widgets.Widget_Event) is
   begin
      if not Commands.Is_Bound (Event) then
         return;
      end if;
      declare
         What : constant Command := Commands.What (Event);
      begin
         case What is
            --  The home screen
            when Start_Project =>
               if Item.Nav.Shown = Home then
                  Navigation.Enter_New (Item);
               end if;
            when Open_Settings =>
               if Item.Nav.Shown = Home and then not Item.Prefs.Showing_Settings then
                  Settings_View.Open (Item);
               end if;
            when Open_Project =>
               if Item.Nav.Shown = Home then
                  Navigation.Enter (Item, Item.Home_View.Row_Keys (Event.Index));
               end if;
            when Rename_Project =>
               Recent.Begin_Rename (Item, Event.Index);
            when Delete_Project =>
               Deletion.Confirm (Item, Event.Index);
            when Accept_Rename =>
               if Item.Home_View.Editing /= 0 then
                  Recent.Accept_Rename (Item);
               end if;
            when Cancel_Rename =>
               if Item.Home_View.Editing /= 0 then
                  Recent.Cancel_Edit (Item);
               end if;

            --  The dialog that asks before deleting
            when Confirm_Deletion | Cancel_Deletion =>
               Respond_To_Dialog (Item, What);

            --  The settings
            when Close_Settings | Choose_Light | Choose_Dark | Choose_System
               | Choose_MacOS | Choose_Parakeet | Download_Model | Delete_Model =>
               if Item.Prefs.Showing_Settings then
                  Settings_View.Respond (Item, What);
               end if;

            --  A project
            when Leave_Project =>
               if Item.Nav.Shown = Project then
                  Navigation.Leave (Item);
               end if;
            when Show_Canvas =>
               Writing.Show (Item, Canvas);
            when Show_Writing =>
               Writing.Show (Item, Write);
            when Add_Document =>
               if Item.Toolbar.Mode = Write then
                  Canvas_Items.Add (Item, Canvas_Items.Untitled_Document);
               else
                  Canvas_Items.Add (Item);
               end if;
            when Add_Source =>
               Canvas_Items.Add (Item, Canvas_Items.Untitled_Source, Items.Source);
            when Open_List =>
               Listing.Open (Item);

            --  The list of items
            when Close_List | Reveal_Item | Toggle_Item | Remove_Item =>
               if Item.Item_List.Showing_List then
                  Listing.Respond (Item, What, Event.Index);
               end if;

            --  The writing view
            when Add_Page | Add_Folder | Open_Sources | Dictate | Toggle_Source
               | Choose_Source | Choose_Context =>
               Writing.Respond
                 (Item, What, Event.Index,
                  (if Event.Kind in Pomarine.Widgets.Choose | Pomarine.Widgets.Select_Tag then Event.Row else 0));
         end case;
      end;
   end Respond;

end Viewer.Responses;
