with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Unchecked_Deallocation;
with Repository.Project;

package body Projects is

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
      Repository.Project.Prepare (Item);
   end Open;

   procedure Set_View
     (Item : in out Store; Key : Id; Zoom, Centre_X, Centre_Y : Float) is
   begin
      Repository.Project.Set_View (Item, Key, Zoom, Centre_X, Centre_Y);
   end Set_View;

   procedure Get_View
     (Item   : Store;
      Key    : Id;
      Found  : out Boolean;
      Zoom, Centre_X, Centre_Y : out Float) is
   begin
      Repository.Project.Get_View (Item, Key, Found, Zoom, Centre_X, Centre_Y);
   end Get_View;

   function Create
     (Item        : in out Store;
      Title       : String;
      Description : String := "";
      Time        : Seconds := Now) return Id is
     (Repository.Project.Insert (Item, Title, Description, Time));

   procedure Touch (Item : in out Store; Key : Id; Time : Seconds := Now) is
   begin
      Repository.Project.Touch (Item, Key, Time);
   end Touch;

   procedure Find
     (Item : Store; Key : Id; Found : out Boolean; Result : out Project) is
   begin
      Repository.Project.Find (Item, Key, Found, Result);
   end Find;

   procedure Rename
     (Item  : in out Store;
      Key   : Id;
      Title : String;
      Time  : Seconds := Now) is
   begin
      Repository.Project.Rename (Item, Key, Title, Time);
   end Rename;

   procedure Delete (Item : in out Store; Key : Id) is
   begin
      --  What refers to the project goes with it (foreign keys).
      Repository.Project.Delete (Item, Key);
      declare
         Files : constant String := Folder (Item, Key);
      begin
         if Ada.Directories.Exists (Files) then
            Ada.Directories.Delete_Tree (Files);
         end if;
      end;
   end Delete;

   procedure Recent (Item : Store; Result : out Recent_List) is
   begin
      Repository.Project.Recent (Item, Result);
   end Recent;

   overriding procedure Finalize (Item : in out Store) is
   begin
      --  Closes the database.
      Free (Item.Base);
   end Finalize;

end Projects;
