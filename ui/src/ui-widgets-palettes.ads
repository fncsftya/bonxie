with SDL3.Cursors;
with SDL3.Events;
with SDL3.Windows.Renderers;

--  A small panel that floats over its parent, outside its layout (the
--  application sets it absolute, and where it starts), with a grip along
--  its top, and widgets in it. It can be dragged by the grip or by any
--  part of it that its widgets do not take, but not out of its parent.
package UI.Widgets.Palettes is

   Grip_Height : constant Float := 12.0;
   --  Of the grip along its top, in points: the application leaves this
   --  much room there, as padding.

   type Palette is new Widget with private;

   function Is_Dragging (Item : Palette) return Boolean;

   overriding procedure Draw
     (Item   : in out Palette;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme);

   overriding procedure Handle
     (Item    : in out Palette;
      Event   : SDL3.Events.Event;
      Handled : out Boolean);

   overriding function Cursor (Item : Palette) return SDL3.Cursors.Kind;

private

   type Palette is new Widget with record
      Dragging : Boolean := False;
      Grab_X, Grab_Y : Float := 0.0;
      --  Where it was held, in pixels from its top left.
      Pointer_Y : Float := 0.0;
      --  Where the pointer was last seen over it, in pixels.
   end record;

end UI.Widgets.Palettes;
