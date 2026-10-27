with Pomarine.UI;
with Canvas_UI;
with Canvas_VM;
with Items.Links;
with Icon_Set;
with Pomarine.Widgets;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Callbacks;
with Pomarine.Widgets.Canvases;
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
   package UI renames Pomarine.UI;

   package Hooks is new Pomarine.Widgets.Callbacks (Session);

   use type Items.Id;
   use type Item_Links.Strokes;
   use type Item_Links.Endings;

   procedure Listen (Item : in out Session);
   --  Give the widgets of the links the procedures they call.

   procedure Build (Item : in out Session) is
      function Pictured (Name : String; Icon : Pomarine.Icons.Icon) return Buttons.Settings is
        (Buttons.Looks (Name, Icon => Pomarine.Icons.Shown (Icon)));

      Buttons_Needed : constant Natural :=
        Item_Links.Strokes'Pos (Item_Links.Strokes'Last) + 1 + Item_Links.Endings'Pos (Item_Links.Endings'Last) + 1
        + Item_Links.Link_Colors'Pos (Item_Links.Link_Colors'Last) + 1 + 1;
      Tools : UI.Layout_Array (1 .. Buttons_Needed);
      Last  : Natural := 0;
   begin
      Open (Item.Forms (Canvas_Region), Item.Root.Widgets'Unchecked_Access, Canvas_Region);
      declare
         Form : UI.View renames Item.Forms (Canvas_Region).Screen.all;
         Bound : constant Canvas_UI.Context'Class :=
           Canvas_UI.Bind (Form, Item.Canvas_Model.Model'Unrestricted_Access);

         procedure Tool
           (Part : in out Buttons.Button; Apart : Boolean; Looks : Buttons.Settings; What : Canvas_VM.Command;
            Index : Natural := 0) is
         begin
            Buttons.Configure (Part, Looks);
            Last := Last + 1;
            Tools (Last) :=
              UI.Styled
                (UI.Place (Bound.Borrow_Button (Part, What, Index, Reflect => False)),
                 (Width => Layouts.Length_Of (Style.Link_Button_Size),
                  Height => Layouts.Length_Of (Style.Link_Button_Size),
                  Margin => (if Apart then (Left => Layouts.Length_Of (Style.Link_Group_Gap),
                                            others => <>) else (others => <>)),
                  others => <>));
         end Tool;
      begin
         for Each in Item_Links.Strokes loop
            Tool (Item.Linking.Stroke_Buttons (Each), Apart => Each = Item_Links.Solid,
                  Looks => (case Each is
                               when Item_Links.Solid  => Pictured ("Solid", Icon_Set.Stroke_Solid),
                               when Item_Links.Dots   => Pictured ("Dots", Icon_Set.Stroke_Dots),
                               when Item_Links.Dashed => Pictured ("Dash", Icon_Set.Stroke_Dashed)),
                  What => Canvas_VM.Set_Stroke, Index => Item_Links.Strokes'Pos (Each) + 1);
         end loop;
         for Each in Item_Links.Endings loop
            Tool (Item.Linking.End_Buttons (Each), Apart => Each = Item_Links.Plain,
                  Looks => (case Each is
                               when Item_Links.Plain => Pictured ("Plain", Icon_Set.End_Plain),
                               when Item_Links.Arrow => Pictured ("Arrow", Icon_Set.End_Arrow)),
                  What => Canvas_VM.Set_Ending, Index => Item_Links.Endings'Pos (Each) + 1);
         end loop;
         for Each in Item_Links.Link_Colors loop
            Tool (Item.Linking.Color_Buttons (Each), Apart => Each = 1, Looks => Buttons.Looks ("Ink"),
                  What => Canvas_VM.Set_Color, Index => Each);
            Buttons.Set_Swatch (Item.Linking.Color_Buttons (Each),
                                Style.Link_Inks (Each));
         end loop;
         Tool (Item.Linking.Delete_Link, Apart => True,
               Looks => Buttons.Looks ("Del", Buttons.Danger, Icon => Pomarine.Icons.Shown (Icon_Set.Delete)),
               What => Canvas_VM.Delete_Link);

         declare
            Bar    : constant UI.Layout :=
              UI.Styled
                (UI.Put_In (Form, Item.Linking.Link_Bar, Tools, Flow => Layouts.Row),
                 (Place => Layouts.Absolute, Flow => Layouts.Row, Align => Layouts.Center,
                  Padding => (others => Layouts.Length_Of (Style.Link_Bar_Pad)),
                    Gap => Layouts.Length_Of (Style.Link_Bar_Gap),
                  Width => Layouts.Length_Of (Style.Link_Bar_Width),
                    Height => Layouts.Length_Of (Style.Link_Bar_Height), others => <>));
            Grabber : constant UI.Layout :=
              UI.Styled
                (UI.Put (Form, Item.Linking.Link_Handle),
                 (Place => Layouts.Absolute, Width => Layouts.Length_Of (Pins.Diameter),
                  Height => Layouts.Length_Of (Pins.Diameter), others => <>));
            Lines : constant UI.Widget_Handle := Bound.Borrow_Widget (Item.Canvas_View);
         begin
            Bound.On_Canvas_Event (Lines, Canvas_UI.Line_Selected, Canvas_VM.Pick_Link, Index_From_Event => True);
            Bound.On_Canvas_Event (Lines, Canvas_UI.Line_Deleted, Canvas_VM.Delete_Link);
            UI.Mount_Into (Form, Item.Canvas_View, Bar);
            UI.Mount_Into (Form, Item.Canvas_View, Grabber);
         end;
      end;
      Pomarine.Widgets.Panels.Set_Fill (Item.Linking.Link_Bar, Style.Toolbar);
      Widgets.Set_Visible (Item.Linking.Link_Bar, False);
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
            UI.Mount_Into
              (Item.Forms (Canvas_Region).Screen.all, Item.Canvas_View,
               UI.Styled
                 (UI.Put (Item.Forms (Canvas_Region).Screen.all, Pin),
                  (Place => Layouts.Absolute, Width => Layouts.Length_Of (Pins.Diameter),
                   Height => Layouts.Length_Of (Pins.Diameter), others => <>)));
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
      Hear (Item.Linking.Link_Handle, Press, Events.Handle_Pressed'Access);
      Hear (Item.Linking.Link_Handle, Release, Events.Pin_Released'Access);
   end Listen;

   function Shown_Pins (Item : Session) return Natural is
      Found : Natural := 0;
   begin
      for Each of Item.Linking.Pins loop
         for Side in Item_Links.Sides loop
            if Widgets.Is_Showing (Each (Side)) then
               Found := Found + 1;
            end if;
         end loop;
      end loop;
      return Found;
   end Shown_Pins;

   procedure Update (Item : in out Session) is
      Changed : Boolean := False;
      Picked  : constant Items.Id := Canvas_VM.Selected_Link (Item.Canvas_Model.Model);
   begin
      if Picked /= Item.Linking.Picked then
         Item.Linking.Picked := Picked;
         if Picked /= 0 then
            --  So that Backspace is not for the text being typed in.
            Widgets.Clear_Focus (Item.Root.Widgets);
         end if;
      end if;
      Drawing.Show_Pins (Item, Changed);
      Drawing.Draw_Lines (Item, Changed);
      Drawing.Raise_Over (Item);
      --  So that the next event finds them where they are.
      if Changed then
         Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      end if;
   end Update;

end View.Links;
