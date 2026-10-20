with Pomarine.Marks;
with Projects;

--  The highlighter's marks on a source's picture, kept in a table of
--  their own, one row to a mark, that goes with the item.
package Items.Marks is

   subtype Mark is Pomarine.Marks.Mark;
   subtype Mark_Array is Pomarine.Marks.Mark_Array;

   type Mark_List is record
      Count : Natural := 0;
      Marks : Pomarine.Marks.Mark_Store;
      Past : Pomarine.Marks.History;
   end record;
   --  Marks.Data (1 .. Count), the earliest made first. Past follows the marks
   --  between views, during this session; it is not kept in the database.

   procedure Save_Marks
     (Store : in out Projects.Store; Key : Id; Made : Mark_List)
     with Pre => Projects.Is_Open (Store);
   --  Keep the highlighter's marks on the source's picture, in place of
   --  any kept before. They are in a table of their own, one row to a
   --  mark, that goes with the item.

   procedure Load_Marks
     (Store : Projects.Store; Key : Id; Into : out Mark_List)
     with Pre => Projects.Is_Open (Store);
   --  The marks kept for the source; none if there are none.

   procedure Clear_Marks (Store : in out Projects.Store; Key : Id)
     with Pre => Projects.Is_Open (Store);
   --  Forget them, as of a picture that is not the one they were made on
   --  (see Set_Captured).

end Items.Marks;
