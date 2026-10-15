with Pomarine.Widgets.Labels;
with Viewer.Navigation;

package body Viewer.Home_Screen is

   use type Projects.Id;

   procedure New_Project (Item : in out Session)
     renames Navigation.Enter_New;

   procedure Open_Project (Item : in out Session; Key : Projects.Id)
     renames Navigation.Enter;

   procedure Add_Project
     (Item    : in out Session;
      Name    : String;
      Updated : Projects.Seconds)
     renames Navigation.Keep;

   function Is_Renaming (Item : Session) return Boolean is
     (Item.Home_View.Editing /= 0);

   function Is_Confirming (Item : Session) return Boolean is
     (Item.Confirm.Deleting /= 0
      or else Item.Confirm.Deleting_Node.Kind /= Overview_Node);

   function Row_Title (Item : Session; Row : Positive) return String is
     (if Row <= Item.Home_View.Listed.Count
      then Pomarine.Widgets.Labels.Text (Item.Home_View.Cards (Row).Title)
      else "");

end Viewer.Home_Screen;
