--  Tests of the update's view-model alone: no window, no network, no disk, no script. What is offered and when,
--  that nothing is fetched until the person says so, that a skipped version is not offered again by a check that
--  was not asked for, and what happens when a step fails. See Goldens.

package Update_VM_Tests is

   procedure Checking;
   --  What a check finds: newer, the same, older, a prerelease, nothing like a release; and what it keeps.

   procedure Offering;
   --  Install, Skip and Later: what each does, and what is said.

   procedure Installing;
   --  The install from the first fetch to the quitting, and each place it can stop.

   procedure Starting;
   --  When the program looks by itself, and what it tells at start.

end Update_VM_Tests;
