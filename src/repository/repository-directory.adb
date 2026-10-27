with Growing;
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

   package Natural_Lists is new Growing (Natural);
   subtype Natural_Array is Natural_Lists.List;

   procedure Prepare (Store : in out Projects.Store) is
   begin
      Ada_Sqlite3.Execute (DB (Store).all, Schema);
      Add_Column (Store, "directories", "position", "INTEGER NOT NULL DEFAULT 0");
      Add_Column (Store, "directories", "parent_id", "INTEGER REFERENCES directories (id) ON DELETE SET NULL");
   end Prepare;

   function Insert (Store : in out Projects.Store; Project : Projects.Id; Title : String) return Items.Id is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all, "INSERT INTO directories (project_id, title) " & "VALUES (:project, :title)");
   begin
      Ada_Sqlite3.Bind_Int64 (Query, ":project", Long_Integer (Project));
      Ada_Sqlite3.Bind_Text (Query, ":title", Title);
      Ada_Sqlite3.Step (Query);
      return Items.Id (Ada_Sqlite3.Last_Insert_Row_ID (DB (Store).all));
   end Insert;

   function Key_Of (Position : Natural) return Natural
   is (if Position = 0 then Natural'Last else Position);
   --  Never put comes after what was.

   procedure Order_Sections (List : in out Items.Directories.Directory_List; Rank : in out Natural_Array) is
      --  The sections' folders take the places they had among the rest, but
      --  in the order of the outline: a section is moved there, not here.
      Held   : Natural := 0;
      Places : array (1 .. List.Count) of Natural;
      Which  : array (1 .. List.Count) of Positive;
   begin
      for Each in 1 .. List.Count loop
         if List (Each).Section /= 0 then
            Held := Held + 1;
            Places (Held) := List (Each).Position;
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
         List (Which (Each)).Position := Places (Each);
      end loop;
      --  And all in their places.
      for Each in 2 .. List.Count loop
         declare
            Mover      : constant Items.Directories.Directory := List (Each);
            Mover_Rank : constant Natural := Rank (Each);
            Back       : Natural := Each - 1;
         begin
            --  Not yet put, sections come in the order of the outline.
            while Back >= 1
              and then (Key_Of (List (Back).Position) > Key_Of (Mover.Position)
                        or else (Key_Of (List (Back).Position) = Key_Of (Mover.Position)
                                 and then List (Back).Section /= 0
                                 and then Mover.Section /= 0
                                 and then Rank (Back) > Mover_Rank))
            loop
               List (Back + 1) := List (Back);
               Rank (Back + 1) := Rank (Back);
               Back := Back - 1;
            end loop;
            List (Back + 1) := Mover;
            Rank (Back + 1) := Mover_Rank;
         end;
      end loop;
   end Order_Sections;

   procedure Load (Store : Projects.Store; Project : Projects.Id; Result : out Items.Directories.Directory_List) is
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
           & "COALESCE(s.colour, 0), COALESCE(s.position, 0), COALESCE(d.parent_id, 0) "
           & "FROM directories d LEFT JOIN sections s ON s.id = d.section_id "
           & "WHERE d.project_id = :project "
           & "ORDER BY d.position = 0, d.position, d.id");
      Rank  : Natural_Array;
      --  Of a section's folder: where the section is in the outline.
   begin
      --  Every section has a folder.
      Ada_Sqlite3.Bind_Int64 (Make, ":project", Long_Integer (Project));
      Ada_Sqlite3.Step (Make);
      Result.Clear;
      Ada_Sqlite3.Bind_Int64 (Query, ":project", Long_Integer (Project));
      while Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW loop
         Result.Append
           ((Key      => Items.Id (Ada_Sqlite3.Column_Int64 (Query, 0)),
             Title    => Projects.Titles.To_Text (Ada_Sqlite3.Column_Text (Query, 1)),
             Position => Natural'Max (0, Ada_Sqlite3.Column_Int (Query, 2)),
             Parent   => Items.Id (Ada_Sqlite3.Column_Int64 (Query, 6)),
             Section  => Ada_Sqlite3.Column_Int64 (Query, 3),
             Colour   => Natural'Max (0, Ada_Sqlite3.Column_Int (Query, 4))));
         Rank.Append (Natural'Max (0, Ada_Sqlite3.Column_Int (Query, 5)));
      end loop;
      Order_Sections (Result, Rank);
   end Load;

   function Count (Store : Projects.Store; Project : Projects.Id) return Natural is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare (DB (Store).all, "SELECT count(*) FROM directories WHERE project_id = :project");
   begin
      Ada_Sqlite3.Bind_Int64 (Query, ":project", Long_Integer (Project));
      return (if Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW then Ada_Sqlite3.Column_Int (Query, 0) else 0);
   end Count;

   procedure Rename (Store : in out Projects.Store; Key : Items.Id; Title : String) is
   begin
      Set_Text (Store, "directories", "title", Long_Integer (Key), Title);
   end Rename;

   procedure Set_Position (Store : in out Projects.Store; Key : Items.Id; Position : Positive) is
   begin
      Set_Int (Store, "directories", "position", Long_Integer (Key), Position);
   end Set_Position;

   procedure Set_Parent (Store : in out Projects.Store; Key, Parent : Items.Id) is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "WITH RECURSIVE descendants(id) AS (SELECT :id UNION ALL "
           & "SELECT d.id FROM directories d JOIN descendants c ON d.parent_id = c.id) "
           & "UPDATE directories SET parent_id = NULLIF(:parent, 0) WHERE id = :id AND section_id IS NULL "
           & "AND (:parent = 0 OR EXISTS (SELECT 1 FROM directories p WHERE p.id = :parent "
           & "AND p.project_id = directories.project_id AND p.id NOT IN (SELECT id FROM descendants)))");
   begin
      Ada_Sqlite3.Bind_Int64 (Update, ":parent", Long_Integer (Parent));
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Update);
      pragma Assert (Ada_Sqlite3.Changes (DB (Store).all) = 1);
   end Set_Parent;

   procedure Delete (Store : in out Projects.Store; Key : Items.Id) is
   begin
      Delete_Where (Store, "directories", "id", Long_Integer (Key));
   end Delete;

end Repository.Directory;
