with Ada.Strings;
with Ada_Sqlite3;
with Items.Database; use Items.Database;

package body Items.Directories is

   use type Ada_Sqlite3.Result_Code;

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

end Items.Directories;
