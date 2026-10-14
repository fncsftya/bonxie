with Ada.Strings;
with Ada_Sqlite3;
with Repository.Database; use Repository.Database;

package body Repository.Directory is

   use type Ada_Sqlite3.Result_Code;

   Schema : constant String :=
     "CREATE TABLE IF NOT EXISTS directories ("
     & "id INTEGER PRIMARY KEY, "
     & "project_id INTEGER NOT NULL "
     & "REFERENCES projects (id) ON DELETE CASCADE, "
     & "title TEXT NOT NULL, "
     & "position INTEGER NOT NULL DEFAULT 0)";

   procedure Prepare (Store : in out Projects.Store) is
   begin
      Ada_Sqlite3.Execute (DB (Store).all, Schema);
      Add_Column
        (Store, "directories", "position", "INTEGER NOT NULL DEFAULT 0");
   end Prepare;

   function Insert
     (Store   : in out Projects.Store;
      Project : Projects.Id;
      Title   : String) return Items.Id
   is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "INSERT INTO directories (project_id, title) "
           & "VALUES (:project, :title)");
   begin
      Ada_Sqlite3.Bind_Int64 (Query, ":project", Long_Integer (Project));
      Ada_Sqlite3.Bind_Text (Query, ":title", Title);
      Ada_Sqlite3.Step (Query);
      return Items.Id (Ada_Sqlite3.Last_Insert_Row_ID (DB (Store).all));
   end Insert;

   procedure Load
     (Store   : Projects.Store;
      Project : Projects.Id;
      Result  : out Items.Directories.Directory_List)
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
      Ada_Sqlite3.Bind_Int (Query, ":limit", Items.Directories.Max_Directories);
      while Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW loop
         pragma Assert (Result.Count < Items.Directories.Max_Directories);
         Result.Count := Result.Count + 1;
         Result.Directories (Result.Count) :=
           (Key   => Items.Id (Ada_Sqlite3.Column_Int64 (Query, 0)),
            Title => Projects.Titles.To_Bounded_String
              (Ada_Sqlite3.Column_Text (Query, 1), Ada.Strings.Right),
            Position => Natural'Max (0, Ada_Sqlite3.Column_Int (Query, 2)));
      end loop;
   end Load;

   function Count
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
   end Count;

   procedure Rename
     (Store : in out Projects.Store; Key : Items.Id; Title : String)
   is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "UPDATE directories SET title = :title WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Text (Update, ":title", Title);
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Update);
   end Rename;

   procedure Set_Position
     (Store : in out Projects.Store; Key : Items.Id; Position : Positive)
   is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "UPDATE directories SET position = :position WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int (Update, ":position", Position);
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Update);
   end Set_Position;

   procedure Delete (Store : in out Projects.Store; Key : Items.Id) is
      Remove : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all, "DELETE FROM directories WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int64 (Remove, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Remove);
   end Delete;

end Repository.Directory;
