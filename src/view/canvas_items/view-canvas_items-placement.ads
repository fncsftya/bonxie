--  Where the canvas is looking: what it says of itself to the view-model, where the view-model asks it to go, and the
--  items put in place by it.
private package View.Canvas_Items.Placement is

   procedure Report_Camera (Item : in out Session);
   --  Tell the view-model how the canvas is looked at now, and how much of it there is to see: the person may have
   --  panned or zoomed it.

   procedure Place_All (Item : in out Session);
   --  Put every window where the canvas has them.

   procedure Follow (Item : in out Session);
   --  Go where the view-model asks, if it has asked since, and put the windows where the canvas has them if it has
   --  been moved.

end View.Canvas_Items.Placement;
