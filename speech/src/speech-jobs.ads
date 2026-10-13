--  Listening in the background: each job has a slot, and a task of its
--  own that does it (Speech.Begin_Listening, which can wait for leave to
--  use the microphone, and Speech.End_Listening, which waits for the rest
--  of what was said to be made text) while the caller goes on. The
--  caller polls (State), says when to stop (Stop), and takes the text
--  when it is Done. The text is kept in the slot until Take.
package Speech.Jobs is

   Slot_Count : constant := Max_Sessions;

   subtype Slot is Positive range 1 .. Slot_Count;

   type States is (Idle, Starting, Listening, Finishing, Done, Failed);
   --  Idle: nothing was started, or it was taken (Reset). Starting: the
   --  microphone is not yet listening. Listening: it is. Finishing: it
   --  was stopped, and what was heard is being made text. Done: the text
   --  is there to Take. Failed: it could not be done, and Message says
   --  why.

   subtype Open is States range Starting .. Listening;
   --  Not yet stopped: Stop ends it.

   Max_Message : constant := 160;

   procedure Start (Which : Slot)
     with Pre  => State (Which) in Idle | Done | Failed,
          Post => State (Which) in Starting | Listening | Failed;
   --  Begin to listen. If a job that was reset is still running in the
   --  slot, this waits for it.

   procedure Stop (Which : Slot)
     with Pre => State (Which) in Open;
   --  Stop listening, and make what was heard into text. It does not
   --  wait: the state is Finishing (if the microphone has not begun, it
   --  goes straight on to finish when it does).

   function State (Which : Slot) return States;

   function Loudness (Which : Slot) return Float
     with Post => Loudness'Result in 0.0 .. 1.0;
   --  How loud what is heard is, while Listening (see Speech.Level).

   function Message (Which : Slot) return String
     with Pre  => State (Which) = Failed,
          Post => Message'Result'Length <= Max_Message;

   procedure Take (Which : Slot; Into : in out Transcript)
     with Pre => State (Which) = Done;
   --  Copy the text out of the slot, which is then Idle.

   procedure Reset (Which : Slot)
     with Post => State (Which) = Idle;
   --  Forget the job, if any, and how it ended. One still running is
   --  stopped, and what it heard is thrown away.

end Speech.Jobs;
