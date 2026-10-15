with Ada.Strings;
with Ada_Sqlite3;
with Repository.Database; use Repository.Database;

package body Repository.Item is

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

   Index : constant String :=
     "CREATE INDEX IF NOT EXISTS items_project ON items (project_id, id)";

   function State_Of (Code : Integer) return Items.States is
     (if Code in 0 .. Items.States'Pos (Items.States'Last)
      then Items.States'Val (Code) else Items.Open);

   function Kind_Of (Code : Integer) return Items.Kinds is
     (if Code in 0 .. Items.Kinds'Pos (Items.Kinds'Last)
      then Items.Kinds'Val (Code) else Items.Note);

   procedure Prepare (Store : in out Projects.Store) is
      Integer_Column : constant String := "INTEGER NOT NULL DEFAULT 0";
   begin
      Ada_Sqlite3.Execute (DB (Store).all, Items_Table);
      --  Those below were added to the table after it was first made.
      if not Has_Column (Store, "items", "kind") then
         Add_Column (Store, "items", "kind", Integer_Column);
         Add_Column (Store, "items", "captured_at", Integer_Column);
      end if;
      Add_Column (Store, "items", "zoom", "REAL NOT NULL DEFAULT 1.0");
      Add_Column (Store, "items", "scroll_across", "REAL NOT NULL DEFAULT 0.0");
      Add_Column (Store, "items", "scroll", "REAL NOT NULL DEFAULT 0.0");
      Add_Column (Store, "items", "recognized_at", Integer_Column);
      Add_Column (Store, "items", "words_version", Integer_Column);
      Add_Column (Store, "items", "position", Integer_Column);
      Add_Column (Store, "items", "directory_id", Integer_Column);
      --  Those made before it was said where a source is from are links.
      Add_Column (Store, "items", "origin", "INTEGER NOT NULL DEFAULT 1");
      Add_Column (Store, "items", "page", Integer_Column);
      Add_Column (Store, "items", "page_count", Integer_Column);
      Add_Column (Store, "items", "document", "TEXT NOT NULL DEFAULT ''");
      Ada_Sqlite3.Execute (DB (Store).all, Index);
   end Prepare;

   function Insert
     (Store   : in out Projects.Store;
      Project : Projects.Id;
      Title   : String;
      Where   : Items.Frame;
      Text    : String;
      Kind    : Items.Kinds) return Items.Id
   is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "INSERT INTO items (project_id, title, content, x, y, w, h, kind)"
           & " VALUES (:project, :title, :content, :x, :y, :w, :h, :kind)");
   begin
      Ada_Sqlite3.Bind_Int64 (Query, ":project", Long_Integer (Project));
      Ada_Sqlite3.Bind_Text (Query, ":title", Title);
      Ada_Sqlite3.Bind_Text (Query, ":content", Text);
      Ada_Sqlite3.Bind_Double (Query, ":x", Where.Left);
      Ada_Sqlite3.Bind_Double (Query, ":y", Where.Top);
      Ada_Sqlite3.Bind_Double (Query, ":w", Where.Width);
      Ada_Sqlite3.Bind_Double (Query, ":h", Where.Height);
      Ada_Sqlite3.Bind_Int (Query, ":kind", Items.Kinds'Pos (Kind));
      Ada_Sqlite3.Step (Query);
      return Items.Id (Ada_Sqlite3.Last_Insert_Row_ID (DB (Store).all));
   end Insert;

   procedure Load
     (Store   : Projects.Store;
      Project : Projects.Id;
      Result  : out Items.Info_List)
   is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "SELECT id, title, x, y, w, h, state, kind, "
           & "captured_at, zoom, recognized_at, scroll, scroll_across, "
           & "page, page_count, document, origin "
           & "FROM items "
           & "WHERE project_id = :project ORDER BY id LIMIT :limit");
   begin
      Result.Count := 0;
      Ada_Sqlite3.Bind_Int64 (Query, ":project", Long_Integer (Project));
      Ada_Sqlite3.Bind_Int (Query, ":limit", Items.Capacity);
      while Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW loop
         pragma Assert (Result.Count < Items.Capacity);
         Result.Count := Result.Count + 1;
         Result.Items (Result.Count) :=
           (Key   => Items.Id (Ada_Sqlite3.Column_Int64 (Query, 0)),
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
              (Items.Max_Zoom,
               Float'Max
                 (Items.Min_Zoom, Ada_Sqlite3.Column_Double (Query, 9))),
            Recognized_At => Ada_Sqlite3.Column_Int64 (Query, 10),
            Scroll => Float'Max
              (0.0, Ada_Sqlite3.Column_Double (Query, 11)),
            Scroll_Across => Float'Min
              (1.0,
               Float'Max (0.0, Ada_Sqlite3.Column_Double (Query, 12))),
            Page => Natural'Max (0, Ada_Sqlite3.Column_Int (Query, 13)),
            Page_Count => Natural'Max (0, Ada_Sqlite3.Column_Int (Query, 14)),
            Document => Items.Extensions.To_Bounded_String
              (Ada_Sqlite3.Column_Text (Query, 15), Ada.Strings.Right),
            Origin => (if Ada_Sqlite3.Column_Int (Query, 16)
                          in 0 .. Items.Origins'Pos (Items.Origins'Last)
                       then Items.Origins'Val (Ada_Sqlite3.Column_Int (Query, 16))
                       else Items.Remote));
      end loop;
   end Load;

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

   function Content (Store : Projects.Store; Key : Items.Id) return String is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all, "SELECT content FROM items WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int64 (Query, ":id", Long_Integer (Key));
      return (if Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW
              then Ada_Sqlite3.Column_Text (Query, 0) else "");
   end Content;

   function Owner (Store : Projects.Store; Key : Items.Id) return Projects.Id
   is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all, "SELECT project_id FROM items WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int64 (Query, ":id", Long_Integer (Key));
      return (if Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW
              then Projects.Id (Ada_Sqlite3.Column_Int64 (Query, 0)) else 0);
   end Owner;

   procedure Set_Title
     (Store : in out Projects.Store; Key : Items.Id; Title : String)
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
     (Store : in out Projects.Store; Key : Items.Id; Text : String)
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
     (Store : in out Projects.Store; Key : Items.Id; Where : Items.Frame)
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
     (Store : in out Projects.Store; Key : Items.Id; State : Items.States)
   is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all, "UPDATE items SET state = :state WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int (Update, ":state", Items.States'Pos (State));
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Update);
   end Set_State;

   procedure Set_Scroll
     (Store : in out Projects.Store; Key : Items.Id; Scroll, Across : Float)
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

   procedure Set_Zoom
     (Store : in out Projects.Store; Key : Items.Id; Zoom : Items.Zoom_Level)
   is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all, "UPDATE items SET zoom = :zoom WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Double (Update, ":zoom", Zoom);
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Update);
   end Set_Zoom;

   procedure Set_Captured
     (Store : in out Projects.Store; Key : Items.Id; At_Time : Projects.Seconds)
   is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "UPDATE items SET captured_at = :time WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int64 (Update, ":time", At_Time);
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Update);
   end Set_Captured;

   procedure Set_Document
     (Store      : in out Projects.Store;
      Key        : Items.Id;
      Document   : String;
      Page_Count : Natural)
   is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "UPDATE items SET document = :document, page_count = :count, "
           & "page = :page WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Text (Update, ":document", Document);
      Ada_Sqlite3.Bind_Int (Update, ":count", Page_Count);
      Ada_Sqlite3.Bind_Int (Update, ":page", Boolean'Pos (Page_Count > 0));
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Update);
   end Set_Document;

   procedure Set_Origin
     (Store : in out Projects.Store; Key : Items.Id; Origin : Items.Origins)
   is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all, "UPDATE items SET origin = :origin WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int (Update, ":origin", Items.Origins'Pos (Origin));
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Update);
   end Set_Origin;

   procedure Set_Page
     (Store : in out Projects.Store; Key : Items.Id; Page : Natural)
   is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all, "UPDATE items SET page = :page WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int (Update, ":page", Page);
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Update);
   end Set_Page;

   procedure Set_Recognized
     (Store   : in out Projects.Store;
      Key     : Items.Id;
      At_Time : Projects.Seconds;
      Version : Natural)
   is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "UPDATE items SET recognized_at = :time, "
           & "words_version = :version WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int64 (Update, ":time", At_Time);
      Ada_Sqlite3.Bind_Int (Update, ":version", Version);
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Update);
   end Set_Recognized;

   function Is_Recognized
     (Store   : Projects.Store;
      Key     : Items.Id;
      Version : Natural) return Boolean
   is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "SELECT recognized_at, words_version FROM items WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int64 (Query, ":id", Long_Integer (Key));
      return Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW
        and then Ada_Sqlite3.Column_Int64 (Query, 0) > 0
        and then Ada_Sqlite3.Column_Int (Query, 1) = Version;
   end Is_Recognized;

   function Position_Of
     (Store : Projects.Store; Key : Items.Id) return Natural
   is
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
     (Store : in out Projects.Store; Key : Items.Id; Position : Positive)
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

   procedure Load_Order
     (Store   : Projects.Store;
      Project : Projects.Id;
      Result  : out Items.Id_List)
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
      Ada_Sqlite3.Bind_Int (Query, ":limit", Items.Capacity);
      while Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW loop
         pragma Assert (Result.Count < Items.Capacity);
         Result.Count := Result.Count + 1;
         Result.Keys (Result.Count) :=
           Items.Id (Ada_Sqlite3.Column_Int64 (Query, 0));
      end loop;
   end Load_Order;

   function Directory_Of
     (Store : Projects.Store; Key : Items.Id) return Items.Id
   is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "SELECT directory_id FROM items WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int64 (Query, ":id", Long_Integer (Key));
      return (if Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW
              then Items.Id (Ada_Sqlite3.Column_Int64 (Query, 0)) else 0);
   end Directory_Of;

   procedure Set_Directory
     (Store : in out Projects.Store; Key, Directory : Items.Id)
   is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "UPDATE items SET directory_id = :directory WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int64 (Update, ":directory", Long_Integer (Directory));
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Update);
   end Set_Directory;

   procedure Free_Directory
     (Store : in out Projects.Store; Directory : Items.Id)
   is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "UPDATE items SET directory_id = 0 WHERE directory_id = :id");
   begin
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Long_Integer (Directory));
      Ada_Sqlite3.Step (Update);
   end Free_Directory;

   procedure Delete (Store : in out Projects.Store; Key : Items.Id) is
      Remove : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all, "DELETE FROM items WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int64 (Remove, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Remove);
   end Delete;

end Repository.Item;
