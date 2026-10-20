--  Where the canvas is looking: the items put in place, the view centred on one, and kept.
private package Viewer.Canvas_Items.Placement is

   procedure Place_All (Item : in out Session);
   --  Put every window where the canvas has them.

   procedure Centre_On (Item : in out Session; X, Y : Float);
   --  Pan so that the canvas point X, Y is in the middle of the view.

   procedure Centre_On_Visible (Item : in out Session);
   --  Centre the view on the middle of the bounding box of the windows
   --  that are open, if there are any.

   procedure Save_View (Item : in out Session);
   --  Keep how the canvas is seen, for the project to open at again.

   procedure Restore_View
     (Item : in out Session; Found : out Boolean);
   --  Put the canvas as it was kept, if it was.

end Viewer.Canvas_Items.Placement;
