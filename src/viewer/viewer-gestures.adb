with Confirm_VM;

package body Viewer.Gestures is

   function Active (Item : Session) return Boolean is
     (Item.Nav.Shown = Project
      and then not Confirm_VM.Is_About_Node (Item.Dialog_Model.Model)
      and then not Item.Item_List.Showing_List);

end Viewer.Gestures;
