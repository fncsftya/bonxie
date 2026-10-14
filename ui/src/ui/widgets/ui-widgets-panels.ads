with SDL3.Windows.Renderers;
private with UI.Boxes;

--  A box that holds other widgets, to lay them out: with a colour to
--  fill it with, or none, to show what is behind; an outline, and a
--  shadow (see UI.Boxes), if it is to stand out; and a ring over what is
--  in it, as of what is chosen.
package UI.Widgets.Panels is

   type Panel is new Widget with private;

   procedure Set_Fill (Item : in out Panel; Value : Themes.Slot);
   --  Fill the box with Value, a colour of the theme.

   procedure Set_Fill_Color (Item : in out Panel; Value : Themes.Color);
   --  Fill the box with Value, whatever the theme: for a colour that is
   --  not one of the theme's.

   procedure Clear_Fill (Item : in out Panel);
   --  Fill it with nothing.

   function Has_Fill (Item : Panel) return Boolean;

   function Fill (Item : Panel) return Themes.Slot
     with Pre => Has_Fill (Item);

   procedure Set_Border
     (Item : in out Panel; Value : Themes.Slot; Dashed : Boolean := False);
   --  Outline the face a point wide in Value, in dashes if Dashed. What
   --  is in it is laid over the outline unless it is padded clear of it.

   procedure Set_Shadow (Item : in out Panel; Value : Themes.Slot);
   --  Cast a shadow in Value, inside the box (see UI.Boxes): pad what is
   --  in it clear of that at the right and the foot.

   procedure Set_Ring (Item : in out Panel; Value : Themes.Slot);
   --  Draw a ring of Ring_Width points in Value round the face, over what
   --  is in it.

   procedure Clear_Ring (Item : in out Panel);

   Ring_Width : constant Float := 2.0;

   overriding procedure Draw
     (Item   : in out Panel;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme);

   overriding procedure Draw_Over
     (Item   : in out Panel;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme);

private

   type Panel is new Widget with record
      Look   : UI.Boxes.Look;  --  its flags; its colours are the slots below
      Fill_Slot   : Themes.Slot := Themes.Page;
      Fill_Fixed  : Boolean := False;  --  whether Fill_Color is the fill
      Fill_Color  : Themes.Color := (0, 0, 0, 255);
      Border_Slot : Themes.Slot := Themes.Border;
      Shadow_Slot : Themes.Slot := Themes.Shadow;
      Ringed : Boolean := False;
      Ring_Slot : Themes.Slot := Themes.Focus;
   end record;

end UI.Widgets.Panels;
