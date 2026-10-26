with Ada_Sqlite3;
with Projects;

--  What the tables' modules have in common: the connection they are
--  reached by, which is the projects'.
private package Repository.Database is

   function DB (Store : Projects.Store)
      return not null access Ada_Sqlite3.Database is
     (Projects.Connection (Store));

   function Has_Column
     (Store : Projects.Store; Table, Name : String) return Boolean
     with Pre => Projects.Is_Open (Store);
   --  Whether the table has the column.

   procedure Add_Column
     (Store : Projects.Store; Table, Name, Definition : String)
     with Pre => Projects.Is_Open (Store);
   --  Add the column, as Definition says (its type and the rest), to the
   --  table if it was made without it.

   procedure Set_Int
     (Store : Projects.Store; Table, Column : String; Key : Long_Integer; Value : Integer)
     with Pre => Projects.Is_Open (Store);
   procedure Set_Int64
     (Store : Projects.Store; Table, Column : String; Key : Long_Integer; Value : Long_Integer)
     with Pre => Projects.Is_Open (Store);
   procedure Set_Double
     (Store : Projects.Store; Table, Column : String; Key : Long_Integer; Value : Float)
     with Pre => Projects.Is_Open (Store);
   procedure Set_Text
     (Store : Projects.Store; Table, Column : String; Key : Long_Integer; Value : String)
     with Pre => Projects.Is_Open (Store);
   --  Set the column of the table's row whose id is Key.

   procedure Delete_Where (Store : Projects.Store; Table, Column : String; Key : Long_Integer)
     with Pre => Projects.Is_Open (Store);
   --  Delete the table's rows whose column is Key; Column is "id" for the row itself.

end Repository.Database;
