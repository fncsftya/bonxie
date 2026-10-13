with SDL3.Cursors;
with SDL3.Events;
with SDL3.Windows.Renderers;

--  A slider to drag: a track with a knob on it, whose place along the
--  track is a value from 0.0, at the left, to 1.0, at the right.
--
--  A press of the left button on it moves the knob to the pointer, and
--  starts a drag, which lasts until the button is let go, wherever the
--  pointer goes. The application takes the change, as it takes a
--  button's click.
package UI.Widgets.Sliders is

   type Slider is new Widget with private;

   procedure Set_Value (Item : in out Slider; To : Float)
     with Pre  => To in 0.0 .. 1.0,
          Post => Is_Dragging (Item) or else Value (Item) = To;
   --  Put the knob there, as the application's model has it. It does not
   --  count as a change to take, and is ignored while the knob is held, which
   --  the pointer moves.

   function Value (Item : Slider) return Float
     with Post => Value'Result in 0.0 .. 1.0;

   procedure Take_Change (Item : in out Slider; Changed : out Boolean);
   --  Say whether the knob has been moved by the pointer since this was
   --  last called, and forget it.

   function Is_Dragging (Item : Slider) return Boolean;
   --  Whether the button is down from a press on it.

   overriding procedure Handle
     (Item    : in out Slider;
      Event   : SDL3.Events.Event;
      Handled : out Boolean);

   overriding procedure Draw
     (Item   : in out Slider;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme);

   overriding procedure Hover_Changed
     (Item : in out Slider; Hovered : Boolean);

   overriding function Cursor (Item : Slider) return SDL3.Cursors.Kind;

private

   type Slider is new Widget with record
      Fraction : Float := 0.0;
      Held     : Boolean := False;
      Moved    : Boolean := False;
   end record;

end UI.Widgets.Sliders;
