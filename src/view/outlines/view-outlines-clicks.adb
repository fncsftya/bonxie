with Outline_VM;
with View.Outlines.Support;
with View.Style;
with Pomarine.Themes;
with View.Outlines.Blocks;
with Pomarine.Widgets.Layouts;
with Section_Colour_Pickers;

package body View.Outlines.Clicks is

   procedure Colour_Clicked
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      Pane : Outline_Parts renames Item.Outline_View;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      use Pomarine.Widgets.Layouts;
   begin
      if not Support.In_Outline (Item) or else Event.Index not in 1 .. Section_Count (Item) then
         return;
      end if;
      Sync (Item);
      Pane.Colour_Key := Section_At (Item, Event.Index).Key;
      Section_Colour_Pickers.Set_Colour
        (Pane.Colour_Picker,
         Pomarine.Themes.Resolve (Style.Colors, Style.Section_Ink (Section_At (Item, Event.Index).Colour)));
      Set_Layout
        (Pane.Colour_Popout,
         Position =>
           (Left => Float'Max (0.0, Float'Min
              ((Widgets.Left_Of (Source) - Widgets.Left_Of (Item.Toolbar.Content_Panel)) / Pixels,
               Widgets.Width_Of (Item.Toolbar.Content_Panel) / Pixels - 264.0)),
            Top => Float'Max (0.0, Float'Min
              ((Widgets.Top_Of (Source) + Widgets.Height_Of (Source)
                - Widgets.Top_Of (Item.Toolbar.Content_Panel)) / Pixels,
               Widgets.Height_Of (Item.Toolbar.Content_Panel) / Pixels - 270.0)), others => <>));
      Widgets.Set_Visible (Pane.Colour_Popout, True);
      Widgets.Raise_To_Front (Pane.Colour_Popout);
   end Colour_Clicked;

   procedure Colour_Cancelled
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      Item.Outline_View.Colour_Key := 0;
      Widgets.Set_Visible (Item.Outline_View.Colour_Popout, False);
   end Colour_Cancelled;

   procedure Colour_Accepted
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      Pane : Outline_Parts renames Item.Outline_View;
      Row : constant Natural := Index_Of_Key (Item, Pane.Colour_Key);
   begin
      if Support.In_Outline (Item) and then Row /= 0
        and then Section_Colour_Pickers.Changed (Pane.Colour_Picker)
      then
         Outline_VM.Set_Colour (Item.Outline_Model.Model, Row, Section_Colour_Pickers.Colour (Pane.Colour_Picker));
         Item.Section_Menu.Changes := @ + 1;
         Blocks.Show_Blocks (Item);
      end if;
      Colour_Cancelled (Item, Source, Event);
   end Colour_Accepted;

   procedure Title_Submitted
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      if Support.In_Outline (Item) then
         Widgets.Clear_Focus (Item.Root.Widgets);
      end if;
   end Title_Submitted;

end View.Outlines.Clicks;
