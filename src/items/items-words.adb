with Ada_Sqlite3;
with Items.Database; use Items.Database;

package body Items.Words is

   use type Ada_Sqlite3.Result_Code;

   Words_Version : constant := 1;
   --  Of how the words are put in order (see Vision.Layout): words kept
   --  by an earlier version are looked for again.

   procedure Clear_Words (Store : in out Projects.Store; Key : Id) is
      Remove : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all, "DELETE FROM item_words WHERE item_id = :id");
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "UPDATE items SET recognized_at = 0 WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int64 (Remove, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Remove);
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Update);
   end Clear_Words;

   procedure Save_Words
     (Store   : in out Projects.Store;
      Key     : Id;
      Found   : Vision.Result;
      At_Time : Projects.Seconds)
   is
      Insert : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "INSERT INTO item_words (item_id, seq, line, word, x, y, w, h)"
           & " VALUES (:item, :seq, :line, :word, :x, :y, :w, :h)");
      Stamp  : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "UPDATE items SET recognized_at = :time, "
           & "words_version = " & Words_Version'Image & " WHERE id = :id");
   begin
      --  One transaction: a row to a word is a lot of writes to sync.
      Ada_Sqlite3.Execute (DB (Store).all, "BEGIN");
      Clear_Words (Store, Key);
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
      Ada_Sqlite3.Bind_Int64 (Stamp, ":time", At_Time);
      Ada_Sqlite3.Bind_Int64 (Stamp, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Stamp);
      Ada_Sqlite3.Execute (DB (Store).all, "COMMIT");
   end Save_Words;

   function Has_Words
     (Store : Projects.Store; Key : Id) return Boolean
   is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "SELECT recognized_at, words_version FROM items WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int64 (Query, ":id", Long_Integer (Key));
      return Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW
        and then Ada_Sqlite3.Column_Int64 (Query, 0) > 0
        and then Ada_Sqlite3.Column_Int (Query, 1) = Words_Version;
   end Has_Words;

   procedure Load_Words
     (Store : Projects.Store; Key : Id; Into : in out Vision.Result)
   is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "SELECT line, word, x, y, w, h FROM item_words "
           & "WHERE item_id = :id ORDER BY seq LIMIT :limit");
   begin
      Into.Count := 0;
      Into.Length := 0;
      Into.Truncated := False;
      Ada_Sqlite3.Bind_Int64 (Query, ":id", Long_Integer (Key));
      Ada_Sqlite3.Bind_Int (Query, ":limit", Vision.Max_Words);
      while Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW loop
         declare
            Text : constant String := Ada_Sqlite3.Column_Text (Query, 1);
         begin
            if Into.Length + Text'Length > Vision.Text_Capacity then
               Into.Truncated := True;
               exit;
            end if;
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
   end Load_Words;

end Items.Words;
