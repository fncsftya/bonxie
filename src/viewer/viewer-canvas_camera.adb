with UI.Widgets.Canvases;

package body Viewer.Canvas_Camera is

   package Canvases renames UI.Widgets.Canvases;

   function Canvas_Zoom (Item : Session) return Float is
     (Canvases.Zoom (Item.Canvas_View));

   function Canvas_Origin_X (Item : Session) return Float is
     (Canvases.Origin_X (Item.Canvas_View));

   function Canvas_Origin_Y (Item : Session) return Float is
     (Canvases.Origin_Y (Item.Canvas_View));

end Viewer.Canvas_Camera;
