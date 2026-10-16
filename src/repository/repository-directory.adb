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

   type Natural_Array is array (Positive range <>) of Natural;

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

   function Key_Of (Position : Natural) return Natural is
     (if Position = 0 then Natural'Last else Position);
   --  Never put comes after what was.

   procedure Order_Sections
     (List : in out Items.Directories.Directory_List;
      Rank : in out Natural_Array)
   is
      --  The sections' folders take the places they had among the rest, but
      --  in the order of the outline: a section is moved there, not here.
      Held   : Natural := 0;
      Places : array (1 .. List.Count) of Natural;
      Which  : array (1 .. List.Count) of Positive;
   begin
      for Each in 1 .. List.Count loop
         if List.Directories (Each).Section /= 0 then
            Held := Held + 1;
            Places (Held) := List.Directories (Each).Position;
            Which (Held) := Each;
         end if;
      end loop;
      --  Places are in order already; those that follow in the outline's.
      for Each in 2 .. Held loop
         declare
            Mover : constant Positive := Which (Each);
            Back  : Natural := Each - 1;
         begin
            while Back >= 1 and then Rank (Which (Back)) > Rank (Mover) loop
               Which (Back + 1) := Which (Back);
               Back := Back - 1;
            end loop;
            Which (Back + 1) := Mover;
         end;
      end loop;
      for Each in 1 .. Held loop
         List.Directories (Which (Each)).Position := Places (Each);
      end loop;
      --  And all in their places.
      for Each in 2 .. List.Count loop
         declare
            Mover : constant Items.Directories.Directory := List.Directories (Each);
            Mover_Rank : constant Natural := Rank (Each);
            Back  : Natural := Each - 1;
         begin
            --  Not yet put, sections come in the order of the outline.
            while Back >= 1
              and then (Key_Of (List.Directories (Back).Position) > Key_Of (Mover.Position)
                        or else (Key_Of (List.Directories (Back).Position) = Key_Of (Mover.Position)
                                 and then List.Directories (Back).Section /= 0
                                 and then Mover.Section /= 0
                                 and then Rank (Back) > Mover_Rank))
            loop
               List.Directories (Back + 1) := List.Directories (Back);
               Rank (Back + 1) := Rank (Back);
               Back := Back - 1;
            end loop;
            List.Directories (Back + 1) := Mover;
            Rank (Back + 1) := Mover_Rank;
         end;
      end loop;
   end Order_Sections;

   procedure Load
     (Store   : Projects.Store;
      Project : Projects.Id;
      Result  : out Items.Directories.Directory_List)
   is
      Make  : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "INSERT INTO directories (project_id, title, section_id) "
           & "SELECT project_id, title, id FROM sections WHERE project_id = :project "
           & "AND id NOT IN (SELECT section_id FROM directories WHERE section_id IS NOT NULL)");
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "SELECT d.id, COALESCE(s.title, d.title), d.position, COALESCE(d.section_id, 0), "
           & "COALESCE(s.colour, 0), COALESCE(s.position, 0) "
           & "FROM directories d LEFT JOIN sections s ON s.id = d.section_id "
           & "WHERE d.project_id = :project "
           & "ORDER BY d.position = 0, d.position, d.id LIMIT :limit");
      Rank : Natural_Array (1 .. Items.Directories.Max_Directories) := [others => 0];
      --  Of a section's folder: where the section is in the outline.
   begin
      --  Every section has a folder.
      Ada_Sqlite3.Bind_Int64 (Make, ":project", Long_Integer (Project));
      Ada_Sqlite3.Step (Make);
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
            Position => Natural'Max (0, Ada_Sqlite3.Column_Int (Query, 2)),
            Section => Ada_Sqlite3.Column_Int64 (Query, 3),
            Colour => Natural'Max (0, Ada_Sqlite3.Column_Int (Query, 4)));
         Rank (Result.Count) := Natural'Max (0, Ada_Sqlite3.Column_Int (Query, 5));
      end loop;
      Order_Sections (Result, Rank);
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
