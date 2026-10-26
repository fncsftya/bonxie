with Canvas_VM;
with System;
with Pomarine.Widgets.Pins;
with View.Links.Support;

package body View.Links.Events is

   package Pins renames Pomarine.Widgets.Pins;

   use type System.Address;

   Side_Count : constant := Item_Links.Sides'Pos (Item_Links.Sides'Last) + 1;

   procedure Set_Accepting (Item : in out Session; Except : Natural) is
   begin
      for Which in 1 .. Item.Windows.Count loop
         for Side in Item_Links.Sides loop
            Pins.Set_Accepting
              (Item.Linking.Pins (Which) (Side),
               Except /= 0 and then Which /= Except);
         end loop;
      end loop;
   end Set_Accepting;

   function Pin_Number (Which : Items.Slot; Side : Item_Links.Sides) return Positive is
     ((Which - 1) * Side_Count + Item_Links.Sides'Pos (Side) + 1);

   procedure Pin_Pressed
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
      Which : constant Items.Slot := (Event.Index - 1) / Side_Count + 1;
      Side  : constant Item_Links.Sides := Item_Links.Sides'Val ((Event.Index - 1) mod Side_Count);
   begin
      if Canvas_VM.Link_From (Item.Canvas_Model.Model) = 0 then
         Canvas_VM.Begin_Link (Item.Canvas_Model.Model, Which, Side);
         Set_Accepting (Item, Which);
      end if;
   end Pin_Pressed;

   procedure Handle_Pressed
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      if Canvas_VM.Link_From (Item.Canvas_Model.Model) /= 0 then
         return;
      end if;
      Canvas_VM.Begin_Moving_Link (Item.Canvas_Model.Model);
      if Canvas_VM.Link_From (Item.Canvas_Model.Model) /= 0 then
         Set_Accepting (Item, Canvas_VM.Link_From (Item.Canvas_Model.Model));
      else
         Pins.Cancel (Item.Linking.Link_Handle);
      end if;
   end Handle_Pressed;

   procedure Pin_Released
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Event);
      Model : Canvas_VM.View_Model renames Item.Canvas_Model.Model;
      To    : Natural := 0;
      Where : Item_Links.Sides := Item_Links.Top;
   begin
      if Canvas_VM.Link_From (Model) = 0 or else Source'Address /= Support.Dragger (Item).all'Address then
         return;
      end if;
      --  The pointer is over the pin it was let go on, if any.
      for Which in 1 .. Item.Windows.Count loop
         for Side in Item_Links.Sides loop
            if Which /= Canvas_VM.Link_From (Model)
              and then Widgets.Is_Showing (Item.Linking.Pins (Which) (Side))
              and then Widgets.Is_Hovered (Item.Linking.Pins (Which) (Side))
            then
               To := Which;
               Where := Side;
            end if;
         end loop;
      end loop;
      Canvas_VM.End_Link (Model, To, Where);
      Set_Accepting (Item, 0);
   end Pin_Released;

end View.Links.Events;
