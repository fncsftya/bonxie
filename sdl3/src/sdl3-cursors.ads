--  The pointer's shape, from the system's own.
package SDL3.Cursors is

   type Kind is (Default, Move, Pointer);
   --  Default: the arrow. Move: four arrows, for what is being dragged or
   --  panned. Pointer: a hand, for what can be clicked.

   procedure Set (Which : Kind);
   --  Show the cursor for the window the pointer is over. Made the first
   --  time, and kept. SDL must be initialized.

end SDL3.Cursors;
