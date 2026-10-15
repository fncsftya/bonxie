with Ada.Real_Time;
with Ada.Strings.Unbounded;
with Ada.Unchecked_Deallocation;
with Interfaces.C;
with System;

package body MLX.Jobs is

   package C renames Interfaces.C;
   package US renames Ada.Strings.Unbounded;

   use type C.int;

   subtype Place_Range is Positive range 1 .. Max_Jobs;

   function MX_Generate
     (Directory          : System.Address;
      System_Prompt      : System.Address;
      Prompt             : System.Address;
      Max_Tokens         : C.int;
      Temperature        : C.C_float;
      Top_P              : C.C_float;
      Top_K              : C.int;
      Min_P              : C.C_float;
      Repetition_Penalty : C.C_float;
      Repetition_Context : C.int;
      Seed               : Interfaces.Integer_64;
      Thinking           : C.int;
      Job_Number         : Interfaces.Integer_64;
      Reply_Text         : System.Address;
      Reply_Room         : C.int;
      Message            : System.Address;
      Message_Room       : C.int) return C.int
     with Import, Convention => C, External_Name => "mx_generate";

   procedure MX_Cancel (Job_Number : Interfaces.Integer_64)
     with Import, Convention => C, External_Name => "mx_cancel";

   --  What each place holds: how its ask is, and what came of it.
   protected type Place_State is
      procedure Begin_Ask;
      procedure Finish (To : States; Said : String)
        with Pre => To in Done | Failed | Cancelled and then Said'Length <= Max_Reply;
      procedure Request_Cancel;
      procedure Forget;
      function Cancelling return Boolean;
      function State return States;
      function Words return String;
   private
      Now     : States := Idle;
      Stopped : Boolean := False;
      Reply   : String (1 .. Max_Reply) := [others => ' '];
      Length  : Natural range 0 .. Max_Reply := 0;
   end Place_State;

   protected body Place_State is
      procedure Begin_Ask is
      begin
         Now := Running;
         Stopped := False;
         Length := 0;
      end Begin_Ask;

      procedure Finish (To : States; Said : String) is
      begin
         Reply (1 .. Said'Length) := Said;
         Length := Said'Length;
         Now := To;
      end Finish;

      procedure Request_Cancel is
      begin
         Stopped := True;
      end Request_Cancel;

      procedure Forget is
      begin
         Now := Idle;
         Stopped := False;
         Length := 0;
      end Forget;

      function Cancelling return Boolean is (Stopped);

      function State return States is (Now);

      function Words return String is (Reply (1 .. Length));
   end Place_State;

   Places : array (Place_Range) of Place_State;

   type Use_Array is array (Place_Range) of Boolean;

   --  Which places are in use.
   protected Pool is
      procedure Claim (Place : out Natural);
      procedure Free (Place : Place_Range);
   private
      Used : Use_Array := [others => False];
   end Pool;

   --  Text for the binding, which may be as long as the prompt is.
   type Text_Access is access C.char_array;

   procedure Free is new Ada.Unchecked_Deallocation (C.char_array, Text_Access);

   function Copy (Words : US.Unbounded_String) return Text_Access is
     (new C.char_array'(C.To_C (US.To_String (Words))));

   protected body Pool is
      procedure Claim (Place : out Natural) is
      begin
         Place := 0;
         for Each in Used'Range loop
            if not Used (Each) then
               Used (Each) := True;
               Place := Each;
               return;
            end if;
         end loop;
      end Claim;

      procedure Free (Place : Place_Range) is
      begin
         Used (Place) := False;
      end Free;
   end Pool;

   --  When the model was last asked, for the watch that unloads it.
   protected Activity is
      procedure Begin_Ask;
      --  A job is under way.
      procedure End_Ask (Watch : out Boolean);
      --  It is over. Watch says whether the watch is to be told, as it is
      --  not watching already.
      procedure Set_Timeout (To : Duration);
      function Timeout return Duration;
      procedure Stop;
      --  The program is ending.
      entry Stopped;
      --  Open from then on.
      procedure Check (Expired : out Boolean);
      --  Whether the model has been unasked for long enough to let go; if
      --  so, the watch is ended.
   private
      Busy     : Natural := 0;
      Last     : Ada.Real_Time.Time := Ada.Real_Time.Clock;
      Limit    : Duration := Default_Idle_Timeout;
      Watching : Boolean := False;
      Ending   : Boolean := False;
   end Activity;

   protected body Activity is
      procedure Begin_Ask is
      begin
         Busy := Busy + 1;
      end Begin_Ask;

      procedure End_Ask (Watch : out Boolean) is
      begin
         Busy := Busy - 1;
         Last := Ada.Real_Time.Clock;
         Watch := not Watching and then not Ending;
         Watching := Watching or else Watch;
      end End_Ask;

      procedure Set_Timeout (To : Duration) is
      begin
         Limit := To;
      end Set_Timeout;

      function Timeout return Duration is (Limit);

      procedure Stop is
      begin
         Ending := True;
      end Stop;

      entry Stopped when Ending is
      begin
         null;
      end Stopped;

      procedure Check (Expired : out Boolean) is
         use type Ada.Real_Time.Time;
         use type Ada.Real_Time.Time_Span;
      begin
         Expired := Busy = 0
           and then Limit < Duration'Last
           and then Ada.Real_Time.Clock - Last >= Ada.Real_Time.To_Time_Span (Limit);
         if Expired then
            Watching := False;
         end if;
      end Check;
   end Activity;

   --  The watch: told when a job has ended, it looks now and then until
   --  the model has not been asked for the timeout, and unloads it. It is
   --  idle, and ends with the program, the rest of the time.
   task Watch is
      entry Start_Watching;
   end Watch;

   task body Watch is
      Slice : constant Duration := 1.0;
      Let_Go : Boolean;
   begin
      loop
         select
            accept Start_Watching;
         or
            terminate;
         end select;
         Looking :
         loop
            select
               Activity.Stopped;
               exit Looking;
            or
               delay Slice;
            end select;
            Activity.Check (Let_Go);
            if Let_Go then
               MLX.Unload;
               exit Looking;
            end if;
         end loop Looking;
      end loop;
   end Watch;

   --  The tasks that ask the binding, one to a place. A task waits for its
   --  ask and, ending, for the next; while the program ends it is let go.
   task type Worker is
      entry Ask
        (For_Place     : Place_Range;
         For_Directory : US.Unbounded_String;
         For_System    : US.Unbounded_String;
         For_Prompt    : US.Unbounded_String;
         For_Tuning    : Parameters);
   end Worker;

   Workers : array (Place_Range) of Worker;

   task body Worker is
      Place     : Place_Range := 1;
      Directory : US.Unbounded_String;
      Told      : US.Unbounded_String;
      Prompt    : US.Unbounded_String;
      Tuning    : Parameters;
   begin
      loop
         select
            accept Ask
              (For_Place     : Place_Range;
               For_Directory : US.Unbounded_String;
               For_System    : US.Unbounded_String;
               For_Prompt    : US.Unbounded_String;
               For_Tuning    : Parameters)
            do
               Place := For_Place;
               Directory := For_Directory;
               Told := For_System;
               Prompt := For_Prompt;
               Tuning := For_Tuning;
            end Ask;
         or
            terminate;
         end select;

         declare
            Where    : Text_Access := Copy (Directory);
            System_P : Text_Access := (if US.Length (Told) = 0 then null else Copy (Told));
            Asked    : Text_Access := Copy (Prompt);
            Reply    : aliased C.char_array (0 .. Max_Reply) := [others => C.nul];
            Why      : aliased C.char_array (0 .. Max_Message) := [others => C.nul];
            Result   : C.int := 0;

            function Number (Value : Integer) return C.int is (C.int (Value));
            function Real (Value : Float) return C.C_float is (C.C_float (Value));

            procedure Release is
            begin
               Free (Where);
               Free (System_P);
               Free (Asked);
            end Release;
         begin
            Activity.Begin_Ask;
            if not Places (Place).Cancelling then
               Result :=
                 MX_Generate
                   (Directory          => Where (Where'First)'Address,
                    System_Prompt      => (if System_P = null then Standard.System.Null_Address
                                           else System_P (System_P'First)'Address),
                    Prompt             => Asked (Asked'First)'Address,
                    Max_Tokens         => Number (Tuning.Max_Tokens),
                    Temperature        => Real (Tuning.Temperature),
                    Top_P              => Real (Tuning.Top_P),
                    Top_K              => Number (Tuning.Top_K),
                    Min_P              => Real (Tuning.Min_P),
                    Repetition_Penalty => Real (Tuning.Repetition_Penalty),
                    Repetition_Context => Number (Tuning.Repetition_Context),
                    Seed               => Interfaces.Integer_64 (Tuning.Seed),
                    Thinking           => (case Tuning.Thinking is
                                              when Model_Default => -1,
                                              when Off           => 0,
                                              when On            => 1),
                    Job_Number         => Interfaces.Integer_64 (Place),
                    Reply_Text         => Reply'Address,
                    Reply_Room         => Reply'Length,
                    Message            => Why'Address,
                    Message_Room       => Why'Length);
            else
               Result := 2;
            end if;
            Release;
            declare
               Tell : Boolean;
            begin
               Activity.End_Ask (Tell);
               if Tell then
                  Watch.Start_Watching;
               end if;
            end;

            if Result = 1 and then not Places (Place).Cancelling then
               Places (Place).Finish (Done, C.To_Ada (Reply));
            elsif Result = 0 and then not Places (Place).Cancelling then
               declare
                  Said : constant String := C.To_Ada (Why);
               begin
                  Places (Place).Finish (Failed, (if Said = "" then "The model did not reply" else Said));
               end;
            else
               Places (Place).Finish (Cancelled, "");
            end if;
         exception
            when others =>
               Release;
               Places (Place).Finish (Failed, "The model could not be asked");
         end;
      end loop;
   end Worker;

   procedure Set_Idle_Timeout (To : Duration) is
   begin
      Activity.Set_Timeout (To);
   end Set_Idle_Timeout;

   function Idle_Timeout return Duration is (Activity.Timeout);

   procedure Shutdown is
   begin
      Activity.Stop;
      MLX.Cancel_All;
   end Shutdown;

   function State (Item : Job) return States is
     (if Item.Place = 0 then Idle else Places (Item.Place).State);

   procedure Start
     (Item      : in out Job;
      Directory : String;
      Prompt    : String;
      System_Prompt : String := "";
      Tuning    : Parameters := (others => <>)) is
   begin
      if Item.Place = 0 then
         Pool.Claim (Item.Place);
         if Item.Place = 0 then
            raise Capacity_Error with "all" & Max_Jobs'Image & " jobs are in use";
         end if;
      end if;
      Places (Item.Place).Begin_Ask;
      Workers (Item.Place).Ask
        (Item.Place, US.To_Unbounded_String (Directory), US.To_Unbounded_String (System_Prompt),
         US.To_Unbounded_String (Prompt), Tuning);
   end Start;

   function Raw_Text (Item : Job) return String is (Places (Item.Place).Words);

   function Text (Item : Job) return String is
     (case State (Item) is
         when Done   => Without_Thinking (Places (Item.Place).Words),
         when others => Places (Item.Place).Words);

   procedure Cancel (Item : in out Job) is
   begin
      if Item.Place /= 0 and then Places (Item.Place).State = Running then
         Places (Item.Place).Request_Cancel;
         MX_Cancel (Interfaces.Integer_64 (Item.Place));
      end if;
   end Cancel;

   procedure Reset (Item : in out Job) is
   begin
      if Item.Place /= 0 then
         Places (Item.Place).Forget;
         Pool.Free (Item.Place);
         Item.Place := 0;
      end if;
   end Reset;

end MLX.Jobs;
