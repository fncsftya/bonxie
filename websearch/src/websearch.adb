with Ada.Real_Time;
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
   begin
      Limiter.Take (Accepted);
      if Accepted then
         declare
            Started : constant Interfaces.C.int := WSR_Start (Index (Which), Interfaces.C.To_C (Query));
         begin
            pragma Assert (Started = 1);
         end;
      end if;
   end Start;

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

   function State (Which : Slot) return States is
     (case WSR_State (Index (Which)) is
         when 1 => Working,
         when 2 => Done,
         when 3 => Failed,
         when others => Idle);

   function Count (Which : Slot) return Natural is
     (Natural (WSR_Count (Index (Which))));

   function Title (Which : Slot; Item : Result_Index) return String is
     (Interfaces.C.Strings.Value (WSR_Title (Index (Which), Interfaces.C.int (Item - 1))));

   function URL (Which : Slot; Item : Result_Index) return String is
     (Interfaces.C.Strings.Value (WSR_URL (Index (Which), Interfaces.C.int (Item - 1))));

   function Message (Which : Slot) return String is
     (Interfaces.C.Strings.Value (WSR_Message (Index (Which))));

   procedure Reset (Which : Slot) is
   begin
      WSR_Reset (Index (Which));
   end Reset;

begin
   WSR_Set_Hook (On_Outcome'Access);
end Websearch;
