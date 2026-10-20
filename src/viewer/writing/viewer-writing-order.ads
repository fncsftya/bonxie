--  The order of the documents: the tree, the pages and the directories, and keeping them.
private package Viewer.Writing.Order is

   procedure Sync_Order (Item : in out Session);
   --  Take the documents' order from the tree, which is the pages'.

   procedure Insert_Row
     (Item : in out Session; Index : Positive; Node : Tree_Entry)
     with Pre => Index in 2 .. Item.Docs.Tree_Count + 1
                 and then Item.Docs.Tree_Count < Tree_Capacity;
   --  Put the row before the Indexth.

   procedure Delete_Row (Item : in out Session; Index : Positive)
     with Pre => Index in 2 .. Item.Docs.Tree_Count;

   procedure Move_Block (Item : in out Session; From, Index : Positive)
     with Pre => From in 2 .. Item.Docs.Tree_Count
                 and then Index in 2 .. Item.Docs.Tree_Count + 1;
   --  Put the row, and those moved with it, before the Indexth (as it
   --  was before it was moved).

   procedure Build_Order (Item : in out Session);
   --  Find the documents, in the order kept, and the sources.

   procedure Keep_Directory (Item : in out Session; Which : Items.Slot);
   --  Write the directory the document is in to the database.

   procedure Keep_Order (Item : in out Session);
   --  Write the order of the documents to the database.

   function Last_Of (Item : Session; Dir : Natural) return Positive;
   --  Where a document last in the directory is put (before the row that
   --  comes after it); Dir_Row cannot be 0 for a directory.

end Viewer.Writing.Order;
