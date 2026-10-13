with SDL3.Events;
with SDL3.Windows.Renderers;
with UI.Scrollbars;

--  A box that shows part of what is taller than it is, to scroll with the
--  wheel (or a trackpad's two fingers): its one child, which it clips to
--  its box, and which the layout sizes to fit what is in it, as a column
--  of rows. While the pointer is over it, a bar along its right edge shows
--  how far down it is, and can be dragged.
--
--  It moves the child by the child's position, so the child's own style
--  must leave that to it.
package UI.Widgets.Scrollers is

   Points_Per_Notch : constant Float := 24.0;
   --  How far a notch of the wheel scrolls.

   type Scroller is new Widget with private;

   function Offset (Item : Scroller) return Float;
   --  How far the child has been moved up, in points: 0 when its top is
   --  at the top of the box.

   procedure Scroll_To (Item : in out Scroller; To : Float)
     with Pre => Is_Attached (Item) and then Child_Count (Item) = 1;
   --  Show the child from To points down, no further than shows its end,
   --  as of the last layout, and no less than its start.

   overriding procedure Draw_Over
     (Item   : in out Scroller;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme);
   --  Its scroll bar, over the child.

   overriding procedure Hover_Changed
     (Item : in out Scroller; Hovered : Boolean);

   overriding procedure Handle
     (Item    : in out Scroller;
      Event   : SDL3.Events.Event;
      Handled : out Boolean);

private

   type Scroller is new Widget with record
      Moved : Float := 0.0;
      Bar   : Scrollbars.Bar;
   end record;

end UI.Widgets.Scrollers;
