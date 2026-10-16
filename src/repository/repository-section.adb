with Ada.Strings;
with Ada.Strings.Fixed;
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

   Palette : constant := Projects.Sections.Palette_Size;

   procedure Prepare (Store : in out Projects.Store) is
      Coloured : Boolean;
   begin
      Ada_Sqlite3.Execute (DB (Store).all, Schema);
      Coloured := Has_Column (Store, "sections", "colour");
      --  Those below were added to the table after it was first made.
      Add_Column (Store, "sections", "colour", "INTEGER NOT NULL DEFAULT 0");
      Add_Column (Store, "sections", "item_id", "INTEGER REFERENCES items (id) ON DELETE SET NULL");
      if not Coloured then
         --  Those made before: one colour after another, in the order made.
         Ada_Sqlite3.Execute
           (DB (Store).all,
            "UPDATE sections SET colour = (SELECT COUNT(*) FROM sections other "
            & "WHERE other.project_id = sections.project_id AND other.id < sections.id) % "
            & Ada.Strings.Fixed.Trim (Palette'Image, Ada.Strings.Left));
      end if;
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
           "SELECT id, title, colour, COALESCE(item_id, 0) FROM sections WHERE project_id = :project "
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
              (Ada_Sqlite3.Column_Text (Query, 1), Ada.Strings.Right),
            Colour => Projects.Sections.Colour_Index
              (Integer'Max (0, Ada_Sqlite3.Column_Int (Query, 2)) mod Palette),
            Linked => Ada_Sqlite3.Column_Int64 (Query, 3));
      end loop;
   end Load;

   function Least_Used
     (Store : Projects.Store; Project : Projects.Id) return Projects.Sections.Colour_Index
   is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "SELECT colour, COUNT(*) FROM sections WHERE project_id = :project GROUP BY colour");
      Used  : array (Projects.Sections.Colour_Index) of Natural := [others => 0];
      Best  : Projects.Sections.Colour_Index := 0;
   begin
      Ada_Sqlite3.Bind_Int64 (Query, ":project", Long_Integer (Project));
      while Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW loop
         Used (Projects.Sections.Colour_Index (Ada_Sqlite3.Column_Int (Query, 0) mod Palette)) :=
           Ada_Sqlite3.Column_Int (Query, 1);
      end loop;
      for Each in Used'Range loop
         if Used (Each) < Used (Best) then
            Best := Each;
         end if;
      end loop;
      return Best;
   end Least_Used;

   function Insert
     (Store   : in out Projects.Store;
      Project : Projects.Id;
      Title   : String) return Projects.Sections.Section_Id
   is
      Colour : constant Projects.Sections.Colour_Index := Least_Used (Store, Project);
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "INSERT INTO sections (project_id, position, title, colour) VALUES "
           & "(:project, (SELECT COALESCE(MAX(position), 0) + 1 "
           & "FROM sections WHERE project_id = :project), :title, :colour)");
   begin
      Ada_Sqlite3.Bind_Int64 (Query, ":project", Long_Integer (Project));
      Ada_Sqlite3.Bind_Text (Query, ":title", Title);
      Ada_Sqlite3.Bind_Int (Query, ":colour", Colour);
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

   procedure Link
     (Store : in out Projects.Store;
      Key   : Projects.Sections.Section_Id;
      Item  : Long_Integer)
   is
      Clear : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all, "UPDATE sections SET item_id = NULL WHERE item_id = :item OR id = :id");
      Set   : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all, "UPDATE sections SET item_id = :item WHERE id = :id");
   begin
      Ada_Sqlite3.Execute (DB (Store).all, "BEGIN");
      Ada_Sqlite3.Bind_Int64 (Clear, ":item", Item);
      Ada_Sqlite3.Bind_Int64 (Clear, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Clear);
      Ada_Sqlite3.Bind_Int64 (Set, ":item", Item);
      Ada_Sqlite3.Bind_Int64 (Set, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Set);
      Ada_Sqlite3.Execute (DB (Store).all, "COMMIT");
   end Link;

   procedure Unlink
     (Store : in out Projects.Store; Key : Projects.Sections.Section_Id)
   is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all, "UPDATE sections SET item_id = NULL WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Update);
   end Unlink;

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
