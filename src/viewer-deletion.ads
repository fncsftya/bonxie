--  The dialog over the home screen to confirm deleting a project.
private package Viewer.Deletion is

   procedure Confirm (Item : in out Session; Row : Positive)
     with Pre => Row <= Item.Listed.Count;
   --  Show the dialog to confirm deleting the project of the row.

   procedure Close (Item : in out Session);
   --  Hide the dialog: nothing is deleted.

   procedure Delete_Confirmed (Item : in out Session);
   --  Delete the project the dialog is about, and hide it.

end Viewer.Deletion;
