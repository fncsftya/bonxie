with Growing;
with Projects;

--  The tree of the writing view: the items in folders, and the order of
--  its rows.
package Items.Directories is

   type Directory is record
      Key   : Id := 0;
      Position : Natural := 0;
      --  Where it was put in the tree, with the documents; 0 if never.
      Title : Projects.Titles.Text :=
        Projects.Titles.Null_Text;
      Section : Long_Integer := 0;
      --  The key of the outline's section that this is the folder of, 0
      --  for a folder that was made. A section's folder is made for it
      --  when it is first loaded; the documents in it are the section's
      --  own, and its title is the section's.
      Colour : Natural := 0;
      --  Of a section's: the colour it was given (Projects.Sections).
   end record;
   --  A folder of the writing view's documents.

   package Directory_Lists is new Growing (Directory);
   subtype Directory_List is Directory_Lists.List;
   --  The earliest made first.

   procedure Load_Order
     (Store   : Projects.Store;
      Project : Projects.Id;
      Result  : out Id_List)
     with Pre => Projects.Is_Open (Store);
   --  The project's items, in the order the writing view lists them: as
   --  they were put by Set_Position, those never put after, the earliest
   --  made first.

   function Position_Of (Store : Projects.Store; Key : Id) return Natural
     with Pre => Projects.Is_Open (Store);
   --  Where the item was put, from 1; 0 if never.

   procedure Set_Position
     (Store : in out Projects.Store; Key : Id; Position : Positive)
     with Pre => Projects.Is_Open (Store);
   --  Put the item at the place in the order, which is shared with the
   --  directories (Set_Directory_Position): the tree's rows.

   procedure Set_Directory_Position
     (Store : in out Projects.Store; Key : Id; Position : Positive)
     with Pre => Projects.Is_Open (Store);

   function Directory_Count
     (Store : Projects.Store; Project : Projects.Id) return Natural
     with Pre => Projects.Is_Open (Store);

   function Create_Directory
     (Store   : in out Projects.Store;
      Project : Projects.Id;
      Title   : String) return Id
     with Pre => Projects.Is_Open (Store);
   --  Add a directory to the project, after those it has.

   procedure Load_Directories
     (Store   : Projects.Store;
      Project : Projects.Id;
      Result  : out Directory_List)
     with Pre => Projects.Is_Open (Store);
   --  The project's directories, in the order they were put in, those
   --  never put after, the earliest made first.

   procedure Rename_Directory
     (Store : in out Projects.Store; Key : Id; Title : String)
     with Pre => Projects.Is_Open (Store);

   procedure Delete_Directory (Store : in out Projects.Store; Key : Id)
     with Pre => Projects.Is_Open (Store);
   --  Remove the directory. What was in it is at the top level.

   function Directory_Of (Store : Projects.Store; Key : Id) return Id
     with Pre => Projects.Is_Open (Store);
   --  The directory the item is in, 0 if it is at the top level (or there
   --  is no such item).

   procedure Set_Directory
     (Store : in out Projects.Store; Key : Id; Into : Id)
     with Pre => Projects.Is_Open (Store);
   --  Put the item in the directory, or at the top level if it is 0.

end Items.Directories;
