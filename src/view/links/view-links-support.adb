with Items.Models;
with Pomarine.Widgets.Canvases;

package body View.Links.Support is

   package Widgets renames Pomarine.Widgets;
   package Canvases renames Pomarine.Widgets.Canvases;
   package Windows renames Items.Windows;
   package Models renames Items.Models;

   use type Items.States;

   function Diameter (Item : Session) return Float is
     (Float'Rounding (Pins.Diameter * Widgets.Density (Item.Root.Widgets)));

   function Is_Open (Item : Session; Which : Items.Slot) return Boolean is
     (Windows.Is_Assigned (Item.Windows (Which))
      and then Models.Details (Item.Models (Which)).State = Items.Open);

   function Slot_Of (Item : Session; Key : Items.Id) return Natural is
      Which : constant Natural := Canvas_VM.Slot_Of (Item.Canvas_Model.Model, Key);
   begin
      return (if Which /= 0 and then Is_Open (Item, Which) then Which else 0);
   end Slot_Of;

   function Index_Of (Item : Session; Key : Items.Id) return Natural is
     (Canvas_VM.Link_Number (Item.Canvas_Model.Model, Key));

   function Middle
     (Where : Items.Frame; Side : Item_Links.Sides) return Point is
     (Boxes.Side_Midpoint
        (Where.Left, Where.Top, Where.Width, Where.Height,
         Boxes.Sides'Val (Item_Links.Sides'Pos (Side))));

   function Pixels_Of (Item : Session; Spot : Point) return Point is
     ((X => Float'Rounding
              (Canvases.To_Screen (Spot.X, Canvas_VM.Camera (Item.Canvas_Model.Model).Zoom,
                                   Canvas_VM.Camera (Item.Canvas_Model.Model).Origin_X)
               * Widgets.Density (Item.Root.Widgets)),
       Y => Float'Rounding
              (Canvases.To_Screen (Spot.Y, Canvas_VM.Camera (Item.Canvas_Model.Model).Zoom,
                                   Canvas_VM.Camera (Item.Canvas_Model.Model).Origin_Y)
               * Widgets.Density (Item.Root.Widgets))));

   function Dragger (Item : Session) return access Pins.Pin is
      Model : Canvas_VM.View_Model renames Item.Canvas_Model.Model;
   begin
      if Canvas_VM.Is_Moving_Link (Model) then
         return Item.Linking.Link_Handle'Unrestricted_Access;
      end if;
      return Item.Linking.Pins (Canvas_VM.Link_From (Model)) (Canvas_VM.Link_From_Side (Model))'Unrestricted_Access;
   end Dragger;

end View.Links.Support;
