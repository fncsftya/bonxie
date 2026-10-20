with Items.Links;
with Pomarine.Widgets;

--  What the pins and the link's buttons say: links made, moved, restyled and deleted.
private package Viewer.Links.Events is

   package Widgets renames Pomarine.Widgets;
   package Item_Links renames Items.Links;

   procedure Set_Accepting (Item : in out Session; Except : Natural);
   --  Say which pins a line being dragged may end on: those of all the
   --  windows but Except, or none, if that is 0.

   function Pin_Number (Which : Items.Slot; Side : Item_Links.Sides) return Positive;
   --  What a pin says of itself, as its Index.

   procedure Pin_Pressed
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);
   --  A pin was pressed: start a drag from it, if none is on.

   procedure Handle_Pressed
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);
   --  The handle of the link selected was pressed: move the link, if its
   --  window is there to move it from.

   procedure Pin_Released
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);
   --  The pin that was held, while a line was dragged, was let go: end the
   --  drag where the button was let go.

   procedure Stroke_Clicked
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);
   --  A stroke button of the toolbar: Index says which.

   procedure Ending_Clicked
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);

   procedure Color_Clicked
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);

   procedure Delete_Clicked
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);
   --  The toolbar's button to delete the link selected.

   procedure Line_Selected
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);
   --  A line was pressed on (Row is its tag), or none: select that link.

   procedure Line_Deleted
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);
   --  Backspace was pressed with a line selected: delete its link.

end Viewer.Links.Events;
