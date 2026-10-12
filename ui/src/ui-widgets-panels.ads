with SDL3.Windows.Renderers;

--  A box that holds other widgets, to lay them out: with a colour to
--  fill it with, or none, to show what is behind.
package UI.Widgets.Panels is

   type Panel is new Widget with private;

   procedure Set_Fill (Item : in out Panel; Value : Themes.Color);
   --  Fill the box with Value, which is opaque if its Alpha is 255.

   procedure Clear_Fill (Item : in out Panel);
   --  Fill it with nothing.

   function Has_Fill (Item : Panel) return Boolean;

   function Fill (Item : Panel) return Themes.Color
     with Pre => Has_Fill (Item);

   overriding procedure Draw
     (Item   : in out Panel;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme);

private

   type Panel is new Widget with record
      Filled : Boolean := False;
      Color  : Themes.Color := (0, 0, 0, 255);
   end record;

end UI.Widgets.Panels;
