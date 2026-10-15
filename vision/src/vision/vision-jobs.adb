with System;
with Pomarine.Application;

package body Vision.Jobs is

   Max_Path : constant := 1_024;

   type Results is array (Slot) of Result;

   Found : Results;
   --  What each slot's task writes, while the slot is Working (and no one
   --  else reads), and the caller reads once it is Done.

   subtype Message_Text is String (1 .. Max_Message);

   type Job_Numbers is array (Slot) of Natural;
   type State_Array is array (Slot) of States;
   type Message_Array is array (Slot) of Message_Text;

   protected Board is
      procedure Begin_Job (Which : Slot; Job : out Natural);
      --  Say it is Working: Job tells this one from an earlier, reset one.
      procedure End_Job
        (Which : Slot; Job : Natural; Ok : Boolean; Why : String);
      --  Ignored if the slot was reset since.
      procedure Forget (Which : Slot);
      function Stand (Which : Slot) return States;
      function Said_Why (Which : Slot) return String;
   private
      Current   : Job_Numbers := [others => 0];
      Counter   : Natural := 0;
      Stated    : State_Array := [others => Idle];
      Said      : Message_Array := [others => [others => ' ']];
      Said_Last : Job_Numbers := [others => 0];
   end Board;

   protected body Board is

      procedure Begin_Job (Which : Slot; Job : out Natural) is
      begin
         Counter := Counter + 1;
         Current (Which) := Counter;
         Stated (Which) := Working;
         Said_Last (Which) := 0;
         Job := Counter;
      end Begin_Job;

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

      procedure Forget (Which : Slot) is
      begin
         Current (Which) := 0;
         Stated (Which) := Idle;
         Said_Last (Which) := 0;
      end Forget;

      function Stand (Which : Slot) return States is (Stated (Which));

      function Said_Why (Which : Slot) return String is
        (Said (Which) (1 .. Said_Last (Which)));

   end Board;

   procedure Nothing (Data : System.Address) is null;
   --  What the application runs when told a job has ended: the waking up
   --  is all that is wanted, to look at the states.

   task type Worker
     with Storage_Size => 4 * 1024 * 1024
   is
      entry Run (Which : Slot; Job : Natural; File : String);
   end Worker;

   task body Worker is
      Mine : Slot := 1;
      Wher : Natural := 0;
      Name : String (1 .. Max_Path);
      Long : Natural := 0;
   begin
      loop
         select
            --  Take what to do, and let the caller go on.
            accept Run (Which : Slot; Job : Natural; File : String) do
               Mine := Which;
               Wher := Job;
               Long := File'Length;
               Name (1 .. Long) := File;
            end Run;
            declare
               Ok   : Boolean;
               Why  : String (1 .. Max_Message);
               Last : Natural;
            begin
               Recognize (Name (1 .. Long), Found (Mine), Ok, Why, Last);
               Board.End_Job (Mine, Wher, Ok, Why (1 .. Last));
               --  Wake the application's loop, which is waiting for an
               --  event, to see it: it need not look until then.
               declare
                  Posted : constant Boolean := Pomarine.Application.Post (Nothing'Access);
                  pragma Unreferenced (Posted);
                  --  If the queue is full the loop is busy, and will look.
               begin
                  null;
               end;
            end;
         or
            terminate;
         end select;
      end loop;
   end Worker;

   type Worker_Access is access Worker;

   Workers : array (Slot) of Worker_Access := [others => null];
   --  One to a slot, so that starting a job never waits for another's.
   --  Made when the slot is first started: a task costs its stack, and
   --  most slots are never used.

   procedure Start (Which : Slot; File_Name : String) is
      Job : Natural;
   begin
      Board.Begin_Job (Which, Job);
      if Workers (Which) = null then
         Workers (Which) := new Worker;
      end if;
      Workers (Which).Run (Which, Job, File_Name);
   end Start;

   function State (Which : Slot) return States is (Board.Stand (Which));

   function Message (Which : Slot) return String is (Board.Said_Why (Which));

   procedure Take (Which : Slot; Into : in out Result) is
   begin
      Into := Found (Which);
      Board.Forget (Which);
   end Take;

   procedure Reset (Which : Slot) is
   begin
      Board.Forget (Which);
   end Reset;

end Vision.Jobs;
