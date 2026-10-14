--  Listening in the background: each job has a slot, and a task of its
--  own that does it (Speech.Begin_Listening, which can wait for leave to
--  use the microphone, and Speech.End_Listening, which waits for the rest
--  of what was said to be made text) while the caller goes on. The
--  caller polls (State), says when to stop (Stop), and takes the text
--  when it is Done. The text is kept in the slot until Take.
--
--  Two engines can do the listening: the system's (SpeechAnalyzer) or
--  Parakeet, a model on Core ML (Speech.Streams). The model's task hears
--  the microphone as 16 kHz mono (Speech.Capture) from the first moment,
--  and feeds it to the model as it comes, so that Heard_So_Far has the
--  words as they are worked out; the model is loaded meanwhile, so what is
--  said while it loads is not lost, only late.
package Speech.Jobs is
   --  This is the shell: what is asked of it is checked here (as what is
   --  asked of a slot's state, which is shared, cannot be said in SPARK),
   --  and what is done is in Speech.Jobs.Core, which is proved.

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

   type Engines is (System, Model);

   Max_Message : constant := 160;
   Max_Path    : constant := 1024;
   --  Of the folder the model is kept in.

   procedure Start
     (Which           : Slot;
      Engine          : Engines := System;
      Model_Directory : String  := "")
     with Pre  => State (Which) in Idle | Done | Failed
                  and then Model_Directory'Length <= Max_Path
                  and then (Engine = System or else Model_Directory /= ""),
          Post => State (Which) in Starting | Listening | Failed;
   --  Begin to listen, with the engine; Model_Directory is where the
   --  model is kept (see Speech.Models), for Model. If a job that was reset
   --  is still running in the slot, the new one begins when that is over.

   procedure Stop (Which : Slot)
     with Pre => State (Which) in Open;
   --  Stop listening, and make what was heard into text. It does not
   --  wait: the state is Finishing (if the microphone has not begun, it
   --  goes straight on to finish when it does).

   function State (Which : Slot) return States;

   function Loudness (Which : Slot) return Float
     with Post => Loudness'Result in 0.0 .. 1.0;
   --  How loud what is heard is, while Listening (see Speech.Level).

   procedure Heard_So_Far (Which : Slot; Into : in out Transcript);
   --  What has been heard so far, while Listening (see Speech.Peek):
   --  Into is empty at any other time.

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

   procedure Shutdown;
   --  The program is ending: let the tasks that listen go. A program that
   --  uses this package must call it before it ends, or it does not: the
   --  tasks are made when the program begins, one to a slot, and wait for
   --  something to do. (A job that is listening is not stopped by this,
   --  and its task does not go until it is: Stop, or Reset, first.)

end Speech.Jobs;
