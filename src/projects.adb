with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Unchecked_Deallocation;

package body Projects is

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
     "COALESCE(nullif(:time, -1), CAST(strftime('%s', 'now') AS INTEGER))";
   --  A time bound to :time, or the current one if it is Now.

   procedure Free is new Ada.Unchecked_Deallocation
     (Ada_Sqlite3.Database, Database_Access);

   function Default_Path return String is
      use Ada.Environment_Variables;
      Config : constant String :=
        (if Exists ("XDG_CONFIG_HOME") and then Value ("XDG_CONFIG_HOME") /= ""
         then Value ("XDG_CONFIG_HOME")
         elsif Exists ("HOME") and then Value ("HOME") /= ""
         then Value ("HOME") & "/.config"
         else ".");
   begin
      return Config & "/bonxie/projects.db";
   end Default_Path;

   function Is_Open (Item : Store) return Boolean is
     (Item.Base /= null and then Ada_Sqlite3.Is_Open (Item.Base.all));

   function Folder (Item : Store; Key : Id) return String is
     (Paths.To_String (Item.Root) & "/"
      & Ada.Strings.Fixed.Trim (Key'Image, Ada.Strings.Both));

   function Connection
     (Item : Store) return not null access Ada_Sqlite3.Database is
     (Item.Base);

   procedure Open (Item : in out Store; Path : String := Default_Path) is
   begin
      if Path /= Memory then
         Ada.Directories.Create_Path
           (Ada.Directories.Containing_Directory (Path));
         Item.Root :=
           Paths.To_Bounded_String
             (Ada.Directories.Containing_Directory (Path), Ada.Strings.Error);
      else
         Item.Root :=
           Paths.To_Bounded_String
             ((if Ada.Environment_Variables.Exists ("TMPDIR")
                 and then Ada.Environment_Variables.Value ("TMPDIR") /= ""
               then Ada.Strings.Fixed.Trim
                      (Ada.Environment_Variables.Value ("TMPDIR"),
                       Ada.Strings.Right)
               else "/tmp")
              & "/bonxie-memory",
              Ada.Strings.Right);
      end if;
      Item.Base := new Ada_Sqlite3.Database'(Ada_Sqlite3.Open (Path));
      Ada_Sqlite3.Execute (Item.Base.all, "PRAGMA foreign_keys = ON");
      Ada_Sqlite3.Execute (Item.Base.all, Schema);
      Ada_Sqlite3.Execute (Item.Base.all, Index);
   end Open;

   function Create
     (Item        : in out Store;
      Title       : String;
      Description : String := "";
      Time        : Seconds := Now) return Id
   is
      Insert : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (Item.Base.all,
           "INSERT INTO projects (title, description, created_at, updated_at)"
           & " VALUES (:title, :description, " & Clock & ", " & Clock & ")");
   begin
      Ada_Sqlite3.Bind_Text (Insert, ":title", Title);
      Ada_Sqlite3.Bind_Text (Insert, ":description", Description);
      Ada_Sqlite3.Bind_Int64 (Insert, ":time", Time);
      Ada_Sqlite3.Step (Insert);
      return Id (Ada_Sqlite3.Last_Insert_Row_ID (Item.Base.all));
   end Create;

   procedure Touch (Item : in out Store; Key : Id; Time : Seconds := Now) is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (Item.Base.all,
           "UPDATE projects SET updated_at = " & Clock & " WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int64 (Update, ":time", Time);
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Update);
   end Touch;

   procedure Find
     (Item : Store; Key : Id; Found : out Boolean; Result : out Project)
   is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (Item.Base.all,
           "SELECT id, title, description, created_at, updated_at "
           & "FROM projects WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Int64 (Query, ":id", Long_Integer (Key));
      Found := Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW;
      if Found then
         Result :=
           (Key         => Id (Ada_Sqlite3.Column_Int64 (Query, 0)),
            Title       => Titles.To_Bounded_String
              (Ada_Sqlite3.Column_Text (Query, 1), Ada.Strings.Right),
            Description => Descriptions.To_Bounded_String
              (Ada_Sqlite3.Column_Text (Query, 2), Ada.Strings.Right),
            Created_At  => Ada_Sqlite3.Column_Int64 (Query, 3),
            Updated_At  => Ada_Sqlite3.Column_Int64 (Query, 4));
      end if;
   end Find;

   procedure Rename
     (Item  : in out Store;
      Key   : Id;
      Title : String;
      Time  : Seconds := Now)
   is
      Update : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (Item.Base.all,
           "UPDATE projects SET title = :title, updated_at = " & Clock
           & " WHERE id = :id");
   begin
      Ada_Sqlite3.Bind_Text (Update, ":title", Title);
      Ada_Sqlite3.Bind_Int64 (Update, ":time", Time);
      Ada_Sqlite3.Bind_Int64 (Update, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Update);
   end Rename;

   procedure Delete (Item : in out Store; Key : Id) is
      Remove : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (Item.Base.all, "DELETE FROM projects WHERE id = :id");
   begin
      --  What refers to the project goes with it (foreign keys).
      Ada_Sqlite3.Bind_Int64 (Remove, ":id", Long_Integer (Key));
      Ada_Sqlite3.Step (Remove);
      declare
         Files : constant String := Folder (Item, Key);
      begin
         if Ada.Directories.Exists (Files) then
            Ada.Directories.Delete_Tree (Files);
         end if;
      end;
   end Delete;

   procedure Recent (Item : Store; Result : out Recent_List) is
      Query : Ada_Sqlite3.Statement :=
        Ada_Sqlite3.Prepare
          (Item.Base.all,
           "SELECT id, title, description, created_at, updated_at "
           & "FROM projects ORDER BY updated_at DESC, id DESC LIMIT :limit");
   begin
      Result.Count := 0;
      Ada_Sqlite3.Bind_Int (Query, ":limit", Recent_Count);
      while Ada_Sqlite3.Step (Query) = Ada_Sqlite3.ROW loop
         pragma Assert (Result.Count < Recent_Count);
         Result.Count := Result.Count + 1;
         Result.Items (Result.Count) :=
           (Key         => Id (Ada_Sqlite3.Column_Int64 (Query, 0)),
            Title       => Titles.To_Bounded_String
              (Ada_Sqlite3.Column_Text (Query, 1), Ada.Strings.Right),
            Description => Descriptions.To_Bounded_String
              (Ada_Sqlite3.Column_Text (Query, 2), Ada.Strings.Right),
            Created_At  => Ada_Sqlite3.Column_Int64 (Query, 3),
            Updated_At  => Ada_Sqlite3.Column_Int64 (Query, 4));
      end loop;
   end Recent;

   overriding procedure Finalize (Item : in out Store) is
   begin
      --  Closes the database.
      Free (Item.Base);
   end Finalize;

end Projects;
