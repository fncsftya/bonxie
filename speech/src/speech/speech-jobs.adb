with Ada.Containers.Ordered_Sets;
with Speech.Jobs.Core;

package body Speech.Jobs is

   package Slot_Sets is new Ada.Containers.Ordered_Sets (Slot);

   Too_Many : constant String := "Too many dictations at once";

   type Owner_Array is array (Lane) of Natural;

   protected Lanes is
      procedure Claim (Which : Slot; Using : out Natural);
      --  The lane the slot goes on in, one it had or a free one; 0 if all are kept.
      function Lane_Of (Which : Slot) return Natural;
      procedure Release (Which : Slot);
      procedure Refuse (Which : Slot);
      function Is_Refused (Which : Slot) return Boolean;
   private
      Owner   : Owner_Array := [others => 0];
      Refused : Slot_Sets.Set;
   end Lanes;

   protected body Lanes is

      procedure Claim (Which : Slot; Using : out Natural) is
         Free : Natural := 0;
      begin
         Using := 0;
         Refused.Exclude (Which);
         for Each in Lane loop
            if Owner (Each) = Which then
               Using := Each;
               return;
            elsif Owner (Each) = 0 and then Free = 0 then
               Free := Each;
            end if;
         end loop;
         if Free /= 0 then
            Owner (Free) := Which;
            Using := Free;
         end if;
      end Claim;

      function Lane_Of (Which : Slot) return Natural is
      begin
         for Each in Lane loop
            if Owner (Each) = Which then
               return Each;
            end if;
         end loop;
         return 0;
      end Lane_Of;

      procedure Release (Which : Slot) is
      begin
         Refused.Exclude (Which);
         for Each in Lane loop
            if Owner (Each) = Which then
               Owner (Each) := 0;
            end if;
         end loop;
      end Release;

      procedure Refuse (Which : Slot) is
      begin
         Refused.Include (Which);
      end Refuse;

      function Is_Refused (Which : Slot) return Boolean
      is (Refused.Contains (Which));

   end Lanes;

   procedure Start (Which : Slot; Engine : Engines := System; Model_Directory : String := "") is
      Using : Natural;
   begin
      Lanes.Claim (Which, Using);
      if Using = 0 then
         Lanes.Refuse (Which);
      else
         Core.Start_Job (Using, Engine, Model_Directory);
      end if;
   end Start;

   procedure Stop (Which : Slot) is
      Using : constant Natural := Lanes.Lane_Of (Which);
   begin
      if Using /= 0 then
         Core.Stop_Job (Using);
      end if;
   end Stop;

   function State (Which : Slot) return States is
      Using : constant Natural := Lanes.Lane_Of (Which);
   begin
      if Using /= 0 then
         return Core.Job_State (Using);
      end if;
      return (if Lanes.Is_Refused (Which) then Failed else Idle);
   end State;

   function Loudness (Which : Slot) return Float is
      Using : constant Natural := Lanes.Lane_Of (Which);
   begin
      return (if Using /= 0 then Core.Job_Loudness (Using) else 0.0);
   end Loudness;

   procedure Heard_So_Far (Which : Slot; Into : in out Transcript) is
      Using : constant Natural := Lanes.Lane_Of (Which);
   begin
      if Using /= 0 then
         Core.Words_So_Far (Using, Into);
      else
         Into := (others => <>);
      end if;
   end Heard_So_Far;

   function Message (Which : Slot) return String is
      Using : constant Natural := Lanes.Lane_Of (Which);
   begin
      return (if Using /= 0 then Core.Job_Message (Using) else Too_Many);
   end Message;

   procedure Take (Which : Slot; Into : in out Transcript) is
      Using : constant Natural := Lanes.Lane_Of (Which);
   begin
      if Using /= 0 then
         Core.Take_Words (Using, Into);
         Lanes.Release (Which);
      end if;
   end Take;

   procedure Reset (Which : Slot) is
      Using : constant Natural := Lanes.Lane_Of (Which);
   begin
      if Using /= 0 then
         Core.Reset_Job (Using);
      end if;
      Lanes.Release (Which);
   end Reset;

   procedure Shutdown is
   begin
      Core.End_Jobs;
   end Shutdown;

end Speech.Jobs;
