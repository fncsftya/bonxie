--  Asking a model in the background. A Job is one ask at a time: Start it
--  with a prompt, the system prompt (what the model is told it is for) and
--  the parameters that tune it, and look at State now and then (it does
--  not wait); when it is Done, Text is the reply. The asking is tasked
--  here, in Ada, one task to a Job that is started, and the binding
--  underneath only waits for the model.
--
--  The model runs one ask at a time, whatever the number of jobs: the
--  others wait their turn, and still show Running. There are Max_Jobs at
--  once.
package MLX.Jobs is

   Max_Jobs : constant := 4;

   type States is (Idle, Running, Done, Failed, Cancelled);
   --  Idle: no ask was started, or it was forgotten (Reset). Done: the
   --  model replied, and Text is what it said. Failed: it could not, and
   --  Text says why. Cancelled: it was stopped.

   type Job is limited private;

   function State (Item : Job) return States;

   procedure Start
     (Item      : in out Job;
      Directory : String;
      Prompt    : String;
      System_Prompt : String := "";
      Tuning    : Parameters := (others => <>))
     with Pre  => State (Item) /= Running
                  and then Directory'Length in 1 .. Max_Path
                  and then Prompt'Length > 0,
          Post => State (Item) = Running;
   --  Begin to ask the model in Directory, loading it if it is not
   --  loaded. System_Prompt may be "" for none. The strings are copied.
   --  Raises Capacity_Error if Max_Jobs are in use: a job is in use from
   --  its first Start to its Reset.

   Capacity_Error : exception;

   function Text (Item : Job) return String
     with Pre  => State (Item) in Done | Failed,
          Post => Text'Result'Length <= Max_Reply;
   --  The reply, less what the model thought aloud (see Without_Thinking),
   --  or why it failed.

   function Raw_Text (Item : Job) return String
     with Pre  => State (Item) = Done,
          Post => Raw_Text'Result'Length <= Max_Reply;
   --  The reply as the model said it.

   procedure Cancel (Item : in out Job);
   --  Stop the ask, if it is running, without waiting: State is Cancelled
   --  when the binding has seen to it.

   procedure Reset (Item : in out Job)
     with Pre  => State (Item) /= Running,
          Post => State (Item) = Idle;
   --  Forget how the last ask ended, and give up the job's place.

   --  Memory

   Default_Idle_Timeout : constant Duration := 300.0;

   procedure Set_Idle_Timeout (To : Duration)
     with Pre => To > 0.0;
   --  How long the model is kept in memory once no job has asked it, before
   --  it is unloaded (the next job loads it again, which takes some
   --  seconds). Duration'Last for always. To begin with, Default_Idle_Timeout.

   function Idle_Timeout return Duration;

   procedure Shutdown;
   --  For when the program is ending: stop every job, and the watch that
   --  unloads the model, without waiting. Jobs that are not stopped are
   --  waited for, as is the watch while one is under way.

private

   type Job is limited record
      Place : Natural range 0 .. Max_Jobs := 0;
      --  0 until it is started, and after it is reset.
   end record;

end MLX.Jobs;
