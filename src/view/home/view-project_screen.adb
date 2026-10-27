with View.Navigation;

package body View.Project_Screen is

   function Mode (Item : Session) return Modes is (View_Mode (Item));

   procedure Set_Mode (Item : in out Session; To : Modes) is
   begin
      Navigation.Show (Item, To);
   end Set_Mode;

   function Current_Project (Item : Session) return Projects.Id is
     (Open_Key (Item));

   procedure Close_Project (Item : in out Session)
     renames Navigation.Leave;

   function Is_Listing (Item : Session) return Boolean is
     (Items_Listed (Item));

end View.Project_Screen;
