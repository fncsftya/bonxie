with Nav_VM;
with Nav_VM.Stored;
with Pomarine.View_Models;

--  Where the person is: the screen, the view of the project, its name and the list of its items.

package View_Parts.Nav is

   Nav_Tag_Base : constant := 500;
   --  Native menu command tags. Declarative widgets use the tags owned by their UI view.

   Check_Updates_Tag : constant := 450;
   --  The menu's "Check for Updates", which is Update_VM's, not Nav_VM's.

   function Tag_Of (What : Nav_VM.Command) return Integer
   is (Nav_Tag_Base + Nav_VM.Command'Pos (What));
   --  For a menu item, which asks for the command by its tag.

   function Is_Nav_Tag (Tag : Integer) return Boolean
   is (Tag in Nav_Tag_Base .. Tag_Of (Nav_VM.Command'Last));

   function Command_Of (Tag : Integer) return Nav_VM.Command
   is (Nav_VM.Command'Val (Tag - Nav_Tag_Base))
   with Pre => Is_Nav_Tag (Tag);

   type Nav_Choices is limited record
      Library : aliased Nav_VM.Stored.Projects_Kept;
      Model   : aliased Nav_VM.View_Model;
      --  What the screen, the view and the layers over them are, and the project's name.
      Seen    : Pomarine.View_Models.Watch;
      --  The model's version as last shown, for what is shown by all of it (the commands' states).
      Screens : Pomarine.View_Models.Watch;
      Views   : Pomarine.View_Models.Watch;
      --  The versions of the screen and the view, as last shown.
   end record;
   --  The view-model of where the person is, and what the widgets show of it.

end View_Parts.Nav;
