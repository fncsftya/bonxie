with SDL3.Events;

--  Zooming the page, with the wheel or the keys.
private package Viewer.Zooming is

   Settle_MS : constant := 120;
   --  How long the zoom must hold still to count as settled.

   procedure Zoom_By (Item : in out Session; Factor : Float);
   --  Multiply the zoom by Factor, within limits, and lay out again.

   procedure Handle
     (Item : in out Session; Event : SDL3.Events.Event; Handled : out Boolean);
   --  Command with the wheel, =, - or 0.

end Viewer.Zooming;
