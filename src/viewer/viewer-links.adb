with Items.Links;
with Icon_Set;
with Pomarine.Widgets;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Callbacks;
with Pomarine.Widgets.Canvases;
with Pomarine.Widgets.Panels;
with Pomarine.Widgets.Pins;
with Viewer.Style;
with Pomarine.Widgets.Layouts;
with Viewer.Links.Drawing;
with Viewer.Links.Events;
with Viewer.Links.Support;

package body Viewer.Links is

   package Widgets renames Pomarine.Widgets;
   package Layouts renames Pomarine.Widgets.Layouts;
   package Canvases renames Pomarine.Widgets.Canvases;
   package Pins renames Pomarine.Widgets.Pins;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Item_Links renames Items.Links;
   package Hooks is new Pomarine.Widgets.Callbacks (Session);

   use type Item_Links.Strokes;
   use type Item_Links.Endings;

   pragma Assert (Canvases.Max_Lines >= Item_Links.Max_Links);

   procedure Listen (Item : in out Session);
   --  Give the widgets of the links the procedures they call.

   procedure Build (Item : in out Session) is
      procedure Size (Part : in out Widgets.Widget'Class; Wide, High : Float)
      is
      begin
         Layouts.Set_Layout (Part, Width => Wide, Height => High);
      end Size;

      procedure Tool (Part : in out Buttons.Button; Apart : Boolean) is
      begin
         Widgets.Add (Item.Linking.Link_Bar, Part);
         Size (Part, Style.Link_Button_Size, Style.Link_Button_Size);
         if Apart then
            Layouts.Set_Layout
              (Part, Margin => (Left => Style.Link_Group_Gap, others => <>));
         end if;
      end Tool;
   begin
      Widgets.Add (Item.Canvas_View, Item.Linking.Link_Bar);
      Pomarine.Widgets.Panels.Set_Fill (Item.Linking.Link_Bar, Style.Toolbar);
      Layouts.Set_Layout
        (Item.Linking.Link_Bar, Place => Layouts.Absolute, Flow => Layouts.Row,
         Align => Layouts.Center, Padding => (others => Style.Link_Bar_Pad),
         Gap => Style.Link_Bar_Gap, Width => Style.Link_Bar_Width,
         Height => Style.Link_Bar_Height);

      for Each in Item_Links.Strokes loop
         Tool (Item.Linking.Stroke_Buttons (Each),
               Apart => Each = Item_Links.Solid);
      end loop;
      Buttons.Set_Label
        (Item.Linking.Stroke_Buttons (Item_Links.Solid), "Solid");
      Buttons.Set_Icon (Item.Linking.Stroke_Buttons (Item_Links.Solid),
                        Icon_Set.Stroke_Solid);
      Buttons.Set_Label
        (Item.Linking.Stroke_Buttons (Item_Links.Dots), "Dots");
      Buttons.Set_Icon (Item.Linking.Stroke_Buttons (Item_Links.Dots),
                        Icon_Set.Stroke_Dots);
      Buttons.Set_Label
        (Item.Linking.Stroke_Buttons (Item_Links.Dashed), "Dash");
      Buttons.Set_Icon (Item.Linking.Stroke_Buttons (Item_Links.Dashed),
                        Icon_Set.Stroke_Dashed);
      for Each in Item_Links.Endings loop
         Tool
           (Item.Linking.End_Buttons (Each),
            Apart => Each = Item_Links.Plain);
      end loop;
      Buttons.Set_Label (Item.Linking.End_Buttons (Item_Links.Plain), "Plain");
      Buttons.Set_Icon (Item.Linking.End_Buttons (Item_Links.Plain),
                        Icon_Set.End_Plain);
      Buttons.Set_Label (Item.Linking.End_Buttons (Item_Links.Arrow), "Arrow");
      Buttons.Set_Icon (Item.Linking.End_Buttons (Item_Links.Arrow),
                        Icon_Set.End_Arrow);
      for Each in Item_Links.Link_Colors loop
         Tool (Item.Linking.Color_Buttons (Each), Apart => Each = 1);
         Buttons.Set_Label (Item.Linking.Color_Buttons (Each), "Ink");
         Buttons.Set_Swatch (Item.Linking.Color_Buttons (Each),
                             Style.Link_Inks (Each));
      end loop;
      Tool (Item.Linking.Delete_Link, Apart => True);
      Buttons.Set_Label (Item.Linking.Delete_Link, "Del");
      Buttons.Set_Icon (Item.Linking.Delete_Link, Icon_Set.Delete);
      Buttons.Set_Kind (Item.Linking.Delete_Link, Buttons.Danger);
      Widgets.Set_Visible (Item.Linking.Link_Bar, False);

      for Which in Items.Slot loop
         for Side in Item_Links.Sides loop
            declare
               Pin : Pins.Pin renames Item.Linking.Pins (Which, Side);
            begin
               Widgets.Add (Item.Canvas_View, Pin);
               Layouts.Set_Layout
                 (Pin, Place => Layouts.Absolute, Width => Pins.Diameter, Height => Pins.Diameter);
               Widgets.Set_Visible (Pin, False);
            end;
         end loop;
      end loop;
      Widgets.Add (Item.Canvas_View, Item.Linking.Link_Handle);
      Layouts.Set_Layout
        (Item.Linking.Link_Handle, Place => Layouts.Absolute, Width => Pins.Diameter,
         Height => Pins.Diameter);
      Widgets.Set_Visible (Item.Linking.Link_Handle, False);
      Listen (Item);
   end Build;

   procedure Reload (Item : in out Session) is
   begin
      Item_Links.Load_Links (Item.Nav.Store, Item.Opened.Current,
                        Item.Linking.Link_Set);
      if Support.Index_Of (Item, Item.Linking.Link_Key) = 0 then
         Item.Linking.Link_Key := 0;
      end if;
   end Reload;

   procedure Enter (Item : in out Session) is
   begin
      Item.Linking.Link_From := 0;
      Item.Linking.Link_Moving := False;
      Item.Linking.Link_Key := 0;
      Reload (Item);
   end Enter;

   procedure Leave (Item : in out Session) is
   begin
      for Which in Items.Slot loop
         for Side in Item_Links.Sides loop
            Pins.Cancel (Item.Linking.Pins (Which, Side));
            Widgets.Set_Visible (Item.Linking.Pins (Which, Side), False);
         end loop;
      end loop;
      Pins.Cancel (Item.Linking.Link_Handle);
      Widgets.Set_Visible (Item.Linking.Link_Handle, False);
      Widgets.Set_Visible (Item.Linking.Link_Bar, False);
      Events.Set_Accepting (Item, 0);
      Item.Linking.Link_From := 0;
      Item.Linking.Link_Moving := False;
      Item.Linking.Link_Key := 0;
      Item.Linking.Link_Set.Count := 0;
      Canvases.Set_Selected (Item.Canvas_View, 0);
      Canvases.Clear_Ghost (Item.Canvas_View);
      Canvases.Set_Lines (Item.Canvas_View, []);
   end Leave;

   procedure Listen (Item : in out Session) is
      use all type Widgets.Event_Kind;

      procedure Hear
        (Part    : in out Widgets.Widget'Class;
         Kind    : Widgets.Event_Kind;
         Do_This : Hooks.Handler;
         Index   : Natural := 0) is
      begin
         if Index /= 0 then
            Widgets.Set_Tag (Part, Widgets.No_Tag, Index);
         end if;
         Hooks.On (Part, Kind, Item'Unchecked_Access, Do_This);
      end Hear;
   begin
      for Each in Item_Links.Strokes loop
         Hear (Item.Linking.Stroke_Buttons (Each), Click, Events.Stroke_Clicked'Access,
               Item_Links.Strokes'Pos (Each) + 1);
      end loop;
      for Each in Item_Links.Endings loop
         Hear (Item.Linking.End_Buttons (Each), Click, Events.Ending_Clicked'Access,
               Item_Links.Endings'Pos (Each) + 1);
      end loop;
      for Each in Item_Links.Link_Colors loop
         Hear (Item.Linking.Color_Buttons (Each), Click, Events.Color_Clicked'Access, Each);
      end loop;
      Hear (Item.Linking.Delete_Link, Click, Events.Delete_Clicked'Access);
      for Which in Items.Slot loop
         for Side in Item_Links.Sides loop
            Hear (Item.Linking.Pins (Which, Side), Press, Events.Pin_Pressed'Access, Events.Pin_Number (Which, Side));
            Hear (Item.Linking.Pins (Which, Side), Release, Events.Pin_Released'Access);
         end loop;
      end loop;
      Hear (Item.Linking.Link_Handle, Press, Events.Handle_Pressed'Access);
      Hear (Item.Linking.Link_Handle, Release, Events.Pin_Released'Access);
      Hear (Item.Canvas_View, Select_Tag, Events.Line_Selected'Access);
      Hear (Item.Canvas_View, Delete, Events.Line_Deleted'Access);
   end Listen;

   function Shown_Pins (Item : Session) return Natural is
      Found : Natural := 0;
   begin
      for Each of Item.Linking.Pins loop
         if Widgets.Is_Shown (Each) then
            Found := Found + 1;
         end if;
      end loop;
      return Found;
   end Shown_Pins;

   procedure Update (Item : in out Session) is
      Changed : Boolean := False;
   begin
      Drawing.Show_Pins (Item, Changed);
      Drawing.Draw_Lines (Item, Changed);
      Drawing.Raise_Over (Item);
      --  So that the next event finds them where they are.
      if Changed then
         Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      end if;
   end Update;

end Viewer.Links;
