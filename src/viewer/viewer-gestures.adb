with Viewer.Canvas_Items;
with Viewer.Navigation;
with Viewer.Writing;

package body Viewer.Gestures is

   procedure Take (Item : in out Session) is
   begin
      --  Only a project has any, and not under a dialog or the list.
      if Item.Nav.Shown = Project
        and then Item.Confirm.Deleting_Node.Kind = Overview_Node
        and then not Item.Item_List.Showing_List
      then
         Navigation.Take_Rename (Item);
         Canvas_Items.Take (Item);
         if Item.Toolbar.Mode = Write then
            Writing.Take (Item);
         end if;
      end if;
   end Take;

end Viewer.Gestures;
