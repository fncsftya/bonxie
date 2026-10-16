with Ada.Strings;
with Ada_Sqlite3;
with Repository.Database; use Repository.Database;

package body Repository.Section is

   use type Ada_Sqlite3.Result_Code;

   Schema : constant String :=
     "CREATE TABLE IF NOT EXISTS sections ("
     & "id INTEGER PRIMARY KEY, "
     & "project_id INTEGER NOT NULL "
     & "REFERENCES projects (id) ON DELETE CASCADE, "
     & "position INTEGER NOT NULL, "
     & "title TEXT NOT NULL)";

   Index : constant String :=
     "CREATE INDEX IF NOT EXISTS sections_order "
     & "ON sections (project_id, position)";

   procedure Prepare (Store : in out Projects.Store) is
   begin
      Ada_Sqlite3.Execute (DB (Store).all, Schema);
      Ada_Sqlite3.Execute (DB (Store).all, Index);
   end Prepare;

   procedure Load
     (Store   : Projects.Store;
      Project : Projects.Id;
      Result  : out Projects.Sections.Section_List)
   is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "SELECT id, title FROM sections WHERE project_id = :project "
           & "ORDER BY position, id LIMIT :limit");
   begin
      Result.Count := 0;
      Ada_Sqlite3.Bind_Int64 (Query, ":project", Long_Integer (Project));
      Ada_Sqlite3.Bind_Int (Query, ":limit", Projects.Sections.Max_Sections);
      while Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW loop
         Result.Count := Result.Count + 1;
         Result.Items (Result.Count) :=
           (Key   => Projects.Sections.Section_Id (Ada_Sqlite3.Column_Int64 (Query, 0)),
            Title => Projects.Sections.Title_Texts.To_Bounded_String
              (Ada_Sqlite3.Column_Text (Query, 1), Ada.Strings.Right));
      end loop;
   end Load;

   function Insert
     (Store   : in out Projects.Store;
      Project : Projects.Id;
      Title   : String) return Projects.Sections.Section_Id
   is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "INSERT INTO sections (project_id, position, title) VALUES "
           & "(:project, (SELECT COALESCE(MAX(position), 0) + 1 "
           & "FROM sections WHERE project_id = :project), :title)");
   begin
      Ada_Sqlite3.Bind_Int64 (Query, ":project", Long_Integer (Project));
      Ada_Sqlite3.Bind_Text (Query, ":title", Title);
      Ada_Sqlite3.Step (Query);
      return Projects.Sections.Section_Id
        (Ada_Sqlite3.Last_Insert_Row_ID (DB (Store).all));
   end Insert;

   procedure Rename
     (Store : in out Projects.Store;
      Key   : Projects.Sections.Section_Id;
      Title : String)
   is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all, "UPDATE sections SET title = :title WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Text (Update, ":title", Title);
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Update);
   end Rename;

   procedure Set_Order
     (Store   : in out Projects.Store;
      Project : Projects.Id;
      Order   : Projects.Sections.Key_Array)
   is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "UPDATE sections SET position = :position "
           & "WHERE id = :id AND project_id = :project");
      Place  : Natural := 0;
   begin
      Ada_Sqlite3.Execute (DB (Store).all, "BEGIN");
      for Each of Order loop
         Place := Place + 1;
         Ada_Sqlite3.Reset (Update);
         Ada_Sqlite3.Bind_Int (Update, ":position", Place);
         Ada_Sqlite3.Bind_Int64 (Update, ":id", Long_Integer (Each));
         Ada_Sqlite3.Bind_Int64 (Update, ":project", Long_Integer (Project));
         Ada_Sqlite3.Step (Update);
      end loop;
      Ada_Sqlite3.Execute (DB (Store).all, "COMMIT");
   end Set_Order;

   procedure Delete
     (Store : in out Projects.Store; Key : Projects.Sections.Section_Id)
   is
      Remove : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all, "DELETE FROM sections WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int64 (Remove, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Remove);
   end Delete;

end Repository.Section;
