with Pomarine.Widgets.Canvases;

package body Viewer.Links.Support is

   package Widgets renames Pomarine.Widgets;
   package Canvases renames Pomarine.Widgets.Canvases;
   package Windows renames Items.Windows;

   use type Items.Id;
   use type Items.States;

   function Diameter (Item : Session) return Float is
     (Float'Rounding (Pins.Diameter * Widgets.Density (Item.Root.Widgets)));

   function Is_Open (Item : Session; Which : Items.Slot) return Boolean is
     (Windows.Is_Assigned (Item.Windows (Which))
      and then Windows.Details (Item.Windows (Which)).State = Items.Open);

   function Slot_Of (Item : Session; Key : Items.Id) return Natural is
   begin
      for Which in Items.Slot loop
         if Is_Open (Item, Which)
           and then Windows.Details (Item.Windows (Which)).Key = Key
         then
            return Which;
         end if;
      end loop;
      return 0;
   end Slot_Of;

   function Index_Of (Item : Session; Key : Items.Id) return Natural is
   begin
      for Number in 1 .. Item.Linking.Link_Set.Count loop
         if Item.Linking.Link_Set.Links (Number).Key = Key then
            return Number;
         end if;
      end loop;
      return 0;
   end Index_Of;

   function Middle
     (Where : Items.Frame; Side : Item_Links.Sides) return Point is
     (Boxes.Side_Midpoint
        (Where.Left, Where.Top, Where.Width, Where.Height,
         Boxes.Sides'Val (Item_Links.Sides'Pos (Side))));

   function Pixels_Of (Item : Session; Spot : Point) return Point is
     ((X => Float'Rounding
              (Canvases.To_Screen (Spot.X, Item.Nav.Shown_Zoom,
                                   Item.Nav.Shown_X)
               * Widgets.Density (Item.Root.Widgets)),
       Y => Float'Rounding
              (Canvases.To_Screen (Spot.Y, Item.Nav.Shown_Zoom,
                                   Item.Nav.Shown_Y)
               * Widgets.Density (Item.Root.Widgets))));

   function Dragger (Item : Session) return access Pins.Pin is
     (if Item.Linking.Link_Moving
      then Item.Linking.Link_Handle'Unrestricted_Access
      else Item.Linking.Pins (Item.Linking.Link_From,
                              Item.Linking.Link_From_Side)'Unrestricted_Access);

end Viewer.Links.Support;
