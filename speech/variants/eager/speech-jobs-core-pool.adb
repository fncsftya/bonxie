separate (Speech.Jobs.Core)
package body Pool is

   Workers : array (Lane) of Worker;
   --  One to a slot, from the start: GNATprove's Jorvik profile allows no task to be made while the program runs.

   procedure Ensure (Which : Lane) is
      pragma Unreferenced (Which);
   begin
      null;
   end Ensure;

end Pool;
