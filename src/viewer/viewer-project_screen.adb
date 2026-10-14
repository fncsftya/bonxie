with Viewer.Navigation;
with Viewer.Writing;

package body Viewer.Project_Screen is

   function Mode (Item : Session) return Modes is (Item.Toolbar.Mode);

   procedure Set_Mode (Item : in out Session; To : Modes) is
   begin
      Writing.Show (Item, To);
   end Set_Mode;

   function Current_Project (Item : Session) return Projects.Id is
     (Item.Opened.Current);

   procedure Close_Project (Item : in out Session)
     renames Navigation.Leave;

   function Is_Listing (Item : Session) return Boolean is
     (Item.Item_List.Showing_List);

end Viewer.Project_Screen;
