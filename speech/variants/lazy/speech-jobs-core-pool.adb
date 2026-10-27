separate (Speech.Jobs.Core)
package body Pool
  with SPARK_Mode => Off
is

   type Made_Flags is array (Lane) of Boolean;

   protected Claims is
      procedure Claim (Which : Lane; First : out Boolean);
   private
      Made : Made_Flags := [others => False];
   end Claims;

   protected body Claims is
      procedure Claim (Which : Lane; First : out Boolean) is
      begin
         First := not Made (Which);
         Made (Which) := True;
      end Claim;
   end Claims;

   type Worker_Ref is access Worker;

   Workers : array (Lane) of Worker_Ref;
   pragma Warnings (Off, Workers, Reason => "a task is made and runs on its own; nothing reads the pointer");
   --  Made as they are first wanted, and kept: a task ends only when the program does.

   procedure Ensure (Which : Lane) is
      First : Boolean;
   begin
      Claims.Claim (Which, First);
      if First then
         Workers (Which) := new Worker (Preset => Which);
      end if;
   end Ensure;

end Pool;
