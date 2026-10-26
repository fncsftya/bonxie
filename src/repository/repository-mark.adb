with Pomarine.Marks;
with Pomarine.Mark_Paths;
with Ada_Sqlite3;
with Repository.Database; use Repository.Database;

package body Repository.Mark is

   use type Ada_Sqlite3.Result_Code;

   Schema : constant String :=
     "CREATE TABLE IF NOT EXISTS item_marks ("
     & "item_id INTEGER NOT NULL "
     & "REFERENCES items (id) ON DELETE CASCADE, "
     & "seq INTEGER NOT NULL, "
     & "x0 REAL NOT NULL, x1 REAL NOT NULL, y REAL NOT NULL, "
     & "PRIMARY KEY (item_id, seq)) WITHOUT ROWID";

   procedure Prepare (Store : in out Projects.Store) is
   begin
      Ada_Sqlite3.Execute (DB (Store).all, Schema);
      --  Of a document, the page a mark is on; those made before are of the
      --  first.
      Add_Column (Store, "item_marks", "page", "INTEGER NOT NULL DEFAULT 1");
      Ada_Sqlite3.Execute
        (DB (Store).all,
         "CREATE TABLE IF NOT EXISTS item_mark_points ("
         & "item_id INTEGER NOT NULL, seq INTEGER NOT NULL, point INTEGER NOT NULL, "
         & "x REAL NOT NULL, y REAL NOT NULL, PRIMARY KEY (item_id, seq, point), "
         & "FOREIGN KEY (item_id, seq) REFERENCES item_marks (item_id, seq) ON DELETE CASCADE) WITHOUT ROWID");
   end Prepare;

   procedure Delete (Store : in out Projects.Store; Key : Items.Id) is
   begin
      Delete_Where (Store, "item_marks", "item_id", Long_Integer (Key));
   end Delete;

   procedure Replace
     (Store : in out Projects.Store;
      Key   : Items.Id;
      Made  : Items.Marks.Mark_List)
   is
      Insert : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "INSERT INTO item_marks (item_id, seq, x0, x1, y, page)"
           & " VALUES (:item, :seq, :x0, :x1, :y, :page)");
      Insert_Point : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "INSERT INTO item_mark_points (item_id, seq, point, x, y) VALUES (:item, :seq, :point, :x, :y)");
   begin
      Ada_Sqlite3.Execute (DB (Store).all, "BEGIN");
      Delete (Store, Key);
      for Number in 1 .. Made.Count loop
         Ada_Sqlite3.Reset (Insert);
         Ada_Sqlite3.Bind_Int64 (Insert, ":item", Long_Integer (Key));
         Ada_Sqlite3.Bind_Int (Insert, ":seq", Number);
         Ada_Sqlite3.Bind_Double (Insert, ":x0", Made.Marks.Data (Number).Left);
         Ada_Sqlite3.Bind_Double (Insert, ":x1", Made.Marks.Data (Number).Right);
         Ada_Sqlite3.Bind_Double (Insert, ":y", Made.Marks.Data (Number).Y);
         Ada_Sqlite3.Bind_Int (Insert, ":page", Made.Marks.Data (Number).Page);
         Ada_Sqlite3.Step (Insert);
         for Index in 1 .. Made.Marks.Data (Number).Trace.Count loop
            Ada_Sqlite3.Reset (Insert_Point);
            Ada_Sqlite3.Bind_Int64 (Insert_Point, ":item", Long_Integer (Key));
            Ada_Sqlite3.Bind_Int (Insert_Point, ":seq", Number);
            Ada_Sqlite3.Bind_Int (Insert_Point, ":point", Index);
            Ada_Sqlite3.Bind_Double (Insert_Point, ":x", Made.Marks.Data (Number).Trace.Points (Index).X);
            Ada_Sqlite3.Bind_Double (Insert_Point, ":y", Made.Marks.Data (Number).Trace.Points (Index).Y);
            Ada_Sqlite3.Step (Insert_Point);
         end loop;
      end loop;
      Ada_Sqlite3.Execute (DB (Store).all, "COMMIT");
   end Replace;

   procedure Load
     (Store : Projects.Store;
      Key   : Items.Id;
      Into  : out Items.Marks.Mark_List)
   is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "SELECT x0, x1, y, page, seq FROM item_marks "
           & "WHERE item_id = :id ORDER BY seq");
      Points : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "SELECT x, y FROM item_mark_points WHERE item_id = :id AND seq = :seq ORDER BY point LIMIT :limit");
      function Unit (Value : Float) return Float is
        (Float'Max (0.0, Float'Min (1.0, Value)));
   begin
      Into.Count := 0;
      Into.Past := Pomarine.Marks.Empty_History;
      Ada_Sqlite3.Bind_Int64 (Query, ":id", Long_Integer (Key));
      while Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW loop
         Into.Count := Into.Count + 1;
         Pomarine.Marks.Reserve (Into.Marks, Into.Count);
         Into.Marks.Data (Into.Count) :=
           (Left  => Unit (Ada_Sqlite3.Column_Double (Query, 0)),
            Right => Float'Max (Unit (Ada_Sqlite3.Column_Double (Query, 0)),
                                Unit (Ada_Sqlite3.Column_Double (Query, 1))),
            Y     => Unit (Ada_Sqlite3.Column_Double (Query, 2)),
            Page  => Integer'Max (1, Ada_Sqlite3.Column_Int (Query, 3)),
            Trace => <>);
         Ada_Sqlite3.Reset (Points);
         Ada_Sqlite3.Bind_Int64 (Points, ":id", Long_Integer (Key));
         Ada_Sqlite3.Bind_Int (Points, ":seq", Ada_Sqlite3.Column_Int (Query, 4));
         Ada_Sqlite3.Bind_Int (Points, ":limit", Pomarine.Mark_Paths.Max_Points);
         while Ada_Sqlite3.Step (Points) = Ada_Sqlite3.ROW loop
            Pomarine.Mark_Paths.Append
              (Into.Marks.Data (Into.Count).Trace, Unit (Ada_Sqlite3.Column_Double (Points, 0)),
               Unit (Ada_Sqlite3.Column_Double (Points, 1)));
         end loop;
      end loop;
   end Load;

end Repository.Mark;
