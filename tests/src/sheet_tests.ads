--  Tests of the widgets of the interface, as the design's sheet of them
--  shows them: each kind, in its states, drawn on one board, and what
--  each does with clicks and keys. See Goldens.
package Sheet_Tests is

   procedure Board;
   --  Every kind of widget, at rest: buttons of each kind, turned off, of
   --  icons only, of sizes, toggles; dropdowns and a select field; a mode
   --  switch and a tool group; boxes to tick, radios, switches, a slider;
   --  fields, focused, invalid, turned off, with a hint and an icon; chips,
   --  a badge, a tag, a tooltip, a toast; menus; a scroll bar.

   procedure States;
   --  A button pressed, one with the focus, one under the pointer.

   procedure Behaviour;
   --  What the new widgets do with clicks, and a focused button with keys.

end Sheet_Tests;
