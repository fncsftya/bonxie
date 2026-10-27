with Outline_VM;
with Pomarine.UI.Contexts;

--  How the outline's controls (Pomarine.UI) are bound to its view-model: the buttons that add a section and
--  move, delete or open the notes of one. Instantiated once, here, in a package of its own.
package Outline_UI is new Pomarine.UI.Contexts (Outline_VM.Commands, Outline_VM.View_Model);
