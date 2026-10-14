with Speech.Jobs.Core;

package body Speech.Jobs is

   procedure Start
     (Which           : Slot;
      Engine          : Engines := System;
      Model_Directory : String  := "") is
   begin
      Core.Start_Job (Which, Engine, Model_Directory);
   end Start;

   procedure Stop (Which : Slot) is
   begin
      Core.Stop_Job (Which);
   end Stop;

   function State (Which : Slot) return States is (Core.Job_State (Which));

   function Loudness (Which : Slot) return Float is (Core.Job_Loudness (Which));

   procedure Heard_So_Far (Which : Slot; Into : in out Transcript) is
   begin
      Core.Words_So_Far (Which, Into);
   end Heard_So_Far;

   function Message (Which : Slot) return String is (Core.Job_Message (Which));

   procedure Take (Which : Slot; Into : in out Transcript) is
   begin
      Core.Take_Words (Which, Into);
   end Take;

   procedure Reset (Which : Slot) is
   begin
      Core.Reset_Job (Which);
   end Reset;

   procedure Shutdown is
   begin
      Core.End_Jobs;
   end Shutdown;

end Speech.Jobs;
