--  Experimental web search (macOS only): WebKit loads DuckDuckGo's page of
--  results for a query, offscreen, and the links on it (title and address)
--  are read out of the page.
--
--  A search runs in the background, and goes on only while the main thread
--  runs its event loop (SDL's does). A search has a slot, and one in a slot
--  at a time.
--
--  What a search found is kept for Cache_Lifetime, so that the same query
--  asked again soon is answered from memory, and DuckDuckGo is not.
--
--  DuckDuckGo turns away what looks like a robot, so searches are spaced
--  out: Start accepts one only if Min_Interval has passed since the last
--  that was accepted (in any slot, from any task). After DuckDuckGo blocks
--  a search it waits far longer, more each time it happens in a row.
package Websearch is

   Slot_Count : constant := 4;

   subtype Slot is Positive range 1 .. Slot_Count;

   type States is (Idle, Working, Done, Failed);
   --  Idle: nothing was started, or it was taken (Reset). Working: the page
   --  is not loaded or not read yet. Done: the results are there (there may
   --  be none). Failed: the page could not be had, or it was DuckDuckGo's
   --  challenge or refusal (see Blocked), and Message says why.

   Max_Results : constant := 25;
   --  Links kept from a page: later ones are dropped.

   Max_Title : constant := 160;
   --  Bytes of a title kept.

   Max_URL : constant := 512;
   --  Bytes of an address kept: a link longer than that is dropped.

   Max_Query : constant := 256;
   --  Bytes of a query.

   subtype Result_Index is Positive range 1 .. Max_Results;

   Min_Interval : constant Duration := 5.0;
   --  Seconds between one search starting and the next.

   First_Backoff : constant Duration := 60.0;
   Max_Backoff   : constant Duration := 3_600.0;
   --  Seconds Start refuses after a search was blocked, and after each
   --  that was blocked again with no good one between: twice as long as
   --  before, to the most. A search that finds its page ends it.

   procedure Start (Which : Slot; Query : String; Accepted : out Boolean)
     with Pre  => State (Which) /= Working and then Query'Length in 1 .. Max_Query,
          Post => (if Accepted then State (Which) in Working | Done | Failed);
   --  Begin to search for Query. If the same query (whatever its case, and
   --  the spaces in it) found links in the last Cache_Lifetime seconds, they
   --  are the results: the state is Done at once, Accepted is True, and no
   --  turn of the limit below is taken. Otherwise, if it is too soon after the last search,
   --  Accepted is False and nothing was begun (the state is as it was);
   --  Retry_After says how long to wait. Else the state is Working.
   --  Tasks may call this at once, but the rest (Pump, State...) is for the
   --  main thread.

   Cache_Lifetime : constant Duration := 900.0;
   --  Seconds the links a search found are kept, to answer the same query.

   Cache_Capacity : constant := 16;
   --  Queries kept: when there are more, the oldest goes.

   procedure Clear_Cache;
   --  Forget the links kept.

   function Was_Cached (Which : Slot) return Boolean
     with Pre => State (Which) = Done;
   --  Whether the results of the slot's search were kept from before, not
   --  found by a search of DuckDuckGo just now.

   function Retry_After return Duration
     with Post => Retry_After'Result in 0.0 .. Max_Backoff;
   --  Seconds until Start would accept a search, 0.0 if it would now.
   --  Another task may take the turn first: Accepted is what to go by.

   procedure Read_Page (Which : Slot; Address : String)
     with Pre => State (Which) /= Working;
   --  For tests: read the links off the page at Address (a file: link, say) as
   --  if it were DuckDuckGo's results, with no limit on how often. A blocked
   --  page counts toward the back-off, as a search's would.

   procedure Pump (Milliseconds : Natural);
   --  Run the main thread's run loop for that long, for what has no event
   --  loop of its own (tests); SDL's does it as it waits for events.

   function State (Which : Slot) return States;

   function Count (Which : Slot) return Natural
     with Pre => State (Which) = Done,
          Post => Count'Result <= Max_Results;
   --  Links found, in the order the page has them.

   function Title (Which : Slot; Item : Result_Index) return String
     with Pre => State (Which) = Done and then Item <= Count (Which);
   --  The text of the link: not empty.

   function URL (Which : Slot; Item : Result_Index) return String
     with Pre => State (Which) = Done and then Item <= Count (Which);
   --  Where the link goes: an http or https address, not DuckDuckGo's
   --  redirect through its own server.

   function Blocked (Which : Slot) return Boolean
     with Pre => State (Which) = Failed;
   --  True if the failure is DuckDuckGo asking for proof of a person (the
   --  captcha page) or saying there were too many searches: asking again
   --  soon makes it worse, so leave it a good while.

   function Message (Which : Slot) return String
     with Pre => State (Which) = Failed;

   procedure Reset (Which : Slot)
     with Post => State (Which) = Idle;
   --  Stop the search, if any, and forget how it ended.

end Websearch;
