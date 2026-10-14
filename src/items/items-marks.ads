with Projects;

--  The highlighter's marks on a source's picture, kept in a table of
--  their own, one row to a mark, that goes with the item.
package Items.Marks is

   Max_Marks : constant := 256;
   --  Of one source's picture.

   type Mark is record
      Left, Right, Y : Float := 0.0;
   end record;
   --  A swipe of the highlighter over a source's picture: from Left to
   --  Right (0.0 .. 1.0, of the picture's width), Y down it (of its
   --  height).

   type Mark_Array is array (Positive range <>) of Mark;

   type Mark_List is record
      Count : Natural range 0 .. Max_Marks := 0;
      Marks : Mark_Array (1 .. Max_Marks);
   end record;
   --  Marks (1 .. Count), the earliest made first.

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
