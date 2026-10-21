with Viewer.Outlines.Support;
with Viewer.Style;
with Pomarine.Themes;
with Viewer.Outlines.Blocks;
with Pomarine.Widgets.Layouts;
with Section_Colour_Pickers;

package body Viewer.Outlines.Clicks is

   procedure Colour_Clicked
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      View : Outline_Parts renames Item.Outline_View;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      use Pomarine.Widgets.Layouts;
   begin
      if not Support.In_Outline (Item) or else Event.Index not in 1 .. View.Order.Count then
         return;
      end if;
      Sync (Item);
      View.Colour_Key := View.Order (Event.Index).Key;
      Section_Colour_Pickers.Set_Colour
        (View.Colour_Picker,
         Pomarine.Themes.Resolve (Style.Colors, Style.Section_Ink (View.Order (Event.Index).Colour)));
      Set_Layout
        (View.Colour_Popout,
         Position =>
           (Left => Float'Max (0.0, Float'Min
              ((Widgets.Left_Of (Source) - Widgets.Left_Of (Item.Toolbar.Content_Panel)) / Pixels,
               Widgets.Width_Of (Item.Toolbar.Content_Panel) / Pixels - 264.0)),
            Top => Float'Max (0.0, Float'Min
              ((Widgets.Top_Of (Source) + Widgets.Height_Of (Source)
                - Widgets.Top_Of (Item.Toolbar.Content_Panel)) / Pixels,
               Widgets.Height_Of (Item.Toolbar.Content_Panel) / Pixels - 270.0)), others => <>));
      Widgets.Set_Visible (View.Colour_Popout, True);
      Widgets.Raise_To_Front (View.Colour_Popout);
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
      View : Outline_Parts renames Item.Outline_View;
      Row : constant Natural := Index_Of_Key (Item, View.Colour_Key);
   begin
      if Support.In_Outline (Item) and then Row /= 0
        and then Section_Colour_Pickers.Changed (View.Colour_Picker)
      then
         Projects.Sections.Set_Colour
           (Item.Nav.Store, View.Colour_Key, Section_Colour_Pickers.Colour (View.Colour_Picker));
         View.Order (Row).Colour := Section_Colour_Pickers.Colour (View.Colour_Picker);
         Item.Section_Menu.Changes := @ + 1;
         Blocks.Show_Blocks (Item);
      end if;
      Colour_Cancelled (Item, Source, Event);
   end Colour_Accepted;

   procedure Add_Clicked
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      if Support.In_Outline (Item) then
         Add_Section (Item);
      end if;
   end Add_Clicked;

   procedure Up_Clicked
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
   begin
      if Support.In_Outline (Item) and then Event.Index in 2 .. Item.Outline_View.Order.Count then
         Move_Section (Item, Event.Index, Event.Index - 1);
      end if;
   end Up_Clicked;

   procedure Down_Clicked
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
   begin
      if Support.In_Outline (Item) and then Event.Index in 1 .. Item.Outline_View.Order.Count - 1 then
         Move_Section (Item, Event.Index, Event.Index + 1);
      end if;
   end Down_Clicked;

   procedure Remove_Clicked
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
   begin
      if Support.In_Outline (Item) and then Event.Index in 1 .. Item.Outline_View.Order.Count then
         Remove_Section (Item, Event.Index);
      end if;
   end Remove_Clicked;

   procedure Notes_Clicked
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
   begin
      if Support.In_Outline (Item) and then Event.Index in 1 .. Item.Outline_View.Order.Count then
         Toggle_Notes (Item, Event.Index);
      end if;
   end Notes_Clicked;

   procedure Title_Submitted
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      if Support.In_Outline (Item) then
         Widgets.Clear_Focus (Item.Root.Widgets);
      end if;
   end Title_Submitted;

end Viewer.Outlines.Clicks;
