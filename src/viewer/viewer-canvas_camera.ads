--  Where the canvas is looked at from.
package Viewer.Canvas_Camera is

   function Canvas_Zoom (Item : Session) return Float
     with Pre => Is_Open (Item);
   --  Screen points to a canvas unit.

   function Canvas_Origin_X (Item : Session) return Float
     with Pre => Is_Open (Item);
   function Canvas_Origin_Y (Item : Session) return Float
     with Pre => Is_Open (Item);
   --  Where the canvas's origin is, in points from the top left of the
   --  canvas.

end Viewer.Canvas_Camera;
