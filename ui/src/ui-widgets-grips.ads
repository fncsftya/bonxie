with SDL3.Cursors;
with SDL3.Events;
with SDL3.Windows.Renderers;

--  A place to take hold of and drag, as a window's title bar to move it
--  or its corner to size it. It has no state of the thing it moves: it
--  says how far the pointer has gone, and the application moves it, as it
--  takes a button's click.
--
--  A press of the left button on it, where nothing in it takes the press,
--  starts a drag, which lasts until the button is let go, wherever the
--  pointer goes.
package UI.Widgets.Grips is

   type Shape is (Bar, Corner);
   --  Bar draws nothing, and is for a panel to be dragged by. Corner
   --  draws a few dots in a triangle in its lower right, the mark of a
   --  corner to size by.

   type Grip is new Widget with private;

   procedure Set_Shape (Item : in out Grip; To : Shape);

   procedure Set_Fill (Item : in out Grip; Value : Themes.Color);
   --  Fill its box with Value, behind what is in it, which it is drawn
   --  with: a bar to drag by, and the widgets on it. By default it fills
   --  with nothing.

   procedure Set_Wanted_Cursor (Item : in out Grip; To : SDL3.Cursors.Kind);
   --  The pointer's shape over it, and while it is dragged.

   procedure Set_Hover_Outline (Item : in out Grip; Value : Themes.Color);
   --  Draw an outline of a point round its box, in Value, while the
   --  pointer is over it or what is in it: to show it can be used.

   procedure Take_Click (Item : in out Grip; Clicked : out Boolean);
   --  Say whether the button has been let go over it, after a press on
   --  it, since this was last called, and forget it.

   procedure Take_Double_Click (Item : in out Grip; Doubled : out Boolean);
   --  Say whether it has been pressed twice in quick succession since
   --  this was last called, and forget it.

   procedure Take_Drag (Item : in out Grip; Across, Down : out Float);
   --  How far the pointer has gone, in points to the right and down,
   --  since this was last called, and forget it.

   procedure Cancel_Drag (Item : in out Grip)
     with Post => not Is_Dragging (Item);
   --  Forget a press, as when what it was on is hidden and so will not
   --  be told the button is let go.

   function Is_Dragging (Item : Grip) return Boolean;
   --  Whether the button is down from a press on it.

   overriding procedure Handle
     (Item    : in out Grip;
      Event   : SDL3.Events.Event;
      Handled : out Boolean);

   overriding procedure Draw
     (Item   : in out Grip;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme);

   overriding procedure Hover_Changed
     (Item : in out Grip; Hovered : Boolean);

   overriding function Cursor (Item : Grip) return SDL3.Cursors.Kind;

private

   type Grip is new Widget with record
      Form    : Shape := Bar;
      Filled  : Boolean := False;
      Color   : Themes.Color := (0, 0, 0, 255);
      Wanted  : SDL3.Cursors.Kind := SDL3.Cursors.Move;
      Outlined : Boolean := False;
      Outline_Color : Themes.Color := (0, 0, 0, 255);
      Clicked : Boolean := False;
      Doubled : Boolean := False;
      Held    : Boolean := False;
      Last_X, Last_Y : Float := 0.0;
      --  Where the pointer was, in points.
      Across, Down : Float := 0.0;
      --  How far it has gone since it was taken.
   end record;

end UI.Widgets.Grips;
