with Speech.Capture;
with Transcribe.Sessions;

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
   type Engine_Array is array (Slot) of Engines;

   protected Board is
      procedure Begin_Job
        (Which : Slot; Engine : Engines; Job : out Natural);
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
      function Engine_Of (Which : Slot) return Engines;
      function Phase (Which : Slot; Job : Natural) return States;
      --  How the job stands, Idle if it was reset (or a later one began).
      function Said_Why (Which : Slot) return String;
   private
      Current   : Job_Numbers := [others => 0];
      Counter   : Natural := 0;
      Stated    : State_Array := [others => Idle];
      Early     : Flag_Array := [others => False];
      Said      : Message_Array := [others => [others => ' ']];
      Said_Last : Job_Numbers := [others => 0];
      Using     : Engine_Array := [others => System];
   end Board;

   protected body Board is

      procedure Begin_Job
        (Which : Slot; Engine : Engines; Job : out Natural) is
      begin
         Using (Which) := Engine;
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
               Wake := Using (Which) = System;
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
         Wake := Stated (Which) = Listening and then Using (Which) = System;
         Current (Which) := 0;
         Stated (Which) := Idle;
         Early (Which) := False;
         Said_Last (Which) := 0;
      end Forget;

      function Stand (Which : Slot) return States is (Stated (Which));

      function Engine_Of (Which : Slot) return Engines is (Using (Which));

      function Phase (Which : Slot; Job : Natural) return States is
        (if Current (Which) = Job then Stated (Which) else Idle);

      function Said_Why (Which : Slot) return String is
        (Said (Which) (1 .. Said_Last (Which)));

   end Board;

   protected Live is
      procedure Put (Which : Slot; Words : String; Cut : Boolean);
      procedure Get (Which : Slot; Into : in out Transcript);
   private
      Texts : Transcripts;
   end Live;
   --  What the model has made of the speech so far, for each slot that
   --  uses it: written by the slot's task, read by the caller's polling.

   protected body Live is

      procedure Put (Which : Slot; Words : String; Cut : Boolean) is
         Used : constant Natural := Natural'Min (Words'Length, Text_Capacity);
      begin
         Texts (Which).Length := Used;
         Texts (Which).Truncated := Cut or else Used < Words'Length;
         Texts (Which).Text (1 .. Used) :=
           Words (Words'First .. Words'First + Used - 1);
      end Put;

      procedure Get (Which : Slot; Into : in out Transcript) is
      begin
         Into := Texts (Which);
      end Get;

   end Live;

   function Trimmed (Words : String) return String is
      First : Positive := Words'First;
      Last  : Natural := Words'Last;
   begin
      while First <= Last and then Words (First) in ' ' | ASCII.HT | ASCII.LF
      loop
         First := First + 1;
      end loop;
      while Last >= First and then Words (Last) in ' ' | ASCII.HT | ASCII.LF
      loop
         Last := Last - 1;
      end loop;
      return Words (First .. Last);
   end Trimmed;

   procedure Run_Model (Which : Slot; Job : Natural; Path : String);
   --  Hear the microphone and make it text with the model, until the job
   --  is told to stop (or is reset); then the rest. In the slot's task.

   procedure Run_Model (Which : Slot; Job : Natural; Path : String) is
      Pause      : constant Duration := 0.05;
      Item       : Transcribe.Sessions.Session;
      Ok         : Boolean;
      Why        : String (1 .. Max_Message);
      Why_Last   : Natural;
      Stop_Now   : Boolean;
      Audio      : Transcribe.Samples (1 .. Transcribe.Sample_Rate);
      Audio_Last : Natural;
      Words      : String (1 .. Text_Capacity);
      Words_Last : Natural;
      Cut        : Boolean;
      Changed    : Boolean;

      procedure Fail (Reason : String) is
      begin
         Capture.Close (Which);
         Board.End_Job (Which, Job, False, Reason);
      end Fail;

      procedure Show is
      begin
         Transcribe.Sessions.Text (Item, Words, Words_Last, Cut);
         Live.Put (Which, Trimmed (Words (1 .. Words_Last)), Cut);
      end Show;

      procedure Feed_What_Came (Any : out Boolean) is
      begin
         Capture.Read (Which, Audio, Audio_Last);
         Any := Audio_Last >= Audio'First;
         if Any then
            Transcribe.Sessions.Feed
              (Item, Audio (Audio'First .. Audio_Last), Changed, Ok, Why,
               Why_Last);
            if Ok and then Changed then
               Show;
            end if;
         end if;
      end Feed_What_Came;

      Any : Boolean;
   begin
      Live.Put (Which, "", False);
      Capture.Begin_Capture (Which, Ok, Why, Why_Last);
      if not Ok then
         Board.End_Job (Which, Job, False, Why (1 .. Why_Last));
         return;
      end if;
      Board.Begin_Waiting (Which, Job, Stop_Now);
      --  Heard from now on, while the model loads. (Stopped or reset
      --  meanwhile, the loop below sees it.)
      if Stop_Now and then Board.Phase (Which, Job) = Idle then
         Capture.Close (Which);
         return;
      end if;
      Transcribe.Sessions.Open (Item, Path, Ok, Why, Why_Last);
      if not Ok then
         Fail (Why (1 .. Why_Last));
         return;
      end if;
      Transcribe.Sessions.Begin_Stream (Item, Ok, Why, Why_Last);
      if not Ok then
         Fail (Why (1 .. Why_Last));
         return;
      end if;
      while Board.Phase (Which, Job) = Listening loop
         Feed_What_Came (Any);
         if not Ok then
            Fail (Why (1 .. Why_Last));
            return;
         end if;
         if not Any then
            delay Pause;
         end if;
      end loop;
      Capture.Stop (Which);
      if Board.Phase (Which, Job) = Idle then
         Capture.Close (Which);  --  reset: what was heard is not wanted
         return;
      end if;
      loop
         Feed_What_Came (Any);
         if not Ok then
            Fail (Why (1 .. Why_Last));
            return;
         end if;
         exit when not Any;
      end loop;
      Capture.Close (Which);
      Transcribe.Sessions.Finalize_Stream (Item, Ok, Why, Why_Last);
      if not Ok then
         Board.End_Job (Which, Job, False, Why (1 .. Why_Last));
         return;
      end if;
      Transcribe.Sessions.Text (Item, Words, Words_Last, Cut);
      declare
         Said : constant String := Trimmed (Words (1 .. Words_Last));
      begin
         Heard (Which).Length := Said'Length;
         Heard (Which).Truncated := Cut;
         Heard (Which).Text (1 .. Said'Length) := Said;
      end;
      Board.End_Job (Which, Job, True, "");
   end Run_Model;

   task type Worker
     with Storage_Size => 4 * 1024 * 1024
   is
      entry Run
        (Which  : Slot;
         Job    : Natural;
         Engine : Engines;
         File   : String);
      entry Stop;
      --  Only called when the task is, or is about to be, waiting for it.
   end Worker;

   task body Worker is
      Mine : Slot := 1;
      Wher : Natural := 0;
      How  : Engines := System;
      Path : String (1 .. Max_Path);
      Plen : Natural := 0;
   begin
      loop
         select
            --  Take what to do, and let the caller go on.
            accept Run
              (Which  : Slot;
               Job    : Natural;
               Engine : Engines;
               File   : String) do
               Mine := Which;
               Wher := Job;
               How := Engine;
               Plen := File'Length;
               Path (1 .. Plen) := File;
            end Run;
            if How = Model then
               Run_Model (Mine, Wher, Path (1 .. Plen));
            else
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
            end if;
         or
            terminate;
         end select;
      end loop;
   end Worker;

   type Worker_Access is access Worker;

   Workers : array (Slot) of Worker_Access := [others => null];
   --  One to a slot, so that starting a job never waits for another's.
   --  Made when the slot is first started: a task costs its stack, and
   --  most slots are never used. Only a slot that has been started has
   --  a job to stop or reset, so its task is there.

   procedure Start
     (Which      : Slot;
      Engine     : Engines := System;
      Model_File : String  := "")
   is
      Job : Natural;
   begin
      Board.Begin_Job (Which, Engine, Job);
      if Workers (Which) = null then
         Workers (Which) := new Worker;
      end if;
      Workers (Which).Run (Which, Job, Engine, Model_File);
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
     (if Board.Stand (Which) /= Listening then 0.0
      elsif Board.Engine_Of (Which) = Model then Capture.Loudness (Which)
      else Speech.Level (Which));

   procedure Heard_So_Far (Which : Slot; Into : in out Transcript) is
   begin
      if Board.Stand (Which) = Listening then
         if Board.Engine_Of (Which) = Model then
            Live.Get (Which, Into);
         else
            Speech.Peek (Which, Into);
         end if;
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
