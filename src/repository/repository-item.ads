with Items;
with Projects;

--  The table of items: their rows, one to a window on a project's canvas,
--  and what is kept in them of a source's picture, of where the item is
--  in the writing view, and of which directory.
package Repository.Item is

   procedure Prepare (Store : in out Projects.Store)
     with Pre => Projects.Is_Open (Store);
   --  Make the table, if there is none, and bring one made by an earlier
   --  version up to date.

   function Insert
     (Store   : in out Projects.Store;
      Project : Projects.Id;
      Title   : String;
      Where   : Items.Frame;
      Text    : String;
      Kind    : Items.Kinds) return Items.Id
     with Pre => Projects.Is_Open (Store);

   procedure Load
     (Store   : Projects.Store;
      Project : Projects.Id;
      Result  : out Items.Info_List)
     with Pre => Projects.Is_Open (Store);
   --  The project's items, but for their text: see Content.

   function Count
     (Store : Projects.Store; Project : Projects.Id) return Natural
     with Pre => Projects.Is_Open (Store);

   function Content (Store : Projects.Store; Key : Items.Id) return String
     with Pre => Projects.Is_Open (Store);
   --  "" if there is no such item.

   function Owner (Store : Projects.Store; Key : Items.Id) return Projects.Id
     with Pre => Projects.Is_Open (Store);
   --  The project the item is of, 0 if there is no such item.

   procedure Set_Title
     (Store : in out Projects.Store; Key : Items.Id; Title : String)
     with Pre => Projects.Is_Open (Store);

   procedure Set_Content
     (Store : in out Projects.Store; Key : Items.Id; Text : String)
     with Pre => Projects.Is_Open (Store);

   procedure Set_Frame
     (Store : in out Projects.Store; Key : Items.Id; Where : Items.Frame)
     with Pre => Projects.Is_Open (Store);

   procedure Set_State
     (Store : in out Projects.Store; Key : Items.Id; State : Items.States)
     with Pre => Projects.Is_Open (Store);

   procedure Set_Scroll
     (Store : in out Projects.Store; Key : Items.Id; Scroll, Across : Float)
     with Pre => Projects.Is_Open (Store);

   procedure Set_Zoom
     (Store : in out Projects.Store; Key : Items.Id; Zoom : Items.Zoom_Level)
     with Pre => Projects.Is_Open (Store);

   procedure Set_Captured
     (Store : in out Projects.Store; Key : Items.Id; At_Time : Projects.Seconds)
     with Pre => Projects.Is_Open (Store);

   procedure Set_Document
     (Store      : in out Projects.Store;
      Key        : Items.Id;
      Document   : String;
      Page_Count : Natural)
     with Pre => Projects.Is_Open (Store);
   --  Of a source: its file's ending ("" for a web page) and how many
   --  pages it has (0 for none); the page is the first, or none.

   procedure Set_Origin
     (Store : in out Projects.Store; Key : Items.Id; Origin : Items.Origins)
     with Pre => Projects.Is_Open (Store);

   procedure Set_Page
     (Store : in out Projects.Store; Key : Items.Id; Page : Natural)
     with Pre => Projects.Is_Open (Store);

   procedure Set_Recognized
     (Store   : in out Projects.Store;
      Key     : Items.Id;
      At_Time : Projects.Seconds;
      Version : Natural)
     with Pre => Projects.Is_Open (Store);
   --  Say the words found in the item's picture were kept at At_Time, put
   --  in order as Version says. At_Time is 0 for those that were not (or
   --  are forgotten).

   function Is_Recognized
     (Store   : Projects.Store;
      Key     : Items.Id;
      Version : Natural) return Boolean
     with Pre => Projects.Is_Open (Store);
   --  Whether the words were kept, as Set_Recognized had them, at that
   --  Version.

   function Position_Of
     (Store : Projects.Store; Key : Items.Id) return Natural
     with Pre => Projects.Is_Open (Store);
   --  Where the item was put in the writing view; 0 if never or if there
   --  is no such item.

   procedure Set_Position
     (Store : in out Projects.Store; Key : Items.Id; Position : Positive)
     with Pre => Projects.Is_Open (Store);

   procedure Load_Order
     (Store   : Projects.Store;
      Project : Projects.Id;
      Result  : out Items.Id_List)
     with Pre => Projects.Is_Open (Store);
   --  The project's items by Position, those never put after, the earliest
   --  made first.

   function Directory_Of
     (Store : Projects.Store; Key : Items.Id) return Items.Id
     with Pre => Projects.Is_Open (Store);
   --  0 if the item is at the top level, or if there is no such item.

   procedure Set_Directory
     (Store : in out Projects.Store; Key, Directory : Items.Id)
     with Pre => Projects.Is_Open (Store);

   procedure Free_Directory
     (Store : in out Projects.Store; Directory : Items.Id)
     with Pre => Projects.Is_Open (Store);
   --  Put what is in the directory at the top level.

   procedure Delete (Store : in out Projects.Store; Key : Items.Id)
     with Pre => Projects.Is_Open (Store);
   --  The row only, and what refers to it (foreign keys).

end Repository.Item;
