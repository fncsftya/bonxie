--  Tests of Websearch: reading links off local pages, spotting DuckDuckGo's
--  challenge, and the limit on how often a search starts (no network); then,
--  unless the first argument is --offline, a search of the web for the rest
--  of the command line (default: ada language), printing each link.
with Ada.Characters.Handling;
with Ada.Command_Line;
with Ada.Directories;
with Ada.Text_IO;
with Websearch;

procedure Websearch_Test is
   use Ada.Text_IO;
   use type Websearch.States;

   Which   : constant Websearch.Slot := 1;
   Timeout : constant := 40_000;  --  ms, a little over the search's own

   Offline : constant Boolean :=
     Ada.Command_Line.Argument_Count > 0 and then Ada.Command_Line.Argument (1) = "--offline";

   Failures : Natural := 0;

   procedure Check (Ok : Boolean; What : String) is
   begin
      if not Ok then
         Put_Line ("FAIL: " & What);
         Failures := Failures + 1;
      end if;
   end Check;

   procedure Wait_For (Slot : Websearch.Slot) is
      Waited : Natural := 0;
   begin
      while Websearch.State (Slot) = Websearch.Working and then Waited < Timeout loop
         Websearch.Pump (50);
         Waited := Waited + 50;
      end loop;
   end Wait_For;

   procedure Read (Page : String) is
   begin
      Websearch.Reset (Which);
      Websearch.Read_Page (Which, "file://" & Ada.Directories.Full_Name ("pages/" & Page));
      Wait_For (Which);
   end Read;

   function Query return String is
      Words : String (1 .. Websearch.Max_Query);
      Last  : Natural := 0;
      First : constant Positive := (if Offline then 2 else 1);
   begin
      for I in First .. Ada.Command_Line.Argument_Count loop
         declare
            Word : constant String := Ada.Command_Line.Argument (I);
         begin
            exit when Last + Word'Length + 1 > Words'Length;
            if Last > 0 then
               Last := Last + 1;
               Words (Last) := ' ';
            end if;
            Words (Last + 1 .. Last + Word'Length) := Word;
            Last := Last + Word'Length;
         end;
      end loop;
      return (if Last = 0 then "ada language" else Words (1 .. Last));
   end Query;

   Accepted : Boolean;
begin
   --  Links: the address taken out of DuckDuckGo's redirect, text tidied,
   --  and only web links of results.
   Read ("results.html");
   Check (Websearch.State (Which) = Websearch.Done, "results page is Done");
   if Websearch.State (Which) = Websearch.Done then
      Check (Websearch.Count (Which) = 2, "two links, got" & Websearch.Count (Which)'Image);
      if Websearch.Count (Which) = 2 then
         Check (Websearch.Title (Which, 1) = "First result", "title tidied: " & Websearch.Title (Which, 1));
         Check (Websearch.URL (Which, 1) = "https://example.com/a?b=1", "redirect undone: " & Websearch.URL (Which, 1));
         Check (Websearch.URL (Which, 2) = "https://example.org/direct", "direct link kept");
      end if;
   end if;

   --  A page with no results is not a failure.
   Read ("none.html");
   Check (Websearch.State (Which) = Websearch.Done and then Websearch.Count (Which) = 0,
          "no results is Done with none");

   --  Limit: the first search starts, a second at once does not, from any
   --  slot, and says when to try again. (No wait for the page: Reset.)
   Websearch.Start (Which, "limit test", Accepted);
   Check (Accepted, "first search accepted");
   Websearch.Reset (Which);
   Websearch.Start (2, "limit test", Accepted);
   Check (not Accepted, "second search at once refused");
   Check (Websearch.State (2) = Websearch.Idle, "refused search left the slot Idle");
   Check (Websearch.Retry_After in 0.1 .. Websearch.Min_Interval, "Retry_After is a wait");

   --  The web itself, once the limit has passed.
   if not Offline then
      delay Websearch.Retry_After + 0.1;
      Websearch.Start (Which, Query, Accepted);
      Check (Accepted, "search accepted after the wait");
      Wait_For (Which);
      case Websearch.State (Which) is
         when Websearch.Done =>
            Put_Line (Websearch.Count (Which)'Image & " links");
            for I in 1 .. Websearch.Count (Which) loop
               Put_Line (I'Image & ". " & Websearch.Title (Which, I));
               Put_Line ("     " & Websearch.URL (Which, I));
            end loop;
            Check (Websearch.Count (Which) > 0, "some links");
            Check (not Websearch.Was_Cached (Which), "the first time is not from the cache");

            --  The same query again, in other case and spaces, within the limit's wait:
            --  answered from memory, with the same links, and no turn of the limit taken.
            declare
               Count : constant Natural := Websearch.Count (Which);
               First : constant String := Websearch.URL (Which, 1);
               Wait  : constant Duration := Websearch.Retry_After;
            begin
               Websearch.Reset (Which);
               Websearch.Start (2, "  " & Ada.Characters.Handling.To_Upper (Query) & " ", Accepted);
               Check (Accepted, "the same query is accepted at once");
               Check (Websearch.State (2) = Websearch.Done, "from the cache it is Done at once");
               Check (Websearch.Was_Cached (2), "and says it is from the cache");
               Check (Websearch.Count (2) = Count, "the same number of links");
               Check (Websearch.URL (2, 1) = First, "the same first link");
               Check (Websearch.Retry_After <= Wait, "no turn of the limit was taken");
               Websearch.Reset (2);

               --  Forgotten, it is searched for again, and so is held to the limit.
               Websearch.Clear_Cache;
               Websearch.Start (2, Query, Accepted);
               Check (not Accepted, "after Clear_Cache the limit applies again");
            end;
         when Websearch.Failed =>
            Put_Line ("Failed: " & Websearch.Message (Which)
                      & (if Websearch.Blocked (Which) then " [blocked]" else ""));
            Failures := Failures + 1;
         when others =>
            Put_Line ("Gave up waiting");
            Failures := Failures + 1;
      end case;
      Websearch.Reset (Which);
   end if;

   --  The challenge is a failure, and a blocked one.
   Read ("challenge.html");
   Check (Websearch.State (Which) = Websearch.Failed, "challenge page is Failed");
   if Websearch.State (Which) = Websearch.Failed then
      Check (Websearch.Blocked (Which), "challenge page is Blocked");
      Put_Line ("challenge: " & Websearch.Message (Which));
   end if;
   Websearch.Reset (Which);

   --  Back-off: a block makes searches wait First_Backoff, a second in a
   --  row twice that, and a page found does not shorten it, but starts the
   --  count again.
   Check (Websearch.Retry_After in Websearch.First_Backoff - 5.0 .. Websearch.First_Backoff,
          "first block waits a minute:" & Websearch.Retry_After'Image);
   Websearch.Start (2, "blocked test", Accepted);
   Check (not Accepted, "search refused during back-off");
   Read ("challenge.html");
   Check (Websearch.Retry_After in 2.0 * Websearch.First_Backoff - 5.0 .. 2.0 * Websearch.First_Backoff,
          "second block waits twice as long:" & Websearch.Retry_After'Image);
   Read ("results.html");
   Check (Websearch.Retry_After > Websearch.First_Backoff, "a page found leaves the wait");
   Read ("challenge.html");
   Check (Websearch.Retry_After in Websearch.First_Backoff - 5.0 .. Websearch.First_Backoff,
          "a block after a page found waits a minute:" & Websearch.Retry_After'Image);
   for Block in 1 .. 20 loop
      Read ("challenge.html");
   end loop;
   Check (Websearch.Retry_After in Websearch.Max_Backoff - 5.0 .. Websearch.Max_Backoff,
          "back-off stops at the most:" & Websearch.Retry_After'Image);

   if Failures > 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   else
      Put_Line ("checks passed");
   end if;
end Websearch_Test;
