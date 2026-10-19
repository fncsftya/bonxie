with Projects;

--  The items as rows of the table: made, read, changed and removed.
package Items.Records is

   function Create
     (Store   : in out Projects.Store;
      Project : Projects.Id;
      Title   : String;
      Where   : Frame;
      Text    : String := "";
      Kind    : Kinds := Note) return Id
     with Pre => Projects.Is_Open (Store);
   --  Add an item, open, to the project. The project must exist, and have
   --  fewer than Capacity items. The text of a source is its link.

   procedure Load
     (Store   : Projects.Store;
      Project : Projects.Id;
      Result  : out Info_List)
     with Pre => Projects.Is_Open (Store);
   --  The project's items, but for their text: see Content.

   function Count
     (Store : Projects.Store; Project : Projects.Id) return Natural
     with Pre => Projects.Is_Open (Store);

   function Content (Store : Projects.Store; Key : Id) return String
     with Pre => Projects.Is_Open (Store);
   --  The text of the item, "" if there is no such item.

   function Stored_Content (Store : Projects.Store; Key : Id) return String
     with Pre => Projects.Is_Open (Store);
   --  Versioned editor content for loading a document, retaining formatting.

   procedure Set_Title
     (Store : in out Projects.Store; Key : Id; Title : String)
     with Pre => Projects.Is_Open (Store);

   procedure Set_Content
     (Store : in out Projects.Store; Key : Id; Text : String)
     with Pre => Projects.Is_Open (Store);

   procedure Set_Frame
     (Store : in out Projects.Store; Key : Id; Where : Frame)
     with Pre => Projects.Is_Open (Store);

   procedure Set_State
     (Store : in out Projects.Store; Key : Id; State : States)
     with Pre => Projects.Is_Open (Store);

   procedure Set_Scroll
     (Store : in out Projects.Store; Key : Id; Scroll, Across : Float)
     with Pre => Projects.Is_Open (Store) and then Scroll >= 0.0
                 and then Across in 0.0 .. 1.0;
   --  How far the item's content is scrolled (see Info.Scroll and
   --  Info.Scroll_Across).

   procedure Delete (Store : in out Projects.Store; Key : Id)
     with Pre => Projects.Is_Open (Store);
   --  Remove the item for good, and its picture. Nothing is done if there
   --  is no such item.

end Items.Records;
