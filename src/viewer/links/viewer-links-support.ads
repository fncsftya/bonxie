with Canvas_VM;
with Items.Links;
with Pomarine.Boxes;
with Pomarine.Widgets;
with Pomarine.Widgets.Pins;

--  Where the pins and windows are, and which are open, shared by the links' parts.
private package Viewer.Links.Support is

   package Boxes renames Pomarine.Boxes;
   package Pins renames Pomarine.Widgets.Pins;
   package Item_Links renames Items.Links;

   subtype Point is Boxes.Spot;

   function Diameter (Item : Session) return Float;
   --  Of a pin, in pixels.

   function Is_Open (Item : Session; Which : Items.Slot) return Boolean;

   function Slot_Of (Item : Session; Key : Items.Id) return Natural;
   --  The window of the item, if it is open; 0 if not.

   function Index_Of (Item : Session; Key : Items.Id) return Natural;
   --  Of the link in the set; 0 if there is none.

   function Middle
     (Where : Items.Frame; Side : Item_Links.Sides) return Point;
   --  The middle of the side of the window, in canvas units.

   function Pixels_Of (Item : Session; Spot : Point) return Point;
   --  A place on the canvas, in pixels from its top left.

   function Dragger (Item : Session) return access Pins.Pin
     with Pre => Canvas_VM.Link_From (Item.Canvas_Model.Model) /= 0;
   --  The pin that is held while a line is dragged.

end Viewer.Links.Support;
