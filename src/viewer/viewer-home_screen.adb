with Confirm_VM;
with Home_VM;
with Viewer.Navigation;

package body Viewer.Home_Screen is

   use type Confirm_VM.Subjects;

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
     (Home_VM.Editing (Item.Home_Model.Model) /= 0);

   function Is_Confirming (Item : Session) return Boolean is
     (Confirm_VM.Is_Asking (Item.Dialog_Model.Model)
      and then Confirm_VM.Subject (Item.Dialog_Model.Model) /= Confirm_VM.Model);

   function Row_Title (Item : Session; Row : Positive) return String is
     (if Row <= Home_VM.Count (Item.Home_Model.Model) then Home_VM.Title (Item.Home_Model.Model, Row) else "");

end Viewer.Home_Screen;
