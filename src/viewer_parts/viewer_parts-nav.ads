with Nav_VM;
with Nav_VM.Stored;
with Pomarine.View_Models;
with Pomarine.Widgets.Bindings;
with Pomarine.Widgets.Bindings.For_Commands;

--  Where the person is: the screen, the view of the project, its name and the list of its items.
package Viewer_Parts.Nav is

   Nav_Tag_Base : constant := 500;
   --  The tag of the first command of the view-model of where the person is: after the outline's (see
   --  Viewer_Parts.Outline).

   package Nav_Binding is new Pomarine.Widgets.Bindings.For_Commands (Nav_VM.Commands, Nav_Tag_Base);

   function Tag_Of (What : Nav_VM.Command) return Integer is (Nav_Tag_Base + Nav_VM.Command'Pos (What));
   --  For a menu item, which asks for the command by its tag.

   type Nav_Choices is limited record
      Library : aliased Nav_VM.Stored.Projects_Kept;
      Model   : aliased Nav_VM.View_Model;
      --  What the screen, the view and the layers over them are, and the project's name.
      Judge   : aliased Nav_Binding.Judge;
      Seen    : Pomarine.View_Models.Watch;
      --  The model's version as last shown, for what is shown by all of it (the commands' states).
      Screens : Pomarine.View_Models.Watch;
      Views   : Pomarine.View_Models.Watch;
      Naming  : Pomarine.View_Models.Watch;
      Names   : Pomarine.View_Models.Watch;
      --  The versions of the screen, the view, the renaming and the name, as last shown.
      Link    : Pomarine.Widgets.Bindings.Text_Link;
      --  The field the project is renamed in, and the draft.
   end record;
   --  The view-model of where the person is, and what the widgets show of it.

end Viewer_Parts.Nav;
