with Repository.Mark;

package body Items.Marks is

   procedure Clear_Marks (Store : in out Projects.Store; Key : Id) is
   begin
      Repository.Mark.Delete (Store, Key);
   end Clear_Marks;

   procedure Save_Marks
     (Store : in out Projects.Store; Key : Id; Made : Mark_List) is
   begin
      Repository.Mark.Replace (Store, Key, Made);
   end Save_Marks;

   procedure Load_Marks
     (Store : Projects.Store; Key : Id; Into : out Mark_List) is
   begin
      Repository.Mark.Load (Store, Key, Into);
   end Load_Marks;

end Items.Marks;
