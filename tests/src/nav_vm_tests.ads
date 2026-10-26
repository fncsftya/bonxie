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

   procedure Creating;
   --  Canvas creation commands, modal availability and effects without navigation changes.

   procedure Writing_Sections;
   --  Writing section commands validate current rows and carry their indices into effects.

   procedure List_Commands;
   --  Item-list command layers and closing before reveal.

   procedure Source_Commands;
   procedure Link_Offers;
   procedure Naming;
   --  Source order, identity across slot reuse and declarative row commands.

   procedure Page_Commands;
   --  Current page ranks, dictation availability and injected surface effects.

   procedure Sidebar;
   --  Writing sidebar commands, persisted folding choices and unavailable layers.

   procedure Publishing;
   --  Publishing options, format-menu rules, content versions and modal layers.

   procedure Publishing_Output;
   --  Export snapshots and completion, clipboard confirmation and file persistence.

   procedure Stored;
   --  The same over the database the program keeps.

end Nav_VM_Tests;
