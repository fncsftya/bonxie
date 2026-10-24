with Canvas_VM;
with System;
with Pomarine.Widgets.Pins;
with View.Links.Support;

package body View.Links.Events is

   package Pins renames Pomarine.Widgets.Pins;

   use type System.Address;
   use type Items.Id;

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
              and then Widgets.Is_Shown (Item.Linking.Pins (Which) (Side))
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

   procedure Restyle_Selected
     (Item   : in out Session;
      Stroke : Item_Links.Strokes;
      Ending : Item_Links.Endings;
      Color  : Item_Links.Link_Colors);
   --  Give the link selected another look.

   procedure Restyle_Selected
     (Item   : in out Session;
      Stroke : Item_Links.Strokes;
      Ending : Item_Links.Endings;
      Color  : Item_Links.Link_Colors) is
   begin
      Canvas_VM.Restyle (Item.Canvas_Model.Model, Stroke, Ending, Color);
   end Restyle_Selected;

   function Chosen (Item : Session) return Natural is
     (Canvas_VM.Link_Number (Item.Canvas_Model.Model, Canvas_VM.Selected_Link (Item.Canvas_Model.Model)));
   --  The place of the link selected; 0 if none is.

   function Was_Of (Item : Session) return Item_Links.Link is
     (Canvas_VM.Link_At (Item.Canvas_Model.Model, Chosen (Item)))
     with Pre => Chosen (Item) /= 0;

   function Is_Selected (Item : Session) return Boolean is (Chosen (Item) /= 0);

   procedure Stroke_Clicked
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
   begin
      if Is_Selected (Item) then
         Restyle_Selected
           (Item, Item_Links.Strokes'Val (Event.Index - 1), Was_Of (Item).Ending, Was_Of (Item).Color);
      end if;
   end Stroke_Clicked;

   procedure Ending_Clicked
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
   begin
      if Is_Selected (Item) then
         Restyle_Selected
           (Item, Was_Of (Item).Stroke, Item_Links.Endings'Val (Event.Index - 1), Was_Of (Item).Color);
      end if;
   end Ending_Clicked;

   procedure Color_Clicked
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
   begin
      if Is_Selected (Item) then
         Restyle_Selected (Item, Was_Of (Item).Stroke, Was_Of (Item).Ending, Event.Index);
      end if;
   end Color_Clicked;

   procedure Delete_Selected (Item : in out Session);
   --  The link selected goes, if there is one.

   procedure Delete_Selected (Item : in out Session) is
   begin
      if Canvas_VM.Can_Execute (Item.Canvas_Model.Model, Canvas_VM.Delete_Link) then
         Canvas_VM.Execute (Item.Canvas_Model.Model, Canvas_VM.Delete_Link);
      end if;
   end Delete_Selected;

   procedure Delete_Clicked
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      Delete_Selected (Item);
   end Delete_Clicked;

   procedure Line_Selected
     (Item : in out Session; Source : in out Widgets.Canvases.Canvas'Class; Tag : Natural)
   is
      pragma Unreferenced (Source);
   begin
      Canvas_VM.Select_Link
        (Item.Canvas_Model.Model, (if Tag in 1 .. Canvas_VM.Link_Count (Item.Canvas_Model.Model) then Tag else 0));
      if Canvas_VM.Selected_Link (Item.Canvas_Model.Model) /= 0 then
         --  So that Backspace is not for the text being typed in.
         Widgets.Clear_Focus (Item.Root.Widgets);
      end if;
   end Line_Selected;

   procedure Line_Deleted (Item : in out Session; Source : in out Widgets.Canvases.Canvas'Class) is
      pragma Unreferenced (Source);
   begin
      Delete_Selected (Item);
   end Line_Deleted;

end View.Links.Events;
