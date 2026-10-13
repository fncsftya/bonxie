with SDL3.Cursors;
with SDL3.Events;
with SDL3.Windows.Renderers;

--  A small round handle to start a line from, by pressing on it and
--  dragging, and to end one on. It says when it is pressed and let go,
--  and where the pointer is meanwhile, as a grip says how far it has
--  gone: what is drawn from it is the application's.
--
--  A press of the left button on it starts a drag, which lasts until the
--  button is let go, wherever the pointer goes. The pointer is over the
--  pin that a drag is to end on, if there is one, as Is_Hovered says; the
--  application says that pins may be ended on (Set_Accepting), and those
--  the pointer is over are drawn with a border to show it.
package UI.Widgets.Pins is

   Diameter : constant Float := 14.0;
   --  What the application sizes a pin to, in points.

   type Pin is new Widget with private;

   procedure Set_Accepting (Item : in out Pin; To : Boolean);
   --  Whether a line being dragged may end on it.

   function Is_Accepting (Item : Pin) return Boolean;

   procedure Take_Press (Item : in out Pin; Pressed : out Boolean);
   --  Say whether the button has been pressed on it since this was last
   --  called, and forget it.

   procedure Take_Release (Item : in out Pin; Released : out Boolean);
   --  Say whether the button has been let go after a press on it since
   --  this was last called, and forget it.

   function Is_Held (Item : Pin) return Boolean;
   --  Whether the button is down from a press on it.

   procedure Cancel (Item : in out Pin)
     with Post => not Is_Held (Item);
   --  Forget a press, as when it is hidden and so will not be told the
   --  button is let go.

   function Pointer_X (Item : Pin) return Float;
   function Pointer_Y (Item : Pin) return Float;
   --  Where the pointer was last, in points of the window, while it is
   --  held.

   overriding procedure Handle
     (Item    : in out Pin;
      Event   : SDL3.Events.Event;
      Handled : out Boolean);

   overriding procedure Draw
     (Item   : in out Pin;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme);

   overriding procedure Hover_Changed (Item : in out Pin; Hovered : Boolean);

   overriding function Cursor (Item : Pin) return SDL3.Cursors.Kind;

private

   type Pin is new Widget with record
      Accepting : Boolean := False;
      Held      : Boolean := False;
      Pressed   : Boolean := False;
      Released  : Boolean := False;
      Pointer_At_X, Pointer_At_Y : Float := 0.0;
   end record;

end UI.Widgets.Pins;
