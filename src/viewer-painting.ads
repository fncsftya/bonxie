--  Drawing what is shown to the target.
private package Viewer.Painting is

   procedure Paint (Item : in out Session);
   --  Draw what is shown, but do not present it.

   procedure Draw (Item : in out Session);
   --  Fit the target to the window, paint and present.

end Viewer.Painting;
