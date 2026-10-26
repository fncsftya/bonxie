with Naming_VM;
with Sidebar_VM;
with Items.Models;
with Settings_VM;
with Preferences;
with Pomarine.Icons;
with Pomarine.Widgets.Labels;
with Pomarine.Text_Areas;
with Pomarine.Widgets.Grips;
with Pomarine.Widgets.Text_Fields;
with View.Style;
with Pomarine.Widgets.Layouts;
with View.Writing.Reader_Windows;
with View.Writing.Rename;
with View.Writing.Support;
with View.Writing.Tree;

package body View.Writing.Panes is

   package Layouts renames Pomarine.Widgets.Layouts;
   package Grips renames Pomarine.Widgets.Grips;
   package Text_Fields renames Pomarine.Widgets.Text_Fields;
   package Models renames Items.Models;

   use type Items.States;

   procedure Row_Clicked (Item : in out Session; Row : Positive) is
      Moved : constant Boolean := Item.Dragging.Dropped_Moved;
   begin
      Item.Dragging.Dropped_Moved := False;
      if not Support.In_Writing (Item) or else Row > Trees.Count (Item.Docs.Ordering)
        or else Moved or else Item.Dragging.Drag_Row /= 0
      then
         return;
      end if;
      declare
         Node : constant Tree_Entry := Trees.Element (Item.Docs.Ordering, Row);
      begin
         case Node.Kind is
            when Overview_Node =>
               Tree.Show_Directory (Item, 0);
            when Directory_Node =>
               if Naming_VM.Directory (Item.Naming.Names) /= Node.Dir then
                  Tree.Show_Directory (Item, Node.Dir);
               end if;
            when Document_Leaf =>
               Tree.Show_Page (Item, Node.Doc);
         end case;
      end;
   end Row_Clicked;

   procedure Row_Double_Clicked (Item : in out Session; Row : Positive) is
   begin
      if not Support.In_Writing (Item) or else Row > Trees.Count (Item.Docs.Ordering) then
         return;
      end if;
      declare
         Node : constant Tree_Entry := Trees.Element (Item.Docs.Ordering, Row);
      begin
         if Node.Kind = Directory_Node and then Naming_VM.Directory (Item.Naming.Names) /= Node.Dir then
            --  The press that began it is not let go on its row.
            Grips.Cancel_Drag (Item.Docs.Doc_Rows (Row).Row);
            Rename.Begin_Rename_Dir (Item, Node.Dir);
         end if;
      end;
   end Row_Double_Clicked;

   procedure Directory_Field_Ended (Item : in out Session) is
   begin
      if not Support.In_Writing (Item) then
         return;
      end if;
      if Naming_VM.Directory (Item.Naming.Names) /= 0 then
         Rename.End_Rename_Dir (Item);
      elsif Naming_VM.Document (Item.Naming.Names) /= 0 then
         Rename.End_Rename_Doc (Item);
      end if;
   end Directory_Field_Ended;

   procedure Source_Field_Ended (Item : in out Session) is
   begin
      if Support.In_Writing (Item) and then Naming_VM.Source (Item.Naming.Names) /= 0 then
         Rename.End_Rename_Source (Item);
      end if;
   end Source_Field_Ended;

   procedure Sidebar_Dragged
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
   begin
      if Support.In_Writing (Item) and then Event.Across /= 0.0 then
         declare
            Most : constant Float :=
              Float'Max
                (Style.Sidebar_Least,
                 Float'Min
                   (Style.Sidebar_Most,
                    Widgets.Width_Of (Item.Page_View.Write_View) / Pixels
                    - (if Item.Reading.Pinned_Slot /= 0 then Item.Page_View.Pane_Wide else 0.0)
                    - Style.Page_Min_Width - 2.0 * Style.Page_Margin));
         begin
            Item.Page_View.Sidebar_Wide :=
              Float'Min (Most, Float'Max (Style.Sidebar_Least, Item.Page_View.Sidebar_Wide + Event.Across));
            Layouts.Set_Layout (Item.Page_View.Sidebar, Width => Item.Page_View.Sidebar_Wide);
         end;
      end if;
   end Sidebar_Dragged;

   procedure Sidebar_Released
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      if Settings_VM.Persists (Item.Choices.Model) then
         begin
            Preferences.Save_Sidebar_Width
              (Settings_VM.Config_Directory (Item.Choices.Model),
               Natural (Float'Rounding (Item.Page_View.Sidebar_Wide)));
         exception
            when others =>
               null;  --  the width is only not kept
         end;
      end if;
   end Sidebar_Released;

   procedure Fit_Sections (Item : in out Session) is
      Pane : Page_Parts renames Item.Page_View;

      procedure Head (Fold : in out Fold_Head; Unfolded : Boolean) is
      begin
         Pomarine.Widgets.Labels.Set_Icon
           (Fold.Mark, (if Unfolded then Pomarine.Icons.Chevron_Up else Pomarine.Icons.Chevron_Down));
      end Head;
   begin
      Head (Pane.Edit_Heading, Sidebar_VM.Is_Open (Pane.Folding, Sidebar_VM.Edit));
      Head (Pane.Docs_Heading, Sidebar_VM.Is_Open (Pane.Folding, Sidebar_VM.Documents));
      Head (Pane.Sources_Heading, Sidebar_VM.Is_Open (Pane.Folding, Sidebar_VM.Sources));
      Widgets.Set_Visible (Pane.Grammar_Row, Sidebar_VM.Is_Open (Pane.Folding, Sidebar_VM.Edit));
      Widgets.Set_Visible (Pane.Docs_Scroll, Sidebar_VM.Is_Open (Pane.Folding, Sidebar_VM.Documents));
      Widgets.Set_Visible (Pane.Docs_Add, Sidebar_VM.Is_Open (Pane.Folding, Sidebar_VM.Documents));
      Widgets.Set_Visible (Pane.Docs_Folder, Sidebar_VM.Is_Open (Pane.Folding, Sidebar_VM.Documents));
      Widgets.Set_Visible (Pane.Sources_Scroll, Sidebar_VM.Is_Open (Pane.Folding, Sidebar_VM.Sources));
      --  The divider is between two lists that are both there.
      Widgets.Set_Visible
        (Pane.Sources_Edge, Sidebar_VM.Is_Open (Pane.Folding, Sidebar_VM.Documents)
         and then Sidebar_VM.Is_Open (Pane.Folding, Sidebar_VM.Sources));
   end Fit_Sections;

   procedure Sources_Edge_Dragged
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Pane   : Page_Parts renames Item.Page_View;
   begin
      if Support.In_Writing (Item) and then Event.Down /= 0.0 then
         declare
            Current : constant Float := Widgets.Height_Of (Pane.Docs_Scroll) / Pixels;
            Available : constant Float := Current + Widgets.Height_Of (Pane.Sources_Scroll) / Pixels;
            Minimum : constant Float := Float'Min (2.0 * Style.Index_Pitch, Available / 2.0);
            Maximum : constant Float := Available - Minimum;
            Wanted : constant Float := Float'Max (Minimum, Float'Min (Maximum, Current + Event.Down));
         begin
            pragma Assert (Available >= 0.0 and then Minimum <= Maximum);
            --  Fix the space above the divider; Sources takes the remainder.
            --  Both lists must not shrink together, or the divider lags the pointer.
            Layouts.Set_Layout (Pane.Docs_Scroll, Height => Wanted, Grow => 0.0, Shrink => 0.0);
            Layouts.Set_Layout (Pane.Sources_Scroll, Height => 0.0, Grow => 1.0, Shrink => 1.0);
         end;
      end if;
   end Sources_Edge_Dragged;

   procedure Pane_Dragged
     (Item : in out Session; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
   begin
      if Support.In_Writing (Item) and then Event.Across /= 0.0 then
         declare
            Most : constant Float :=
              Float'Max
                (Style.Pane_Least,
                 Widgets.Width_Of (Item.Page_View.Write_View) / Pixels
                 - Item.Page_View.Sidebar_Wide - 2.0 * Style.Sidebar_Margin
                 - Style.Page_Min_Width);
         begin
            Item.Page_View.Pane_Wide :=
              Float'Min (Most, Float'Max (Style.Pane_Least,
                                          Item.Page_View.Pane_Wide - Event.Across));
            Layouts.Set_Layout (Item.Page_View.Pane, Width => Item.Page_View.Pane_Wide);
         end;
      end if;
   end Pane_Dragged;

   procedure Page_Title_Double_Clicked (Item : in out Session; Rank : Positive) is
      Each : Doc_Page renames Item.Docs.Pages (Rank);
   begin
      if Support.In_Writing (Item) and then not Naming_VM.Is_Titling (Item.Naming.Names, Rank)
        and then Each.Bound /= 0
      then
         Text_Fields.Attach
           (Each.Title_Field,
            Models.Title_Document (Item.Models (Each.Bound)));
         Naming_VM.Begin_Title (Item.Naming.Names, Rank);
         Widgets.Set_Visible (Each.Heading_Area, False);
         --  The press that began it is not let go on what is hidden.
         Grips.Cancel_Drag (Each.Heading_Area);
         Widgets.Set_Visible (Each.Title_Field, True);
         Pomarine.Text_Areas.Select_All (Text_Fields.Area (Each.Title_Field).all);
         Widgets.Focus (Each.Title_Field);
      end if;
   end Page_Title_Double_Clicked;

   procedure Page_Title_Ended (Item : in out Session; Rank : Positive) is
      Each : Doc_Page renames Item.Docs.Pages (Rank);
   begin
      if Naming_VM.Is_Titling (Item.Naming.Names, Rank) then
         Naming_VM.End_Title (Item.Naming.Names, Rank);
         Widgets.Set_Visible (Each.Title_Field, False);
         Widgets.Set_Visible (Each.Heading_Area, True);
      end if;
   end Page_Title_Ended;

   procedure Reader_Asked
     (Item   : in out Session;
      Which  : Natural;
      Action : Readers.Actions) is
   begin
      if not Support.In_Writing (Item) then
         return;
      end if;
      if Which /= 0 then
         case Action is
            when Readers.None | Readers.Visit =>
               null;
            when Readers.Close =>
               Readers.Set_State (Item.Reading.Readers (Which), Items.Closed);
               Tree.Refresh (Item);
            when Readers.Toggle_Pin =>
               Reader_Windows.Pin (Item, Which);
               Tree.Refresh (Item);
         end case;
      else
         case Action is
            when Readers.None | Readers.Visit =>
               null;
            when Readers.Close =>
               Reader_Windows.Unpin (Item, Reopen => False);
               Tree.Refresh (Item);
            when Readers.Toggle_Pin =>
               Reader_Windows.Unpin (Item, Reopen => True);
               Tree.Refresh (Item);
         end case;
      end if;
   end Reader_Asked;

end View.Writing.Panes;
