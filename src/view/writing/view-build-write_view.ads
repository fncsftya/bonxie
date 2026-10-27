--  The writing view: the sidebar, the pages and the pane of the pinned source.

private package View.Build.Write_View is

   procedure Build_Write (Item : in out Session);
   --  Add and style the writing view's widgets.

   procedure Make_Tree_Row (Item : in out Session; Index : Positive);
   --  Add and style a row of the tree of documents, in the sidebar.

   procedure Make_Source_Row (Item : in out Session; Which : Items.Slot);
   --  Add and style the row of the source of the slot, in the sidebar.

   procedure Make_Page (Item : in out Session; Rank : Items.Slot);
   --  Add and style the page of the slot, among the pages.

   procedure Make_Reader (Item : in out Session; Which : Items.Slot);
   --  Add and style the reader of the slot, over the pages.

   procedure Make_Section (Item : in out Session; Index : Positive);
   --  Add and style the heading, notes and empty box of a section, among the pages.

   procedure Make_Gap (Item : in out Session; Index : Natural);
   --  Add and style the mark for the documents of no section after the
   --  Index'th section (before the first if 0).

end View.Build.Write_View;
