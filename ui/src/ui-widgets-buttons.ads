with SDL3.Events;
with SDL3.Windows.Renderers;

--  A button to click, with a short label.
--
--  It is pressed by the left button over it, and clicked by that button
--  let go over it; the application takes the click. It does not take the
--  focus, so that clicking it does not take it from what is being typed
--  into.
package UI.Widgets.Buttons is

   Label_Capacity : constant := 32;
   --  Characters of label.

   type Button is new Widget with private;

   procedure Set_Label (Item : in out Button; Text : String)
     with Pre => Text'Length <= Label_Capacity;
   --  Show Text, in the debug font of SDL3.Windows.Renderers, scaled to
   --  the density, in the middle.

   function Label (Item : Button) return String;

   procedure Take_Click (Item : in out Button; Clicked : out Boolean);
   --  Say whether it has been clicked since this was last called, and
   --  forget it.

   function Is_Pressed (Item : Button) return Boolean;
   --  Whether the button is down, and over it.

   overriding procedure Handle
     (Item    : in out Button;
      Event   : SDL3.Events.Event;
      Handled : out Boolean);

   overriding procedure Draw
     (Item   : in out Button;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme);

   overriding procedure Hover_Changed
     (Item : in out Button; Hovered : Boolean);

private

   type Button is new Widget with record
      Text    : String (1 .. Label_Capacity) := [others => ' '];
      Length  : Natural range 0 .. Label_Capacity := 0;
      Down    : Boolean := False;  --  pressed, and not yet let go
      Clicked : Boolean := False;
   end record;

end UI.Widgets.Buttons;
