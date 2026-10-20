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
     (Which           : Lane;
      Engine          : Engines := System;
      Model_Directory : String  := "")
     with Pre => Model_Directory'Length <= Max_Path;

   procedure Stop_Job (Which : Lane);

   function Job_State (Which : Lane) return States
     with Volatile_Function;

   function Job_Loudness (Which : Lane) return Float
     with Volatile_Function,
          Post => Job_Loudness'Result in 0.0 .. 1.0;

   procedure Words_So_Far (Which : Lane; Into : in out Transcript);

   function Job_Message (Which : Lane) return String
     with Volatile_Function,
          Post => Job_Message'Result'Length <= Max_Message;

   procedure Take_Words (Which : Lane; Into : out Transcript);

   procedure Reset_Job (Which : Lane);

   procedure End_Jobs;

end Speech.Jobs.Core;
