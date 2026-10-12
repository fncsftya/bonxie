with SDL3.Events;
with SDL3.Windows.Renderers;
with UI.Icons;

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

   type Kind is (Normal, Primary, Danger);
   --  Primary is in the theme's primary colour, for the main action;
   --  Danger in its danger colour, for what cannot be undone.

   procedure Set_Kind (Item : in out Button; To : Kind);

   function Kind_Of (Item : Button) return Kind;

   procedure Set_Label (Item : in out Button; Text : String)
     with Pre => Text'Length <= Label_Capacity;
   --  Show Text, in the debug font of SDL3.Windows.Renderers, scaled to
   --  the density, in the middle.

   procedure Set_Icon (Item : in out Button; To : UI.Icons.Icon);
   --  Show the icon, in the middle, in place of the label, if the tree has
   --  icons and the icon can be drawn; the label otherwise.

   function Has_Icon (Item : Button) return Boolean;

   procedure Set_Captioned (Item : in out Button; To : Boolean);
   --  With an icon, show the label under it, in place of the icon alone.

   procedure Set_Selected (Item : in out Button; To : Boolean);
   --  Show it as pressed in, as the chosen one of a row of tabs; it still
   --  takes clicks.

   function Is_Selected (Item : Button) return Boolean;

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
      Style   : Kind := Normal;
      Picture : Boolean := False;
      Which   : UI.Icons.Icon := UI.Icons.Icon'First;
      Captioned : Boolean := False;
      Selected  : Boolean := False;
      Down    : Boolean := False;  --  pressed, and not yet let go
      Clicked : Boolean := False;
   end record;

end UI.Widgets.Buttons;
