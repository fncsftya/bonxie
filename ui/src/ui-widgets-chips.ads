with SDL3.Events;
with SDL3.Windows.Renderers;

--  A chip: a small white box, outlined, that names a thing (a square of
--  its colour, if it is given one, and its name) and has a small button
--  at its right, standing up, a cross on it, to take the thing away. A
--  click on the cross is the application's to take, as a button's.
package UI.Widgets.Chips is

   Label_Capacity : constant := 48;
   --  Bytes of label.

   type Chip is new Widget with private;

   procedure Set_Label (Item : in out Chip; Text : String)
     with Pre => Text'Length <= Label_Capacity;

   function Label (Item : Chip) return String;

   procedure Set_Swatch (Item : in out Chip; To : Themes.Color);
   --  Show a square of the colour before the label.

   procedure Take_Close (Item : in out Chip; Closed : out Boolean);
   --  Say whether its cross has been clicked since this was last called,
   --  and forget it.

   overriding procedure Handle
     (Item    : in out Chip;
      Event   : SDL3.Events.Event;
      Handled : out Boolean);

   overriding procedure Draw
     (Item   : in out Chip;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme);

   overriding procedure Hover_Changed
     (Item : in out Chip; Hovered : Boolean);

private

   type Chip is new Widget with record
      Text     : String (1 .. Label_Capacity) := [others => ' '];
      Length   : Natural range 0 .. Label_Capacity := 0;
      Swatched : Boolean := False;
      Swatch   : Themes.Color := (0, 0, 0, 255);
      Down     : Boolean := False;  --  pressed on the cross
      Over     : Boolean := False;  --  the pointer is over the cross
      Closed   : Boolean := False;
   end record;

end UI.Widgets.Chips;
