with Items.Links;
with Pomarine.Widgets;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Canvases;
with Pomarine.Widgets.Pins;
with Viewer.Style;
with Viewer.Links.Support;

package body Viewer.Links.Drawing is

   package Widgets renames Pomarine.Widgets;
   package Canvases renames Pomarine.Widgets.Canvases;
   package Pins renames Pomarine.Widgets.Pins;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Windows renames Items.Windows;
   package Item_Links renames Items.Links;

   use type Widgets.Widget_Access;
   use type Items.Id;
   use type Item_Links.Sides;
   use type Item_Links.Strokes;
   use type Item_Links.Endings;

   procedure Put_Pin
     (Item    : in out Session;
      Which   : Items.Slot;
      Side    : Item_Links.Sides;
      Changed : in out Boolean) is
   --  Put the pin at the middle of its side of the window, as
   --  Windows.Place has the window.
      Where  : constant Items.Frame :=
        Windows.Details (Item.Windows (Which)).Where;
      Spot   : constant Support.Point := Support.Pixels_Of (Item, Support.Middle (Where, Side));
      Half   : constant Float := Support.Diameter (Item) / 2.0;
   begin
      Widgets.Move_To (Item.Linking.Pins (Which, Side), Spot.X - Half, Spot.Y - Half,
               Item.Linking.Pin_Left (Which, Side),
                  Item.Linking.Pin_Top (Which, Side),
               Changed);
   end Put_Pin;

   procedure Show_Pins (Item : in out Session; Changed : in out Boolean) is
   begin
      for Which in Items.Slot loop
         declare
            Near : Boolean := False;
         begin
            if Support.Is_Open (Item, Which) then
               Near := Windows.Is_Hovered (Item.Windows (Which));
               for Side in Item_Links.Sides loop
                  Near := Near or else Widgets.Is_Hovered
                            (Item.Linking.Pins (Which, Side));
               end loop;
            end if;
            for Side in Item_Links.Sides loop
               declare
                  Want : constant Boolean :=
                    Support.Is_Open (Item, Which)
                    and then
                      (if Item.Linking.Link_From = 0 then Near
                       elsif Item.Linking.Link_Moving
                          then Which /= Item.Linking.Link_From
                       else Which /= Item.Linking.Link_From
                            or else Side = Item.Linking.Link_From_Side);
                  Pin : Pins.Pin renames Item.Linking.Pins (Which, Side);
               begin
                  if Want /= Widgets.Is_Visible (Pin) then
                     if not Want then
                        Pins.Cancel (Pin);
                     end if;
                     Widgets.Set_Visible (Pin, Want);
                     Changed := True;
                  end if;
                  if Want then
                     Put_Pin (Item, Which, Side, Changed);
                  end if;
               end;
            end loop;
         end;
      end loop;
   end Show_Pins;

   procedure Draw_Lines (Item : in out Session; Changed : in out Boolean) is

      Lines : Canvases.Line_Array (1 .. Item_Links.Max_Links);
      Drawn : Natural := 0;
      Chosen : Natural := 0;
      --  The tag of the selected link, if it is drawn.
      Target, Mid : Support.Point := (0.0, 0.0);
   begin
      for Number in 1 .. Item.Linking.Link_Set.Count loop
         declare
            Each : Item_Links.Link renames
              Item.Linking.Link_Set.Links (Number);
            From : constant Natural := Support.Slot_Of (Item, Each.From);
            To   : constant Natural := Support.Slot_Of (Item, Each.To);
         begin
            if From /= 0 and then To /= 0 then
               declare
                  A : constant Support.Point :=
                    Support.Middle (Windows.Details (Item.Windows (From)).Where,
                            Each.From_Side);
                  B : constant Support.Point :=
                    Support.Middle (Windows.Details (Item.Windows (To)).Where,
                            Each.To_Side);
               begin
                  Drawn := Drawn + 1;
                  Lines (Drawn) :=
                    (From_X => A.X, From_Y => A.Y, To_X => B.X, To_Y => B.Y,
                     Tag    => Number,
                     Dash   => (case Each.Stroke is
                                   when Item_Links.Solid  => Canvases.Solid,
                                   when Item_Links.Dots   => Canvases.Dotted,
                                   when Item_Links.Dashed => Canvases.Dashed),
                     Arrow  => Each.Ending = Item_Links.Arrow,
                     Ink    => Style.Link_Inks (Each.Color));
                  if Each.Key = Item.Linking.Link_Key then
                     Chosen := Number;
                     Target := B;
                     Mid := (X => (A.X + B.X) / 2.0,
                             Y => Float'Max (A.Y, B.Y));
                  end if;
               end;
            end if;
         end;
      end loop;
      Canvases.Set_Selected (Item.Canvas_View, Chosen);
      Canvases.Set_Lines (Item.Canvas_View, Lines (1 .. Drawn));

      --  The handle over the target end, and the toolbar by the middle.
      declare
         Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
         Shown  : constant Boolean := Chosen /= 0;
         Half   : constant Float := Support.Diameter (Item) / 2.0;
         Spot   : constant Support.Point := Support.Pixels_Of (Item, Target);
         Centre : constant Support.Point := Support.Pixels_Of (Item, Mid);
         Wide   : constant Float := Style.Link_Bar_Width * Pixels;
         High   : constant Float := Style.Link_Bar_Height * Pixels;
         Left   : constant Float :=
           Float'Max (0.0, Float'Min (Centre.X - Wide / 2.0,
                                      Widgets.Width_Of (Item.Canvas_View)
                                      - Wide));
         Top    : constant Float :=
           Float'Max (0.0, Float'Min
                        (Centre.Y + Style.Link_Bar_Offset * Pixels,
                         Widgets.Height_Of (Item.Canvas_View) - High));
      begin
         if Shown /= Widgets.Is_Visible (Item.Linking.Link_Handle) then
            if not Shown then
               Pins.Cancel (Item.Linking.Link_Handle);
            end if;
            Widgets.Set_Visible (Item.Linking.Link_Handle, Shown);
            Widgets.Set_Visible (Item.Linking.Link_Bar, Shown);
            Changed := True;
         end if;
         if Shown then
            Widgets.Move_To (Item.Linking.Link_Handle, Spot.X - Half, Spot.Y - Half,
                     Item.Linking.Handle_Left, Item.Linking.Handle_Top,
                        Changed);
            Widgets.Move_To (Item.Linking.Link_Bar, Float'Rounding (Left),
                     Float'Rounding (Top),
                     Item.Linking.Bar_Left, Item.Linking.Bar_Top, Changed);
            declare
               Was : constant Item_Links.Link
                  := Item.Linking.Link_Set.Links (Chosen);
            begin
               for Each in Item_Links.Strokes loop
                  Buttons.Set_Selected
                    (Item.Linking.Stroke_Buttons (Each), Each = Was.Stroke);
               end loop;
               for Each in Item_Links.Endings loop
                  Buttons.Set_Selected
                    (Item.Linking.End_Buttons (Each), Each = Was.Ending);
               end loop;
               for Each in Item_Links.Link_Colors loop
                  Buttons.Set_Selected
                    (Item.Linking.Color_Buttons (Each), Each = Was.Color);
               end loop;
            end;
         end if;
      end;

      if Item.Linking.Link_From /= 0
        and then Support.Is_Open (Item, Item.Linking.Link_From)
      then
         declare
            Source : constant Support.Point :=
              Support.Middle
                (Windows.Details
                   (Item.Windows (Item.Linking.Link_From)).Where,
                 Item.Linking.Link_From_Side);
            Pin : constant access Pins.Pin := Support.Dragger (Item);
         begin
            Canvases.Set_Ghost
              (Item.Canvas_View, Source.X, Source.Y,
               Pins.Pointer_X (Pin.all), Pins.Pointer_Y (Pin.all));
         end;
      else
         Canvases.Clear_Ghost (Item.Canvas_View);
      end if;
   end Draw_Lines;

   procedure Raise_Over (Item : in out Session) is
      Last  : constant Widgets.Widget_Access :=
        Widgets.Widget_Access'(Item.Linking.Link_Handle'Unrestricted_Access);
      Children : constant Natural := Widgets.Child_Count (Item.Canvas_View);
   begin
      if Children > 0
        and then Widgets.Child_At (Item.Canvas_View, Children) /= Last
        and then (Widgets.Is_Visible (Item.Linking.Link_Handle)
                  or else Widgets.Is_Visible (Item.Linking.Link_Bar)
                  or else Shown_Pins (Item) > 0)
      then
         Widgets.Raise_To_Front (Item.Linking.Link_Bar);
         for Which in Items.Slot loop
            for Side in Item_Links.Sides loop
               Widgets.Raise_To_Front (Item.Linking.Pins (Which, Side));
            end loop;
         end loop;
         Widgets.Raise_To_Front (Item.Linking.Link_Handle);
      end if;
   end Raise_Over;

end Viewer.Links.Drawing;
