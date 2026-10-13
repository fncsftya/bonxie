with SDL3.Windows.Renderers;

--  A tooltip: a short name for what is under the pointer, white on the
--  dark bars' colour, in the middle of its box. The application shows it
--  (below the thing, not over it, so that the pointer is not taken from
--  that) and hides it; Natural_Width says how wide to make it. It takes
--  no events.
package UI.Widgets.Tooltips is

   Text_Capacity : constant := 48;
   --  Bytes.

   type Tooltip is new Widget with private;

   procedure Set_Text (Item : in out Tooltip; Value : String)
     with Pre => Value'Length <= Text_Capacity;

   function Text (Item : Tooltip) return String;

   function Natural_Width (Item : Tooltip) return Float
     with Pre => Is_Attached (Item);
   --  In points: of the text, and its padding.

   Height : constant Float := 22.0;
   --  In points, to make it.

   overriding procedure Draw
     (Item   : in out Tooltip;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme);

private

   type Tooltip is new Widget with record
      Content : String (1 .. Text_Capacity) := [others => ' '];
      Length  : Natural range 0 .. Text_Capacity := 0;
   end record;

end UI.Widgets.Tooltips;
