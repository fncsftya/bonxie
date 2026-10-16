with Projects.Sections;

--  The table of the sections of the projects' outlines, one row to a
--  section.
package Repository.Section is

   procedure Prepare (Store : in out Projects.Store)
     with Pre => Projects.Is_Open (Store);
   --  Make the table, if there is none.

   procedure Load
     (Store   : Projects.Store;
      Project : Projects.Id;
      Result  : out Projects.Sections.Section_List)
     with Pre => Projects.Is_Open (Store);

   function Insert
     (Store   : in out Projects.Store;
      Project : Projects.Id;
      Title   : String) return Projects.Sections.Section_Id
     with Pre => Projects.Is_Open (Store);
   --  After the rest.

   procedure Rename
     (Store : in out Projects.Store;
      Key   : Projects.Sections.Section_Id;
      Title : String)
     with Pre => Projects.Is_Open (Store);

   procedure Set_Order
     (Store   : in out Projects.Store;
      Project : Projects.Id;
      Order   : Projects.Sections.Key_Array)
     with Pre => Projects.Is_Open (Store);

   procedure Link
     (Store : in out Projects.Store;
      Key   : Projects.Sections.Section_Id;
      Item  : Long_Integer)
     with Pre => Projects.Is_Open (Store) and then Item /= 0;
   --  The item is one of the section's, and of no other.

   procedure Unlink (Store : in out Projects.Store; Item : Long_Integer)
     with Pre => Projects.Is_Open (Store);

   procedure Load_Links
     (Store   : Projects.Store;
      Project : Projects.Id;
      Result  : out Projects.Sections.Link_List)
     with Pre => Projects.Is_Open (Store);
   --  The items of the project that are of a section.

   procedure Delete
     (Store : in out Projects.Store; Key : Projects.Sections.Section_Id)
     with Pre => Projects.Is_Open (Store);

end Repository.Section;
