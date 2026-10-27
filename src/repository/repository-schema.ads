with Projects;

--  The tables of the items, and the links, directories, words and marks
--  that go with them.

package Repository.Schema is

   procedure Prepare (Store : in out Projects.Store)
   with Pre => Projects.Is_Open (Store);
   --  Make the tables, if there are none, and bring those made by an
   --  earlier version up to date: once, after the store is opened (which
   --  has made the projects', see Repository.Project.Prepare).

end Repository.Schema;
