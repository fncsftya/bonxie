with Writing_VM;
with Canvas_VM;
with Items.Links;
with Items.Models;
with Projects.Sections;
with Items.Readers;
with Pomarine.Themes;
with Pomarine.Line_Texts;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Editors;
with Pomarine.Widgets.Grips;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Panels;
with Pomarine.Widgets.Scrollers;
with Viewer.Canvas_Items;
with Viewer.Section_Links;
with Viewer.Style;
with Pomarine.Widgets.Layouts;
with Viewer.Writing.Layout;
with Viewer.Writing.Order;
with Viewer.Writing.Popups;
with Viewer.Writing.Support;

package body Viewer.Writing.Tree is

   package Widgets renames Pomarine.Widgets;
   package Layouts renames Pomarine.Widgets.Layouts;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Editors renames Pomarine.Widgets.Editors;
   package Grips renames Pomarine.Widgets.Grips;
   package Labels renames Pomarine.Widgets.Labels;
   package Scrollers renames Pomarine.Widgets.Scrollers;
   package Readers renames Items.Readers;
   package Models renames Items.Models;

   use type Items.Id;
   use type Items.States;

   procedure Choose_Row (Row : in out Index_Row; Chosen : Boolean) is
   begin
      Labels.Set_Style
        (Row.Caption,
         (if Chosen then Pomarine.Line_Texts.Strong else Pomarine.Line_Texts.Regular));
      if Chosen then
         Grips.Set_Fill (Row.Row, Style.Row_Open);
         Grips.Set_Hover_Fill (Row.Row, Style.Row_Open);
         Grips.Set_Shadow (Row.Row, Pomarine.Themes.Shadow);
      else
         --  Its shadow is the ground: unseen, but the face is the same
         --  size.
         Grips.Set_Fill (Row.Row, Style.Row_Fill);
         Grips.Set_Hover_Fill (Row.Row, Style.Row_Hover);
         Grips.Set_Shadow (Row.Row, Style.Side_Fill);
      end if;
   end Choose_Row;

   function Linked_Sources
     (Item : Session; Which : Items.Slot) return Natural
   is
      Key   : constant Items.Id := Models.Details (Item.Models (Which)).Key;
      Total : Natural := 0;
   begin
      for Row in 1 .. Item.Reading.Source_Total loop
         declare
            Other : constant Items.Id :=
              Models.Details (Item.Models (Item.Reading.Source_Order (Row))).Key;
         begin
            for Number in 1 .. Canvas_VM.Link_Count (Item.Canvas_Model.Model) loop
               declare
                  Each : constant Items.Links.Link := Canvas_VM.Link_At (Item.Canvas_Model.Model, Number);
               begin
                  if (Each.From = Key and then Each.To = Other)
                    or else (Each.From = Other and then Each.To = Key)
                  then
                     Total := Total + 1;
                     exit;
                  end if;
               end;
            end loop;
         end;
      end loop;
      return Total;
   end Linked_Sources;

   procedure Show_Tree_Row (Item : in out Session; Row : Tree_Row);
   --  Show the row of the tree as what it is of: its name, its count, how
   --  far in it is, and whether it is the one chosen or dropped on.

   procedure Show_Tree_Row (Item : in out Session; Row : Tree_Row) is
      Each    : Index_Row renames Item.Docs.Doc_Rows (Row);
      Node    : constant Tree_Entry := Trees.Element (Item.Docs.Ordering, Row);
      Dropped : constant Boolean :=
        Item.Docs.Drop.Kind = Into_Node and then Item.Docs.Drop.Row = Row;
      --  While a document is dragged, the nodes it can be dropped on show.
      Hinted  : constant Boolean :=
        Item.Dragging.Drag_Row /= 0 and then Item.Dragging.Drag_Moved
        and then (Trees.Element (Item.Docs.Ordering, Item.Dragging.Drag_Row).Kind = Document_Leaf
                  or else Node.Kind = Overview_Node
                  or else (Node.Kind = Directory_Node
                           and then not Support.Within
                             (Item, Node.Dir, Trees.Element (Item.Docs.Ordering, Item.Dragging.Drag_Row).Dir)));
      Chosen  : Boolean;
      Level   : Float := 0.0;
   begin
      Widgets.Set_Visible
        (Each.Folder_Mark, Node.Kind = Directory_Node and then not Support.Is_Section (Item, Node.Dir));
      case Node.Kind is
         when Overview_Node =>
            Labels.Set_Text (Each.Caption, "Overview");
            Labels.Set_Text (Each.Count,
                             Support.Count_Image (Trees.Page_Count (Item.Docs.Ordering)));
            Chosen := Writing_VM.Shown (Item.Docs.Navigation, Item.Docs.Dirs) = 0;
         when Directory_Node =>
            Labels.Set_Text
              (Each.Caption,
               Projects.Titles.To_String
                         (Item.Docs.Dirs (Node.Dir).Title));
            Labels.Set_Text
              (Each.Count, Support.Count_Image (Support.Documents_In (Item, Node.Dir)));
            Chosen := Writing_VM.Shown (Item.Docs.Navigation, Item.Docs.Dirs) = Node.Dir;
            Level := Float (Support.Depth (Item, Node.Dir)) * Style.Tree_Indent;
         when Document_Leaf =>
            Labels.Set_Text (Each.Caption, Support.Title_Of (Item, Node.Doc));
            Labels.Set_Text
              (Each.Count,
               Support.Count_Image (Models.Words (Item.Models (Node.Doc))));
            if Node.Dir /= 0 then
               Level := Float (Support.Depth (Item, Node.Dir) + 1) * Style.Tree_Indent;
            end if;
            Chosen :=
              (if Item.Dragging.Drag_Row /= 0 and then Item.Dragging.Drag_Moved
               then Row = Item.Dragging.Drag_Row
               else Widgets.Has_Focus
                      (Item.Docs.Pages (Support.Rank_Of (Item, Node.Doc)).Text));
      end case;
      Widgets.Set_Accessible_Name
        (Each.Row,
         (case Node.Kind is
             when Overview_Node => "Overview",
             when Directory_Node => "Directory " & Projects.Titles.To_String (Item.Docs.Dirs (Node.Dir).Title),
             when Document_Leaf => "Document " & Support.Title_Of (Item, Node.Doc)));
      if Node.Kind = Overview_Node then
         --  Neither a section, a directory nor a document: a band of its
         --  own, with a rule in the accent colour, lit when it is shown.
         Widgets.Set_Visible (Each.Tag, False);
         Labels.Set_Style (Each.Caption, Pomarine.Line_Texts.Strong);
         Grips.Set_Fill (Each.Row, (if Chosen then Pomarine.Themes.Selection else Pomarine.Themes.Tint));
         Grips.Set_Hover_Fill (Each.Row, Pomarine.Themes.Selection);
         Grips.Clear_Shadow (Each.Row);
         Grips.Set_Border
           (Each.Row, (if Chosen then Pomarine.Themes.Accent else Pomarine.Themes.Border));
      elsif Node.Kind = Document_Leaf then
         --  A box, standing up.
         Choose_Row (Each, Chosen);
         Grips.Set_Border (Each.Row, Pomarine.Themes.Border);
         --  Its colour is the section's, on the section's row.
         Widgets.Set_Visible (Each.Tag, False);
      else
         --  Not a box: bare, with a marker, in bold; the marker is lit
         --  when it is the one shown, and the row is outlined while a
         --  document is over it.
         Labels.Set_Style (Each.Caption, Pomarine.Line_Texts.Strong);
         Grips.Clear_Fill (Each.Row);
         Grips.Set_Hover_Fill (Each.Row, Style.Row_Hover);
         Grips.Clear_Shadow (Each.Row);
         if Dropped then
            Grips.Set_Border (Each.Row, Pomarine.Themes.Focus);
         elsif Hinted then
            Grips.Set_Border (Each.Row, Pomarine.Themes.Border, Dashed => True);
         else
            Grips.Clear_Border (Each.Row);
         end if;
         Pomarine.Widgets.Panels.Set_Fill
           (Each.Tag,
            (if Support.Is_Section (Item, Node.Dir)
             then Style.Section_Ink
                    (Projects.Sections.Colour_Value (Item.Docs.Dirs (Node.Dir).Colour))
             elsif Chosen then Pomarine.Themes.Accent else Style.Quiet_Ink));
         Widgets.Set_Visible (Each.Tag, Support.Is_Section (Item, Node.Dir));
      end if;
      if Level /= Each.Indent then
         --  Shrinks the box, not only its text.
         Each.Indent := Level;
         Layouts.Set_Layout (Each.Row, Margin => (Left => Level, others => <>));
      end if;
   end Show_Tree_Row;

   procedure Refresh (Item : in out Session) is
   begin
      for Rank in 1 .. Item.Windows.Count loop
         declare
            Each : Doc_Page renames Item.Docs.Pages (Rank);
         begin
            if Rank <= Trees.Page_Count (Item.Docs.Ordering) then
               declare
                  Which : constant Items.Slot
                     := Trees.Page_At (Item.Docs.Ordering, Rank);
               begin
                  if Each.Bound /= Which then
                     Each.Renaming := False;
                     Widgets.Set_Visible (Each.Title_Field, False);
                     Widgets.Set_Visible (Each.Heading_Area, True);
                     Editors.Attach
                       (Each.Text,
                        Models.Content_Document (Item.Models (Which)));
                     Each.Bound := Which;
                     Each.Caret_Seen := 0;
                  end if;
                  Labels.Set_Text
                    (Each.Heading, Support.Title_Of (Item, Which));
                  Widgets.Set_Accessible_Name (Each.Text, "Text of " & Support.Title_Of (Item, Which));
                  declare
                     Section : constant Natural := Section_Links.Section_Of (Item, Which);
                  begin
                     Widgets.Set_Visible (Each.Swatch, Section /= 0);
                     if Section /= 0 then
                        Pomarine.Widgets.Panels.Set_Fill (Each.Swatch, Section_Links.Ink_Of (Item, Section));
                     end if;
                  end;
                  if not Support.In_View (Item, Which) then
                     --  Out of sight, it keeps neither the focus nor a
                     --  title being renamed.
                     Each.Renaming := False;
                     Widgets.Set_Visible (Each.Title_Field, False);
                     Widgets.Set_Visible (Each.Heading_Area, True);
                     if Widgets.Has_Focus (Each.Text) then
                        Widgets.Release_Focus (Each.Text);
                     end if;
                  end if;
               end;
            elsif Each.Bound /= 0 then
               Each.Bound := 0;
               Each.Renaming := False;
               Widgets.Set_Visible (Each.Title_Field, False);
               Widgets.Set_Visible (Each.Heading_Area, True);
               if Widgets.Has_Focus (Each.Text) then
                  Widgets.Release_Focus (Each.Text);
               end if;
            end if;
            Widgets.Set_Visible
              (Each.Box,
               Rank <= Trees.Page_Count (Item.Docs.Ordering)
               and then Support.In_View (Item, Trees.Page_At (Item.Docs.Ordering, Rank)));
         end;
      end loop;
      Widgets.Set_Visible (Item.Page_View.Docs_None,
                           Trees.Page_Count (Item.Docs.Ordering) = 0);
      Buttons.Set_Enabled (Item.Page_View.Docs_Folder, True);

      for Row in 1 .. Item.Docs.Doc_Rows.Count loop
         if Row <= Trees.Count (Item.Docs.Ordering) then
            Show_Tree_Row (Item, Row);
         end if;
         Widgets.Set_Visible (Item.Docs.Doc_Rows (Row).Row,
                              Row <= Trees.Count (Item.Docs.Ordering));
      end loop;

      for Row in 1 .. Item.Windows.Count loop
         declare
            Each : Index_Row renames Item.Reading.Source_Rows (Row);
         begin
            if Row <= Item.Reading.Source_Total then
               declare
                  Which : constant Items.Slot
                     := Item.Reading.Source_Order (Row);
               begin
                  Labels.Set_Text
                    (Each.Caption, Support.Title_Of (Item, Which));
                  Pomarine.Widgets.Panels.Set_Fill
                    (Each.Tag, Canvas_Items.Source_Ink (Item, Which));
                  Choose_Row
                    (Each,
                     Item.Reading.Pinned_Slot = Which
                     or else Readers.Details
                               (Item.Reading.Readers (Which)).State
                             = Items.Open);
               end;
            end if;
            Widgets.Set_Visible (Each.Row, Row <= Item.Reading.Source_Total);
         end;
      end loop;
      Widgets.Set_Visible (Item.Page_View.Sources_None,
                           Item.Reading.Source_Total = 0);
   end Refresh;

   procedure Go_To (Item : in out Session; Rank : Positive) is
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
   begin
      Scrollers.Scroll_To
        (Item.Page_View.Pages_Scroll,
         (Widgets.Top_Of (Item.Docs.Pages (Rank).Box)
          - Widgets.Top_Of (Item.Page_View.Pages_Content)) / Pixels
         - Style.Page_Margin / 2.0);
   end Go_To;

   procedure Show_Directory (Item : in out Session; Directory : Natural) is
   begin
      Popups.Close_Menu (Item);
      Writing_VM.Show (Item.Docs.Navigation, Item.Docs.Dirs, Directory);
      Refresh (Item);
      Scrollers.Scroll_To (Item.Page_View.Pages_Scroll, 0.0);
      if View_Mode (Item) = Write then
         Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
         Layout.Fit_Pages (Item);
      end if;
   end Show_Directory;

   procedure Show_Page (Item : in out Session; Which : Items.Slot) is
   begin
      if not Support.In_View (Item, Which) then
         Show_Directory (Item, Trees.Directory_Of (Item.Docs.Ordering, Which));
      end if;
      Go_To (Item, Support.Rank_Of (Item, Which));
   end Show_Page;

   procedure Rebuild (Item : in out Session) is
   begin
      Order.Build_Order (Item);
      Writing_VM.Reconcile (Item.Docs.Navigation, Item.Docs.Dirs);
      Item.Section_Menu.Seen := Item.Section_Menu.Changes;
      Refresh (Item);
   end Rebuild;

end Viewer.Writing.Tree;
