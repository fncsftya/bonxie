with Projects;

--  The table of projects, and the view of the canvas kept with each.
package Repository.Project is

   procedure Prepare (Store : in out Projects.Store)
     with Pre => Projects.Is_Open (Store);
   --  Make the table, if there is none, and bring one made by an earlier
   --  version up to date: once, after the database is opened.

   function Insert
     (Store       : in out Projects.Store;
      Title       : String;
      Description : String;
      Time        : Projects.Seconds) return Projects.Id
     with Pre => Projects.Is_Open (Store) and then Time >= Projects.Now;
   --  Add a project made and updated at Time.

   procedure Touch
     (Store : in out Projects.Store;
      Key   : Projects.Id;
      Time  : Projects.Seconds)
     with Pre => Projects.Is_Open (Store) and then Time >= Projects.Now;

   procedure Rename
     (Store : in out Projects.Store;
      Key   : Projects.Id;
      Title : String;
      Time  : Projects.Seconds)
     with Pre => Projects.Is_Open (Store) and then Time >= Projects.Now;

   procedure Set_View
     (Store : in out Projects.Store;
      Key   : Projects.Id;
      Zoom, Centre_X, Centre_Y : Float)
     with Pre => Projects.Is_Open (Store);

   procedure Get_View
     (Store  : Projects.Store;
      Key    : Projects.Id;
      Found  : out Boolean;
      Zoom, Centre_X, Centre_Y : out Float)
     with Pre => Projects.Is_Open (Store);

   procedure Find
     (Store  : Projects.Store;
      Key    : Projects.Id;
      Found  : out Boolean;
      Result : out Projects.Project)
     with Pre => Projects.Is_Open (Store);

   procedure Delete (Store : in out Projects.Store; Key : Projects.Id)
     with Pre => Projects.Is_Open (Store);
   --  The row only: what refers to the project goes with it (foreign
   --  keys).

   procedure Recent
     (Store : Projects.Store; Result : out Projects.Recent_List)
     with Pre => Projects.Is_Open (Store);

end Repository.Project;
