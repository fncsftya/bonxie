with Confirm_VM;

--  The dialog over the home screen and the writing view to confirm deleting a project, a folder, a document
--  or source, or the speech model's files: the widgets set from Confirm_VM, which has what it says and
--  what it is about.

private package View.Deletion is

   procedure Confirm_Node (Item : in out Session; Node : Tree_Entry)
   with Pre => Node.Kind /= Overview_Node;
   --  Show the dialog to confirm deleting a document or directory of the writing view.

   procedure Confirm_Model (Item : in out Session; Size : String)
   with Post => Confirm_VM."=" (Confirm_VM.Subject (Item.Dialog_Model.Model), Confirm_VM.Model);
   --  Show the dialog to confirm deleting the files of the speech model, which are Size (say so).
   --  Settings_View acts on the answer.

   procedure Close (Item : in out Session);
   --  Hide the dialog: nothing is deleted.

   procedure Sync (Item : in out Session);
   --  Show the dialog, or hide it, as the view-model says, and what it says.

   procedure Answered (Item : in out Session; Said : Confirm_VM.Answer);
   --  Confirm was done: do what it was about (the dialog is closed).

end View.Deletion;
