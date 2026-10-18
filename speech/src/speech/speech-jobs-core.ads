--  This is the SPARK implementation of Speech.Jobs: per-slot job state,
--  transcripts and worker tasks. GNATprove checks the Ada code for run-time
--  errors and analyzes it with the Jorvik tasking profile
--  (`gnatprove -P speech.gpr -XSPEECH_PROOF=yes`). Shared Ada job state is
--  accessed through protected objects. This supports the race-freedom
--  argument for that Ada state under the proof configuration; it does not
--  prove the native code, Speech.Capture's external state, or behavior under
--  the program's full-tasking runtime.
--
--  What is asked of it is said in Speech.Jobs, which checks it first.
private package Speech.Jobs.Core
  with SPARK_Mode
is

   procedure Start_Job
     (Which           : Slot;
      Engine          : Engines := System;
      Model_Directory : String  := "")
     with Pre => Model_Directory'Length <= Max_Path;

   procedure Stop_Job (Which : Slot);

   function Job_State (Which : Slot) return States
     with Volatile_Function;

   function Job_Loudness (Which : Slot) return Float
     with Volatile_Function,
          Post => Job_Loudness'Result in 0.0 .. 1.0;

   procedure Words_So_Far (Which : Slot; Into : in out Transcript);

   function Job_Message (Which : Slot) return String
     with Volatile_Function,
          Post => Job_Message'Result'Length <= Max_Message;

   procedure Take_Words (Which : Slot; Into : out Transcript);

   procedure Reset_Job (Which : Slot);

   procedure End_Jobs;

end Speech.Jobs.Core;
