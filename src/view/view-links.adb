with Canvas_VM;
with Items.Links;
with Icon_Set;
with Pomarine.Widgets;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Callbacks;
with Pomarine.Widgets.Canvases;
with Pomarine.Widgets.Canvases.Callbacks;
with Pomarine.Widgets.Panels;
with Pomarine.Widgets.Pins;
with View.Style;
with Pomarine.Widgets.Layouts;
with View.Links.Drawing;
with View.Links.Events;
with Pomarine.Icons;

package body View.Links is

   package Widgets renames Pomarine.Widgets;
   package Layouts renames Pomarine.Widgets.Layouts;
   package Canvases renames Pomarine.Widgets.Canvases;
   package Pins renames Pomarine.Widgets.Pins;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Item_Links renames Items.Links;
   package Hooks is new Pomarine.Widgets.Callbacks (Session);
   package Canvas_Hooks is new Pomarine.Widgets.Canvases.Callbacks (Session);

   use type Item_Links.Strokes;
   use type Item_Links.Endings;

   procedure Listen (Item : in out Session);
   --  Give the widgets of the links the procedures they call.

   procedure Build (Item : in out Session) is
      function Pictured (Name : String; Icon : Pomarine.Icons.Icon) return Buttons.Settings is
        (Buttons.Looks (Name, Icon => Pomarine.Icons.Shown (Icon)));

      procedure Tool (Part : in out Buttons.Button; Apart : Boolean; Looks : Buttons.Settings) is
      begin
         Buttons.Add
           (Item.Linking.Link_Bar, Part, Looks,
            (Width => Style.Link_Button_Size, Height => Style.Link_Button_Size,
             Margin => (if Apart then (Left => Style.Link_Group_Gap, others => <>) else (others => <>)),
             others => <>));
      end Tool;
   begin
      Layouts.Add (Item.Canvas_View, Item.Linking.Link_Bar,
                   (Place => Layouts.Absolute, Flow => Layouts.Row, Align => Layouts.Center,
                    Padding => (others => Style.Link_Bar_Pad), Gap => Style.Link_Bar_Gap, Width => Style.Link_Bar_Width,
                    Height => Style.Link_Bar_Height, others => <>));
      Pomarine.Widgets.Panels.Set_Fill (Item.Linking.Link_Bar, Style.Toolbar);

      for Each in Item_Links.Strokes loop
         Tool (Item.Linking.Stroke_Buttons (Each), Apart => Each = Item_Links.Solid,
               Looks => (case Each is
                            when Item_Links.Solid  => Pictured ("Solid", Icon_Set.Stroke_Solid),
                            when Item_Links.Dots   => Pictured ("Dots", Icon_Set.Stroke_Dots),
                            when Item_Links.Dashed => Pictured ("Dash", Icon_Set.Stroke_Dashed)));
      end loop;
      for Each in Item_Links.Endings loop
         Tool (Item.Linking.End_Buttons (Each), Apart => Each = Item_Links.Plain,
               Looks => (case Each is
                            when Item_Links.Plain => Pictured ("Plain", Icon_Set.End_Plain),
                            when Item_Links.Arrow => Pictured ("Arrow", Icon_Set.End_Arrow)));
      end loop;
      for Each in Item_Links.Link_Colors loop
         Tool (Item.Linking.Color_Buttons (Each), Apart => Each = 1, Looks => Buttons.Looks ("Ink"));
         Buttons.Set_Swatch (Item.Linking.Color_Buttons (Each),
                             Style.Link_Inks (Each));
      end loop;
      Tool (Item.Linking.Delete_Link, Apart => True,
            Looks => Buttons.Looks ("Del", Buttons.Danger, Icon => Pomarine.Icons.Shown (Icon_Set.Delete)));
      Widgets.Set_Visible (Item.Linking.Link_Bar, False);

      Layouts.Add (Item.Canvas_View, Item.Linking.Link_Handle,
                   (Place => Layouts.Absolute, Width => Pins.Diameter, Height => Pins.Diameter, others => <>));
      Widgets.Set_Visible (Item.Linking.Link_Handle, False);
      Listen (Item);
   end Build;

   procedure Make_Pins (Item : in out Session; Which : Items.Slot) is
      use all type Widgets.Event_Kind;
   begin
      for Side in Item_Links.Sides loop
         declare
            Pin : Pins.Pin renames Item.Linking.Pins (Which) (Side);
         begin
            Layouts.Add (Item.Canvas_View, Pin,
                         (Place => Layouts.Absolute, Width => Pins.Diameter, Height => Pins.Diameter, others => <>));
            Widgets.Set_Visible (Pin, False);
            Widgets.Set_Tag (Pin, Widgets.No_Tag, Events.Pin_Number (Which, Side));
            Hooks.On (Pin, Press, Item'Unchecked_Access, Events.Pin_Pressed'Access);
            Hooks.On (Pin, Release, Item'Unchecked_Access, Events.Pin_Released'Access);
         end;
      end loop;
   end Make_Pins;

   procedure Reload (Item : in out Session) is
   begin
      Canvas_VM.Reload_Links (Item.Canvas_Model.Model);
   end Reload;

   procedure Enter (Item : in out Session) is
   begin
      --  What the view-model has of them, from when it entered the project.
      Canvas_VM.Select_Link (Item.Canvas_Model.Model, 0);
   end Enter;

   procedure Leave (Item : in out Session) is
   begin
      for Each of Item.Linking.Pins loop
         for Side in Item_Links.Sides loop
            Pins.Cancel (Each (Side));
            Widgets.Set_Visible (Each (Side), False);
         end loop;
      end loop;
      Pins.Cancel (Item.Linking.Link_Handle);
      Widgets.Set_Visible (Item.Linking.Link_Handle, False);
      Widgets.Set_Visible (Item.Linking.Link_Bar, False);
      Events.Set_Accepting (Item, 0);
      Canvases.Set_Selected (Canvases.Canvas (Item.Canvas_View), 0);
      Canvases.Clear_Ghost (Canvases.Canvas (Item.Canvas_View));
      Canvases.Set_Lines (Canvases.Canvas (Item.Canvas_View), []);
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
      Hear (Item.Linking.Link_Handle, Press, Events.Handle_Pressed'Access);
      Hear (Item.Linking.Link_Handle, Release, Events.Pin_Released'Access);
      Canvas_Hooks.On_Select (Item.Canvas_View, Item'Unchecked_Access, Events.Line_Selected'Access);
      Canvas_Hooks.On_Delete (Item.Canvas_View, Item'Unchecked_Access, Events.Line_Deleted'Access);
   end Listen;

   function Shown_Pins (Item : Session) return Natural is
      Found : Natural := 0;
   begin
      for Each of Item.Linking.Pins loop
         for Side in Item_Links.Sides loop
            if Widgets.Is_Shown (Each (Side)) then
               Found := Found + 1;
            end if;
         end loop;
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

end View.Links;
