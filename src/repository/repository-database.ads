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

end Repository.Database;
