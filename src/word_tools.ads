with Pomarine.Widgets;
with Pomarine.Widgets.Editors;

--  The tools bonxie adds to the toolbar of a rich text editor, for what is
--  selected in its text: Fade (Cmd+D) and Reword (Cmd+R).
package Word_Tools is

   Fade   : constant := 1;
   Reword : constant := 2;
   --  Their numbers, in the order Add gives them.

   procedure Add (Item : in out Pomarine.Widgets.Editors.Editor)
     with Pre => Pomarine.Widgets.Editors.Tool_Count (Item) = 0,
          Post => Pomarine.Widgets.Editors.Tool_Count (Item) = Reword;

   procedure Use_Tool (Source : in out Pomarine.Widgets.Widget'Class; Tool : Natural);
   --  Do what the tool of this number, said by Source's Use_Tool event, is
   --  for. Fade fades the selected text, or, if all of it is faded, brings
   --  it back (kept as <f> round it in the document's markup); Reword
   --  does nothing yet.

end Word_Tools;
