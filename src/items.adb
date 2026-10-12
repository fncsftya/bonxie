with Ada.Directories;
with Ada.Strings;
with Ada.Strings.Fixed;
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
     & "captured_at INTEGER NOT NULL DEFAULT 0)";

   Has_Kind : constant String :=
     "SELECT count(*) FROM pragma_table_info('items') WHERE name = 'kind'";

   Add_Kind : constant String :=
     "ALTER TABLE items ADD COLUMN kind INTEGER NOT NULL DEFAULT 0";

   Add_Captured : constant String :=
     "ALTER TABLE items ADD COLUMN captured_at INTEGER NOT NULL DEFAULT 0";

   Index : constant String :=
     "CREATE INDEX IF NOT EXISTS items_project ON items (project_id, id)";

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

   procedure Prepare (Store : in out Projects.Store) is
   begin
      Ada_Sqlite3.Execute (DB (Store).all, Schema);
      if Lacks_Kind (Store) then
         Ada_Sqlite3.Execute (DB (Store).all, Add_Kind);
         Ada_Sqlite3.Execute (DB (Store).all, Add_Captured);
      end if;
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
           "SELECT id, title, x, y, w, h, state, kind, captured_at FROM items "
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
            Captured_At => Ada_Sqlite3.Column_Int64 (Query, 8));
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
   end Set_Captured;

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
