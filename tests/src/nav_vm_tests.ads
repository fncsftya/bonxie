--  Tests of the view-model of where the person is, alone: no window, no display, no event. See Goldens.
package Nav_VM_Tests is

   procedure Opening;
   --  The home screen, opening a project from its list or making one, and leaving it.

   procedure Views;
   --  The view of a project, which is kept and is the one it opens to again.

   procedure Renaming;
   --  The project's name: begun, typed over, kept, and not left blank.

   procedure Layers;
   --  What is over the screen: the settings, the list of items, the dialogs; what each takes, and Dismiss.

   procedure Stored;
   --  The same over the database the program keeps.

end Nav_VM_Tests;
