with Pomarine.Boxes;
with Pomarine.Themes;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Grips;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Layouts;
with Texts.Documents;
with Outline_VM;
with Viewer.Style;
with Viewer.Outlines.Support;

package body Viewer.Outlines.Blocks is

   package Layouts renames Pomarine.Widgets.Layouts;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Grips renames Pomarine.Widgets.Grips;
   package Labels renames Pomarine.Widgets.Labels;
   package Docs renames Texts.Documents;

   function Total (Item : Session) return Natural is (Outline_VM.Count (Item.Outline_Model.Model));
   --  How many sections there are.

   Drag_Threshold : constant Float := 4.0;
   --  How far, in points, a press on a block has to go to be a drag.

   procedure Style_Blocks (Item : in out Session);
   --  Outline the block being dragged, once it has moved.

   procedure Style_Blocks (Item : in out Session) is
      View : Outline_Parts renames Item.Outline_View;
   begin
      for Each in 1 .. Total (Item) loop
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
      for Each in 1 .. View.Blocks.Count loop
         declare
            Block : Section_Block renames View.Blocks (Each);
         begin
            if Each <= Total (Item) then
               Docs.Load (Block.Doc, Outline_VM.Title (Item.Outline_Model.Model, Each));
               Block.Seen := Docs.Current (Block.Doc);
               Docs.Load_Stored (Block.Notes_Doc, Outline_VM.Stored_Notes (Item.Outline_Model.Model, Each));
               Block.Notes_Seen := Docs.Current (Block.Notes_Doc);
               Buttons.Set_Selected (Block.Notes, Outline_VM.Is_Open (Item.Outline_Model.Model, Each));
               Widgets.Set_Visible (Block.Notes_Sheet, Outline_VM.Is_Open (Item.Outline_Model.Model, Each));
            end if;
            if Each <= Total (Item) then
               declare
                  Section : constant Projects.Sections.Section :=
                    Outline_VM.Section_At (Item.Outline_Model.Model, Each);
                  Ink     : constant Pomarine.Themes.Slot := Style.Section_Ink (Section.Colour);
               begin
                  if Documents_In (Item, Each) > 0 then
                     Grips.Set_Fill (Block.Swatch, Ink);
                  else
                     Grips.Set_Fill (Block.Swatch, Pomarine.Themes.Page);
                  end if;
                  Grips.Set_Border (Block.Swatch, Ink);
               end;
            end if;
            Widgets.Set_Visible (Block.Row, Each <= Total (Item));
         end;
      end loop;
      Widgets.Set_Visible (View.None, Total (Item) = 0);
      --  Each block's buttons are on as the view-model says its section can be moved so, or removed.
      Widgets.Revalidate (Item.Root.Widgets);
      Style_Blocks (Item);
   end Show_Blocks;

   function Drop_Before (Item : Session; Y : Float) return Natural is
      View   : Outline_Parts renames Item.Outline_View;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Point  : constant Float := Y * Pixels;
      Before : Positive := Total (Item) + 1;
   begin
      for Each in 1 .. Total (Item) loop
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
      if View.Drop_Before = 0 or else Total (Item) = 0 then
         Widgets.Set_Visible (View.Drop_Line, False);
         return;
      end if;
      declare
         First : Grips.Grip renames View.Blocks (1).Row;
         Gap   : constant Float := Style.Index_Gap * Pixels - Offset;
         Mid   : constant Float :=
           (if View.Drop_Before > Total (Item)
            then Widgets.Top_Of (View.Blocks (Total (Item)).Row)
                 + Widgets.Height_Of (View.Blocks (Total (Item)).Row) + Gap / 2.0
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
        or else View.Drag_Block > Total (Item)
      then
         Widgets.Set_Visible (View.Ghost, False);
         return;
      end if;
      declare
         Held  : Grips.Grip renames View.Blocks (View.Drag_Block).Row;
         X, Y  : Float;
         --  Of the block folded, whether or not its notes are open.
         High  : constant Float := Widgets.Height_Of (View.Blocks (View.Drag_Block).Line) - Offset;
         Least : constant Float := 0.0;
         Most  : constant Float :=
           Float'Max (Least, Widgets.Height_Of (View.Content) - High);
         --  A little to the side, as far as the pointer is, so that what
         --  it is over is clear.
         Leeway : Float;
      begin
         Grips.Pointer (Held, X, Y);
         Leeway := Float'Max (-Style.Ghost_Leeway, Float'Min (Style.Ghost_Leeway, X - View.Drag_From_X));
         Layouts.Set_Layout
           (View.Ghost,
            Position =>
              (Left => Widgets.Left_Of (Held) - Widgets.Left_Of (View.Content)
                       + Float'Rounding (Leeway * Pixels),
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

   procedure Block_Dragged
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
      View : Outline_Parts renames Item.Outline_View;
      Row  : constant Natural := Event.Index;
   begin
      if not Support.In_Outline (Item) or else Row not in 1 .. Total (Item) then
         return;
      end if;
      if View.Drag_Block = 0 then
         View.Drag_Block := Row;
         View.Drag_Total := 0.0;
         View.Drag_Moved := False;
         View.Drop_Before := 0;
         declare
            X, Y : Float;
         begin
            Grips.Pointer (View.Blocks (Row).Row, X, Y);
            View.Drag_From_X := X;
            pragma Unreferenced (Y);
         end;
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
            Labels.Set_Text (View.Ghost_Title, Words);
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
