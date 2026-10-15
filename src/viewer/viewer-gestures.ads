--  When the pointer's and the keys' gestures on a project's screen are
--  for it: an item's window dragged, a field left, a title pressed twice.
--  What each widget says of them is done as it is said, by the procedures
--  Viewer.Responses gives them; those that are only for a project's screen
--  ask here whether it is the one in use.
private package Viewer.Gestures is

   function Active (Item : Session) return Boolean;
   --  Whether a project is shown, and not under a dialog or the list of
   --  items.

end Viewer.Gestures;
