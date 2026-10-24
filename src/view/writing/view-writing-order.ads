--  The order of the documents: the tree, the pages and the directories, and keeping them.
private package View.Writing.Order is

   procedure Insert_Row
     (Item : in out Session; Index : Positive; Node : Tree_Entry)
     with Pre => Index in 2 .. Trees.Count (Item.Docs.Ordering) + 1;
   --  Put the row before the Indexth.

   procedure Delete_Row (Item : in out Session; Index : Positive)
     with Pre => Index in 2 .. Trees.Count (Item.Docs.Ordering);

   procedure Relocate (Item : in out Session; Row, Index : Positive; Dir : Natural)
     with Pre => Trees.Can_Execute (Item.Docs.Ordering, Item.Docs.Dirs, Row, Index, Dir);

   procedure Build_Order (Item : in out Session);
   --  Find the documents, in the order kept, and the sources.

   procedure Keep_Directory (Item : in out Session; Which : Items.Slot);
   --  Write the directory the document is in to the database.

   procedure Keep_Order (Item : in out Session);
   --  Write the order of the documents to the database.

   function Last_Of (Item : Session; Dir : Natural) return Positive;
   --  Where a document last in the directory is put (before the row that
   --  comes after it); Dir_Row cannot be 0 for a directory.

end View.Writing.Order;
