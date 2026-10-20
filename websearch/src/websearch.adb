with Ada.Characters.Handling;
with Ada.Real_Time;
with Ada.Strings.Bounded;
with Interfaces.C.Strings;

package body Websearch is

   use type Interfaces.C.int;

   function WSR_Start
     (Which : Interfaces.C.int;
      Query : Interfaces.C.char_array) return Interfaces.C.int
     with Import, Convention => C, External_Name => "wsr_start";

   function WSR_Start_Page
     (Which : Interfaces.C.int;
      Where : Interfaces.C.char_array) return Interfaces.C.int
     with Import, Convention => C, External_Name => "wsr_start_page";

   function WSR_Blocked (Which : Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C, External_Name => "wsr_blocked";

   type Outcome_Hook is access procedure (Was_Blocked : Interfaces.C.int)
     with Convention => C;

   procedure WSR_Set_Hook (Hook : Outcome_Hook)
     with Import, Convention => C, External_Name => "wsr_set_hook";

   function WSR_State (Which : Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C, External_Name => "wsr_state";

   function WSR_Count (Which : Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C, External_Name => "wsr_count";

   function WSR_Title
     (Which, Item : Interfaces.C.int) return Interfaces.C.Strings.chars_ptr
     with Import, Convention => C, External_Name => "wsr_title";

   function WSR_URL
     (Which, Item : Interfaces.C.int) return Interfaces.C.Strings.chars_ptr
     with Import, Convention => C, External_Name => "wsr_url";

   function WSR_Message
     (Which : Interfaces.C.int) return Interfaces.C.Strings.chars_ptr
     with Import, Convention => C, External_Name => "wsr_message";

   procedure WSR_Pump (Milliseconds : Interfaces.C.int)
     with Import, Convention => C, External_Name => "wsr_pump";

   procedure WSR_Reset (Which : Interfaces.C.int)
     with Import, Convention => C, External_Name => "wsr_reset";

   function Index (Which : Slot) return Interfaces.C.int is
     (Interfaces.C.int (Which - 1));

   --  The links kept

   package Keys is new Ada.Strings.Bounded.Generic_Bounded_Length (Max_Query);
   package Item_Titles is new Ada.Strings.Bounded.Generic_Bounded_Length (Max_Title);
   package Item_Addresses is new Ada.Strings.Bounded.Generic_Bounded_Length (Max_URL);

   type Link is record
      Title   : Item_Titles.Bounded_String;
      Address : Item_Addresses.Bounded_String;
   end record;

   type Link_Array is array (Result_Index) of Link;

   type Found_Links is record
      Used    : Boolean := False;
      Key     : Keys.Bounded_String;
      At_Time : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      Count   : Natural range 0 .. Max_Results := 0;
      Links   : Link_Array;
   end record;

   function Key_Of (Query : String) return String;
   --  The query as it is kept by: in lower case, with a space for each run of
   --  spaces and no others at the ends.

   function Key_Of (Query : String) return String is
      Result : String (1 .. Query'Length);
      Last   : Natural := 0;
      Gap    : Boolean := False;
   begin
      for C of Query loop
         if C <= ' ' then
            Gap := Last > 0;
         else
            if Gap then
               Last := Last + 1;
               Result (Last) := ' ';
               Gap := False;
            end if;
            Last := Last + 1;
            Result (Last) := Ada.Characters.Handling.To_Lower (C);
         end if;
      end loop;
      return Result (1 .. Last);
   end Key_Of;

   type Found_Array is array (1 .. Cache_Capacity) of Found_Links;

   protected Cache is
      procedure Find (Key : String; Found : out Boolean; Links : out Found_Links);
      --  The links kept for the query, if it was kept in the last Cache_Lifetime seconds.
      procedure Put (Key : String; Links : Found_Links);
      procedure Clear;
   private
      Entries : Found_Array;
   end Cache;

   protected body Cache is

      procedure Find (Key : String; Found : out Boolean; Links : out Found_Links) is
         use type Ada.Real_Time.Time;
         use type Ada.Real_Time.Time_Span;
         Now : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
      begin
         Found := False;
         for Each of Entries loop
            if Each.Used and then Keys.To_String (Each.Key) = Key then
               if Now - Each.At_Time <= Ada.Real_Time.To_Time_Span (Cache_Lifetime) then
                  Links := Each;
                  Found := True;
               else
                  Each.Used := False;
               end if;
            end if;
         end loop;
      end Find;

      procedure Put (Key : String; Links : Found_Links) is
         use type Ada.Real_Time.Time;
         Place : Positive := 1;
      begin
         --  Where the query was, else a free place, else the oldest.
         for Each in Entries'Range loop
            if Entries (Each).Used and then Keys.To_String (Entries (Each).Key) = Key then
               Place := Each;
               exit;
            elsif not Entries (Each).Used then
               Place := Each;
            elsif Entries (Place).Used and then Entries (Each).At_Time < Entries (Place).At_Time then
               Place := Each;
            end if;
         end loop;
         Entries (Place) := Links;
         Entries (Place).Used := True;
         Entries (Place).Key := Keys.To_Bounded_String (Key);
      end Put;

      procedure Clear is
      begin
         for Each of Entries loop
            Each.Used := False;
         end loop;
      end Clear;

   end Cache;

   Served  : array (Slot) of Boolean := [others => False];
   Copy    : array (Slot) of Found_Links;
   --  Whether the slot's results are the cache's, and the links it was given.

   Waiting : array (Slot) of Boolean := [others => False];
   Asked   : array (Slot) of Keys.Bounded_String;
   --  Whether the slot has a search of DuckDuckGo whose links are yet to be
   --  kept, and its query.

   --  The turn to search: one at a time, whichever task asks.
   protected Limiter is
      procedure Take (Accepted : out Boolean);
      procedure Blocked;
      procedure Found;
      function Wait return Duration;
   private
      Next    : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      --  When the next search may start.
      Strikes : Natural := 0;
      --  Searches blocked in a row.
   end Limiter;

   protected body Limiter is

      procedure Take (Accepted : out Boolean) is
         use type Ada.Real_Time.Time;
         Now : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
      begin
         Accepted := Now >= Next;
         if Accepted then
            Next := Now + Ada.Real_Time.To_Time_Span (Min_Interval);
         end if;
      end Take;

      procedure Blocked is
         use type Ada.Real_Time.Time;
         Pause : Duration := First_Backoff;
      begin
         for Doubling in 2 .. Strikes + 1 loop
            Pause := Duration'Min (Max_Backoff, Pause * 2);
         end loop;
         Strikes := Natural'Min (Strikes + 1, 64);
         Next := Ada.Real_Time.Clock + Ada.Real_Time.To_Time_Span (Pause);
      end Blocked;

      procedure Found is
      begin
         Strikes := 0;
      end Found;

      function Wait return Duration is
         use type Ada.Real_Time.Time;
         Now : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
      begin
         return (if Now >= Next then 0.0
                 else Duration'Min (Max_Backoff, Ada.Real_Time.To_Duration (Next - Now)));
      end Wait;

   end Limiter;

   --  Called, on the main thread, as a search ends in a block or in a page.
   procedure On_Outcome (Was_Blocked : Interfaces.C.int)
     with Convention => C;

   procedure On_Outcome (Was_Blocked : Interfaces.C.int) is
   begin
      if Was_Blocked = 1 then
         Limiter.Blocked;
      else
         Limiter.Found;
      end if;
   end On_Outcome;

   procedure Start (Which : Slot; Query : String; Accepted : out Boolean) is
      Key   : constant String := Key_Of (Query);
      Found : Boolean := False;
   begin
      Served (Which) := False;
      Waiting (Which) := False;
      if Key /= "" then
         Cache.Find (Key, Found, Copy (Which));
      end if;
      if Found then
         WSR_Reset (Index (Which));
         Served (Which) := True;
         Accepted := True;
         return;
      end if;
      Limiter.Take (Accepted);
      if Accepted then
         declare
            Started : constant Interfaces.C.int := WSR_Start (Index (Which), Interfaces.C.To_C (Query));
         begin
            pragma Assert (Started = 1);
            Waiting (Which) := Key /= "";
            Asked (Which) := Keys.To_Bounded_String (Key);
         end;
      end if;
   end Start;

   procedure Clear_Cache is
   begin
      Cache.Clear;
   end Clear_Cache;

   function Was_Cached (Which : Slot) return Boolean is (Served (Which));

   function Retry_After return Duration is (Limiter.Wait);

   procedure Read_Page (Which : Slot; Address : String) is
      Started : constant Interfaces.C.int := WSR_Start_Page (Index (Which), Interfaces.C.To_C (Address));
   begin
      pragma Assert (Started = 1);
   end Read_Page;

   function Blocked (Which : Slot) return Boolean is
     (WSR_Blocked (Index (Which)) = 1);

   procedure Pump (Milliseconds : Natural) is
   begin
      WSR_Pump (Interfaces.C.int (Milliseconds));
   end Pump;

   function Count (Which : Slot) return Natural is
     (if Served (Which) then Copy (Which).Count else Natural (WSR_Count (Index (Which))));

   function Title (Which : Slot; Item : Result_Index) return String is
     (if Served (Which) then Item_Titles.To_String (Copy (Which).Links (Item).Title)
      else Interfaces.C.Strings.Value (WSR_Title (Index (Which), Interfaces.C.int (Item - 1))));

   function URL (Which : Slot; Item : Result_Index) return String is
     (if Served (Which) then Item_Addresses.To_String (Copy (Which).Links (Item).Address)
      else Interfaces.C.Strings.Value (WSR_URL (Index (Which), Interfaces.C.int (Item - 1))));

   procedure Keep (Which : Slot) is
      Links : Found_Links;
   begin
      Waiting (Which) := False;
      Links.Count := Count (Which);
      --  What had no links may only have been turned away: not kept.
      if Links.Count > 0 then
         for Item in 1 .. Links.Count loop
            Links.Links (Item) :=
              (Title   => Item_Titles.To_Bounded_String (Title (Which, Item)),
               Address => Item_Addresses.To_Bounded_String (URL (Which, Item)));
         end loop;
         Links.At_Time := Ada.Real_Time.Clock;
         Cache.Put (Keys.To_String (Asked (Which)), Links);
      end if;
   end Keep;

   function State (Which : Slot) return States is
      Now : constant States :=
        (if Served (Which) then Done
         else (case WSR_State (Index (Which)) is
                  when 1 => Working,
                  when 2 => Done,
                  when 3 => Failed,
                  when others => Idle));
   begin
      if Now = Done and then Waiting (Which) then
         Keep (Which);
      elsif Now /= Working then
         Waiting (Which) := False;
      end if;
      return Now;
   end State;

   function Message (Which : Slot) return String is
     (Interfaces.C.Strings.Value (WSR_Message (Index (Which))));

   procedure Reset (Which : Slot) is
   begin
      WSR_Reset (Index (Which));
      Served (Which) := False;
      Waiting (Which) := False;
   end Reset;

begin
   WSR_Set_Hook (On_Outcome'Access);
end Websearch;
