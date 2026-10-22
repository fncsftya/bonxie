with Pomarine.Text_Areas;
with Texts.Documents;

package body Word_Tools is

   package Editors renames Pomarine.Widgets.Editors;

   procedure Add (Item : in out Pomarine.Widgets.Editors.Editor) is
   begin
      Pomarine.Widgets.Editors.Add_Tool (Item, "Fade", Key => 'd', Needs_Selection => True);
      Pomarine.Widgets.Editors.Add_Tool (Item, "Reword", Key => 'r', Needs_Selection => True);
   end Add;

   procedure Use_Tool (Source : in out Pomarine.Widgets.Widget'Class; Tool : Natural) is
      Item : Editors.Editor'Class renames Editors.Editor'Class (Source);
   begin
      if Tool = Fade and then Editors.Has_Document (Item) then
         Pomarine.Text_Areas.Toggle_Format (Editors.Area (Item).all, Texts.Documents.Faded);
         Pomarine.Widgets.Invalidate (Item);
      end if;
   end Use_Tool;

end Word_Tools;
