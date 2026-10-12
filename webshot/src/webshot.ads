--  Pictures of web pages (macOS only): WebKit loads a page, offscreen,
--  and its whole length is written as a PNG file.
--
--  A job runs in the background, and goes on only while the main thread
--  runs its event loop (SDL's does). A job has a slot, and one in a slot
--  at a time.
package Webshot is

   Slot_Count : constant := 16;

   subtype Slot is Positive range 1 .. Slot_Count;

   type States is (Idle, Working, Done, Failed);
   --  Idle: nothing was started, or it was taken (Reset). Working: not
   --  loaded or not written yet. Done: the file is there. Failed: it
   --  could not be, and Message says why.

   Page_Width : constant := 1024;
   --  Pixels wide a page is laid out and drawn.

   Max_Height : constant := 16_384;
   --  Pixels tall a picture is at most: a long page is cut off.

   procedure Start (Which : Slot; URL : String; File_Name : String)
     with Pre => State (Which) /= Working;
   --  Begin to take the picture of the page at URL, to be written as
   --  File_Name (in a folder that exists). The state is Working, or
   --  Failed at once if URL is not a link.

   procedure Pump (Milliseconds : Natural);
   --  Run the main thread's run loop for that long, for what has no event
   --  loop of its own (tests); SDL's does it as it waits for events.

   function State (Which : Slot) return States;

   function Height (Which : Slot) return Natural
     with Pre => State (Which) = Done;
   --  Pixels tall the picture is: it is Page_Width wide.

   function Message (Which : Slot) return String
     with Pre => State (Which) = Failed;

   procedure Reset (Which : Slot)
     with Post => State (Which) = Idle;
   --  Stop the job, if any, and forget how it ended.

end Webshot;
