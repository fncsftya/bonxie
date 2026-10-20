with Ada.Finalization;
with Ada_Sqlite3;
with Long_Texts;

--  The projects bonxie keeps, in a SQLite database on disk.
package Projects is

   package Titles renames Long_Texts;
   package Descriptions renames Long_Texts;

   type Id is new Long_Integer;

   subtype Seconds is Long_Integer;
   --  Since 1970-01-01 00:00:00 UTC, as SQLite's unixepoch.

   Now : constant Seconds := -1;
   --  For a time: the time of the call.

   type Project is record
      Key         : Id := 0;
      Title       : Titles.Text := Titles.Null_Text;
      Description : Descriptions.Text :=
        Descriptions.Null_Text;
      Created_At  : Seconds := 0;
      Updated_At  : Seconds := 0;
   end record;

   Recent_Count : constant := 5;
   --  How many Recent gives, at most.

   type Project_Array is array (Positive range <>) of Project;

   type Recent_List is record
      Count : Natural range 0 .. Recent_Count := 0;
      Items : Project_Array (1 .. Recent_Count);
   end record;
   --  Items (1 .. Count) are the most recently updated first.

   Memory : constant String := ":memory:";
   --  A database that is lost when it is closed, for tests.

   function Default_Path return String;
   --  projects.db in bonxie's folder in the user's config folder:
   --  $XDG_CONFIG_HOME/bonxie, or ~/.config/bonxie without it. It does not
   --  make the folder: Open does.

   type Store is limited private;
   --  The projects in one database.

   procedure Open (Item : in out Store; Path : String := Default_Path)
     with Pre => not Is_Open (Item), Post => Is_Open (Item);
   --  Open the database at Path, making it, and the folder it is in, and
   --  the tables, if there are none. Memory for one that is not kept.

   function Is_Open (Item : Store) return Boolean;

   function Folder (Item : Store; Key : Id) return String
     with Pre => Is_Open (Item);
   --  Where the project's files are kept: its id, in the folder of the
   --  database (or, for Memory, in a folder in the system's temporary
   --  one). Open does not make it; Delete removes it.

   function Connection
     (Item : Store) return not null access Ada_Sqlite3.Database
     with Pre => Is_Open (Item);
   --  The open database, for the Repository to reach its tables by: no
   --  one else is to. Foreign keys are on: what refers to a project is
   --  removed with it.

   function Create
     (Item        : in out Store;
      Title       : String;
      Description : String := "";
      Time        : Seconds := Now) return Id
     with Pre => Is_Open (Item) and then Time >= Now;
   --  Add a project made and updated at Time.

   procedure Touch
     (Item : in out Store; Key : Id; Time : Seconds := Now)
     with Pre => Is_Open (Item) and then Time >= Now;
   --  Say the project was updated at Time.

   function Stored_Description (Item : Store; Key : Id) return String
     with Pre => Is_Open (Item);

   procedure Set_Description
     (Item : in out Store; Key : Id; Description : String)
     with Pre => Is_Open (Item);
   --  Keep the project's description. This is not an update of the project.

   procedure Set_Tab (Item : in out Store; Key : Id; To : Natural)
     with Pre => Is_Open (Item);
   --  Keep which view of the project was last shown, as the number of its
   --  tab, from 0. This is not an update of the project.

   function Tab (Item : Store; Key : Id) return Natural
     with Pre => Is_Open (Item);
   --  The view kept for the project; 0 if none has been.

   procedure Set_View
     (Item : in out Store; Key : Id; Zoom, Centre_X, Centre_Y : Float)
     with Pre => Is_Open (Item);
   --  Keep how the project's canvas is seen: its zoom, and the canvas
   --  point in the middle of the view. This is not an update of the
   --  project. Nothing is done if there is no such project.

   procedure Get_View
     (Item   : Store;
      Key    : Id;
      Found  : out Boolean;
      Zoom, Centre_X, Centre_Y : out Float)
     with Pre => Is_Open (Item);
   --  The view kept for the project; not Found if none has been.

   procedure Find
     (Item : Store; Key : Id; Found : out Boolean; Result : out Project)
     with Pre => Is_Open (Item);
   --  The project with the id, if there is one.

   procedure Rename
     (Item  : in out Store;
      Key   : Id;
      Title : String;
      Time  : Seconds := Now)
     with Pre => Is_Open (Item) and then Time >= Now;
   --  Give the project a new title, and say it was updated at Time. Nothing
   --  is done if there is no such project.

   procedure Delete (Item : in out Store; Key : Id)
     with Pre => Is_Open (Item);
   --  Remove the project from the database. Nothing is done if there is
   --  no such project. This is the one place a project is removed:
   --  whatever else belongs to it, such as its files (see Folder), is to
   --  go here too.

   procedure Recent (Item : Store; Result : out Recent_List)
     with Pre => Is_Open (Item);
   --  The Recent_Count projects most recently updated, latest first; the
   --  later made first among those updated at once.

private

   type Database_Access is access Ada_Sqlite3.Database;

   package Paths renames Long_Texts;

   type Store is new Ada.Finalization.Limited_Controlled with record
      Base : Database_Access;
      Root : Paths.Text;
      --  The folder the project folders are in.
      --  Database is limited and can only be made by Ada_Sqlite3.Open.
   end record;

   overriding procedure Finalize (Item : in out Store);

end Projects;
