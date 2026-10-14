with Ada_Sqlite3;
with Items.Database; use Items.Database;

package body Items.Marks is

   use type Ada_Sqlite3.Result_Code;

   procedure Clear_Marks (Store : in out Projects.Store; Key : Id) is
      Remove : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all, "DELETE FROM item_marks WHERE item_id = :id");
   begin
      Ada_Sqlite3.Bind_Int64 (Remove, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Remove);
   end Clear_Marks;

   procedure Save_Marks
     (Store : in out Projects.Store; Key : Id; Made : Mark_List)
   is
      Insert : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "INSERT INTO item_marks (item_id, seq, x0, x1, y)"
           & " VALUES (:item, :seq, :x0, :x1, :y)");
   begin
      Ada_Sqlite3.Execute (DB (Store).all, "BEGIN");
      Clear_Marks (Store, Key);
      for Number in 1 .. Made.Count loop
         Ada_Sqlite3.Reset (Insert);
         Ada_Sqlite3.Bind_Int64 (Insert, ":item", Long_Integer (Key));
         Ada_Sqlite3.Bind_Int (Insert, ":seq", Number);
         Ada_Sqlite3.Bind_Double (Insert, ":x0", Made.Marks (Number).Left);
         Ada_Sqlite3.Bind_Double (Insert, ":x1", Made.Marks (Number).Right);
         Ada_Sqlite3.Bind_Double (Insert, ":y", Made.Marks (Number).Y);
         Ada_Sqlite3.Step (Insert);
      end loop;
      Ada_Sqlite3.Execute (DB (Store).all, "COMMIT");
   end Save_Marks;

   procedure Load_Marks
     (Store : Projects.Store; Key : Id; Into : out Mark_List)
   is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "SELECT x0, x1, y FROM item_marks "
           & "WHERE item_id = :id ORDER BY seq LIMIT :limit");
   begin
      Into.Count := 0;
      Ada_Sqlite3.Bind_Int64 (Query, ":id", Long_Integer (Key));
      Ada_Sqlite3.Bind_Int (Query, ":limit", Max_Marks);
      while Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW loop
         Into.Count := Into.Count + 1;
         Into.Marks (Into.Count) :=
           (Left  => Ada_Sqlite3.Column_Double (Query, 0),
            Right => Ada_Sqlite3.Column_Double (Query, 1),
            Y     => Ada_Sqlite3.Column_Double (Query, 2));
      end loop;
   end Load_Marks;

end Items.Marks;
