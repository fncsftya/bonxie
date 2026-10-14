--  The pointer's shape, from the system's own.
package SDL3.Cursors is

   type Kind is (Default, Move, Pointer, Resize, Crosshair, Resize_Across);
   --  Default: the arrow. Move: four arrows, for what is being dragged or
   --  panned. Pointer: a hand, for what can be clicked. Resize: two arrows
   --  across a diagonal, for what is sized by a corner. Crosshair: for what
   --  is drawn on. Resize_Across: two arrows left and right, for what is
   --  sized by an edge.

   procedure Set (Which : Kind);
   --  Show the cursor for the window the pointer is over. Made the first
   --  time, and kept. SDL must be initialized.

end SDL3.Cursors;
