with Pomarine.Boxes;
with Pomarine.Themes;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Grips;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Layouts;
with Pomarine.Widgets.Panels;
with Texts.Documents;
with Viewer.Style;
with Viewer.Outlines.Support;

package body Viewer.Outlines.Blocks is

   package Layouts renames Pomarine.Widgets.Layouts;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Grips renames Pomarine.Widgets.Grips;
   package Labels renames Pomarine.Widgets.Labels;
   package Panels renames Pomarine.Widgets.Panels;
   package Docs renames Texts.Documents;

   Drag_Threshold : constant Float := 4.0;
   --  How far, in points, a press on a block has to go to be a drag.

   procedure Style_Blocks (Item : in out Session);
   --  Outline the block being dragged, once it has moved.

   procedure Style_Blocks (Item : in out Session) is
      View : Outline_Parts renames Item.Outline_View;
   begin
      for Each in 1 .. View.Order.Count loop
         if View.Drag_Block = Each and then View.Drag_Moved then
            Grips.Set_Border (View.Blocks (Each).Row, Pomarine.Themes.Focus);
         else
            Grips.Set_Border (View.Blocks (Each).Row, Pomarine.Themes.Border);
         end if;
      end loop;
   end Style_Blocks;

   procedure Show_Blocks (Item : in out Session) is
      View : Outline_Parts renames Item.Outline_View;
   begin
      for Each in View.Blocks'Range loop
         declare
            Block : Section_Block renames View.Blocks (Each);
         begin
            if Each <= View.Order.Count then
               Docs.Load
                 (Block.Doc,
                  Projects.Sections.Title_Texts.To_String (View.Order.Items (Each).Title));
               Block.Seen := Docs.Current (Block.Doc);
               Docs.Load_Stored
                 (Block.Notes_Doc,
                  Projects.Sections.Stored_Notes (Item.Nav.Store, View.Order.Items (Each).Key));
               Block.Notes_Seen := Docs.Current (Block.Notes_Doc);
               Buttons.Set_Selected (Block.Notes, View.Order.Items (Each).Open);
               Widgets.Set_Visible (Block.Notes_Sheet, View.Order.Items (Each).Open);
            end if;
            if Each <= View.Order.Count then
               declare
                  Section : constant Projects.Sections.Section := View.Order.Items (Each);
                  Ink     : constant Pomarine.Themes.Slot := Style.Section_Ink (Section.Colour);
               begin
                  if Documents_In (Item, Each) > 0 then
                     Panels.Set_Fill (Block.Swatch, Ink);
                  else
                     Panels.Set_Fill (Block.Swatch, Pomarine.Themes.Page);
                  end if;
                  Panels.Set_Border (Block.Swatch, Ink);
               end;
            end if;
            Widgets.Set_Visible (Block.Row, Each <= View.Order.Count);
            Buttons.Set_Enabled (Block.Up, Each > 1);
            Buttons.Set_Enabled (Block.Down, Each < View.Order.Count);
         end;
      end loop;
      Widgets.Set_Visible (View.None, View.Order.Count = 0);
      Buttons.Set_Enabled (View.Add_Button, View.Order.Count < Section_Capacity);
      Style_Blocks (Item);
   end Show_Blocks;

   function Drop_Before (Item : Session; Y : Float) return Natural is
      View   : Outline_Parts renames Item.Outline_View;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Point  : constant Float := Y * Pixels;
      Before : Positive := View.Order.Count + 1;
   begin
      for Each in 1 .. View.Order.Count loop
         declare
            Row : Grips.Grip renames View.Blocks (Each).Row;
         begin
            if Point < Widgets.Top_Of (Row) + Widgets.Height_Of (Row) / 2.0 then
               Before := Each;
               exit;
            end if;
         end;
      end loop;
      return (if Before in View.Drag_Block .. View.Drag_Block + 1 then 0 else Before);
   end Drop_Before;

   procedure Show_Drop_Line (Item : in out Session) is
      View   : Outline_Parts renames Item.Outline_View;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Offset : constant Float := Pomarine.Boxes.Offset (Pixels);
   begin
      if View.Drop_Before = 0 or else View.Order.Count = 0 then
         Widgets.Set_Visible (View.Drop_Line, False);
         return;
      end if;
      declare
         First : Grips.Grip renames View.Blocks (1).Row;
         Gap   : constant Float := Style.Index_Gap * Pixels - Offset;
         Mid   : constant Float :=
           (if View.Drop_Before > View.Order.Count
            then Widgets.Top_Of (View.Blocks (View.Order.Count).Row)
                 + Widgets.Height_Of (View.Blocks (View.Order.Count).Row) + Gap / 2.0
            else Widgets.Top_Of (View.Blocks (View.Drop_Before).Row) - Gap / 2.0);
         Thick : constant Float := Style.Drop_Line_Height * Pixels;
      begin
         Layouts.Set_Layout
           (View.Drop_Line,
            Position =>
              (Left => Widgets.Left_Of (First) - Widgets.Left_Of (View.Content),
               Top  => Float'Max
                         (0.0, Float'Rounding
                                 (Mid - Thick / 2.0 - Widgets.Top_Of (View.Content))),
               others => <>),
            Width => Widgets.Width_Of (First) - Offset,
            Unit => Layouts.Device_Pixels);
      end;
      Widgets.Set_Visible (View.Drop_Line, True);
      Widgets.Request_Layout (View.Drop_Line);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Show_Drop_Line;

   procedure Show_Ghost (Item : in out Session) is
      View   : Outline_Parts renames Item.Outline_View;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Offset : constant Float := Pomarine.Boxes.Offset (Pixels);
   begin
      if View.Drag_Block = 0 or else not View.Drag_Moved
        or else View.Drag_Block > View.Order.Count
      then
         Widgets.Set_Visible (View.Ghost, False);
         return;
      end if;
      declare
         Held  : Grips.Grip renames View.Blocks (View.Drag_Block).Row;
         X, Y  : Float;
         High  : constant Float := Widgets.Height_Of (Held) - Offset;
         Least : constant Float := 0.0;
         Most  : constant Float :=
           Float'Max (Least, Widgets.Height_Of (View.Content) - High);
      begin
         Grips.Pointer (Held, X, Y);
         Layouts.Set_Layout
           (View.Ghost,
            Position =>
              (Left => Widgets.Left_Of (Held) - Widgets.Left_Of (View.Content),
               Top  => Float'Min
                         (Most, Float'Max
                                  (Least, Float'Rounding
                                            (Y * Pixels - High / 2.0
                                             - Widgets.Top_Of (View.Content)))),
               others => <>),
            Width  => Widgets.Width_Of (Held) - Offset,
            Height => High,
            Unit   => Layouts.Device_Pixels);
      end;
      Widgets.Set_Visible (View.Ghost, True);
      Widgets.Request_Layout (View.Ghost);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Show_Ghost;

   procedure Keep_Order (Item : in out Session) is
      View : Outline_Parts renames Item.Outline_View;
      Keys : constant Projects.Sections.Key_Array (1 .. View.Order.Count) :=
        [for Each in 1 .. View.Order.Count => View.Order.Items (Each).Key];
   begin
      Projects.Sections.Set_Order (Item.Nav.Store, Item.Opened.Current, Keys);
   end Keep_Order;

   procedure Block_Dragged
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
      View : Outline_Parts renames Item.Outline_View;
      Row  : constant Natural := Event.Index;
   begin
      if not Support.In_Outline (Item) or else Row not in 1 .. View.Order.Count then
         return;
      end if;
      if View.Drag_Block = 0 then
         View.Drag_Block := Row;
         View.Drag_Total := 0.0;
         View.Drag_Moved := False;
         View.Drop_Before := 0;
      end if;
      if View.Drag_Block /= Row then
         return;
      end if;
      View.Drag_Total := View.Drag_Total + abs Event.Across + abs Event.Down;
      if View.Drag_Total >= Drag_Threshold and then not View.Drag_Moved then
         View.Drag_Moved := True;
         Style_Blocks (Item);
         declare
            Words : constant String := Section_Title (Item, Row);
         begin
            Labels.Set_Text
              (View.Ghost_Title,
               Words (Words'First ..
                      Words'First - 1
                      + Natural'Min (Words'Length, Labels.Text_Capacity)));
         end;
      end if;
      if View.Drag_Moved then
         declare
            X, Y   : Float;
            Before : Natural;
         begin
            Grips.Pointer (View.Blocks (Row).Row, X, Y);
            Before := Drop_Before (Item, Y);
            if Before /= View.Drop_Before then
               View.Drop_Before := Before;
               Show_Drop_Line (Item);
            end if;
            Show_Ghost (Item);
         end;
      end if;
   end Block_Dragged;

   procedure Block_Released
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
      View : Outline_Parts renames Item.Outline_View;
   begin
      if View.Drag_Block = 0 or else View.Drag_Block /= Event.Index then
         return;
      end if;
      declare
         Held   : constant Positive := View.Drag_Block;
         Before : constant Natural := View.Drop_Before;
         Moved  : constant Boolean := View.Drag_Moved;
      begin
         View.Drag_Block := 0;
         View.Drag_Moved := False;
         View.Drop_Before := 0;
         Show_Drop_Line (Item);
         Show_Ghost (Item);
         if Moved and then Before /= 0 and then Support.In_Outline (Item) then
            Move_Section (Item, Held, (if Before > Held then Before - 1 else Before));
         else
            Style_Blocks (Item);
         end if;
      end;
   end Block_Released;

end Viewer.Outlines.Blocks;
