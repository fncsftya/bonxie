--  Drawing what is shown to the target.
private package Viewer.Painting is

   procedure Paint (Item : in out Session);
   --  Draw what is shown, but do not present it.

   procedure Fit_Buttons (Item : Session);
   --  Put the window's close, minimise and zoom buttons where they line up
   --  with the bar across the top, the same on every screen. The system
   --  moves them back as it lays the window out, so this is done after
   --  that, as often as it may have.

   procedure Draw (Item : in out Session);
   --  Fit the target to the window, paint and present.

end Viewer.Painting;
