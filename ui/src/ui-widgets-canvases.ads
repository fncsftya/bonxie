with SDL3.Cursors;
with SDL3.Events;
with SDL3.Windows.Renderers;

--  An infinite two-dimensional canvas, seen through its box, which can be
--  panned and zoomed. Things on it have places in canvas units, which are
--  points at a zoom of 1; the canvas draws a grid of dots to show where it
--  is.
--
--  The wheel, which a trackpad's two fingers turn, pans it; with Command
--  held, or with a pinch, it zooms about the pointer; so do Command with
--  =, - and 0 (zoom in, out, and back to 1) about the middle. Dragging
--  with the middle button pans it, and shows the move cursor while it does.
--  Zooming stays within limits.
package UI.Widgets.Canvases is

   Min_Zoom : constant Float := 0.1;
   Max_Zoom : constant Float := 8.0;

   type Canvas is new Widget with private;

   function Zoom (Item : Canvas) return Float;
   --  Screen points to a canvas unit; 1.0 to begin with.

   function Origin_X (Item : Canvas) return Float;
   function Origin_Y (Item : Canvas) return Float;
   --  Where the canvas's origin is, in points from the top left of its
   --  box. In the middle of it, once it has a size, to begin with.

   function Is_Panning (Item : Canvas) return Boolean;
   --  Whether it is being dragged.

   procedure Pan_By (Item : in out Canvas; Across, Down : Float);
   --  Move what is seen by Across and Down points, to the right and
   --  down.

   procedure Zoom_By
     (Item : in out Canvas; Factor : Float; About_X, About_Y : Float)
     with Pre => Factor > 0.0;
   --  Multiply the zoom by Factor, within limits, keeping the point
   --  About_X, About_Y (in points from the top left of its box) where it is.

   function To_Canvas_X (Item : Canvas; Point : Float) return Float;
   function To_Canvas_Y (Item : Canvas; Point : Float) return Float;
   --  The canvas unit at Point points from the left or top of the box.

   overriding procedure Placed
     (Item : in out Canvas; Left, Top, Width, Height : Float);

   overriding procedure Draw
     (Item   : in out Canvas;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme);

   overriding procedure Handle
     (Item    : in out Canvas;
      Event   : SDL3.Events.Event;
      Handled : out Boolean);

   overriding function Cursor (Item : Canvas) return SDL3.Cursors.Kind;

private

   type Canvas is new Widget with record
      Scale   : Float := 1.0;
      Across  : Float := 0.0;
      Down    : Float := 0.0;
      --  Of the origin, in points.
      Centered : Boolean := False;
      --  Whether the origin has been put in the middle.
      Panning : Boolean := False;
      Last_X, Last_Y : Float := 0.0;
      --  Where the pointer was, in points, while it pans.
   end record;

end UI.Widgets.Canvases;
