--  Recognition in the background: each job has a slot, and a task of its
--  own that does it (Vision.Recognize) while the caller goes on. The
--  caller looks at (State) and takes the words when it is Done; it is
--  woken, if it is waiting for events, when a job ends (see
--  Pomarine.Application.Post); as with Webshot, a slot has one job at a time. The words are kept in the slot
--  until Take.
package Vision.Jobs is

   Slot_Count : constant := 16;

   subtype Slot is Positive range 1 .. Slot_Count;

   type States is (Idle, Working, Done, Failed);
   --  Idle: nothing was started, or it was taken (Reset). Working: not
   --  finished. Done: the words are there to Take. Failed: it could not
   --  be done, and Message says why.

   Max_Message : constant := 160;

   procedure Start (Which : Slot; File_Name : String)
     with Pre => State (Which) /= Working
                 and then File_Name'Length in 1 .. 1_024;
   --  Begin to find the text in the PNG file. The state is Working. If a
   --  job that was reset is still running in the slot, this waits for it.

   function State (Which : Slot) return States;

   function Message (Which : Slot) return String
     with Pre  => State (Which) = Failed,
          Post => Message'Result'Length <= Max_Message;

   procedure Take (Which : Slot; Into : in out Result)
     with Pre => State (Which) = Done;
   --  Copy the words out of the slot, which is then Idle.

   procedure Reset (Which : Slot)
     with Post => State (Which) = Idle;
   --  Forget the job, if any, and how it ended. One still running goes on
   --  to its end, and what it finds is thrown away.

end Vision.Jobs;
