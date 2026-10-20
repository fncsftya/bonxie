with Growing;
with Long_Texts;
with Projects;

--  The items of a project's canvas, kept in the same database as the
--  projects: a window on the canvas with a title and some text, where it
--  is and how big, and whether it is shown, minimised to a bar, or closed.
--  A project has as many as are made. They go with their project.
--
--  This is what an item is; the children are what is done with it. See
--  Items.Schema (the tables), Items.Records (the items themselves),
--  Items.Sources (what is of a source alone), Items.Words and
--  Items.Marks (what is found and made on a source's picture),
--  Items.Links (the lines between items) and Items.Directories (the
--  writing view's tree). The SQL they are kept by is in the Repository.
package Items is

   subtype Slot is Positive;
   --  Which of a project's items, from 1: the earliest made first.

   type Id is new Long_Integer;

   type Kinds is (Note, Source);
   --  Note: a window of text to write in. Source: a window of a picture of
   --  a web page, at the link that is its text.

   type States is (Open, Minimized, Closed);
   --  Open: a window on the canvas. Minimized: only its title, in a bar
   --  above the tools. Closed: not shown, but kept in the list of items.

   package Extensions renames Long_Texts;
   --  The ending of a file's name, without its dot, as "pdf".

   type Origins is (Unchosen, Remote, Local);
   --  Of a source: whether it is yet to be said where it comes from (a
   --  window with two buttons to say so), it is a link to fetch, or it is
   --  a file on this computer, whose path is its text.

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
      Title : Projects.Titles.Text :=
        Projects.Titles.Null_Text;
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
      Origin : Origins := Remote;
      Page : Natural := 0;
      Page_Count : Natural := 0;
      Document : Extensions.Text := Extensions.Null_Text;
      --  Of a source that is a PDF or e-book, not a web page: its file's
      --  ending, and which of its Page_Count pages the picture is of
      --  (from 1). Page_Count is 0 for a web page, and Page too.
   end record;

   package Info_Lists is new Growing (Info);
   subtype Info_List is Info_Lists.List;
   --  The earliest made first.

   package Id_Lists is new Growing (Id);
   subtype Id_List is Id_Lists.List;
   --  Keys, in an order given.

end Items;
