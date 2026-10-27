with Nav_VM;
with Pomarine.UI.Contexts;

--  How the screens' controls (Pomarine.UI) are bound to the navigation: the buttons that show a screen, a
--  view, or the list of items. Instantiated once, here, in a package of its own, as the adapters must be.

package Nav_UI is new Pomarine.UI.Contexts (Nav_VM.Commands, Nav_VM.View_Model);
