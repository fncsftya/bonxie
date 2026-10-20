--  The dialogs over both screens: their bar and border, the modal and the list of items.
private package Viewer.Build.Dialogs is

   procedure Build_Modal (Item : in out Session);
   --  Add and style the dialog to confirm a deletion: over all else.

   procedure Build_List (Item : in out Session);
   --  Add and style the list of items: a dialog over all else.

end Viewer.Build.Dialogs;
