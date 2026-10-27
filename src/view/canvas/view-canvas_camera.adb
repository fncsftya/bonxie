with Pomarine.Widgets.Canvases;

package body View.Canvas_Camera is

   package Canvases renames Pomarine.Widgets.Canvases;

   function Canvas_Zoom (Item : Session) return Float
   is (Canvases.Zoom (Canvases.Canvas (Item.Canvas_View)));

   function Canvas_Origin_X (Item : Session) return Float
   is (Canvases.Origin_X (Canvases.Canvas (Item.Canvas_View)));

   function Canvas_Origin_Y (Item : Session) return Float
   is (Canvases.Origin_Y (Canvases.Canvas (Item.Canvas_View)));

end View.Canvas_Camera;
