with Ada.Strings;
with Ada.Strings.Fixed;
with Ada_Sqlite3;
with Texts.Documents;
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
      Housed   : Boolean;
   begin
      Ada_Sqlite3.Execute (DB (Store).all, Schema);
      Coloured := Has_Column (Store, "sections", "colour");
      Housed := Has_Column (Store, "directories", "section_id");
      --  Those below were added to the tables after they were first made.
      Add_Column (Store, "sections", "colour", "INTEGER NOT NULL DEFAULT 0");
      Add_Column (Store, "sections", "notes", "TEXT NOT NULL DEFAULT ''");
      Add_Column (Store, "items", "section_id", "INTEGER REFERENCES sections (id) ON DELETE SET NULL");
      Add_Column (Store, "directories", "section_id", "INTEGER REFERENCES sections (id) ON DELETE CASCADE");
      if not Coloured then
         --  Those made before: one colour after another, in the order made.
         Ada_Sqlite3.Execute
           (DB (Store).all,
            "UPDATE sections SET colour = (SELECT COUNT(*) FROM sections other "
            & "WHERE other.project_id = sections.project_id AND other.id < sections.id) % "
            & Ada.Strings.Fixed.Trim (Palette'Image, Ada.Strings.Left));
      end if;
      if not Housed then
         --  An item was of a section by a column of its own, before the
         --  section had a folder for its items: put it in the folder.
         Ada_Sqlite3.Execute
           (DB (Store).all,
            "INSERT INTO directories (project_id, title, section_id) "
            & "SELECT project_id, title, id FROM sections");
         Ada_Sqlite3.Execute
           (DB (Store).all,
            "UPDATE items SET directory_id = (SELECT directories.id FROM directories "
            & "WHERE directories.section_id = items.section_id) "
            & "WHERE section_id IS NOT NULL");
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
           "SELECT id, title, colour, notes FROM sections WHERE project_id = :project "
           & "ORDER BY position, id");
   begin
      Result.Clear;
      Ada_Sqlite3.Bind_Int64 (Query, ":project", Long_Integer (Project));
      while Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW loop
         Result.Append
           ((Key   => Projects.Sections.Section_Id (Ada_Sqlite3.Column_Int64 (Query, 0)),
            Title => Projects.Sections.Title_Texts.To_Text
              (Ada_Sqlite3.Column_Text (Query, 1)),
            Colour => Projects.Sections.Colour_Value
              (Integer'Max (0, Ada_Sqlite3.Column_Int (Query, 2))),
            Notes => Projects.Sections.Note_Texts.To_Text
              (Texts.Documents.Plain_Stored (Ada_Sqlite3.Column_Text (Query, 3))),
            Open  => False));
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
         declare
            Value : constant Natural := Natural'Max (0, Ada_Sqlite3.Column_Int (Query, 0));
         begin
            if Value < Palette then
               Used (Value) := Ada_Sqlite3.Column_Int (Query, 1);
            end if;
         end;
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

   procedure Set_Colour
     (Store : in out Projects.Store; Key : Projects.Sections.Section_Id;
      Colour : Projects.Sections.Colour_Value)
   is
      Query : Ada_Sqlite3.Statement := Ada_Sqlite3.Prepare
        (DB (Store).all, "UPDATE sections SET colour = :colour WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int (Query, ":colour", Colour);
      Ada_Sqlite3.Bind_Int64 (Query, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Query);
   end Set_Colour;

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

   function Stored_Notes (Store : Projects.Store; Key : Projects.Sections.Section_Id) return String is
      Query : Ada_Sqlite3.Statement := Ada_Sqlite3.Prepare
        (DB (Store).all, "SELECT notes FROM sections WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int64 (Query, ":id", Long_Integer (Key));
      if Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW then
         return Ada_Sqlite3.Column_Text (Query, 0);
      end if;
      return "";
   end Stored_Notes;

   procedure Set_Notes
     (Store : in out Projects.Store;
      Key   : Projects.Sections.Section_Id;
      Notes : String)
   is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all, "UPDATE sections SET notes = :notes WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Text (Update, ":notes", Notes);
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Update);
   end Set_Notes;

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
      Make   : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "INSERT INTO directories (project_id, title, section_id) "
           & "SELECT project_id, title, id FROM sections WHERE id = :section "
           & "AND id NOT IN (SELECT section_id FROM directories WHERE section_id IS NOT NULL)");
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "UPDATE items SET directory_id = (SELECT id FROM directories WHERE section_id = :section) "
           & "WHERE id = :id");
   begin
      --  In the section's folder, which it is given if it has none yet.
      Ada_Sqlite3.Bind_Int64 (Make, ":section", Long_Integer (Key));
      Ada_Sqlite3.Step (Make);
      Ada_Sqlite3.Bind_Int64 (Update, ":section", Long_Integer (Key));
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Item);
      Ada_Sqlite3.Step (Update);
   end Link;

   Section_Tree : constant String :=
     "WITH RECURSIVE membership(id, section_id) AS ("
     & "SELECT id, section_id FROM directories WHERE section_id IS NOT NULL UNION ALL "
     & "SELECT d.id, m.section_id FROM directories d JOIN membership m ON d.parent_id = m.id) ";

   procedure Unlink (Store : in out Projects.Store; Item : Long_Integer) is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           Section_Tree & "UPDATE items SET directory_id = 0 WHERE id = :id AND directory_id IN "
           & "(SELECT id FROM membership)");
   begin
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Item);
      Ada_Sqlite3.Step (Update);
   end Unlink;

   procedure Load_Links
     (Store   : Projects.Store;
      Project : Projects.Id;
      Result  : out Projects.Sections.Link_List)
   is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           Section_Tree & "SELECT items.id, m.section_id FROM items JOIN membership m "
           & "ON items.directory_id = m.id WHERE items.project_id = :project ORDER BY items.id");
   begin
      Result.Clear;
      Ada_Sqlite3.Bind_Int64 (Query, ":project", Long_Integer (Project));
      while Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW loop
         Result.Append
           ((Item    => Ada_Sqlite3.Column_Int64 (Query, 0),
            Section => Projects.Sections.Section_Id (Ada_Sqlite3.Column_Int64 (Query, 1))));
      end loop;
   end Load_Links;

   procedure Delete
     (Store : in out Projects.Store; Key : Projects.Sections.Section_Id)
   is
      Remove : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all, "DELETE FROM sections WHERE id = :id");
      Free   : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (DB (Store).all,
           "UPDATE items SET directory_id = 0 WHERE directory_id IN "
           & "(SELECT id FROM directories WHERE section_id = :id)");
   begin
      --  Its documents are of none, and not of a folder that may be made
      --  again under the same number.
      Ada_Sqlite3.Bind_Int64 (Free, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Free);
      Ada_Sqlite3.Bind_Int64 (Remove, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Remove);
   end Delete;

end Repository.Section;
