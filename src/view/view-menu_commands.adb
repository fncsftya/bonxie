with Menu_UI;

package body View.Menu_Commands is
   procedure Initialize (Item : in out Session) is
   begin
      Item.Menu_Target.Owner := Item'Unrestricted_Access;
      Menu_VM.Initialize (Item.Menu_Model, Item.Menu_Target'Access);
   end Initialize;

   function Place
     (Item : Session; Form : in out Pomarine.UI.View;
      Menu : in out Pomarine.Widgets.Menus.Menu; What : Menu_VM.Command;
      Box : Pomarine.Widgets.Layouts.Style) return Pomarine.UI.Layout
   is
      Bound : constant Menu_UI.Context'Class := Menu_UI.Bind (Form, Item.Menu_Model'Unrestricted_Access);
      Control : constant Pomarine.UI.Widget_Handle := Bound.Borrow_Widget (Menu);
   begin
      Bound.On_Event (Control, Pomarine.Widgets.Choose, What, Index_From_Event => True);
      return Pomarine.UI.Styled (Pomarine.UI.Place (Control), Box);
   end Place;
end View.Menu_Commands;
