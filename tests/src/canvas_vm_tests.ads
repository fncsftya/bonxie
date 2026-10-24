--  Tests of the canvas's view-model alone: no window, no display, no event. See Goldens.
package Canvas_VM_Tests is

   procedure Entering;
   --  The items of a project, in their places, and how they are ordered.

   procedure Adding;
   --  A new item: where it is put, in the cascade, in a place free or made.

   procedure Showing;
   --  Shown as a window, a bar or not at all, brought up, and taken away.

   procedure Camera;
   --  Where it is looked at from, what it is asked to look at, and the view kept.

   procedure Handling;
   --  Moved and sized by hand, as far as the camera has it, and tools put away.

   procedure Linking;
   --  A line from a pin to a pin, one moved, restyled and deleted, and what goes with an item that is taken away.

   procedure Stored;
   --  The same over the database the program keeps.

end Canvas_VM_Tests;
