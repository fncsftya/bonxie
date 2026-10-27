with Items.Links;
with Pomarine.Widgets;

--  What the pins and the link's handle say: links made and moved. Restyling and deleting are commands of
--  Canvas_VM, bound beside the buttons.

private package View.Links.Events is

   package Widgets renames Pomarine.Widgets;
   package Item_Links renames Items.Links;

   procedure Set_Accepting (Item : in out Session; Except : Natural);
   --  Say which pins a line being dragged may end on: those of all the
   --  windows but Except, or none, if that is 0.

   function Pin_Number (Which : Items.Slot; Side : Item_Links.Sides) return Positive;
   --  What a pin says of itself, as its Index.

   procedure Pin_Pressed (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);
   --  A pin was pressed: start a drag from it, if none is on.

   procedure Handle_Pressed (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);
   --  The handle of the link selected was pressed: move the link, if its
   --  window is there to move it from.

   procedure Pin_Released (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);
   --  The pin that was held, while a line was dragged, was let go: end the
   --  drag where the button was let go.

end View.Links.Events;
