with Home_VM;
with Pomarine.UI.Contexts;

--  How the home screen's controls (Pomarine.UI) are bound to the view-model of the recent projects: the
--  buttons that rename one. Instantiated once, here, in a package of its own, as the adapters must be.
package Home_UI is new Pomarine.UI.Contexts (Home_VM.Commands, Home_VM.View_Model);
