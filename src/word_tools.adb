package body Word_Tools is

   procedure Add (Item : in out Pomarine.Widgets.Editors.Editor) is
   begin
      Pomarine.Widgets.Editors.Add_Tool (Item, "Fade", Key => 'd', Needs_Selection => True);
      Pomarine.Widgets.Editors.Add_Tool (Item, "Reword", Key => 'r', Needs_Selection => True);
   end Add;

end Word_Tools;
