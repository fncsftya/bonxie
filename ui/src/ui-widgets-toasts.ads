with SDL3.Events;
with SDL3.Windows.Renderers;

--  A toast: a short message that something has been done, on a white box,
--  outlined, casting a solid shadow, with a bar of the theme's primary
--  colour down its left, and, if it is given one, a small button at its
--  right to do something of it (as Undo). A click on the button is the
--  application's to take, as a button's. The application shows it, and
--  hides it when it has been shown long enough.
package UI.Widgets.Toasts is

   Text_Capacity : constant := 48;
   Action_Capacity : constant := 16;
   --  Bytes, of the message and of the button's label.

   type Toast is new Widget with private;

   procedure Set_Message (Item : in out Toast; Text : String)
     with Pre => Text'Length <= Text_Capacity;

   function Message (Item : Toast) return String;

   procedure Set_Action (Item : in out Toast; Label : String)
     with Pre => Label'Length <= Action_Capacity;
   --  The label of the button; none ("") to have no button.

   function Action (Item : Toast) return String;

   procedure Take_Action (Item : in out Toast; Clicked : out Boolean);
   --  Say whether the button has been clicked since this was last called,
   --  and forget it.

   Height : constant Float := 36.0;
   --  In points, to make it, with its shadow.

   overriding procedure Handle
     (Item    : in out Toast;
      Event   : SDL3.Events.Event;
      Handled : out Boolean);

   overriding procedure Draw
     (Item   : in out Toast;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme);

   overriding procedure Hover_Changed
     (Item : in out Toast; Hovered : Boolean);

private

   type Toast is new Widget with record
      Text    : String (1 .. Text_Capacity) := [others => ' '];
      Length  : Natural range 0 .. Text_Capacity := 0;
      Label   : String (1 .. Action_Capacity) := [others => ' '];
      Label_Length : Natural range 0 .. Action_Capacity := 0;
      Over    : Boolean := False;  --  the pointer is over the button
      Down    : Boolean := False;  --  pressed on the button
      Clicked : Boolean := False;
   end record;

end UI.Widgets.Toasts;
