--  The sidebar's tree of documents, shown and selected from.
private package Viewer.Writing.Tree is

   procedure Choose_Row (Row : in out Index_Row; Chosen : Boolean);
   --  Show the row as the one chosen, white and casting a shadow, or not.

   function Linked_Sources
     (Item : Session; Which : Items.Slot) return Natural;
   --  How many sources the document is linked to on the canvas.

   procedure Refresh (Item : in out Session);
   --  Show the pages and the rows of the lists as the items and their
   --  order are now.

   procedure Go_To (Item : in out Session; Rank : Positive);
   --  Scroll the pages to the Rankth.

   procedure Show_Directory (Item : in out Session; Directory : Natural)
     with Pre => Directory <= Item.Docs.Dirs.Count;
   --  Show only the pages of the directory (all, if 0).

   procedure Show_Page (Item : in out Session; Which : Items.Slot);
   --  Scroll the pages to the document's, showing its directory's first
   --  if it is not one of those shown.

   procedure Rebuild (Item : in out Session);
   --  Take the folders, and the documents in them and their order, as they
   --  are kept, which the sections (made, put in another order, or given
   --  documents elsewhere) may have changed; the folder shown stays.

end Viewer.Writing.Tree;
