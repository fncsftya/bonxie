with Ada.Real_Time;
with Speech.Capture;
with Speech.Parakeet;
with Speech.Streams;
with Speech.Windows;

package body Speech.Jobs.Core
  with SPARK_Mode
is

   use type Ada.Real_Time.Time;

   subtype Message_Text is String (1 .. Max_Message);
   subtype Directory_Text is String (1 .. Max_Path);

   type Job_Numbers is array (Slot) of Natural;
   type Directory_Lengths is array (Slot) of Natural range 0 .. Max_Path;
   type Message_Lengths is array (Slot) of Natural range 0 .. Max_Message;
   type State_Array is array (Slot) of States;
   type Flag_Array is array (Slot) of Boolean;
   type Message_Array is array (Slot) of Message_Text;
   type Directory_Array is array (Slot) of Directory_Text;
   type Engine_Array is array (Slot) of Engines;
   type Transcripts is array (Slot) of Transcript;

   ---------------------------------------------------------------------
   --  What is shared. Everything that more than one task can reach is
   --  here, in protected objects: how each job stands (Board), what is
   --  heard of it (Live), and the gates that tell a slot's task to go on
   --  (Run_Gates, Stop_Gates). A task's own work is its own, on its own
   --  stack: that GNATprove sees nothing else is shared is the proof that
   --  there are no races.

   protected Board is
      procedure Begin_Job
        (Which : Slot; Engine : Engines; Directory : String; Job : out Natural)
        with Pre => Directory'Length <= Max_Path;
      --  Say it is Starting: Job tells this one from an earlier, reset one.
      procedure Job_Of
        (Which     : Slot;
         Job       : out Natural;
         Engine    : out Engines;
         Directory : in out Directory_Text;
         Last      : out Natural)
        with Post => Last <= Max_Path;
      --  What the slot is to do: the latest begun (Job is 0 if there is
      --  none, or it was reset); Directory (1 .. Last) is the model's.
      procedure Begin_Waiting
        (Which : Slot; Job : Natural; Stop_Now : out Boolean);
      --  The microphone is listening: Listening, unless it was to stop
      --  while it started, or was reset, when Stop_Now says not to wait.
      procedure Request_Stop (Which : Slot; Wake : out Boolean);
      --  Wake says the task is to be told to go on (it is waiting).
      procedure End_Job
        (Which : Slot; Job : Natural; Ok : Boolean; Why : String)
        with Pre => Why'First >= 1 and then Why'Last < Positive'Last / 2;
      --  Ignored if the slot was reset since.
      procedure Forget (Which : Slot; Wake : out Boolean);
      function Stand (Which : Slot) return States;
      function Engine_Of (Which : Slot) return Engines;
      function Phase (Which : Slot; Job : Natural) return States;
      --  How the job stands, Idle if it was reset (or a later one began).
      function Said_Why (Which : Slot) return String
        with Post => Said_Why'Result'Length <= Max_Message;
   private
      Current   : Job_Numbers := [others => 0];
      Counter   : Natural := 0;
      Stated    : State_Array := [others => Idle];
      Early     : Flag_Array := [others => False];
      Said      : Message_Array := [others => [others => ' ']];
      Said_Last : Message_Lengths := [others => 0];
      Using     : Engine_Array := [others => System];
      Dirs      : Directory_Array := [others => [others => ' ']];
      Dir_Last  : Directory_Lengths := [others => 0];
   end Board;

   protected body Board is

      procedure Begin_Job
        (Which : Slot; Engine : Engines; Directory : String; Job : out Natural) is
      begin
         Using (Which) := Engine;
         Counter := (if Counter = Natural'Last then 1 else Counter + 1);
         Current (Which) := Counter;
         Stated (Which) := Starting;
         Early (Which) := False;
         Said_Last (Which) := 0;
         Dir_Last (Which) := Directory'Length;
         Dirs (Which) (1 .. Directory'Length) := Directory;
         Job := Counter;
      end Begin_Job;

      procedure Job_Of
        (Which     : Slot;
         Job       : out Natural;
         Engine    : out Engines;
         Directory : in out Directory_Text;
         Last      : out Natural) is
      begin
         Job := Current (Which);
         Engine := Using (Which);
         Last := Dir_Last (Which);
         Directory (1 .. Last) := Dirs (Which) (1 .. Last);
      end Job_Of;

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
      procedure Put (Which : Slot; Words : String; Cut : Boolean; Settled : Natural := 0)
        with Pre => Words'First >= 1 and then Words'Last < Positive'Last;
      --  What is heard so far, the first Settled bytes of it settled, for the caller's polling.
      procedure Get (Which : Slot; Into : out Transcript);
      procedure Put_Final (Which : Slot; Words : String; Cut : Boolean)
        with Pre => Words'First >= 1 and then Words'Last < Positive'Last;
      --  What was heard in all, for the caller to take once it is Done.
      procedure Get_Final (Which : Slot; Into : out Transcript);
   private
      Texts  : Transcripts;
      Finals : Transcripts;
   end Live;
   --  What each slot's task has made of the speech, and the caller reads.

   protected body Live is

      procedure Put (Which : Slot; Words : String; Cut : Boolean; Settled : Natural := 0) is
         Used : constant Natural := Natural'Min (Words'Length, Text_Capacity);
      begin
         Texts (Which).Length := Used;
         Texts (Which).Settled := Natural'Min (Settled, Used);
         Texts (Which).Truncated := Cut or else Used < Words'Length;
         Texts (Which).Text (1 .. Used) :=
           Words (Words'First .. Words'First + Used - 1);
      end Put;

      procedure Get (Which : Slot; Into : out Transcript) is
      begin
         Into := Texts (Which);
      end Get;

      procedure Put_Final (Which : Slot; Words : String; Cut : Boolean) is
         Used : constant Natural := Natural'Min (Words'Length, Text_Capacity);
      begin
         Finals (Which).Length := Used;
         Finals (Which).Truncated := Cut or else Used < Words'Length;
         Finals (Which).Text (1 .. Used) :=
           Words (Words'First .. Words'First + Used - 1);
      end Put_Final;

      procedure Get_Final (Which : Slot; Into : out Transcript) is
      begin
         Into := Finals (Which);
      end Get_Final;

   end Live;

   --  The gate of a slot's task: it waits at the gate until it is opened
   --  (a job to do, for Run_Gates; a listening to stop, for Stop_Gates),
   --  or the program is ending.
   protected type Gate is
      procedure Release;
      procedure Close_Down;
      entry Pass (Quit : out Boolean);
   private
      Ready    : Boolean := False;
      Quitting : Boolean := False;
   end Gate;

   protected body Gate is

      procedure Release is
      begin
         Ready := True;
      end Release;

      procedure Close_Down is
      begin
         Quitting := True;
         Ready := True;
      end Close_Down;

      entry Pass (Quit : out Boolean) when Ready is
      begin
         Quit := Quitting;
         Ready := Quitting;
      end Pass;

   end Gate;

   Run_Gates  : array (Slot) of Gate;
   --  One to a slot, so that starting a job never waits for another's.
   Stop_Gates : array (Slot) of Gate;

   function Trimmed (Words : String) return String
     with Pre  => Words'First >= 1 and then Words'Last >= 0 and then Words'Last < Positive'Last,
          Post => Trimmed'Result'Length <= Words'Length
                  and then Trimmed'Result'First >= 1
                  and then Trimmed'Result'Last < Positive'Last;

   function Trimmed (Words : String) return String is
      First : Positive := Words'First;
      Last  : Natural := Words'Last;
   begin
      while First <= Last and then Words (First) in ' ' | ASCII.HT | ASCII.LF
      loop
         pragma Loop_Invariant (First in Words'First .. Words'Last + 1);
         pragma Loop_Invariant (First <= Last);
         pragma Loop_Variant (Increases => First);
         First := First + 1;
      end loop;
      while Last >= First and then Words (Last) in ' ' | ASCII.HT | ASCII.LF
      loop
         pragma Loop_Invariant (Last in First - 1 .. Words'Last);
         pragma Loop_Variant (Decreases => Last);
         Last := Last - 1;
      end loop;
      return Words (First .. Last);
   end Trimmed;

   procedure Run_Model (Which : Slot; Job : Natural; Path : String)
     with Pre => Path'First = 1 and then Path'Length <= Max_Path;
   --  Hear the microphone and make it text with the model, until the job
   --  is told to stop (or is reset); then the rest. In the slot's task.

   procedure Run_Model (Which : Slot; Job : Natural; Path : String) is
      Pause      : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Milliseconds (50);
      Item       : Streams.Stream;
      --  What it hears with: a window of sound, so it is large, and the
      --  task's own (the stack of a task is made for it).
      Ok         : Boolean;
      Why        : String (1 .. Max_Message);
      Why_Last   : Natural;
      Stop_Now   : Boolean;
      Audio      : Windows.Samples (1 .. Windows.Rate);
      Audio_Last : Natural;
      Changed    : Boolean;
      Said       : Transcript;

      procedure Fail (Reason : String) is
      begin
         Capture.Close (Which);
         Board.End_Job (Which, Job, False, Reason);
      end Fail;

      procedure Show is
      begin
         Streams.Text (Item, Said);
         Live.Put (Which, Trimmed (Image (Said)), Said.Truncated, Said.Settled);
      end Show;

      procedure Feed_What_Came (Any : out Boolean) is
      begin
         Capture.Read (Which, Audio, Audio_Last);
         Any := Audio_Last >= Audio'First;
         if Any then
            Streams.Feed (Item, Audio (Audio'First .. Audio_Last), Changed, Ok, Why, Why_Last);
            if Ok and then Changed then
               Show;
            end if;
         end if;
      end Feed_What_Came;

      Any   : Boolean;
      Next  : Ada.Real_Time.Time;
      Phase : States;
      --  How the job stands: looked at, then used (what is shared is not
      --  to be looked at in the middle of a condition).
   begin
      Streams.Reset (Item);
      Live.Put (Which, "", False);
      Capture.Begin_Capture (Which, Ok, Why, Why_Last);
      if not Ok then
         Board.End_Job (Which, Job, False, Why (1 .. Why_Last));
         return;
      end if;
      Board.Begin_Waiting (Which, Job, Stop_Now);
      --  Heard from now on, while the model loads. (Stopped or reset
      --  meanwhile, the loop below sees it.)
      Phase := Board.Phase (Which, Job);
      if Stop_Now and then Phase = Idle then
         Capture.Close (Which);
         return;
      end if;
      if Path = "" then
         Fail ("There is no folder for the model");
         return;
      end if;
      Parakeet.Load (Path, Ok, Why, Why_Last);
      if not Ok then
         Fail (Why (1 .. Why_Last));
         return;
      end if;
      Next := Ada.Real_Time.Clock;
      Phase := Board.Phase (Which, Job);
      while Phase = Listening loop
         pragma Loop_Invariant (Streams.Consistent (Item));
         pragma Loop_Invariant (Why_Last <= Max_Message);
         Feed_What_Came (Any);
         if not Ok then
            Fail (Why (1 .. Why_Last));
            return;
         end if;
         if not Any then
            Next := Next + Pause;
            pragma Annotate
              (GNATprove, False_Positive, "range check might fail",
               "the clock does not run out: it counts in nanoseconds, for centuries");
            delay until Next;
         end if;
         Phase := Board.Phase (Which, Job);
      end loop;
      Capture.Stop (Which);
      Phase := Board.Phase (Which, Job);
      if Phase = Idle then
         Capture.Close (Which);  --  reset: what was heard is not wanted
         return;
      end if;
      loop
         pragma Loop_Invariant (Streams.Consistent (Item));
         pragma Loop_Invariant (Why_Last <= Max_Message);
         Feed_What_Came (Any);
         if not Ok then
            Fail (Why (1 .. Why_Last));
            return;
         end if;
         exit when not Any;
      end loop;
      Capture.Close (Which);
      Streams.Finish (Item, Ok, Why, Why_Last);
      if not Ok then
         Board.End_Job (Which, Job, False, Why (1 .. Why_Last));
         return;
      end if;
      Streams.Text (Item, Said);
      Live.Put_Final (Which, Trimmed (Image (Said)), Said.Truncated);
      Board.End_Job (Which, Job, True, "");
   end Run_Model;

   procedure Run_System (Which : Slot; Job : Natural);
   --  Listen with the system's engine (SpeechAnalyzer) until told to
   --  stop. In the slot's task.

   procedure Run_System (Which : Slot; Job : Natural) is
      Ok       : Boolean;
      Why      : String (1 .. Max_Message);
      Last     : Natural;
      Stop_Now : Boolean;
      Quit     : Boolean;
      Said     : Transcript;
      pragma Warnings
        (GNATprove, Off, "is set by ""Pass"" but not used",
         Reason => "if the program is ending, the listening is ended all the same");
   begin
      Begin_Listening (Which, Ok, Why, Last);
      if not Ok then
         Board.End_Job (Which, Job, False, Why (1 .. Last));
         return;
      end if;
      Board.Begin_Waiting (Which, Job, Stop_Now);
      if not Stop_Now then
         Stop_Gates (Which).Pass (Quit);
         --  (If the program is ending, what was heard is of no use.)
      end if;
      End_Listening (Which, Said, Ok, Why, Last);
      if Ok then
         Live.Put_Final (Which, Image (Said), Said.Truncated);
      end if;
      Board.End_Job (Which, Job, Ok, Why (1 .. Last));
   end Run_System;

   procedure Do_Job (Which : Slot);
   --  What the slot's task has been told to do, if there is any.

   procedure Do_Job (Which : Slot) is
      Job       : Natural;
      Engine    : Engines;
      Directory : Directory_Text := [others => ' '];
      Last      : Natural;
   begin
      Board.Job_Of (Which, Job, Engine, Directory, Last);
      if Job = 0 then
         return;  --  it was reset before the task came to it
      end if;
      if Engine = Model then
         Run_Model (Which, Job, Directory (1 .. Last));
      else
         Run_System (Which, Job);
      end if;
   end Do_Job;

   protected Numbers is
      procedure Next (Which : out Slot);
   private
      Given : Natural range 0 .. Slot_Count := 0;
   end Numbers;
   --  Which slot a task is for: they are told, as they begin, one each.

   protected body Numbers is
      procedure Next (Which : out Slot) is
      begin
         Given := Natural'Min (Given + 1, Slot_Count);
         Which := Given;
      end Next;
   end Numbers;

   task type Worker
     with Storage_Size => 8 * 1024 * 1024;
   --  A slot's task. Its stack holds what it hears with, which is more
   --  than most tasks' (the stack is address space, not memory, until it
   --  is used).

   pragma Annotate
     (GNATprove, Intentional, "might terminate",
      "a task ends only when the program does: see Shutdown");

   task body Worker is
      Mine : Slot;
      Quit : Boolean;
   begin
      Numbers.Next (Mine);
      loop
         Run_Gates (Mine).Pass (Quit);
         exit when Quit;
         Do_Job (Mine);
      end loop;
   end Worker;

   Workers : array (Slot) of Worker;
   --  One to a slot, from the start, so that starting a job never waits
   --  for another's (and nothing is made while the program runs).

   procedure Start_Job
     (Which           : Slot;
      Engine          : Engines := System;
      Model_Directory : String  := "")
   is
      Job : Natural;
      pragma Warnings
        (GNATprove, Off, "is set by ""Begin_Job"" but not used",
         Reason => "the task finds which job it is to do (Job_Of), when it comes to it");
   begin
      Board.Begin_Job (Which, Engine, Model_Directory, Job);
      Run_Gates (Which).Release;
   end Start_Job;

   procedure Stop_Job (Which : Slot) is
      Wake : Boolean;
   begin
      Board.Request_Stop (Which, Wake);
      if Wake then
         Stop_Gates (Which).Release;
      end if;
   end Stop_Job;

   function Job_State (Which : Slot) return States is (Board.Stand (Which));

   function Job_Loudness (Which : Slot) return Float is
      Standing : constant States := Board.Stand (Which);
      Hearing  : constant Engines := Board.Engine_Of (Which);
   begin
      if Standing /= Listening then
         return 0.0;
      elsif Hearing = Model then
         return Capture.Loudness (Which);
      else
         return Speech.Level (Which);
      end if;
   end Job_Loudness;

   procedure Words_So_Far (Which : Slot; Into : in out Transcript) is
      Standing : constant States := Board.Stand (Which);
      Hearing  : constant Engines := Board.Engine_Of (Which);
   begin
      if Standing = Listening then
         if Hearing = Model then
            Live.Get (Which, Into);
         else
            Speech.Peek (Which, Into);
         end if;
      else
         Into.Length := 0;
         Into.Truncated := False;
      end if;
   end Words_So_Far;

   function Job_Message (Which : Slot) return String is (Board.Said_Why (Which));

   procedure Take_Words (Which : Slot; Into : out Transcript) is
      Wake : Boolean;
      pragma Warnings
        (GNATprove, Off, "is set by ""Forget"" but not used",
         Reason => "a job that is Done is not listening, so there is no one to wake");
   begin
      Live.Get_Final (Which, Into);
      Board.Forget (Which, Wake);
   end Take_Words;

   procedure Reset_Job (Which : Slot) is
      Wake : Boolean;
   begin
      Board.Forget (Which, Wake);
      if Wake then
         Stop_Gates (Which).Release;
      end if;
   end Reset_Job;

   procedure End_Jobs is
   begin
      for Which in Slot loop
         Run_Gates (Which).Close_Down;
         Stop_Gates (Which).Close_Down;
      end loop;
   end End_Jobs;

end Speech.Jobs.Core;
