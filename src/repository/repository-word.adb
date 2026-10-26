with Pomarine.Words;
with Ada_Sqlite3;
with Repository.Database; use Repository.Database;
with Repository.Item;

package body Repository.Word is

   use type Ada_Sqlite3.Result_Code;

   Schema : constant String :=
     "CREATE TABLE IF NOT EXISTS item_words ("
     & "item_id INTEGER NOT NULL "
     & "REFERENCES items (id) ON DELETE CASCADE, "
     & "seq INTEGER NOT NULL, "
     & "line INTEGER NOT NULL, "
     & "word TEXT NOT NULL, "
     & "x REAL NOT NULL, y REAL NOT NULL, "
     & "w REAL NOT NULL, h REAL NOT NULL, "
     & "PRIMARY KEY (item_id, seq)) WITHOUT ROWID";

   procedure Prepare (Store : in out Projects.Store) is
   begin
      Ada_Sqlite3.Execute (DB (Store).all, Schema);
   end Prepare;

   procedure Delete (Store : in out Projects.Store; Key : Items.Id) is
   begin
      Delete_Where (Store, "item_words", "item_id", Long_Integer (Key));
   end Delete;

   procedure Replace
     (Store   : in out Projects.Store;
      Key     : Items.Id;
      Found   : Vision.Result;
      At_Time : Projects.Seconds;
      Version : Natural)
   is
      Insert : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "INSERT INTO item_words (item_id, seq, line, word, x, y, w, h)"
           & " VALUES (:item, :seq, :line, :word, :x, :y, :w, :h)");
   begin
      --  One transaction: a row to a word is a lot of writes to sync.
      Ada_Sqlite3.Execute (DB (Store).all, "BEGIN");
      Delete (Store, Key);
      for Number in 1 .. Found.Count loop
         declare
            Each : Vision.Word renames Found.Words (Number);
         begin
            Ada_Sqlite3.Reset (Insert);
            Ada_Sqlite3.Bind_Int64 (Insert, ":item", Long_Integer (Key));
            Ada_Sqlite3.Bind_Int (Insert, ":seq", Number);
            Ada_Sqlite3.Bind_Int (Insert, ":line", Each.Line);
            Ada_Sqlite3.Bind_Text
              (Insert, ":word", Vision.Image (Each, Found));
            Ada_Sqlite3.Bind_Double (Insert, ":x", Each.Left);
            Ada_Sqlite3.Bind_Double (Insert, ":y", Each.Top);
            Ada_Sqlite3.Bind_Double (Insert, ":w", Each.Width);
            Ada_Sqlite3.Bind_Double (Insert, ":h", Each.Height);
            Ada_Sqlite3.Step (Insert);
         end;
      end loop;
      Repository.Item.Set_Recognized (Store, Key, At_Time, Version);
      Ada_Sqlite3.Execute (DB (Store).all, "COMMIT");
   end Replace;

   procedure Load
     (Store : Projects.Store; Key : Items.Id; Into : in out Vision.Result)
   is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "SELECT line, word, x, y, w, h FROM item_words "
           & "WHERE item_id = :id ORDER BY seq");
   begin
      Pomarine.Words.Clear (Into);
      Ada_Sqlite3.Bind_Int64 (Query, ":id", Long_Integer (Key));
      while Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW loop
         declare
            Text : constant String := Ada_Sqlite3.Column_Text (Query, 1);
         begin
            Pomarine.Words.Reserve (Into, Into.Count + 1, Into.Length + Text'Length);
            Into.Count := Into.Count + 1;
            Into.Text (Into.Length + 1 .. Into.Length + Text'Length) := Text;
            Into.Words (Into.Count) :=
              (Line   => Ada_Sqlite3.Column_Int (Query, 0),
               First  => Into.Length + 1,
               Last   => Into.Length + Text'Length,
               Left   => Ada_Sqlite3.Column_Double (Query, 2),
               Top    => Ada_Sqlite3.Column_Double (Query, 3),
               Width  => Ada_Sqlite3.Column_Double (Query, 4),
               Height => Ada_Sqlite3.Column_Double (Query, 5));
            Into.Length := Into.Length + Text'Length;
         end;
      end loop;
   end Load;

end Repository.Word;
