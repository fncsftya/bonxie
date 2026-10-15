package body Viewer.Gestures is

   function Active (Item : Session) return Boolean is
     (Item.Nav.Shown = Project
      and then Item.Confirm.Deleting_Node.Kind = Overview_Node
      and then not Item.Item_List.Showing_List);

end Viewer.Gestures;
