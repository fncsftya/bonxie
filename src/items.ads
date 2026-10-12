with Projects;

--  The items of a project's canvas, kept in the same database as the
--  projects: a window on the canvas with a title and some text, where it
--  is and how big, and whether it is shown, minimised to a bar, or closed.
--  A project has at most Capacity of them. They go with their project.
package Items is

   Capacity : constant := 16;
   --  Of one project.

   subtype Slot is Positive range 1 .. Capacity;

   type Id is new Long_Integer;

   type Kinds is (Note, Source);
   --  Note: a window of text to write in. Source: a window of a picture of
   --  a web page, at the link that is its text.

   type States is (Open, Minimized, Closed);
   --  Open: a window on the canvas. Minimized: only its title, in a bar
   --  above the tools. Closed: not shown, but kept in the list of items.

   type Frame is record
      Left, Top, Width, Height : Float := 0.0;
   end record;
   --  Where an item is on the canvas, in canvas units.

   Min_Width      : constant Float := 160.0;
   Min_Height     : constant Float := 100.0;
   Default_Width  : constant Float := 280.0;
   Default_Height : constant Float := 200.0;

   function Sized (Where : Frame) return Frame is
     (Where with delta
        Width  => Float'Max (Min_Width, Where.Width),
        Height => Float'Max (Min_Height, Where.Height));
   --  Where, no smaller than an item may be.

   type Info is record
      Key   : Id := 0;
      Title : Projects.Titles.Bounded_String :=
        Projects.Titles.Null_Bounded_String;
      Where : Frame;
      State : States := Open;
      Kind  : Kinds := Note;
      Captured_At : Projects.Seconds := 0;
      --  Of a source: when its picture was taken; 0 if it has not been.
   end record;

   type Info_Array is array (Positive range <>) of Info;

   type Info_List is record
      Count : Natural range 0 .. Capacity := 0;
      Items : Info_Array (1 .. Capacity);
   end record;
   --  Items (1 .. Count), the earliest made first.

   procedure Prepare (Store : in out Projects.Store)
     with Pre => Projects.Is_Open (Store);
   --  Make the table, if there is none: once, after the store is opened.

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

   procedure Set_Captured
     (Store : in out Projects.Store; Key : Id; At_Time : Projects.Seconds)
     with Pre => Projects.Is_Open (Store);
   --  Say the picture of a source was taken at At_Time.

   function Image_File
     (Store : Projects.Store; Project : Projects.Id; Key : Id) return String
     with Pre => Projects.Is_Open (Store);
   --  Where the picture of a source is kept, as a PNG file: in the
   --  project's folder (see Projects.Folder), in sources, named for the
   --  item. It does not make the folder: see Make_Image_Folder.

   procedure Make_Image_Folder
     (Store : Projects.Store; Project : Projects.Id)
     with Pre => Projects.Is_Open (Store);

   procedure Delete (Store : in out Projects.Store; Key : Id)
     with Pre => Projects.Is_Open (Store);
   --  Remove the item for good, and its picture. Nothing is done if there
   --  is no such item.

end Items;
