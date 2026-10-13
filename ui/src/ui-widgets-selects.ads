with SDL3.Cursors;
with SDL3.Events;
with SDL3.Windows.Renderers;

--  A field to choose a value in, from a menu: white, outlined, as a field
--  to type in, with the value at the left and, at the right, a button
--  that stands up, a caret on it, as a dropdown's. Open (Set_Open), the
--  button is pressed in and the caret is turned up.
--
--  A click on it is for the application to take, as a button's, and to
--  show a menu of the values for (see UI.Widgets.Menus); it says the one
--  chosen with Set_Value. Turned off (Set_Enabled), it is tinted and
--  faint, and takes nothing.
package UI.Widgets.Selects is

   Value_Capacity : constant := 48;
   --  Bytes of value.

   type Select_Field is new Widget with private;

   procedure Set_Value (Item : in out Select_Field; Text : String)
     with Pre => Text'Length <= Value_Capacity;

   function Value (Item : Select_Field) return String;

   procedure Set_Open (Item : in out Select_Field; To : Boolean);
   --  Show it as open, its menu shown, or not.

   function Is_Open (Item : Select_Field) return Boolean;

   procedure Set_Enabled (Item : in out Select_Field; To : Boolean);

   function Is_Enabled (Item : Select_Field) return Boolean;

   procedure Take_Click (Item : in out Select_Field; Clicked : out Boolean);
   --  Say whether it has been clicked since this was last called, and
   --  forget it.

   overriding procedure Handle
     (Item    : in out Select_Field;
      Event   : SDL3.Events.Event;
      Handled : out Boolean);

   overriding procedure Draw
     (Item   : in out Select_Field;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme);

   overriding procedure Hover_Changed
     (Item : in out Select_Field; Hovered : Boolean);

   overriding function Cursor
     (Item : Select_Field) return SDL3.Cursors.Kind;

private

   type Select_Field is new Widget with record
      Text    : String (1 .. Value_Capacity) := [others => ' '];
      Length  : Natural range 0 .. Value_Capacity := 0;
      Open    : Boolean := False;
      Enabled : Boolean := True;
      Down    : Boolean := False;
      Clicked : Boolean := False;
   end record;

end UI.Widgets.Selects;
