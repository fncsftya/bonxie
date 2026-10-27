with Items.Directories;
with Projects;

--  The table of directories: the folders of the writing view.

package Repository.Directory is

   procedure Prepare (Store : in out Projects.Store)
   with Pre => Projects.Is_Open (Store);
   --  Make the table, if there is none, and bring one made by an earlier
   --  version up to date.

   function Insert (Store : in out Projects.Store; Project : Projects.Id; Title : String) return Items.Id
   with Pre => Projects.Is_Open (Store);

   procedure Load (Store : Projects.Store; Project : Projects.Id; Result : out Items.Directories.Directory_List)
   with Pre => Projects.Is_Open (Store);
   --  By position, those never put after, the earliest made first.

   function Count (Store : Projects.Store; Project : Projects.Id) return Natural
   with Pre => Projects.Is_Open (Store);

   procedure Rename (Store : in out Projects.Store; Key : Items.Id; Title : String)
   with Pre => Projects.Is_Open (Store);

   procedure Set_Position (Store : in out Projects.Store; Key : Items.Id; Position : Positive)
   with Pre => Projects.Is_Open (Store);

   procedure Set_Parent (Store : in out Projects.Store; Key, Parent : Items.Id)
   with Pre => Projects.Is_Open (Store);
   --  Parent must be in the same project, outside Key's subtree, or 0; Key an ordinary folder.

   procedure Delete (Store : in out Projects.Store; Key : Items.Id)
   with Pre => Projects.Is_Open (Store);
   --  The row only: see Repository.Item.Free_Directory.

end Repository.Directory;
