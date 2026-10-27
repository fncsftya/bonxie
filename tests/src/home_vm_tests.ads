--  Tests of the home screen's view-model and the deleting dialog's, alone: no
--  window, no display, no event. See Goldens.

package Home_VM_Tests is

   procedure Listing;
   --  The recent projects, what is said of each, and listing them again.

   procedure Renaming;
   --  Renaming in place: when it can be accepted, what is kept, and stopping.

   procedure Deleting;
   --  Deleting a project, and a row that is not one.

   procedure Stored;
   --  The same over the database the program keeps.

   procedure Asking;
   --  The dialog that asks first: what it says of each thing, and the answer.

end Home_VM_Tests;
