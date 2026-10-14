with Projects;

--  The items of a project's canvas, kept in the same database as the
--  projects: a window on the canvas with a title and some text, where it
--  is and how big, and whether it is shown, minimised to a bar, or closed.
--  A project has at most Capacity of them. They go with their project.
--
--  This is what an item is; the children are what is done with it. See
--  Items.Schema (the tables), Items.Records (the items themselves),
--  Items.Sources (what is of a source alone), Items.Words and
--  Items.Marks (what is found and made on a source's picture),
--  Items.Links (the lines between items) and Items.Directories (the
--  writing view's tree).
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
   Source_Width   : constant Float := 360.0;
   --  A source's window is wider, for the tools in the middle of its
   --  status line to be clear of the words and the zoom on either side.

   function Sized (Where : Frame) return Frame is
     (Where with delta
        Width  => Float'Max (Min_Width, Where.Width),
        Height => Float'Max (Min_Height, Where.Height));
   --  Where, no smaller than an item may be.

   Min_Zoom : constant Float := 0.25;
   Max_Zoom : constant Float := 4.0;
   --  How far a source's picture may be zoomed within its window.

   subtype Zoom_Level is Float range Min_Zoom .. Max_Zoom;

   type Info is record
      Key   : Id := 0;
      Title : Projects.Titles.Bounded_String :=
        Projects.Titles.Null_Bounded_String;
      Where : Frame;
      State : States := Open;
      Kind  : Kinds := Note;
      Captured_At : Projects.Seconds := 0;
      --  Of a source: when its picture was taken; 0 if it has not been.
      Zoom  : Zoom_Level := 1.0;
      --  Of a source: how wide its picture is shown, as a multiple of its
      --  window's width.
      Scroll : Float := 0.0;
      --  How far the window's content is scrolled: for a note, down its
      --  text in layout units; for a source, down its picture, from 0.0
      --  to 1.0 of its height.
      Scroll_Across : Float := 0.0;
      --  Of a source: how far across its picture is scrolled, from 0.0 to
      --  1.0 of how much wider than the window it is (see Zoom).
      Recognized_At : Projects.Seconds := 0;
      --  Of a source: when the text in its picture was found and kept
      --  (see Save_Words); 0 if it has not been, or the picture was taken
      --  again since.
   end record;

   type Info_Array is array (Positive range <>) of Info;

   type Info_List is record
      Count : Natural range 0 .. Capacity := 0;
      Items : Info_Array (1 .. Capacity);
   end record;
   --  Items (1 .. Count), the earliest made first.

   type Id_Array is array (Positive range <>) of Id;

   type Id_List is record
      Count : Natural range 0 .. Capacity := 0;
      Keys  : Id_Array (1 .. Capacity) := [others => 0];
   end record;
   --  Keys (1 .. Count).

end Items;
