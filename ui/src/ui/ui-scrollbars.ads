with SDL3.Events;
with SDL3.Windows.Renderers;
with UI.Themes;

--  The bar that shows how much of something taller (or wider) than its box
--  is in view, and where, and that can be dragged: along the box's right
--  edge (or bottom), for scrolled views to draw over what they show and to
--  give their mouse events to first.
--
--  It is a trough with a button at each end, an arrow on each, and a thumb
--  in it that stands up, bevelled, as a button does. It is shown only
--  while the pointer is over the view (Set_Pane), or while it is held. It
--  is solid, so that drawing it again changes nothing. Pressing on the
--  thumb holds it, to drag; pressing on the trough beside it moves the
--  thumb there, and holds it; pressing an arrow scrolls a step that way,
--  and the arrow is pressed in until it is let go.
package UI.Scrollbars is

   Thickness : constant Float := 12.0;
   Shortest  : constant Float := 16.0;
   --  In points: how thick the bar is (and how long each of its buttons),
   --  and how short the thumb may be.

   Step_Fraction : constant Float := 0.125;
   --  Of what is shown: how far a press of an arrow scrolls.

   type Bar is private;
   --  The state of one bar: whether it is shown, and whether its thumb, or
   --  one of its arrows, is held.

   type Metrics is record
      Left, Top, Width, Height : Float := 0.0;
      Density    : Float := 1.0;
      Start      : Float := 0.0;
      Shown      : Float := 0.0;
      Total      : Float := 0.0;
      Horizontal : Boolean := False;
   end record;
   --  What a bar shows: the box in pixels, along the side of which it goes,
   --  the density of the pixels, and the view Shown high (or wide), which
   --  begins Start down (or across) Total, in any one unit.

   procedure Set_Pane (Item : in out Bar; Over : Boolean);
   --  Say whether the pointer is over what the bar is for.

   function Is_Shown (Item : Bar) return Boolean;

   function Is_Held (Item : Bar) return Boolean;

   procedure Draw
     (Item   : Bar;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme;
      Within : Metrics);
   --  Draw it, if it is shown and there is more than the view shows.

   procedure Handle
     (Item    : in out Bar;
      Event   : SDL3.Events.Event;
      Within  : Metrics;
      Taken   : out Boolean;
      Moved   : out Boolean;
      To      : out Float;
      Changed : out Boolean);
   --  Look at a mouse event: Taken if it is for the bar and not for the
   --  view; Moved if the view is to begin To (in the unit of Within's
   --  Start, within 0 and Total - Shown); Changed if the bar looks
   --  different, so is to be drawn again.

private

   type Arrow is (None, Back, Ahead);
   --  Of the buttons at the ends: up (or left), and down (or right).

   type Bar is record
      Pane     : Boolean := False;
      Pressing : Arrow := None;
      Grabbing : Boolean := False;
      Grab     : Float := 0.0;
      --  While held: how far along the thumb it was taken, in pixels.
   end record;

end UI.Scrollbars;
