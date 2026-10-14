--  What Speech.Jobs does, in SPARK: the state of each slot's job, what is
--  heard of it, and the tasks that listen (one to a slot, made when the
--  program begins), which GNATprove proves are free of data races and of
--  run-time errors (`gnatprove -P speech.gpr -XSPEECH_PROOF=yes`). Nothing
--  here is shared between tasks but protected objects (and the state that
--  is C's, which is volatile), and each task's work is its own.
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
