with Pomarine.Widgets.Editors;

--  The tools bonxie adds to the toolbar of a rich text editor, for what is
--  selected in its text: Fade (Cmd+D) and Reword (Cmd+R). They say Use_Tool
--  with their number; they do nothing yet.
package Word_Tools is

   Fade   : constant := 1;
   Reword : constant := 2;
   --  Their numbers, in the order Add gives them.

   procedure Add (Item : in out Pomarine.Widgets.Editors.Editor)
     with Pre => Pomarine.Widgets.Editors.Tool_Count (Item) = 0,
          Post => Pomarine.Widgets.Editors.Tool_Count (Item) = Reword;

end Word_Tools;
