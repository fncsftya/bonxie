with SDL3.Cursors;
with SDL3.Events;
with SDL3.Windows.Renderers;

--  A box to tick, or one of a set to choose among (a radio): a small white
--  square, sunk into what it is on, with a label after it, and a square of
--  a colour between them if it is given one. A ticked box has a tick in
--  it; a chosen radio, a dark square. There are no round corners, so a
--  radio is square too.
--
--  A click on it (the box, or its label) is a change for the application
--  to take, as it takes a button's click: a box is ticked or not, the
--  other way; a radio is chosen, if it was not. What the application
--  makes of it, it says back with Set_Checked, as for the others of a set
--  of radios. Turned off (Set_Enabled), it is faint and takes nothing.
package UI.Widgets.Checks is

   Label_Capacity : constant := 48;
   --  Bytes of label.

   type Kind is (Box, Radio);

   type Check is new Widget with private;

   procedure Set_Kind (Item : in out Check; To : Kind);

   function Kind_Of (Item : Check) return Kind;

   procedure Set_Label (Item : in out Check; Text : String)
     with Pre => Text'Length <= Label_Capacity;

   function Label (Item : Check) return String;

   procedure Set_Checked (Item : in out Check; To : Boolean)
     with Post => Is_Checked (Item) = To;
   --  As the application's model has it. It is not a change to take.

   function Is_Checked (Item : Check) return Boolean;

   procedure Set_Swatch (Item : in out Check; To : Themes.Color);
   --  Show a square of the colour between the box and the label.

   procedure Set_Enabled (Item : in out Check; To : Boolean);

   function Is_Enabled (Item : Check) return Boolean;

   procedure Take_Change (Item : in out Check; Changed : out Boolean);
   --  Say whether it has been clicked, and so changed, since this was last
   --  called, and forget it.

   Box_Size : constant Float := 14.0;
   --  In points, a side of the box.

   overriding procedure Handle
     (Item    : in out Check;
      Event   : SDL3.Events.Event;
      Handled : out Boolean);

   overriding procedure Draw
     (Item   : in out Check;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme);

   overriding procedure Hover_Changed
     (Item : in out Check; Hovered : Boolean);

   overriding function Cursor (Item : Check) return SDL3.Cursors.Kind;

private

   type Check is new Widget with record
      Form     : Kind := Box;
      Text     : String (1 .. Label_Capacity) := [others => ' '];
      Length   : Natural range 0 .. Label_Capacity := 0;
      Checked  : Boolean := False;
      Swatched : Boolean := False;
      Swatch   : Themes.Color := (0, 0, 0, 255);
      Enabled  : Boolean := True;
      Down     : Boolean := False;
      Changed  : Boolean := False;
   end record;

end UI.Widgets.Checks;
