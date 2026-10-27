with Projects;

--  The tables of the items, and the links, directories, words and marks
--  that go with them.

package Items.Schema is

   procedure Prepare (Store : in out Projects.Store)
   with Pre => Projects.Is_Open (Store);
   --  Make the tables, if there are none, and bring those made by an
   --  earlier version up to date: once, after the store is opened.

end Items.Schema;
