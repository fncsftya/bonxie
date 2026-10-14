with Items.Marks;
with Projects;

--  The table of the highlighter's marks on sources' pictures, one row to
--  a mark.
package Repository.Mark is

   procedure Prepare (Store : in out Projects.Store)
     with Pre => Projects.Is_Open (Store);
   --  Make the table, if there is none.

   procedure Replace
     (Store : in out Projects.Store;
      Key   : Items.Id;
      Made  : Items.Marks.Mark_List)
     with Pre => Projects.Is_Open (Store);
   --  Keep the marks, in place of any kept before for the item. All or
   --  none are kept.

   procedure Load
     (Store : Projects.Store;
      Key   : Items.Id;
      Into  : out Items.Marks.Mark_List)
     with Pre => Projects.Is_Open (Store);
   --  The marks kept for the item, in order; none if there are none.

   procedure Delete (Store : in out Projects.Store; Key : Items.Id)
     with Pre => Projects.Is_Open (Store);

end Repository.Mark;
