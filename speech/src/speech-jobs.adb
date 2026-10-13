package body Speech.Jobs is

   type Transcripts is array (Slot) of Transcript;

   Heard : Transcripts;
   --  What each slot's task writes, while the slot is Finishing (and no
   --  one else reads), and the caller reads once it is Done.

   subtype Message_Text is String (1 .. Max_Message);

   type Job_Numbers is array (Slot) of Natural;
   type State_Array is array (Slot) of States;
   type Flag_Array is array (Slot) of Boolean;
   type Message_Array is array (Slot) of Message_Text;

   protected Board is
      procedure Begin_Job (Which : Slot; Job : out Natural);
      --  Say it is Starting: Job tells this one from an earlier, reset one.
      procedure Begin_Waiting
        (Which : Slot; Job : Natural; Stop_Now : out Boolean);
      --  The microphone is listening: Listening, unless it was to stop
      --  while it started, or was reset, when Stop_Now says not to wait.
      procedure Request_Stop (Which : Slot; Wake : out Boolean);
      --  Wake says the task is to be told to go on (it is waiting).
      procedure End_Job
        (Which : Slot; Job : Natural; Ok : Boolean; Why : String);
      --  Ignored if the slot was reset since.
      procedure Forget (Which : Slot; Wake : out Boolean);
      function Stand (Which : Slot) return States;
      function Said_Why (Which : Slot) return String;
   private
      Current   : Job_Numbers := [others => 0];
      Counter   : Natural := 0;
      Stated    : State_Array := [others => Idle];
      Early     : Flag_Array := [others => False];
      Said      : Message_Array := [others => [others => ' ']];
      Said_Last : Job_Numbers := [others => 0];
   end Board;

   protected body Board is

      procedure Begin_Job (Which : Slot; Job : out Natural) is
      begin
         Counter := Counter + 1;
         Current (Which) := Counter;
         Stated (Which) := Starting;
         Early (Which) := False;
         Said_Last (Which) := 0;
         Job := Counter;
      end Begin_Job;

      procedure Begin_Waiting
        (Which : Slot; Job : Natural; Stop_Now : out Boolean) is
      begin
         if Current (Which) /= Job then
            Stop_Now := True;
         elsif Early (Which) then
            Stated (Which) := Finishing;
            Stop_Now := True;
         else
            Stated (Which) := Listening;
            Stop_Now := False;
         end if;
      end Begin_Waiting;

      procedure Request_Stop (Which : Slot; Wake : out Boolean) is
      begin
         Wake := False;
         case Stated (Which) is
            when Starting =>
               Early (Which) := True;
               Stated (Which) := Finishing;
            when Listening =>
               Stated (Which) := Finishing;
               Wake := True;
            when others =>
               null;
         end case;
      end Request_Stop;

      procedure End_Job
        (Which : Slot; Job : Natural; Ok : Boolean; Why : String) is
      begin
         if Current (Which) /= Job then
            return;
         end if;
         if Ok then
            Stated (Which) := Done;
         else
            Stated (Which) := Failed;
            Said_Last (Which) := Natural'Min (Why'Length, Max_Message);
            Said (Which) (1 .. Said_Last (Which)) :=
              Why (Why'First .. Why'First + Said_Last (Which) - 1);
         end if;
      end End_Job;

      procedure Forget (Which : Slot; Wake : out Boolean) is
      begin
         Wake := Stated (Which) = Listening;
         Current (Which) := 0;
         Stated (Which) := Idle;
         Early (Which) := False;
         Said_Last (Which) := 0;
      end Forget;

      function Stand (Which : Slot) return States is (Stated (Which));

      function Said_Why (Which : Slot) return String is
        (Said (Which) (1 .. Said_Last (Which)));

   end Board;

   task type Worker
     with Storage_Size => 4 * 1024 * 1024
   is
      entry Run (Which : Slot; Job : Natural);
      entry Stop;
      --  Only called when the task is, or is about to be, waiting for it.
   end Worker;

   task body Worker is
      Mine : Slot := 1;
      Wher : Natural := 0;
   begin
      loop
         select
            --  Take what to do, and let the caller go on.
            accept Run (Which : Slot; Job : Natural) do
               Mine := Which;
               Wher := Job;
            end Run;
            declare
               Ok       : Boolean;
               Why      : String (1 .. Max_Message);
               Last     : Natural;
               Stop_Now : Boolean;
            begin
               Begin_Listening (Mine, Ok, Why, Last);
               if not Ok then
                  Board.End_Job (Mine, Wher, False, Why (1 .. Last));
               else
                  Board.Begin_Waiting (Mine, Wher, Stop_Now);
                  if not Stop_Now then
                     select
                        accept Stop;
                     or
                        --  The program is ending.
                        terminate;
                     end select;
                  end if;
                  End_Listening (Mine, Heard (Mine), Ok, Why, Last);
                  Board.End_Job (Mine, Wher, Ok, Why (1 .. Last));
               end if;
            end;
         or
            terminate;
         end select;
      end loop;
   end Worker;

   Workers : array (Slot) of Worker;
   --  One to a slot, so that starting a job never waits for another's.

   procedure Start (Which : Slot) is
      Job : Natural;
   begin
      Board.Begin_Job (Which, Job);
      Workers (Which).Run (Which, Job);
   end Start;

   procedure Stop (Which : Slot) is
      Wake : Boolean;
   begin
      Board.Request_Stop (Which, Wake);
      if Wake then
         Workers (Which).Stop;
      end if;
   end Stop;

   function State (Which : Slot) return States is (Board.Stand (Which));

   function Loudness (Which : Slot) return Float is
     (if Board.Stand (Which) = Listening
      then Speech.Level (Which) else 0.0);

   procedure Heard_So_Far (Which : Slot; Into : in out Transcript) is
   begin
      if Board.Stand (Which) = Listening then
         Speech.Peek (Which, Into);
      else
         Into.Length := 0;
         Into.Truncated := False;
      end if;
   end Heard_So_Far;

   function Message (Which : Slot) return String is (Board.Said_Why (Which));

   procedure Take (Which : Slot; Into : in out Transcript) is
      Wake : Boolean;
   begin
      Into := Heard (Which);
      Board.Forget (Which, Wake);
      pragma Assert (not Wake);
   end Take;

   procedure Reset (Which : Slot) is
      Wake : Boolean;
   begin
      Board.Forget (Which, Wake);
      if Wake then
         Workers (Which).Stop;
      end if;
   end Reset;

end Speech.Jobs;
