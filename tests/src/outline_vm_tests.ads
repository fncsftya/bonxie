--  Tests of the outline's view-model alone: no window, no display, no event. See Goldens.
package Outline_VM_Tests is

   procedure Entering;
   --  Reading a project's sections and what is open.

   procedure Changing;
   --  Adding, moving and removing sections, and the notes shown or hidden.

   procedure Typing;
   --  What is typed of the project and of a section, and what is kept of it.

   procedure Stored;
   --  The same over the database the program keeps.

end Outline_VM_Tests;
