with Pomarine.Boxes;
with Pomarine.Widgets.Grips;
with Pomarine.Widgets.Labels;
with Viewer.Style;
with Pomarine.Widgets.Layouts;
with Viewer.Writing.Moves;
with Viewer.Writing.Support;
with Viewer.Writing.Tree;

package body Viewer.Writing.Row_Drags is

   package Layouts renames Pomarine.Widgets.Layouts;
   package Grips renames Pomarine.Widgets.Grips;
   package Labels renames Pomarine.Widgets.Labels;

   Drag_Threshold : constant Float := 4.0;
   --  How far, in points, a press on a row has to go to be a drag.

   function Target_At
     (Item : Session; X, Y : Float) return Drop_Target;
   --  Where the row being dragged, dropped at X, Y, in points of the
   --  window, would go. A document goes into a directory or the Overview
   --  (the middle of their rows), or between rows: before or after a
   --  directory (the top and foot of its row, the foot only if it has
   --  no documents), or above or below another document (by which half
   --  of its row, or, of the last in a directory, the lowest quarter puts
   --  it after the directory). An ordinary folder can enter a section,
   --  return to Overview, or enter another folder outside its own subtree.
   --  Section rows themselves stay in outline order.

   function Target_At
     (Item : Session; X, Y : Float) return Drop_Target
   is
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Point  : constant Float := Y * Pixels;
      Moving : constant Tree_Entry := Item.Docs.Tree (Item.Dragging.Drag_Row);
      Row    : Natural := Item.Docs.Tree_Count;

      function Top (Of_Row : Positive) return Float is
        (Widgets.Top_Of (Item.Docs.Doc_Rows (Of_Row).Row));

      function Bottom (Of_Row : Positive) return Float is
        (Top (Of_Row) + Widgets.Height_Of (Item.Docs.Doc_Rows (Of_Row).Row));

      function Between (Index : Positive; Dir : Natural) return Drop_Target
      is
         Held : constant Positive := Item.Dragging.Drag_Row;
      begin
         --  Where it already is: nowhere.
         if Moving.Kind = Document_Leaf then
            if Index in Held .. Held + 1 and then Dir = Moving.Dir then
               return (others => <>);
            end if;
         elsif Index in Held .. Support.Block_End (Item, Held) + 1
           and then Dir = Support.Parent_Of (Item, Moving.Dir)
         then
            return (others => <>);
         end if;
         return (Kind => Viewer_Parts.Rows.Between, Row => 0, Index => Index,
                 Dir => Dir);
      end Between;
   begin
      if not Widgets.Contains (Item.Page_View.Docs_Scroll, X * Pixels,
                               Point)
      then
         return (others => <>);
      end if;
      for Each in 1 .. Item.Docs.Tree_Count loop
         if Point < Bottom (Each) then
            Row := Each;
            exit;
         end if;
      end loop;
      if Row = 0 or else Row = Item.Dragging.Drag_Row then
         return (others => <>);
      end if;
      declare
         Node  : constant Tree_Entry := Item.Docs.Tree (Row);
         Fract : constant Float :=
           (Point - Top (Row)) / (Bottom (Row) - Top (Row));
      begin
         if Moving.Kind = Directory_Node then
            if Node.Kind = Overview_Node then
               return (Kind => Into_Node, Row => Row, others => <>);
            elsif Node.Kind = Directory_Node then
               if Support.Within (Item, Node.Dir, Moving.Dir) then
                  return (others => <>);
               end if;
               if Fract in 0.25 .. 0.75 then
                  return (Kind => Into_Node, Row => Row, others => <>);
               elsif Fract < 0.25 then
                  return Between (Row, Support.Parent_Of (Item, Node.Dir));
               else
                  return Between
                    (Support.Block_End (Item, Row) + 1, Support.Parent_Of (Item, Node.Dir));
               end if;
            end if;
            if Node.Kind = Document_Leaf and then Support.Within (Item, Node.Dir, Moving.Dir) then
               return (others => <>);
            end if;
            --  Whole units of the top level: the directory with its
            --  documents, or a document in none.
            declare
               First : constant Natural :=
                 (case Node.Kind is
                  when Overview_Node => 0,
                  when Directory_Node => Row,
                  when Document_Leaf =>
                    (if Node.Dir = 0 then Row else Support.Dir_Row (Item, Node.Dir)));
            begin
               if First = 0 then
                  return (others => <>);
               end if;
               declare
                  Last : constant Positive := Support.Block_End (Item, First);
               begin
                  return (if Point < (Top (First) + Bottom (Last)) / 2.0
                          then Between (First, Support.Parent_Of (Item, Item.Docs.Tree (First).Dir))
                          else Between (Last + 1, Support.Parent_Of (Item, Item.Docs.Tree (First).Dir)));
               end;
            end;
         end if;
         case Node.Kind is
            when Overview_Node =>
               return (Kind => Into_Node, Row => Row, others => <>);
            when Directory_Node =>
               if Fract < 0.25 then
                  return Between (Row, Support.Parent_Of (Item, Node.Dir));
               elsif Fract >= 0.75 and then Support.Block_End (Item, Row) = Row then
                  return Between (Row + 1, Support.Parent_Of (Item, Node.Dir));
               else
                  return (Kind => Into_Node, Row => Row, others => <>);
               end if;
            when Document_Leaf =>
               declare
                  Last : constant Boolean :=
                    Node.Dir /= 0
                    and then Support.Block_End (Item, Support.Dir_Row (Item, Node.Dir))
                             = Row;
               begin
                  if Fract < 0.5 then
                     return Between (Row, Node.Dir);
                  elsif Last and then Fract >= 0.75 then
                     return Between (Row + 1, Support.Parent_Of (Item, Node.Dir));
                  else
                     return Between (Row + 1, Node.Dir);
                  end if;
               end;
         end case;
      end;
   end Target_At;

   procedure Show_Drop_Line (Item : in out Session);
   --  Put the line where a row would go between two, or hide it.

   procedure Show_Drop_Line (Item : in out Session) is
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Offset : constant Float := Pomarine.Boxes.Offset (Pixels);
   begin
      if Item.Docs.Drop.Kind /= Between then
         Widgets.Set_Visible (Item.Docs.Drop_Line, False);
         return;
      end if;
      declare
         --  Below the row before it, in the middle of the gap, and in as
         --  far as what is in a directory is.
         Above : Grips.Grip
            renames Item.Docs.Doc_Rows (Item.Docs.Drop.Index - 1).Row;
         Gap   : constant Float := Style.Index_Gap * Pixels - Offset;
         Mid   : constant Float :=
           Widgets.Top_Of (Above) + Widgets.Height_Of (Above) + Gap / 2.0;
         Thick : constant Float := Style.Drop_Line_Height * Pixels;
         Inset : constant Float :=
           (if Item.Docs.Drop.Dir /= 0
            then Style.Tree_Indent * Pixels
              * Float (Support.Depth (Item, Item.Docs.Drop.Dir) + 1)
            else 0.0);
         Edge  : Grips.Grip renames Item.Docs.Doc_Rows (1).Row;
      begin
         Layouts.Set_Layout
           (Item.Docs.Drop_Line,
            Position =>
              (Left => Widgets.Left_Of (Edge)
                       - Widgets.Left_Of (Item.Page_View.Docs_Content) + Inset,
               Top  => Float'Rounding
                         (Mid - Thick / 2.0 - Widgets.Top_Of (Item.Page_View.Docs_Content)),
               others => <>),
            Width => Widgets.Width_Of (Edge) - Offset - Inset,
            Unit => Layouts.Device_Pixels);
      end;
      Widgets.Set_Visible (Item.Docs.Drop_Line, True);
      Widgets.Request_Layout (Item.Docs.Drop_Line);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Show_Drop_Line;

   procedure Show_Ghost (Item : in out Session);
   --  Put the ghost of the row dragged under the pointer, or hide it.

   procedure Show_Ghost (Item : in out Session) is
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Offset : constant Float := Pomarine.Boxes.Offset (Pixels);
      Row    : constant Natural := Item.Dragging.Drag_Row;
   begin
      if Row = 0 or else not Item.Dragging.Drag_Moved or else Row > Item.Docs.Tree_Count then
         Widgets.Set_Visible (Item.Docs.Ghost, False);
         return;
      end if;
      declare
         Held  : Grips.Grip renames Item.Docs.Doc_Rows (Row).Row;
         X, Y  : Float;
         High  : constant Float := Widgets.Height_Of (Held) - Offset;
         Most  : constant Float :=
           Float'Max (0.0, Widgets.Height_Of (Item.Page_View.Docs_Content) - High);
         --  A little to the side, as far as the pointer is, so that what
         --  it is over is clear.
         Leeway : Float;
      begin
         Grips.Pointer (Held, X, Y);
         Leeway := Float'Max (-Style.Ghost_Leeway, Float'Min (Style.Ghost_Leeway, X - Item.Dragging.Drag_From_X));
         Labels.Set_Text (Item.Docs.Ghost_Title, Labels.Text (Item.Docs.Doc_Rows (Row).Caption));
         Layouts.Set_Layout
           (Item.Docs.Ghost,
            Position =>
              (Left => Widgets.Left_Of (Held) - Widgets.Left_Of (Item.Page_View.Docs_Content)
                       + Float'Rounding (Leeway * Pixels),
               Top  => Float'Min
                         (Most, Float'Max
                                  (0.0, Float'Rounding
                                          (Y * Pixels - High / 2.0
                                           - Widgets.Top_Of (Item.Page_View.Docs_Content)))),
               others => <>),
            Width  => Widgets.Width_Of (Held) - Offset,
            Height => High,
            Unit   => Layouts.Device_Pixels);
      end;
      Widgets.Set_Visible (Item.Docs.Ghost, True);
      Widgets.Request_Layout (Item.Docs.Ghost);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Show_Ghost;

   procedure Start_Drag (Item : in out Session; Row : Positive);
   --  Begin the drag of Row if none is on: not of the Overview, which is
   --  not put elsewhere, nor of a section, whose place is the outline's.

   procedure Start_Drag (Item : in out Session; Row : Positive) is
   begin
      if Item.Dragging.Drag_Row = 0
        and then Row <= Item.Docs.Tree_Count
        and then Item.Docs.Tree (Row).Kind /= Overview_Node
        and then not (Item.Docs.Tree (Row).Kind = Directory_Node
                      and then Support.Is_Section (Item, Item.Docs.Tree (Row).Dir))
      then
         Item.Dragging.Drag_Row := Row;
         Item.Dragging.Drag_Total := 0.0;
         Item.Dragging.Drag_Moved := False;
         Item.Docs.Drop := (others => <>);
         declare
            X, Y : Float;
         begin
            Grips.Pointer (Item.Docs.Doc_Rows (Row).Row, X, Y);
            Item.Dragging.Drag_From_X := X;
            pragma Unreferenced (Y);
         end;
      end if;
   end Start_Drag;

   procedure Row_Dragged
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
      Row : constant Positive := Event.Index;
   begin
      if not Support.In_Writing (Item) or else Row > Item.Docs.Tree_Count then
         return;
      end if;
      Start_Drag (Item, Row);
      if Item.Dragging.Drag_Row /= Row then
         return;
      end if;
      Item.Dragging.Drag_Total := Item.Dragging.Drag_Total + abs Event.Across + abs Event.Down;
      if Item.Dragging.Drag_Total >= Drag_Threshold and then not Item.Dragging.Drag_Moved then
         Item.Dragging.Drag_Moved := True;
         Tree.Refresh (Item);
      end if;
      if Item.Dragging.Drag_Moved then
         declare
            X, Y   : Float;
            Target : Drop_Target;
         begin
            Grips.Pointer (Item.Docs.Doc_Rows (Row).Row, X, Y);
            Show_Ghost (Item);
            Target := Target_At (Item, X, Y);
            if Target /= Item.Docs.Drop then
               Item.Docs.Drop := Target;
               Tree.Refresh (Item);
               Show_Drop_Line (Item);
            end if;
         end;
      end if;
   end Row_Dragged;

   procedure Row_Released
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
      Row : constant Positive := Event.Index;
   begin
      Item.Dragging.Dropped_Moved := False;
      if not Support.In_Writing (Item) or else Row > Item.Docs.Tree_Count then
         return;
      end if;
      Start_Drag (Item, Row);
      if Item.Dragging.Drag_Row /= Row then
         return;
      end if;
      declare
         Was_Moved : constant Boolean := Item.Dragging.Drag_Moved;
         Target    : constant Drop_Target := Item.Docs.Drop;
      begin
         Item.Dragging.Drag_Row := 0;
         Item.Dragging.Drag_Moved := False;
         Item.Docs.Drop := (others => <>);
         Item.Dragging.Dropped_Moved := Was_Moved;
         if Was_Moved then
            Moves.Drop_Row (Item, Row, Target);
         end if;
      end;
      Show_Drop_Line (Item);
      Show_Ghost (Item);
      Tree.Refresh (Item);
   end Row_Released;

end Viewer.Writing.Row_Drags;
