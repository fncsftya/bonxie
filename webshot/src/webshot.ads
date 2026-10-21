--  Pictures of web pages (macOS only): WebKit loads a page, offscreen,
--  and its whole length is written as a PNG file. A cookie banner or other
--  notice that covers the page is clicked away first, if it can be found
--  (see the script in webshot_wk.m): cookies are accepted, which the page is
--  read for; nothing is kept, as it is loaded with no memory of any before.
--
--  A job runs in the background, and goes on only while the main thread
--  runs its event loop (SDL's does). A job has a slot, and one in a slot
--  at a time.
package Webshot is

   Lane_Count : constant := 8;
   --  How many slots, before those of the items, are for the pages found
   --  when finding sources.

   subtype Slot is Integer range 1 - Lane_Count .. Integer'Last;
   --  From 1: the items of a project's canvas, a slot to each, however
   --  many there are. From 1 - Lane_Count to 0: the pages found.

   type States is (Idle, Working, Looked, Done, Failed);
   --  Idle: nothing was started, or it was taken (Reset). Working: not
   --  loaded or not written yet. Looked: the page has been loaded and its top
   --  photographed (see Start); it waits to be told to go on. Done: the file is
   --  there. Failed: it could not be, and Message says why.

   Page_Width : constant := 1024;
   --  Points wide a page is laid out; the picture is up to twice that in
   --  pixels (see Scale).

   Scale : constant := 2;
   --  Pixels to a point of the page, as far as that is no more than
   --  Max_Pixels down the picture: a very long page has fewer, so that the
   --  whole page is in the picture, however long it is.

   Max_Pixels : constant := 16_384;
   --  Pixels tall a picture is at most, which a GPU texture can be.

   procedure Start
     (Which           : Slot;
      URL             : String;
      File_Name       : String;
      Look_File       : String := "";
      Dismiss_Banners : Boolean := True;
      Tile_Prefix     : String := "")
     with Pre => State (Which) /= Working;
   --  Begin to take the picture of the page at URL, to be written as
   --  File_Name (in a folder that exists). The state is Working, or
   --  Failed at once if URL is not a link.
   --
   --  With a Look_File, the page is first photographed as it is seen at the top
   --  of a window, to be written as Look_File, and the state is Looked, with the
   --  page open: someone (a language model, reading the picture's words) can say
   --  what covers it, and Press the button that closes it, which gives another
   --  look; then Continue takes the whole page. Without, the whole page is taken
   --  at once. Dismiss_Banners says whether a cookie banner the page has is
   --  looked for and pressed first, by what the page itself says (see the
   --  script in webshot_wk.m): not when someone else is to do it.
   --
   --  With a Tile_Prefix, the first Tile_Count screens of the page (a window high
   --  each, at the full Scale) are also written, as Tile_Prefix-1.png and on, when
   --  the whole page is taken: a page that is very long is shrunk to fit its
   --  picture, till its words are too small to read, and these are not.

   procedure Pump (Milliseconds : Natural);
   --  Run the main thread's run loop for that long, for what has no event
   --  loop of its own (tests); SDL's does it as it waits for events.

   function State (Which : Slot) return States;

   function Height (Which : Slot) return Natural
     with Pre => State (Which) = Done;
   --  Pixels tall the picture is.

   function Progress (Which : Slot) return Float
     with Post => Progress'Result in 0.0 .. 1.0;
   --  How far on a Working job is, as a fraction: the page's load, then
   --  the settling and the snapshot. 1.0 when Done, 0.0 otherwise.

   procedure Start_Download (Which : Slot; URL : String; File_Name : String)
     with Pre => State (Which) /= Working;
   --  Begin to fetch the file the address is of, to be written as File_Name, as the browser
   --  would download it: with whatever pages loaded before have told it (that it is a person,
   --  say), which a plain fetch of the address has not. The state is Working, then Done, with
   --  nothing to Height or Tile_Count; or Failed if it was not a file (a page), or not had.

   procedure Press (Which : Slot; Label : String)
     with Pre  => State (Which) = Looked and then Label'Length > 0,
          Post => State (Which) = Working;
   --  Press the button of the page that says Label (as the page shows it, to
   --  a person: the case, the punctuation and a letter or so are not looked
   --  at), if there is one, in the page or its frames, and look at the page
   --  again after a moment: the state is Looked once more. Pressed says if one
   --  was found.

   function Pressed (Which : Slot) return Boolean;
   --  Whether the last Press found a button to press.

   procedure Continue (Which : Slot)
     with Pre  => State (Which) = Looked,
          Post => State (Which) = Working;
   --  Take the whole page, as the file was asked for.

   Max_Tiles : constant := 4;
   --  Screens of the top of a page that are written, as Start says, at the most.

   function Tile_Count (Which : Slot) return Natural
     with Pre => State (Which) = Done,
          Post => Tile_Count'Result <= Max_Tiles;
   --  How many were: fewer, if the page is shorter; none if no prefix was given.

   function Document_Link (Which : Slot) return String
     with Pre => State (Which) = Looked;
   --  The address of the PDF that the page says it is the page of, as the
   --  pages of most journals and archives do for the indexes of scholars
   --  (citation_pdf_url); empty if it says none.

   function Page_Title (Which : Slot) return String
     with Pre => State (Which) in Looked | Done;
   --  The title of the page that was loaded; empty if it has none.

   function Message (Which : Slot) return String
     with Pre => State (Which) = Failed;

   procedure Reset (Which : Slot)
     with Post => State (Which) = Idle;
   --  Stop the job, if any, and forget how it ended.

end Webshot;
