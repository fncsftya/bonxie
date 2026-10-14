with Ada.Directories;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Numerics.Elementary_Functions;
with Ada_Sqlite3;

package body Items is

   use type Ada_Sqlite3.Result_Code;
   use type Projects.Id;

   Schema : constant String :=
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

   Words_Version : constant := 1;
   --  Of how the words are put in order (see Vision.Layout): words kept
   --  by an earlier version are looked for again.

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

   function Percent (Zoom : Float) return String is
     (Ada.Strings.Fixed.Trim
        (Integer'Image (Integer (Float'Rounding (Zoom * 100.0))),
         Ada.Strings.Both) & "%");

   function To_Slider (Zoom : Float) return Float is
     (Float'Min
        (1.0,
         Float'Max
           (0.0,
            Ada.Numerics.Elementary_Functions.Log (Zoom / Min_Zoom)
            / Ada.Numerics.Elementary_Functions.Log (Max_Zoom / Min_Zoom))));

   function From_Slider (Along : Float) return Float is
     (Float'Min
        (Max_Zoom,
         Float'Max
           (Min_Zoom,
            Float'Rounding
              (100.0 * Min_Zoom
               * Ada.Numerics.Elementary_Functions."**"
                   (Max_Zoom / Min_Zoom, Along)) / 100.0)));

   function DB (Store : Projects.Store)
      return not null access Ada_Sqlite3.Database is
     (Projects.Connection (Store));

   function State_Code (State : States) return Integer is
     (States'Pos (State));

   function State_Of (Code : Integer) return States is
     (if Code in 0 .. States'Pos (States'Last)
      then States'Val (Code) else Open);

   function Kind_Code (Kind : Kinds) return Integer is (Kinds'Pos (Kind));

   function Kind_Of (Code : Integer) return Kinds is
     (if Code in 0 .. Kinds'Pos (Kinds'Last)
      then Kinds'Val (Code) else Note);

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
      Ada_Sqlite3.Execute (DB (Store).all, Schema);
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

   function Create
     (Store   : in out Projects.Store;
      Project : Projects.Id;
      Title   : String;
      Where   : Frame;
      Text    : String := "";
      Kind    : Kinds := Note) return Id
   is
      Insert : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "INSERT INTO items (project_id, title, content, x, y, w, h, kind)"
           & " VALUES (:project, :title, :content, :x, :y, :w, :h, :kind)");
   begin
      pragma Assert (Count (Store, Project) < Capacity);
      Ada_Sqlite3.Bind_Int64 (Insert, ":project", Long_Integer (Project));
      Ada_Sqlite3.Bind_Text (Insert, ":title", Title);
      Ada_Sqlite3.Bind_Text (Insert, ":content", Text);
      Ada_Sqlite3.Bind_Double (Insert, ":x", Where.Left);
      Ada_Sqlite3.Bind_Double (Insert, ":y", Where.Top);
      Ada_Sqlite3.Bind_Double (Insert, ":w", Where.Width);
      Ada_Sqlite3.Bind_Double (Insert, ":h", Where.Height);
      Ada_Sqlite3.Bind_Int (Insert, ":kind", Kind_Code (Kind));
      Ada_Sqlite3.Step (Insert);
      return Id (Ada_Sqlite3.Last_Insert_Row_ID (DB (Store).all));
   end Create;

   procedure Load
     (Store   : Projects.Store;
      Project : Projects.Id;
      Result  : out Info_List)
   is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "SELECT id, title, x, y, w, h, state, kind, "
           & "captured_at, zoom, recognized_at, scroll, scroll_across "
           & "FROM items "
           & "WHERE project_id = :project ORDER BY id LIMIT :limit");
   begin
      Result.Count := 0;
      Ada_Sqlite3.Bind_Int64 (Query, ":project", Long_Integer (Project));
      Ada_Sqlite3.Bind_Int (Query, ":limit", Capacity);
      while Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW loop
         pragma Assert (Result.Count < Capacity);
         Result.Count := Result.Count + 1;
         Result.Items (Result.Count) :=
           (Key   => Id (Ada_Sqlite3.Column_Int64 (Query, 0)),
            Title => Projects.Titles.To_Bounded_String
              (Ada_Sqlite3.Column_Text (Query, 1), Ada.Strings.Right),
            Where => (Left   => Ada_Sqlite3.Column_Double (Query, 2),
                      Top    => Ada_Sqlite3.Column_Double (Query, 3),
                      Width  => Ada_Sqlite3.Column_Double (Query, 4),
                      Height => Ada_Sqlite3.Column_Double (Query, 5)),
            State => State_Of (Ada_Sqlite3.Column_Int (Query, 6)),
            Kind  => Kind_Of (Ada_Sqlite3.Column_Int (Query, 7)),
            Captured_At => Ada_Sqlite3.Column_Int64 (Query, 8),
            Zoom  => Float'Min
              (Max_Zoom,
               Float'Max (Min_Zoom, Ada_Sqlite3.Column_Double (Query, 9))),
            Recognized_At => Ada_Sqlite3.Column_Int64 (Query, 10),
            Scroll => Float'Max
              (0.0, Ada_Sqlite3.Column_Double (Query, 11)),
            Scroll_Across => Float'Min
              (1.0,
               Float'Max (0.0, Ada_Sqlite3.Column_Double (Query, 12))));
      end loop;
   end Load;

   procedure Load_Order
     (Store   : Projects.Store;
      Project : Projects.Id;
      Result  : out Id_List)
   is
      --  Those never put (position 0) come after those that were.
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "SELECT id FROM items WHERE project_id = :project "
           & "ORDER BY position = 0, position, id LIMIT :limit");
   begin
      Result.Count := 0;
      Ada_Sqlite3.Bind_Int64 (Query, ":project", Long_Integer (Project));
      Ada_Sqlite3.Bind_Int (Query, ":limit", Capacity);
      while Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW loop
         pragma Assert (Result.Count < Capacity);
         Result.Count := Result.Count + 1;
         Result.Keys (Result.Count) :=
           Id (Ada_Sqlite3.Column_Int64 (Query, 0));
      end loop;
   end Load_Order;

   function Create_Directory
     (Store   : in out Projects.Store;
      Project : Projects.Id;
      Title   : String) return Id
   is
      Insert : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "INSERT INTO directories (project_id, title) "
           & "VALUES (:project, :title)");
   begin
      Ada_Sqlite3.Bind_Int64 (Insert, ":project", Long_Integer (Project));
      Ada_Sqlite3.Bind_Text (Insert, ":title", Title);
      Ada_Sqlite3.Step (Insert);
      return Id (Ada_Sqlite3.Last_Insert_Row_ID (DB (Store).all));
   end Create_Directory;

   procedure Load_Directories
     (Store   : Projects.Store;
      Project : Projects.Id;
      Result  : out Directory_List)
   is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "SELECT id, title, position FROM directories "
           & "WHERE project_id = :project "
           & "ORDER BY position = 0, position, id LIMIT :limit");
   begin
      Result.Count := 0;
      Ada_Sqlite3.Bind_Int64 (Query, ":project", Long_Integer (Project));
      Ada_Sqlite3.Bind_Int (Query, ":limit", Max_Directories);
      while Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW loop
         pragma Assert (Result.Count < Max_Directories);
         Result.Count := Result.Count + 1;
         Result.Directories (Result.Count) :=
           (Key   => Id (Ada_Sqlite3.Column_Int64 (Query, 0)),
            Title => Projects.Titles.To_Bounded_String
              (Ada_Sqlite3.Column_Text (Query, 1), Ada.Strings.Right),
            Position => Natural'Max (0, Ada_Sqlite3.Column_Int (Query, 2)));
      end loop;
   end Load_Directories;

   function Position_Of (Store : Projects.Store; Key : Id) return Natural is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all, "SELECT position FROM items WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int64 (Query, ":id", Long_Integer (Key));
      return (if Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW
              then Natural'Max (0, Ada_Sqlite3.Column_Int (Query, 0))
              else 0);
   end Position_Of;

   procedure Set_Position
     (Store : in out Projects.Store; Key : Id; Position : Positive)
   is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "UPDATE items SET position = :position WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int (Update, ":position", Position);
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Update);
   end Set_Position;

   procedure Set_Directory_Position
     (Store : in out Projects.Store; Key : Id; Position : Positive)
   is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "UPDATE directories SET position = :position WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int (Update, ":position", Position);
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Update);
   end Set_Directory_Position;

   function Directory_Count
     (Store : Projects.Store; Project : Projects.Id) return Natural
   is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "SELECT count(*) FROM directories WHERE project_id = :project");
   begin
      Ada_Sqlite3.Bind_Int64 (Query, ":project", Long_Integer (Project));
      return (if Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW
              then Ada_Sqlite3.Column_Int (Query, 0) else 0);
   end Directory_Count;

   procedure Rename_Directory
     (Store : in out Projects.Store; Key : Id; Title : String)
   is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "UPDATE directories SET title = :title WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Text (Update, ":title", Title);
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Update);
   end Rename_Directory;

   procedure Delete_Directory (Store : in out Projects.Store; Key : Id) is
      Free : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "UPDATE items SET directory_id = 0 WHERE directory_id = :id");
      Drop : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all, "DELETE FROM directories WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int64 (Free, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Free);
      Ada_Sqlite3.Bind_Int64 (Drop, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Drop);
   end Delete_Directory;

   function Directory_Of (Store : Projects.Store; Key : Id) return Id is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "SELECT directory_id FROM items WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int64 (Query, ":id", Long_Integer (Key));
      return (if Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW
              then Id (Ada_Sqlite3.Column_Int64 (Query, 0)) else 0);
   end Directory_Of;

   procedure Set_Directory
     (Store : in out Projects.Store; Key : Id; Into : Id)
   is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "UPDATE items SET directory_id = :directory WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int64 (Update, ":directory", Long_Integer (Into));
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Update);
   end Set_Directory;

   function Count
     (Store : Projects.Store; Project : Projects.Id) return Natural
   is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "SELECT count(*) FROM items WHERE project_id = :project");
   begin
      Ada_Sqlite3.Bind_Int64 (Query, ":project", Long_Integer (Project));
      return (if Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW
              then Ada_Sqlite3.Column_Int (Query, 0) else 0);
   end Count;

   function Content (Store : Projects.Store; Key : Id) return String is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all, "SELECT content FROM items WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int64 (Query, ":id", Long_Integer (Key));
      return (if Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW
              then Ada_Sqlite3.Column_Text (Query, 0) else "");
   end Content;

   procedure Set_Title
     (Store : in out Projects.Store; Key : Id; Title : String)
   is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all, "UPDATE items SET title = :title WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Text (Update, ":title", Title);
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Update);
   end Set_Title;

   procedure Set_Content
     (Store : in out Projects.Store; Key : Id; Text : String)
   is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "UPDATE items SET content = :content WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Text (Update, ":content", Text);
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Update);
   end Set_Content;

   procedure Set_Frame
     (Store : in out Projects.Store; Key : Id; Where : Frame)
   is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "UPDATE items SET x = :x, y = :y, w = :w, h = :h WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Double (Update, ":x", Where.Left);
      Ada_Sqlite3.Bind_Double (Update, ":y", Where.Top);
      Ada_Sqlite3.Bind_Double (Update, ":w", Where.Width);
      Ada_Sqlite3.Bind_Double (Update, ":h", Where.Height);
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Update);
   end Set_Frame;

   procedure Set_State
     (Store : in out Projects.Store; Key : Id; State : States)
   is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all, "UPDATE items SET state = :state WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int (Update, ":state", State_Code (State));
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Update);
   end Set_State;

   procedure Set_Zoom
     (Store : in out Projects.Store; Key : Id; Zoom : Zoom_Level)
   is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all, "UPDATE items SET zoom = :zoom WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Double (Update, ":zoom", Zoom);
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Update);
   end Set_Zoom;

   procedure Set_Scroll
     (Store : in out Projects.Store; Key : Id; Scroll, Across : Float)
   is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "UPDATE items SET scroll = :scroll, scroll_across = :across "
           & "WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Double (Update, ":scroll", Scroll);
      Ada_Sqlite3.Bind_Double (Update, ":across", Across);
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Update);
   end Set_Scroll;

   procedure Set_Captured
     (Store : in out Projects.Store; Key : Id; At_Time : Projects.Seconds)
   is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "UPDATE items SET captured_at = :time WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int64 (Update, ":time", At_Time);
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Update);
      Clear_Words (Store, Key);
      Clear_Marks (Store, Key);
   end Set_Captured;

   procedure Clear_Marks (Store : in out Projects.Store; Key : Id) is
      Remove : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all, "DELETE FROM item_marks WHERE item_id = :id");
   begin
      Ada_Sqlite3.Bind_Int64 (Remove, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Remove);
   end Clear_Marks;

   procedure Save_Marks
     (Store : in out Projects.Store; Key : Id; Marks : Mark_List)
   is
      Insert : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "INSERT INTO item_marks (item_id, seq, x0, x1, y)"
           & " VALUES (:item, :seq, :x0, :x1, :y)");
   begin
      Ada_Sqlite3.Execute (DB (Store).all, "BEGIN");
      Clear_Marks (Store, Key);
      for Number in 1 .. Marks.Count loop
         Ada_Sqlite3.Reset (Insert);
         Ada_Sqlite3.Bind_Int64 (Insert, ":item", Long_Integer (Key));
         Ada_Sqlite3.Bind_Int (Insert, ":seq", Number);
         Ada_Sqlite3.Bind_Double (Insert, ":x0", Marks.Marks (Number).Left);
         Ada_Sqlite3.Bind_Double (Insert, ":x1", Marks.Marks (Number).Right);
         Ada_Sqlite3.Bind_Double (Insert, ":y", Marks.Marks (Number).Y);
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

   function Image_Folder
     (Store : Projects.Store; Project : Projects.Id) return String is
     (Projects.Folder (Store, Project) & "/sources");

   function Image_File
     (Store : Projects.Store; Project : Projects.Id; Key : Id) return String
   is
     (Image_Folder (Store, Project) & "/"
      & Ada.Strings.Fixed.Trim (Key'Image, Ada.Strings.Both) & ".png");

   procedure Make_Image_Folder
     (Store : Projects.Store; Project : Projects.Id) is
   begin
      Ada.Directories.Create_Path (Image_Folder (Store, Project));
   end Make_Image_Folder;

   function Owner (Store : Projects.Store; Key : Id) return Projects.Id;
   --  The project the item is of, 0 if there is no such item.

   function Owner (Store : Projects.Store; Key : Id) return Projects.Id is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all, "SELECT project_id FROM items WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int64 (Query, ":id", Long_Integer (Key));
      return (if Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW
              then Projects.Id (Ada_Sqlite3.Column_Int64 (Query, 0)) else 0);
   end Owner;

   function Side_Of (Code : Integer) return Sides is
     (if Code in 0 .. Sides'Pos (Sides'Last)
      then Sides'Val (Code) else Top);

   function Stroke_Of (Code : Integer) return Strokes is
     (if Code in 0 .. Strokes'Pos (Strokes'Last)
      then Strokes'Val (Code) else Solid);

   function Ending_Of (Code : Integer) return Endings is
     (if Code in 0 .. Endings'Pos (Endings'Last)
      then Endings'Val (Code) else Plain);

   function Color_Of (Code : Integer) return Link_Colors is
     (if Code in Link_Colors then Code else 1);

   function Is_Linked
     (Store : Projects.Store; A, B : Id) return Boolean
   is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "SELECT count(*) FROM item_links "
           & "WHERE (from_id = :a AND to_id = :b) "
           & "OR (from_id = :b AND to_id = :a)");
   begin
      Ada_Sqlite3.Bind_Int64 (Query, ":a", Long_Integer (A));
      Ada_Sqlite3.Bind_Int64 (Query, ":b", Long_Integer (B));
      return Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW
        and then Ada_Sqlite3.Column_Int (Query, 0) > 0;
   end Is_Linked;

   procedure Add_Link
     (Store : in out Projects.Store; Made : Link; Added : out Boolean) is
   begin
      Added := not Is_Linked (Store, Made.From, Made.To);
      if Added then
         declare
            Insert : Ada_Sqlite3.Statement :=
              Ada_Sqlite3.Prepare
                (DB (Store).all,
                 "INSERT INTO item_links "
                 & "(from_id, to_id, from_side, to_side, "
                 & "stroke, ending, color) "
                 & "VALUES (:from, :to, :from_side, :to_side, "
                 & ":stroke, :ending, :color)");
         begin
            Ada_Sqlite3.Bind_Int64 (Insert, ":from", Long_Integer (Made.From));
            Ada_Sqlite3.Bind_Int64 (Insert, ":to", Long_Integer (Made.To));
            Ada_Sqlite3.Bind_Int
              (Insert, ":from_side", Sides'Pos (Made.From_Side));
            Ada_Sqlite3.Bind_Int
              (Insert, ":to_side", Sides'Pos (Made.To_Side));
            Ada_Sqlite3.Bind_Int
              (Insert, ":stroke", Strokes'Pos (Made.Stroke));
            Ada_Sqlite3.Bind_Int
              (Insert, ":ending", Endings'Pos (Made.Ending));
            Ada_Sqlite3.Bind_Int (Insert, ":color", Made.Color);
            Ada_Sqlite3.Step (Insert);
         end;
      end if;
   end Add_Link;

   procedure Delete_Link (Store : in out Projects.Store; Key : Id) is
      Remove : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all, "DELETE FROM item_links WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int64 (Remove, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Remove);
   end Delete_Link;

   procedure Set_Link_Style
     (Store  : in out Projects.Store;
      Key    : Id;
      Stroke : Strokes;
      Ending : Endings;
      Color  : Link_Colors)
   is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "UPDATE item_links SET stroke = :stroke, ending = :ending, "
           & "color = :color WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int (Update, ":stroke", Strokes'Pos (Stroke));
      Ada_Sqlite3.Bind_Int (Update, ":ending", Endings'Pos (Ending));
      Ada_Sqlite3.Bind_Int (Update, ":color", Color);
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Update);
   end Set_Link_Style;

   procedure Move_Link
     (Store : in out Projects.Store;
      Key   : Id;
      To    : Id;
      Side  : Sides;
      Moved : out Boolean)
   is
      Joined : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "SELECT count(*) FROM item_links a, item_links b "
           & "WHERE a.id = :id AND b.id <> a.id AND "
           & "((b.from_id = a.from_id AND b.to_id = :to) "
           & "OR (b.to_id = a.from_id AND b.from_id = :to))");
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "UPDATE item_links SET to_id = :to, to_side = :side "
           & "WHERE id = :id AND from_id <> :to");
   begin
      Ada_Sqlite3.Bind_Int64 (Joined, ":id", Long_Integer (Key));
      Ada_Sqlite3.Bind_Int64 (Joined, ":to", Long_Integer (To));
      Moved := Ada_Sqlite3.Step (Joined) = Ada_Sqlite3.ROW
        and then Ada_Sqlite3.Column_Int (Joined, 0) = 0;
      if Moved then
         Ada_Sqlite3.Bind_Int64 (Update, ":to", Long_Integer (To));
         Ada_Sqlite3.Bind_Int (Update, ":side", Sides'Pos (Side));
         Ada_Sqlite3.Bind_Int64 (Update, ":id", Long_Integer (Key));
         Ada_Sqlite3.Step (Update);
      end if;
   end Move_Link;

   procedure Load_Links
     (Store   : Projects.Store;
      Project : Projects.Id;
      Result  : out Link_List)
   is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "SELECT l.from_id, l.to_id, l.from_side, l.to_side, "
           & "l.id, l.stroke, l.ending, l.color "
           & "FROM item_links l JOIN items i ON i.id = l.from_id "
           & "WHERE i.project_id = :project ORDER BY l.id LIMIT :limit");
   begin
      Result.Count := 0;
      Ada_Sqlite3.Bind_Int64 (Query, ":project", Long_Integer (Project));
      Ada_Sqlite3.Bind_Int (Query, ":limit", Max_Links);
      while Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW loop
         Result.Count := Result.Count + 1;
         Result.Links (Result.Count) :=
           (From      => Id (Ada_Sqlite3.Column_Int64 (Query, 0)),
            To        => Id (Ada_Sqlite3.Column_Int64 (Query, 1)),
            From_Side => Side_Of (Ada_Sqlite3.Column_Int (Query, 2)),
            To_Side   => Side_Of (Ada_Sqlite3.Column_Int (Query, 3)),
            Key       => Id (Ada_Sqlite3.Column_Int64 (Query, 4)),
            Stroke    => Stroke_Of (Ada_Sqlite3.Column_Int (Query, 5)),
            Ending    => Ending_Of (Ada_Sqlite3.Column_Int (Query, 6)),
            Color     => Color_Of (Ada_Sqlite3.Column_Int (Query, 7)));
      end loop;
   end Load_Links;

   procedure Delete (Store : in out Projects.Store; Key : Id) is
      Project : constant Projects.Id := Owner (Store, Key);
      Remove  : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all, "DELETE FROM items WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int64 (Remove, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Remove);
      if Project /= 0 then
         declare
            Picture : constant String := Image_File (Store, Project, Key);
         begin
            if Ada.Directories.Exists (Picture) then
               Ada.Directories.Delete_File (Picture);
            end if;
         end;
      end if;
   end Delete;

end Items;
