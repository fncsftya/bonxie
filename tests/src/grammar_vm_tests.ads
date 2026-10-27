--  Tests of the grammar rules' view-model alone: no window, no display, no event. See Goldens.

package Grammar_VM_Tests is

   procedure Rule_List;
   --  The rules of a project: read once, ignored and corrected texts, taken away.

   procedure Entry_Form;
   --  The form that makes a correction: when it can be accepted, and what it makes.

   procedure Card_Actions;

   procedure Stored;
   --  The same over the database the program keeps.

end Grammar_VM_Tests;
