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

   Max_Lines : constant := 128;

   type Dashes is (Solid, Dotted, Dashed);

   type Line is record
      From_X, From_Y, To_X, To_Y : Float := 0.0;
      Tag   : Natural := 0;
      --  What the application calls it, to be told which is selected.
      Dash  : Dashes := Solid;
      Arrow : Boolean := False;
      --  An arrowhead at the To end.
      Ink   : Themes.Slot := Themes.Foreground;
   end record;
   --  A straight line between two places, in canvas units.

   type Line_Array is array (Positive range <>) of Line;

   procedure Set_Lines (Item : in out Canvas; Lines : Line_Array)
     with Pre => Lines'Length <= Max_Lines;
   --  Draw these lines, joining things on the canvas, over the canvas but
   --  under what is on it, in place of any before. Setting what it has
   --  already damages nothing; a line that has moved damages the box
   --  round where it was and where it is.

   function Selected (Item : Canvas) return Natural;
   --  The Tag of the line selected, 0 if none: a press on a line, where
   --  nothing else is, selects it; a press on the canvas where there is no
   --  line, or Escape, selects none. A selected line is drawn with a halo.

   procedure Set_Selected (Item : in out Canvas; Tag : Natural);

   procedure Take_Selection
     (Item : in out Canvas; Changed : out Boolean; Tag : out Natural);
   --  Say whether a press or Escape has changed which line is selected
   --  since this was last called, and which it is now, and forget it.

   procedure Take_Delete (Item : in out Canvas; Asked : out Boolean);
   --  Say whether Backspace or Delete was pressed while a line was
   --  selected since this was last called, and forget it.

   procedure Set_Ghost
     (Item : in out Canvas; From_X, From_Y : Float; To_X, To_Y : Float);
   --  Draw a faint line over everything on the canvas, as of one being
   --  dragged out: from a place on the canvas (in canvas units) to the
   --  pointer (in points of the window).

   procedure Clear_Ghost (Item : in out Canvas);

   function Has_Ghost (Item : Canvas) return Boolean;

   overriding procedure Placed
     (Item : in out Canvas; Left, Top, Width, Height : Float);

   overriding procedure Draw
     (Item   : in out Canvas;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme);

   overriding procedure Draw_Over
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
      Line_Count : Natural range 0 .. Max_Lines := 0;
      Lines      : Line_Array (1 .. Max_Lines);
      Chosen     : Natural := 0;
      Chosen_Changed : Boolean := False;
      Delete_Asked   : Boolean := False;
      Ghosted    : Boolean := False;
      Ghost_From : Line;
      --  The ghost: From_X, From_Y are in canvas units, To_X, To_Y in
      --  points of the window.
   end record;

end UI.Widgets.Canvases;
