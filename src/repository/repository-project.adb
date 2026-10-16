with Ada.Strings;
with Ada_Sqlite3;
with Repository.Database; use Repository.Database;

package body Repository.Project is

   use type Ada_Sqlite3.Result_Code;

   Schema : constant String :=
     "CREATE TABLE IF NOT EXISTS projects ("
     & "id INTEGER PRIMARY KEY, "
     & "title TEXT NOT NULL, "
     & "description TEXT NOT NULL DEFAULT '', "
     & "created_at INTEGER NOT NULL, "
     & "updated_at INTEGER NOT NULL)";

   Index : constant String :=
     "CREATE INDEX IF NOT EXISTS projects_updated "
     & "ON projects (updated_at DESC, id DESC)";

   Clock : constant String :=
     "COALESCE(nullif(:time, " & Projects.Now'Image
     & "), CAST(strftime('%s', 'now') AS INTEGER))";
   --  A time bound to :time, or the current one if it is Now.

   Columns : constant String :=
     "id, title, description, created_at, updated_at";
   --  What a project is read from.

   function Row (Query : Ada_Sqlite3.Statement) return Projects.Project is
     (Key         => Projects.Id (Ada_Sqlite3.Column_Int64 (Query, 0)),
      Title       => Projects.Titles.To_Bounded_String
        (Ada_Sqlite3.Column_Text (Query, 1), Ada.Strings.Right),
      Description => Projects.Descriptions.To_Bounded_String
        (Ada_Sqlite3.Column_Text (Query, 2), Ada.Strings.Right),
      Created_At  => Ada_Sqlite3.Column_Int64 (Query, 3),
      Updated_At  => Ada_Sqlite3.Column_Int64 (Query, 4));

   procedure Prepare (Store : in out Projects.Store) is
   begin
      Ada_Sqlite3.Execute (DB (Store).all, "PRAGMA foreign_keys = ON");
      Ada_Sqlite3.Execute (DB (Store).all, Schema);
      --  Added to tables made before the view was kept.
      Add_Column (Store, "projects", "view_saved", "INTEGER NOT NULL DEFAULT 0");
      Add_Column (Store, "projects", "view_zoom", "REAL NOT NULL DEFAULT 1.0");
      Add_Column (Store, "projects", "view_x", "REAL NOT NULL DEFAULT 0.0");
      Add_Column (Store, "projects", "view_y", "REAL NOT NULL DEFAULT 0.0");
      Add_Column (Store, "projects", "tab", "INTEGER NOT NULL DEFAULT 0");
      Ada_Sqlite3.Execute (DB (Store).all, Index);
   end Prepare;

   procedure Set_Description
     (Store       : in out Projects.Store;
      Key         : Projects.Id;
      Description : String)
   is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "UPDATE projects SET description = :description WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Text (Update, ":description", Description);
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Update);
   end Set_Description;

   procedure Set_Tab
     (Store : in out Projects.Store; Key : Projects.Id; To : Natural)
   is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all, "UPDATE projects SET tab = :tab WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int (Update, ":tab", To);
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Update);
   end Set_Tab;

   function Tab
     (Store : Projects.Store; Key : Projects.Id) return Natural
   is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all, "SELECT tab FROM projects WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int64 (Query, ":id", Long_Integer (Key));
      return (if Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW
              then Natural'Max (0, Ada_Sqlite3.Column_Int (Query, 0))
              else 0);
   end Tab;

   function Insert
     (Store       : in out Projects.Store;
      Title       : String;
      Description : String;
      Time        : Projects.Seconds) return Projects.Id
   is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "INSERT INTO projects (title, description, created_at, updated_at)"
           & " VALUES (:title, :description, " & Clock & ", " & Clock & ")");
   begin
      Ada_Sqlite3.Bind_Text (Query, ":title", Title);
      Ada_Sqlite3.Bind_Text (Query, ":description", Description);
      Ada_Sqlite3.Bind_Int64 (Query, ":time", Time);
      Ada_Sqlite3.Step (Query);
      return Projects.Id (Ada_Sqlite3.Last_Insert_Row_ID (DB (Store).all));
   end Insert;

   procedure Touch
     (Store : in out Projects.Store;
      Key   : Projects.Id;
      Time  : Projects.Seconds)
   is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "UPDATE projects SET updated_at = " & Clock & " WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int64 (Update, ":time", Time);
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Update);
   end Touch;

   procedure Rename
     (Store : in out Projects.Store;
      Key   : Projects.Id;
      Title : String;
      Time  : Projects.Seconds)
   is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "UPDATE projects SET title = :title, updated_at = " & Clock
           & " WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Text (Update, ":title", Title);
      Ada_Sqlite3.Bind_Int64 (Update, ":time", Time);
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Update);
   end Rename;

   procedure Set_View
     (Store : in out Projects.Store;
      Key   : Projects.Id;
      Zoom, Centre_X, Centre_Y : Float)
   is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "UPDATE projects SET view_saved = 1, view_zoom = :zoom, "
           & "view_x = :x, view_y = :y WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Double (Update, ":zoom", Zoom);
      Ada_Sqlite3.Bind_Double (Update, ":x", Centre_X);
      Ada_Sqlite3.Bind_Double (Update, ":y", Centre_Y);
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Update);
   end Set_View;

   procedure Get_View
     (Store  : Projects.Store;
      Key    : Projects.Id;
      Found  : out Boolean;
      Zoom, Centre_X, Centre_Y : out Float)
   is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "SELECT view_saved, view_zoom, view_x, view_y FROM projects "
           & "WHERE id = :id");
   begin
      Found := False;
      Zoom := 1.0;
      Centre_X := 0.0;
      Centre_Y := 0.0;
      Ada_Sqlite3.Bind_Int64 (Query, ":id", Long_Integer (Key));
      if Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW
        and then Ada_Sqlite3.Column_Int (Query, 0) = 1
      then
         Found := True;
         Zoom := Ada_Sqlite3.Column_Double (Query, 1);
         Centre_X := Ada_Sqlite3.Column_Double (Query, 2);
         Centre_Y := Ada_Sqlite3.Column_Double (Query, 3);
      end if;
   end Get_View;

   procedure Find
     (Store  : Projects.Store;
      Key    : Projects.Id;
      Found  : out Boolean;
      Result : out Projects.Project)
   is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "SELECT " & Columns & " FROM projects WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int64 (Query, ":id", Long_Integer (Key));
      Found := Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW;
      if Found then
         Result := Row (Query);
      end if;
   end Find;

   procedure Delete (Store : in out Projects.Store; Key : Projects.Id) is
      Remove : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all, "DELETE FROM projects WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int64 (Remove, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Remove);
   end Delete;

   procedure Recent
     (Store : Projects.Store; Result : out Projects.Recent_List)
   is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "SELECT " & Columns & " FROM projects "
           & "ORDER BY updated_at DESC, id DESC LIMIT :limit");
   begin
      Result.Count := 0;
      Ada_Sqlite3.Bind_Int (Query, ":limit", Projects.Recent_Count);
      while Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW loop
         pragma Assert (Result.Count < Projects.Recent_Count);
         Result.Count := Result.Count + 1;
         Result.Items (Result.Count) := Row (Query);
      end loop;
   end Recent;

end Repository.Project;
