with Ada_Sqlite3;
with Projects;

--  The connection the items' tables are reached by: the projects'.
private package Items.Database is

   function DB (Store : Projects.Store)
      return not null access Ada_Sqlite3.Database is
     (Projects.Connection (Store));

end Items.Database;
