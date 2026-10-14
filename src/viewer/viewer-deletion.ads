--  The dialog over the home screen to confirm deleting a project.
private package Viewer.Deletion is

   procedure Confirm (Item : in out Session; Row : Positive)
     with Pre => Row <= Item.Home_View.Listed.Count;
   --  Show the dialog to confirm deleting the project of the row.

   procedure Confirm_Node (Item : in out Session; Node : Tree_Entry)
     with Pre => Node.Kind /= Overview_Node;
   --  Show the dialog to confirm deleting a document or directory of the
   --  writing view.

   procedure Confirm_Model (Item : in out Session; Size : String)
     with Post => Item.Confirm.Deleting_Model;
   --  Show the dialog to confirm deleting the files of the speech model,
   --  which are Size (say so). Settings_View acts on the answer.

   procedure Close (Item : in out Session);
   --  Hide the dialog: nothing is deleted.

   procedure Delete_Confirmed (Item : in out Session);
   --  Delete the project (or document or directory) the dialog is about,
   --  and hide it.

end Viewer.Deletion;
