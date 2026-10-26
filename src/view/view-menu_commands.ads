with Pomarine.UI;
with Pomarine.Widgets.Layouts;
with Pomarine.Widgets.Menus;

private package View.Menu_Commands is
   procedure Initialize (Item : in out Session);
   function Place
     (Item : Session; Form : in out Pomarine.UI.View;
      Menu : in out Pomarine.Widgets.Menus.Menu; What : Menu_VM.Command;
      Box : Pomarine.Widgets.Layouts.Style) return Pomarine.UI.Layout;
end View.Menu_Commands;
