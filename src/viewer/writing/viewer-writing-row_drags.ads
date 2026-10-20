--  Dragging a row of the sidebar to another place.
private package Viewer.Writing.Row_Drags is

   package Widgets renames Pomarine.Widgets;

   procedure Row_Dragged
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);
   --  A row of the tree was dragged a little (Across, Down): the drag has
   --  begun if it was far enough, and the row is over what it would be
   --  dropped on.

   procedure Row_Released
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event);
   --  A row of the tree was let go: it is dropped, if it was dragged.

end Viewer.Writing.Row_Drags;
