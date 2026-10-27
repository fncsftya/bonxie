with Items.Links;
with Projects;

--  The table of links: the lines between a project's items, one to a row.

package Repository.Link is

   procedure Prepare (Store : in out Projects.Store)
   with Pre => Projects.Is_Open (Store);
   --  Make the table, if there is none, and bring one made by an earlier
   --  version up to date.

   function Exists (Store : Projects.Store; A, B : Items.Id) return Boolean
   with Pre => Projects.Is_Open (Store);
   --  Whether there is a link between the items, whichever way round.

   procedure Insert (Store : in out Projects.Store; Made : Items.Links.Link)
   with Pre => Projects.Is_Open (Store);

   procedure Delete (Store : in out Projects.Store; Key : Items.Id)
   with Pre => Projects.Is_Open (Store);

   procedure Set_Style
     (Store  : in out Projects.Store;
      Key    : Items.Id;
      Stroke : Items.Links.Strokes;
      Ending : Items.Links.Endings;
      Color  : Items.Links.Link_Colors)
   with Pre => Projects.Is_Open (Store);

   procedure Move
     (Store : in out Projects.Store; Key : Items.Id; To : Items.Id; Side : Items.Links.Sides; Moved : out Boolean)
   with Pre => Projects.Is_Open (Store);
   --  Make the link end at the Side of To, which is not the item it starts
   --  from, if that is not joined by another link to it.

   procedure Load (Store : Projects.Store; Project : Projects.Id; Result : out Items.Links.Link_List)
   with Pre => Projects.Is_Open (Store);
   --  The links of the project's items, the earliest made first.

end Repository.Link;
