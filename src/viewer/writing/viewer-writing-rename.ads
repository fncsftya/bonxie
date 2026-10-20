--  Renaming the rows of the tree and the sources, and making a directory.
private package Viewer.Writing.Rename is

   procedure Begin_Rename_Dir (Item : in out Session; Dir : Positive);
   --  Put the field to rename the directory over its row, with the focus.

   procedure End_Rename_Doc (Item : in out Session);

   procedure Begin_Rename_Doc (Item : in out Session; Which : Items.Slot);
   --  The same for a document, whose title the field edits as the
   --  window's own title bar does.

   procedure Begin_Rename_Source (Item : in out Session; Which : Items.Slot);
   --  The same for a source, in the list of them: it is the window's title,
   --  which is the one on the canvas.

   procedure End_Rename_Dir (Item : in out Session);
   --  Keep the new name of the directory, unless it is only spaces.

   procedure End_Rename_Source (Item : in out Session);

   procedure New_Directory (Item : in out Session; Name : String);
   --  Make a directory, put its row last of the directories, and begin to
   --  rename it.

end Viewer.Writing.Rename;
