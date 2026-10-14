with Ada_Sqlite3;
with Items.Database; use Items.Database;

package body Items.Schema is

   use type Ada_Sqlite3.Result_Code;

   Items_Table : constant String :=
     "CREATE TABLE IF NOT EXISTS items ("
     & "id INTEGER PRIMARY KEY, "
     & "project_id INTEGER NOT NULL "
     & "REFERENCES projects (id) ON DELETE CASCADE, "
     & "title TEXT NOT NULL, "
     & "content TEXT NOT NULL DEFAULT '', "
     & "x REAL NOT NULL, y REAL NOT NULL, "
     & "w REAL NOT NULL, h REAL NOT NULL, "
     & "state INTEGER NOT NULL DEFAULT 0, "
     & "kind INTEGER NOT NULL DEFAULT 0, "
     & "captured_at INTEGER NOT NULL DEFAULT 0, "
     & "zoom REAL NOT NULL DEFAULT 1.0, "
     & "recognized_at INTEGER NOT NULL DEFAULT 0, "
     & "words_version INTEGER NOT NULL DEFAULT 0, "
     & "scroll REAL NOT NULL DEFAULT 0.0, "
     & "scroll_across REAL NOT NULL DEFAULT 0.0)";

   Has_Scroll : constant String :=
     "SELECT count(*) FROM pragma_table_info('items') WHERE name = 'scroll'";

   Add_Scroll : constant String :=
     "ALTER TABLE items ADD COLUMN scroll REAL NOT NULL DEFAULT 0.0";

   Has_Scroll_Across : constant String :=
     "SELECT count(*) FROM pragma_table_info('items') "
     & "WHERE name = 'scroll_across'";

   Add_Scroll_Across : constant String :=
     "ALTER TABLE items ADD COLUMN scroll_across "
     & "REAL NOT NULL DEFAULT 0.0";

   Add_Words_Version : constant String :=
     "ALTER TABLE items ADD COLUMN words_version "
     & "INTEGER NOT NULL DEFAULT 0";

   Words_Schema : constant String :=
     "CREATE TABLE IF NOT EXISTS item_words ("
     & "item_id INTEGER NOT NULL "
     & "REFERENCES items (id) ON DELETE CASCADE, "
     & "seq INTEGER NOT NULL, "
     & "line INTEGER NOT NULL, "
     & "word TEXT NOT NULL, "
     & "x REAL NOT NULL, y REAL NOT NULL, "
     & "w REAL NOT NULL, h REAL NOT NULL, "
     & "PRIMARY KEY (item_id, seq)) WITHOUT ROWID";

   Marks_Schema : constant String :=
     "CREATE TABLE IF NOT EXISTS item_marks ("
     & "item_id INTEGER NOT NULL "
     & "REFERENCES items (id) ON DELETE CASCADE, "
     & "seq INTEGER NOT NULL, "
     & "x0 REAL NOT NULL, x1 REAL NOT NULL, y REAL NOT NULL, "
     & "PRIMARY KEY (item_id, seq)) WITHOUT ROWID";

   Links_Schema : constant String :=
     "CREATE TABLE IF NOT EXISTS item_links ("
     & "id INTEGER PRIMARY KEY, "
     & "from_id INTEGER NOT NULL "
     & "REFERENCES items (id) ON DELETE CASCADE, "
     & "to_id INTEGER NOT NULL "
     & "REFERENCES items (id) ON DELETE CASCADE, "
     & "from_side INTEGER NOT NULL, to_side INTEGER NOT NULL, "
     & "stroke INTEGER NOT NULL DEFAULT 0, "
     & "ending INTEGER NOT NULL DEFAULT 0, "
     & "color INTEGER NOT NULL DEFAULT 1, "
     & "CHECK (from_id <> to_id))";

   Has_Recognized : constant String :=
     "SELECT count(*) FROM pragma_table_info('items') "
     & "WHERE name = 'recognized_at'";

   Add_Recognized : constant String :=
     "ALTER TABLE items ADD COLUMN recognized_at INTEGER NOT NULL DEFAULT 0";

   Has_Zoom : constant String :=
     "SELECT count(*) FROM pragma_table_info('items') WHERE name = 'zoom'";

   Add_Zoom : constant String :=
     "ALTER TABLE items ADD COLUMN zoom REAL NOT NULL DEFAULT 1.0";

   Has_Kind : constant String :=
     "SELECT count(*) FROM pragma_table_info('items') WHERE name = 'kind'";

   Add_Kind : constant String :=
     "ALTER TABLE items ADD COLUMN kind INTEGER NOT NULL DEFAULT 0";

   Add_Captured : constant String :=
     "ALTER TABLE items ADD COLUMN captured_at INTEGER NOT NULL DEFAULT 0";

   Add_Position : constant String :=
     "ALTER TABLE items ADD COLUMN position INTEGER NOT NULL DEFAULT 0";

   Has_Position : constant String :=
     "SELECT count(*) FROM pragma_table_info('items') WHERE name = 'position'";

   Has_Directory : constant String :=
     "SELECT count(*) FROM pragma_table_info('items') "
     & "WHERE name = 'directory_id'";

   Add_Directory : constant String :=
     "ALTER TABLE items ADD COLUMN directory_id INTEGER NOT NULL DEFAULT 0";

   Directories_Schema : constant String :=
     "CREATE TABLE IF NOT EXISTS directories ("
     & "id INTEGER PRIMARY KEY, "
     & "project_id INTEGER NOT NULL "
     & "REFERENCES projects (id) ON DELETE CASCADE, "
     & "title TEXT NOT NULL, "
     & "position INTEGER NOT NULL DEFAULT 0)";

   Has_Directory_Position : constant String :=
     "SELECT count(*) FROM pragma_table_info('directories') "
     & "WHERE name = 'position'";

   Add_Directory_Position : constant String :=
     "ALTER TABLE directories ADD COLUMN position "
     & "INTEGER NOT NULL DEFAULT 0";

   Index : constant String :=
     "CREATE INDEX IF NOT EXISTS items_project ON items (project_id, id)";
   function Lacks_Kind (Store : Projects.Store) return Boolean;
   --  Whether the table was made before there were sources.

   function Lacks_Kind (Store : Projects.Store) return Boolean is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare (DB (Store).all, Has_Kind);
   begin
      return Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW
        and then Ada_Sqlite3.Column_Int (Query, 0) = 0;
   end Lacks_Kind;

   function Lacks_Zoom (Store : Projects.Store) return Boolean;
   --  Whether the table was made before sources could be zoomed.

   function Lacks_Zoom (Store : Projects.Store) return Boolean is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare (DB (Store).all, Has_Zoom);
   begin
      return Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW
        and then Ada_Sqlite3.Column_Int (Query, 0) = 0;
   end Lacks_Zoom;

   function Lacks_Recognized (Store : Projects.Store) return Boolean;
   --  Whether the table was made before the text of pictures was kept.

   function Lacks_Recognized (Store : Projects.Store) return Boolean is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare (DB (Store).all, Has_Recognized);
   begin
      return Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW
        and then Ada_Sqlite3.Column_Int (Query, 0) = 0;
   end Lacks_Recognized;

   function Lacks_Words_Version (Store : Projects.Store) return Boolean is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "SELECT count(*) FROM pragma_table_info('items') "
           & "WHERE name = 'words_version'");
   begin
      return Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW
        and then Ada_Sqlite3.Column_Int (Query, 0) = 0;
   end Lacks_Words_Version;

   procedure Add_Link_Column
     (Store : in out Projects.Store; Name, Default : String);
   --  Add the column to the table of links if it was made without it.

   procedure Add_Link_Column
     (Store : in out Projects.Store; Name, Default : String)
   is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "SELECT count(*) FROM pragma_table_info('item_links') "
           & "WHERE name = '" & Name & "'");
   begin
      if Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW
        and then Ada_Sqlite3.Column_Int (Query, 0) = 0
      then
         Ada_Sqlite3.Execute
           (DB (Store).all,
            "ALTER TABLE item_links ADD COLUMN " & Name
            & " INTEGER NOT NULL DEFAULT " & Default);
      end if;
   end Add_Link_Column;

   procedure Prepare (Store : in out Projects.Store) is
   begin
      Ada_Sqlite3.Execute (DB (Store).all, Items_Table);
      if Lacks_Kind (Store) then
         Ada_Sqlite3.Execute (DB (Store).all, Add_Kind);
         Ada_Sqlite3.Execute (DB (Store).all, Add_Captured);
      end if;
      if Lacks_Zoom (Store) then
         Ada_Sqlite3.Execute (DB (Store).all, Add_Zoom);
      end if;
      declare
         Query : Ada_Sqlite3.Statement :=
           Ada_Sqlite3.Prepare (DB (Store).all, Has_Scroll_Across);
      begin
         if Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW
           and then Ada_Sqlite3.Column_Int (Query, 0) = 0
         then
            Ada_Sqlite3.Execute (DB (Store).all, Add_Scroll_Across);
         end if;
      end;
      declare
         Query : Ada_Sqlite3.Statement :=
           Ada_Sqlite3.Prepare (DB (Store).all, Has_Scroll);
      begin
         if Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW
           and then Ada_Sqlite3.Column_Int (Query, 0) = 0
         then
            Ada_Sqlite3.Execute (DB (Store).all, Add_Scroll);
         end if;
      end;
      if Lacks_Recognized (Store) then
         Ada_Sqlite3.Execute (DB (Store).all, Add_Recognized);
      end if;
      if Lacks_Words_Version (Store) then
         Ada_Sqlite3.Execute (DB (Store).all, Add_Words_Version);
      end if;
      declare
         Query : Ada_Sqlite3.Statement :=
           Ada_Sqlite3.Prepare (DB (Store).all, Has_Position);
      begin
         if Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW
           and then Ada_Sqlite3.Column_Int (Query, 0) = 0
         then
            Ada_Sqlite3.Execute (DB (Store).all, Add_Position);
         end if;
      end;
      declare
         Query : Ada_Sqlite3.Statement :=
           Ada_Sqlite3.Prepare (DB (Store).all, Has_Directory);
      begin
         if Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW
           and then Ada_Sqlite3.Column_Int (Query, 0) = 0
         then
            Ada_Sqlite3.Execute (DB (Store).all, Add_Directory);
         end if;
      end;
      Ada_Sqlite3.Execute (DB (Store).all, Directories_Schema);
      declare
         Query : Ada_Sqlite3.Statement :=
           Ada_Sqlite3.Prepare (DB (Store).all, Has_Directory_Position);
      begin
         if Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW
           and then Ada_Sqlite3.Column_Int (Query, 0) = 0
         then
            Ada_Sqlite3.Execute (DB (Store).all, Add_Directory_Position);
         end if;
      end;
      Ada_Sqlite3.Execute (DB (Store).all, Words_Schema);
      Ada_Sqlite3.Execute (DB (Store).all, Marks_Schema);
      Ada_Sqlite3.Execute (DB (Store).all, Links_Schema);
      Add_Link_Column (Store, "stroke", "0");
      Add_Link_Column (Store, "ending", "0");
      Add_Link_Column (Store, "color", "1");
      Ada_Sqlite3.Execute (DB (Store).all, Index);
   end Prepare;

end Items.Schema;
