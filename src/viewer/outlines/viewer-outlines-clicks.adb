with Viewer.Outlines.Support;

package body Viewer.Outlines.Clicks is

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
