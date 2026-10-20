with System;
with Pomarine.Widgets.Pins;
with Viewer.Links.Support;

package body Viewer.Links.Events is

   package Pins renames Pomarine.Widgets.Pins;
   package Windows renames Items.Windows;

   use type System.Address;
   use type Items.Id;
   use type Item_Links.Strokes;
   use type Item_Links.Endings;

   Side_Count : constant := Item_Links.Sides'Pos (Item_Links.Sides'Last) + 1;

   procedure Set_Accepting (Item : in out Session; Except : Natural) is
   begin
      for Which in Items.Slot loop
         for Side in Item_Links.Sides loop
            Pins.Set_Accepting
              (Item.Linking.Pins (Which, Side),
               Except /= 0 and then Which /= Except);
         end loop;
      end loop;
   end Set_Accepting;

   procedure Make_Link
     (Item : in out Session; To : Items.Slot; To_Side : Item_Links.Sides);
   --  Join the item whose pin was dragged from to the one of this pin.

   procedure Make_Link
     (Item : in out Session; To : Items.Slot; To_Side : Item_Links.Sides)
   is
      Added : Boolean;
   begin
      if Item.Linking.Link_From /= 0 and then Item.Linking.Link_From /= To
        and then Support.Is_Open (Item, Item.Linking.Link_From) and then Support.Is_Open (Item,
           To)
      then
         Item_Links.Add_Link
           (Item.Nav.Store,
            (From
             => Windows.Details (Item.Windows (Item.Linking.Link_From)).Key,
             To        => Windows.Details (Item.Windows (To)).Key,
             From_Side => Item.Linking.Link_From_Side,
             To_Side   => To_Side,
             others    => <>),
            Added);
         if Added then
            Reload (Item);
            Projects.Touch (Item.Nav.Store, Item.Opened.Current);
         end if;
      end if;
   end Make_Link;

   procedure Move_Link
     (Item : in out Session; To : Items.Slot; To_Side : Item_Links.Sides);
   --  Make the selected link end at this pin.

   procedure Move_Link
     (Item : in out Session; To : Items.Slot; To_Side : Item_Links.Sides)
   is
      Moved : Boolean;
   begin
      if Item.Linking.Link_Key /= 0 and then Support.Is_Open (Item, To) then
         Item_Links.Move_Link
           (Item.Nav.Store, Item.Linking.Link_Key,
            Windows.Details (Item.Windows (To)).Key, To_Side, Moved);
         if Moved then
            Reload (Item);
            Projects.Touch (Item.Nav.Store, Item.Opened.Current);
         end if;
      end if;
   end Move_Link;

   function Pin_Number (Which : Items.Slot; Side : Item_Links.Sides) return Positive is
     ((Which - 1) * Side_Count + Item_Links.Sides'Pos (Side) + 1);

   procedure Pin_Pressed
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
      Which : constant Items.Slot := (Event.Index - 1) / Side_Count + 1;
      Side  : constant Item_Links.Sides := Item_Links.Sides'Val ((Event.Index - 1) mod Side_Count);
   begin
      if Item.Linking.Link_From = 0 then
         Item.Linking.Link_From := Which;
         Item.Linking.Link_From_Side := Side;
         Item.Linking.Link_Moving := False;
         Set_Accepting (Item, Which);
      end if;
   end Pin_Pressed;

   procedure Handle_Pressed
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      if Item.Linking.Link_From /= 0 then
         return;
      end if;
      declare
         Number : constant Natural := Support.Index_Of (Item, Item.Linking.Link_Key);
         From   : constant Natural :=
           (if Number = 0 then 0
            else Support.Slot_Of (Item, Item.Linking.Link_Set.Links (Number).From));
      begin
         if From /= 0 then
            Item.Linking.Link_From := From;
            Item.Linking.Link_From_Side := Item.Linking.Link_Set.Links (Number).From_Side;
            Item.Linking.Link_Moving := True;
            Set_Accepting (Item, From);
         else
            Pins.Cancel (Item.Linking.Link_Handle);
         end if;
      end;
   end Handle_Pressed;

   procedure Pin_Released
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Event);
   begin
      if Item.Linking.Link_From = 0 or else Source'Address /= Support.Dragger (Item).all'Address then
         return;
      end if;
      --  The pointer is over the pin it was let go on, if any.
      for Which in Items.Slot loop
         for Side in Item_Links.Sides loop
            if Which /= Item.Linking.Link_From
              and then Widgets.Is_Shown (Item.Linking.Pins (Which, Side))
              and then Widgets.Is_Hovered (Item.Linking.Pins (Which, Side))
            then
               if Item.Linking.Link_Moving then
                  Move_Link (Item, Which, Side);
               else
                  Make_Link (Item, Which, Side);
               end if;
            end if;
         end loop;
      end loop;
      Item.Linking.Link_From := 0;
      Item.Linking.Link_Moving := False;
      Set_Accepting (Item, 0);
   end Pin_Released;

   procedure Restyle
     (Item   : in out Session;
      Stroke : Item_Links.Strokes;
      Ending : Item_Links.Endings;
      Color  : Item_Links.Link_Colors);
   --  Give the link selected another look.

   procedure Restyle
     (Item   : in out Session;
      Stroke : Item_Links.Strokes;
      Ending : Item_Links.Endings;
      Color  : Item_Links.Link_Colors)
   is
      Number : constant Natural := Support.Index_Of (Item, Item.Linking.Link_Key);
   begin
      if Number = 0 then
         return;
      end if;
      declare
         Was : constant Item_Links.Link := Item.Linking.Link_Set.Links (Number);
      begin
         if Stroke /= Was.Stroke or else Ending /= Was.Ending or else Color /= Was.Color then
            Item_Links.Set_Link_Style (Item.Nav.Store, Was.Key, Stroke, Ending, Color);
            Reload (Item);
            Projects.Touch (Item.Nav.Store, Item.Opened.Current);
         end if;
      end;
   end Restyle;

   function Was_Of (Item : Session) return Item_Links.Link is
     (Item.Linking.Link_Set.Links (Support.Index_Of (Item, Item.Linking.Link_Key)))
     with Pre => Support.Index_Of (Item, Item.Linking.Link_Key) /= 0;

   procedure Stroke_Clicked
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
   begin
      if Support.Index_Of (Item, Item.Linking.Link_Key) /= 0 then
         Restyle (Item, Item_Links.Strokes'Val (Event.Index - 1),
                  Was_Of (Item).Ending, Was_Of (Item).Color);
      end if;
   end Stroke_Clicked;

   procedure Ending_Clicked
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
   begin
      if Support.Index_Of (Item, Item.Linking.Link_Key) /= 0 then
         Restyle (Item, Was_Of (Item).Stroke,
                  Item_Links.Endings'Val (Event.Index - 1), Was_Of (Item).Color);
      end if;
   end Ending_Clicked;

   procedure Color_Clicked
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
   begin
      if Support.Index_Of (Item, Item.Linking.Link_Key) /= 0 then
         Restyle (Item, Was_Of (Item).Stroke, Was_Of (Item).Ending, Event.Index);
      end if;
   end Color_Clicked;

   procedure Delete_Clicked
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      if Support.Index_Of (Item, Item.Linking.Link_Key) /= 0 then
         Item_Links.Delete_Link (Item.Nav.Store, Item.Linking.Link_Key);
         Reload (Item);
         Projects.Touch (Item.Nav.Store, Item.Opened.Current);
      end if;
   end Delete_Clicked;

   procedure Line_Selected
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
   begin
      Item.Linking.Link_Key :=
        (if Event.Row in 1 .. Item.Linking.Link_Set.Count
         then Item.Linking.Link_Set.Links (Event.Row).Key else 0);
      if Item.Linking.Link_Key /= 0 then
         --  So that Backspace is not for the text being typed in.
         Widgets.Clear_Focus (Item.Root.Widgets);
      end if;
   end Line_Selected;

   procedure Line_Deleted
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      if Item.Linking.Link_Key /= 0 then
         Item_Links.Delete_Link (Item.Nav.Store, Item.Linking.Link_Key);
         Reload (Item);
         Projects.Touch (Item.Nav.Store, Item.Opened.Current);
      end if;
   end Line_Deleted;

end Viewer.Links.Events;
