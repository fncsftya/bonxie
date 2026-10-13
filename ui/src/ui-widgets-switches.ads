with SDL3.Cursors;
with SDL3.Events;
with SDL3.Windows.Renderers;

--  A switch, on or off, with a label after it: a track sunk into what it
--  is on, grey when off, in the theme's primary colour when on, and a knob
--  that stands up in it, at the left when off and the right when on.
--
--  A click on it turns it over, a change for the application to take, as
--  it takes a button's click. Turned off (Set_Enabled), it is faint and
--  takes nothing.
package UI.Widgets.Switches is

   Label_Capacity : constant := 48;
   --  Bytes of label.

   type Switch is new Widget with private;

   procedure Set_Label (Item : in out Switch; Text : String)
     with Pre => Text'Length <= Label_Capacity;

   function Label (Item : Switch) return String;

   procedure Set_On (Item : in out Switch; To : Boolean)
     with Post => Is_On (Item) = To;
   --  As the application's model has it. It is not a change to take.

   function Is_On (Item : Switch) return Boolean;

   procedure Set_Enabled (Item : in out Switch; To : Boolean);

   function Is_Enabled (Item : Switch) return Boolean;

   procedure Take_Change (Item : in out Switch; Changed : out Boolean);
   --  Say whether it has been turned over by a click since this was last
   --  called, and forget it.

   Track_Width  : constant Float := 32.0;
   Track_Height : constant Float := 16.0;
   --  In points.

   overriding procedure Handle
     (Item    : in out Switch;
      Event   : SDL3.Events.Event;
      Handled : out Boolean);

   overriding procedure Draw
     (Item   : in out Switch;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme);

   overriding procedure Hover_Changed
     (Item : in out Switch; Hovered : Boolean);

   overriding function Cursor (Item : Switch) return SDL3.Cursors.Kind;

private

   type Switch is new Widget with record
      Text    : String (1 .. Label_Capacity) := [others => ' '];
      Length  : Natural range 0 .. Label_Capacity := 0;
      On      : Boolean := False;
      Enabled : Boolean := True;
      Down    : Boolean := False;
      Changed : Boolean := False;
   end record;

end UI.Widgets.Switches;
