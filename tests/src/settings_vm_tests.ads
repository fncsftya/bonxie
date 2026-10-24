--  Tests of the settings' view-model alone: no window, no display, no event.
--  What each command can do and when, what is kept and what happens when it
--  cannot be, and what is said of the speech model's download for each state
--  it can be in. See Goldens.
package Settings_VM_Tests is

   procedure Command_Rules;
   --  When each command is possible; the choices, and that the same is no change.

   procedure Keeping;
   --  What is kept for each choice, a save that fails, and the file kept.

   procedure Downloading;
   --  The download's controls and what is said of it, in each state of it.

   procedure Sizes;
   --  How sizes are said.

   procedure No_Widgets;
   --  That the view-models name no widget, window or SDL.

end Settings_VM_Tests;
