--  Questions about the items, the tree of documents and the rows of the writing view.

private package View.Writing.Support is

   function Is_Note (Item : Session; Which : Items.Slot) return Boolean;
   --  Whether the item is a note: a document, to write.

   function Is_Source (Item : Session; Which : Items.Slot) return Boolean;
   --  Whether the item is a source, to read.

   function Is_Section (Item : Session; Dir : Natural) return Boolean;
   --  Whether the directory is a section's: made for it, with its name,
   --  not renamed or deleted here, nor moved.

   function Parent_Of (Item : Session; Dir : Natural) return Natural;
   function Depth (Item : Session; Dir : Natural) return Natural;
   function Section_Directory (Item : Session; Dir : Natural) return Natural;
   function Within (Item : Session; Dir, Ancestor : Natural) return Boolean;

   function Title_Of (Item : Session; Which : Items.Slot) return String;
   --  The title of the item's window.

   function Rank_Of (Item : Session; Which : Items.Slot) return Natural;
   --  Where the document is among the pages, 0 if it is not one.

   function Row_Of (Item : Session; Which : Items.Slot) return Natural;
   --  Where the source is in the list of them, 0 if it is not.

   function In_View (Item : Session; Which : Items.Slot) return Boolean;
   --  Whether the document's page is one shown.

   function Leaf_Row (Item : Session; Which : Items.Slot) return Natural;
   --  Where the document is in the tree, 0 if it is not.

   function Dir_Row (Item : Session; Dir : Positive) return Natural;
   --  Where the directory is in the tree, 0 if it is not.

   function Documents_In (Item : Session; Dir : Positive) return Natural;

   function Block_End (Item : Session; Row : Positive) return Positive;
   --  The last row of what is moved with the row: of a directory, the
   --  last of its documents, which follow it; else the row.

   function Count_Image (Number : Natural) return String;
   --  The number, without a leading space.

   function Dir_Of_Section (Item : Session; Section : Positive) return Natural;
   --  The directory that is the section's, 0 if there is none (yet).

   function In_Writing (Item : Session) return Boolean;
   --  Whether the writing view is the one in use, and not under a dialog.

end View.Writing.Support;
