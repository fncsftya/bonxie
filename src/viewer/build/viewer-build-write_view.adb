with Word_Tools;
with Pomarine.Widgets.Switches;
with Pomarine.Widgets.Editors;
with Items.Readers;
with Items.Windows;
with Pomarine.Widgets.Progress_Bars;
with SDL3.Cursors;
with Pomarine.Boxes;
with Icon_Set;
with Pomarine.Line_Texts;
with Pomarine.Themes;
with Pomarine.Widgets;
with Pomarine.Widgets.Layouts;
with Pomarine.Widgets.Scrollers;
with Pomarine.Text_Areas;
with Viewer.Section_Links;
with Viewer.Style;
with Viewer.Writing;
with Viewer.Grammar;
with Pomarine.Icons;

package body Viewer.Build.Write_View is

   package Widgets renames Pomarine.Widgets;
   package Layouts renames Pomarine.Widgets.Layouts;
   package Panels renames Pomarine.Widgets.Panels;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Labels renames Pomarine.Widgets.Labels;
   package Text_Fields renames Pomarine.Widgets.Text_Fields;
   package Grips renames Pomarine.Widgets.Grips;
   package Scrollers renames Pomarine.Widgets.Scrollers;
   package Editors renames Pomarine.Widgets.Editors;
   package Switches renames Pomarine.Widgets.Switches;
   package Themes renames Pomarine.Themes;

   use Style;
   use Pomarine.Widgets.Layouts;

   procedure Build_Row
     (Item    : Session;
      Content : in out Panels.Panel;
      Before  : Widgets.Widget'Class;
      Each    : in out Index_Row;
      Counted : Boolean)
   is
      Pixels : constant Float := Item.Shell.Density;
      Offset : constant Float := Pomarine.Boxes.Offset (Pixels);
   begin
      Layouts.Add_Before
        (Content, Each.Row, Before,
         (Shrink => 0.0, Flow => Row, Align => Center, Padding => (Left | Right => Index_Pad * Pixels, others => <>),
          Shadowed => True, Height => Index_Height * Pixels + Offset, Unit => Device_Pixels, others => <>));
      Layouts.Add (Each.Row, Each.Tag,
                   (Width => Tag_Size, Height => Tag_Size, Shrink => 0.0, Margin => (Right => Index_Pad, others => <>),
                    others => <>));
      Layouts.Add (Each.Row, Each.Folder_Mark,
                   (Width => 18.0, Height => 18.0, Shrink => 0.0, Margin => (Right => Index_Pad, others => <>),
                    others => <>));
      Layouts.Add (Each.Row, Each.Caption, (Grow => 1.0, Width => 0.0, Height => Index_Height, others => <>));
      Layouts.Add (Each.Row, Each.Count, (Width => Count_Width, Height => Index_Height, others => <>));
      Labels.Set_Text (Each.Folder_Mark, " ");
      Labels.Set_Icon (Each.Folder_Mark, Icon_Set.Folder);
      Labels.Set_Ink (Each.Folder_Mark, Quiet_Ink);
      Widgets.Set_Visible (Each.Folder_Mark, False);
      --  Each row casts a shadow, inside its box: it is that much
      --  taller, and the gap less.
      Grips.Set_Fill (Each.Row, Row_Fill);
      Grips.Set_Hover_Fill (Each.Row, Row_Hover);
      Grips.Set_Border (Each.Row, Themes.Border);
      Grips.Set_Shadow (Each.Row, Side_Fill);
      Grips.Set_Wanted_Cursor (Each.Row, SDL3.Cursors.Pointer);
      Widgets.Set_Visible (Each.Tag, not Counted);
      Labels.Set_Trailing (Each.Count, True);
      Labels.Set_Ink (Each.Count, Quiet_Ink);
      Widgets.Set_Visible (Each.Count, Counted);
   end Build_Row;

   procedure Make_Tree_Row (Item : in out Session; Index : Positive) is
      Each : Index_Row renames Item.Docs.Doc_Rows (Index);
   begin
      Build_Row (Item, Item.Page_View.Docs_Content, Item.Page_View.Docs_None, Each, Counted => True);
      Panels.Set_Fill (Each.Tag, Quiet_Ink);
   end Make_Tree_Row;

   procedure Make_Source_Row (Item : in out Session; Which : Items.Slot) is
   begin
      Build_Row
        (Item, Item.Page_View.Sources_Content, Item.Page_View.Sources_None,
         Item.Reading.Source_Rows (Which), Counted => False);
   end Make_Source_Row;

   procedure Make_Page (Item : in out Session; Rank : Items.Slot) is
      Each : Doc_Page renames Item.Docs.Pages (Rank);
   begin
      Layouts.Add (Item.Page_View.Pages_Content, Each.Box,
                   (Flow => Column, Shrink => 0.0, Width => Write_Width, others => <>));
      Layouts.Add (Each.Box, Each.Bar,
                   (Flow => Row, Align => Center, Height => Page_Head, Gap => Tool_Gap,
                    Padding => (Right => Shadow_Room, others => <>), others => <>));
      Layouts.Add (Each.Bar, Each.Heading_Area,
                   (Flow => Row, Align => Center, Grow => 1.0, Width => 0.0, Height => Page_Head, others => <>));
      Layouts.Add (Each.Heading_Area, Each.Swatch,
                   (Width => Section_Swatch, Height => Section_Swatch, Shrink => 0.0,
                    Margin => (Right => Tool_Gap, others => <>), others => <>));
      Layouts.Add (Each.Heading_Area, Each.Heading, (Grow => 1.0, Width => 0.0, Height => Page_Head, others => <>));
      Layouts.Add (Each.Bar, Each.Title_Field, (Grow => 1.0, Width => 0.0, Height => Title_Height, others => <>));
      Buttons.Add (Each.Bar, Each.Outline_Button,
                   Buttons.Looks ("Section", Captioned => True, Shape => Buttons.Dropdown),
                   (Width => Outline_Link_Width, Height => Bar_Button_Height, others => <>));
      Buttons.Add (Each.Bar, Each.Sources_Button, Buttons.Looks ("Sources", Shape => Buttons.Dropdown),
                   (Width => Sources_Width, Height => Bar_Button_Height, others => <>));
      Buttons.Add (Each.Bar, Each.Mic_Button,
                   Buttons.Looks ("Mic", Icon => Pomarine.Icons.Shown (Icon_Set.Microphone),
                                  Icon_Points => Mic_Icon_Size),
                   (Width => Mic_Width, Height => Bar_Button_Height, others => <>));
      Layouts.Add (Each.Bar, Each.Level,
                   (Place => Absolute, Position => (Left | Bottom => 0.0, Right => Shadow_Room, others => <>),
                    Height => Level_Height, others => <>));
      Layouts.Add (Each.Box, Each.Sheet,
                   (Flow => Column, Shrink => 0.0, Shadowed => True, Padding => (others => Page_Border), others => <>));
      Layouts.Add (Each.Sheet, Each.Text, (Shrink => 0.0, Height => Page_Min_Height, others => <>));
      Layouts.Add (Each.Box, Each.Words,
                   (Height => Page_Foot, Margin => (Right => Shadow_Room, others => <>), others => <>));
      Labels.Set_Style (Each.Heading, Pomarine.Line_Texts.Heading);
      Text_Fields.Set_Shared
        (Each.Title_Field, Item.Host.Doc_Resources'Unchecked_Access);
      Text_Fields.Configure
        (Each.Title_Field, Pomarine.Line_Texts.Interface_Font,
         Pomarine.Line_Texts.Heading_Size);
      Widgets.Set_Visible (Each.Title_Field, False);
      Panels.Set_Fill (Each.Swatch, Themes.Border);
      Widgets.Set_Visible (Each.Swatch, False);
      Pomarine.Widgets.Progress_Bars.Set_Over (Each.Level, Rail, Items.Windows.Meter_Slot);
      Widgets.Set_Visible (Each.Level, False);
      --  The page: white, outlined, with a shadow it leaves room for.
      Panels.Set_Fill (Each.Sheet, Paper);
      Panels.Set_Border (Each.Sheet, Themes.Border);
      Panels.Set_Shadow (Each.Sheet, Themes.Shadow);
      Editors.Set_Shared
        (Each.Text, Item.Host.Doc_Resources'Unchecked_Access);
      Editors.Configure
        (Each.Text, Pomarine.Line_Texts.Serif, Page_Text_Size, 2000.0,
         Spacing => 0.35 * Page_Text_Size);
      Editors.Set_Paper (Each.Text, Paper);
      Editors.Set_Toolbar (Each.Text);
      Word_Tools.Add (Each.Text);
      --  The page's margin is the text area's, so that its toolbar is the page's width.
      Editors.Set_Indent
        (Each.Text, (Write_Width - Write_Text_Width) / 2.0 - Page_Text_Inset - Page_Border);
      Pomarine.Text_Areas.Set_Grows (Editors.Area (Each.Text).all);
      Labels.Set_Trailing (Each.Words, True);
      Labels.Set_Ink (Each.Words, Quiet_Ink);
      Widgets.Set_Visible (Each.Box, False);
      if Item.Section_View.Grouped then
         --  As the pages there are were put when the sections were shown (see Fit_Pages).
         Set_Layout (Each.Box, Place => Absolute, Position => (others => Unset));
      end if;
   end Make_Page;

   procedure Make_Reader (Item : in out Session; Which : Items.Slot) is
   begin
      Items.Readers.Build
        (Item.Reading.Readers (Which), Item.Page_View.Write_View, Toolbar, Item.Shell.Density);
      --  Over the rest, but under the menu.
      Widgets.Raise_To_Front (Item.Page_View.Menu);
   end Make_Reader;

   procedure Make_Section (Item : in out Session; Index : Positive) is
      Sections : Section_View_Parts renames Item.Section_View;
      View     : Page_Parts renames Item.Page_View;
   begin
      declare
         Head  : Section_Head renames Sections.Heads (Index);
         Notes : Note_Box renames Sections.Notes (Index);
         Empty : Section_Empty renames Sections.Empties (Index);
      begin
         Layouts.Add (View.Pages_Content, Head.Row,
                      (Place => Absolute, Flow => Row, Align => Center, Gap => Tool_Gap, Height => Section_Head_Height,
                       Width => Write_Width, others => <>));
         Layouts.Add (Head.Row, Head.Bar,
                      (Width => Section_Bar, Height => Section_Head_Height - 12.0, Shrink => 0.0, others => <>));
         Layouts.Add (Head.Row, Head.Title, (Grow => 1.0, Width => 0.0, Height => Section_Head_Height, others => <>));
         Layouts.Add (Head.Row, Head.Count, (Width => 140.0, Height => Section_Head_Height, others => <>));
         Buttons.Add (Head.Row, Head.Notes, Buttons.Looks ("Notes", Captioned => True, Focusable => True),
                      (Width => Notes_Width, Height => Outline_Button, Shrink => 0.0, others => <>));
         Buttons.Add (Head.Row, Head.Add,
                      Buttons.Looks ("Add document to this section", Icon => Pomarine.Icons.Shown (Icon_Set.Plus),
                                     Focusable => True),
                      (Width => Outline_Button, Height => Outline_Button, Shrink => 0.0,
                       Margin => (Right => Shadow_Room, others => <>), others => <>));
         Layouts.Add (View.Pages_Content, Notes.Box,
                      (Place => Absolute, Flow => Column, Width => Write_Width, Outlined => True,
                       Padding => (others => Notes_Pad), Shrink => 0.0, others => <>));
         Layouts.Add (Notes.Box, Notes.Text, (Shrink => 0.0, Height => Notes_Min_Height, others => <>));
         Layouts.Add (View.Pages_Content, Empty.Box,
                      (Place => Absolute, Flow => Column, Align => Center, Spread => Center, Gap => Tool_Gap,
                       Height => Section_Empty_Height, Width => Write_Width, Outlined => True, others => <>));
         Layouts.Add (Empty.Box, Empty.Note, (Height => Heading_Height, others => <>));
         Buttons.Add (Empty.Box, Empty.Add,
                      Buttons.Looks ("Add document", Icon => Pomarine.Icons.Shown (Icon_Set.Plus), Captioned => True,
                                     Focusable => True),
                      (Width => Wide_Tool_Width, Height => Bar_Button_Height, others => <>));

         Panels.Set_Fill (Head.Bar, Themes.Border);
         Labels.Set_Style (Head.Title, Pomarine.Line_Texts.Heading);
         Labels.Set_Ink (Head.Count, Quiet_Ink);
         Labels.Set_Trailing (Head.Count, True);
         Widgets.Set_Visible (Head.Row, False);

         Panels.Set_Fill (Notes.Box, Side_Fill);
         Panels.Set_Border (Notes.Box, Themes.Border);
         Editors.Set_Shared (Notes.Text, Item.Host.Doc_Resources'Unchecked_Access);
         Editors.Configure (Notes.Text, Pomarine.Line_Texts.Interface_Font, Edit_Size, 2000.0);
         Pomarine.Text_Areas.Set_Grows (Editors.Area (Notes.Text).all);
         Editors.Set_Paper (Notes.Text, Side_Fill);
         Editors.Set_Borderless (Notes.Text, True);
         Editors.Attach (Notes.Text, Item.Outline_View.Blocks (Index).Notes_Doc'Unchecked_Access);
         Widgets.Set_Visible (Notes.Box, False);

         Panels.Set_Border (Empty.Box, Themes.Border);
         Labels.Set_Text (Empty.Note, "No documents in this section yet");
         Labels.Set_Ink (Empty.Note, Quiet_Ink);
         Widgets.Set_Visible (Empty.Box, False);
      end;
   end Make_Section;

   procedure Make_Gap (Item : in out Session; Index : Natural) is
      Sections : Section_View_Parts renames Item.Section_View;
      Each     : Gap_Mark renames Sections.Gaps (Index + 1);
   begin
      Layouts.Add (Item.Page_View.Pages_Content, Each.Row,
                   (Place => Absolute, Flow => Row, Align => Center, Gap => Tool_Gap, Height => Gap_Mark_Height,
                    Width => Write_Width, others => <>));
      Layouts.Add (Each.Row, Each.Caption, (Width => 120.0, Height => Gap_Mark_Height, Shrink => 0.0, others => <>));
      Layouts.Add (Each.Row, Each.Rule, (Grow => 1.0, Width => 0.0, Height => Hairline, others => <>));
      Labels.Set_Text (Each.Caption, "Not in a section");
      Labels.Set_Style (Each.Caption, Pomarine.Line_Texts.Caption);
      Labels.Set_Ink (Each.Caption, Quiet_Ink);
      Panels.Set_Fill (Each.Rule, Themes.Border);
      Widgets.Set_Visible (Each.Row, False);
   end Make_Gap;

   procedure Build_Write (Item : in out Session) is
      View   : Page_Parts renames Item.Page_View;
      Pixels : constant Float := Item.Shell.Density;
      Offset : constant Float := Pomarine.Boxes.Offset (Pixels);

      procedure Build_Index
        (Scroll   : in out Scrollers.Scroller;
         Content  : in out Panels.Panel;
         None     : in out Labels.Label;
         Empty    : String) is
      begin
         --  As tall as its rows, if there is room; the second list
         --  follows the first.
         Layouts.Add (View.Sidebar, Scroll, (Shrink => 1.0, others => <>));
         --  The scroll bar, which is shown only while the pointer is
         --  over the list, is over the rows' right edge.
         Layouts.Add
           (Scroll, Content,
            (Flow => Column, Shrink => 0.0, Gap => Index_Gap * Pixels - Offset, Unit => Device_Pixels, others => <>));
         Labels.Set_Text (None, Empty);
         Labels.Set_Ink (None, Closed_Ink);
         Layouts.Add (Content, None, (Height => Index_Height, others => <>));
      end Build_Index;

      --  The head of a section, which folds it, added to Parent.
      procedure Add_Heading
        (Parent : in out Widgets.Widget'Class;
         Head   : in out Fold_Head;
         Name   : String;
         Grow   : Float := Unset;
         Width  : Float := Unset;
         Margin : Layouts.Sides := (others => <>)) is
      begin
         Layouts.Add
           (Parent, Head.Bar,
            (Flow => Row, Align => Center, Height => Heading_Height, Shrink => 0.0, Grow => Grow, Width => Width,
             Margin => Margin, others => <>));
         Layouts.Add (Head.Bar, Head.Mark, (Width => 18.0, Height => Heading_Height, Shrink => 0.0, others => <>));
         Layouts.Add (Head.Bar, Head.Name, (Grow => 1.0, Width => 0.0, Height => Heading_Height, others => <>));
         Labels.Set_Text (Head.Mark, " ");
         Labels.Set_Text (Head.Name, Name);
         Labels.Set_Style (Head.Name, Pomarine.Line_Texts.Caption);
         Grips.Set_Fill (Head.Bar, Side_Fill);
         Grips.Set_Hover_Fill (Head.Bar, Row_Hover);
         Grips.Set_Wanted_Cursor (Head.Bar, SDL3.Cursors.Pointer);
         Widgets.Set_Accessible_Name (Head.Bar, "Fold or unfold " & Name);
      end Add_Heading;

      --  Put the widgets in each other, styled: the sidebar (its lists, its edges and the fields over its rows),
      --  the pages, scrolled, one above the next, and the pane of the pinned source.
      procedure Assemble is
      begin
         Layouts.Add (Item.Toolbar.Content_Panel, View.Write_View,
                      (Flow => Row, Grow => 1.0, Height => 0.0, others => <>));
         if not Item.Shell.Windowed then
            Panels.Set_Fill (View.Write_View, Desk);
         end if;

         --  The sidebar: two lists one above the other, with a line at its
         --  right.
         Layouts.Add
           (View.Write_View, View.Sidebar,
            (Width => View.Sidebar_Wide, Shrink => 0.0, Flow => Column, Gap => Sidebar_Gap,
             Padding => (Top => Sidebar_Pad + Heading_Top, others => Sidebar_Pad), others => <>));
         Panels.Set_Fill (View.Sidebar, Side_Fill);
         Add_Heading (View.Sidebar, View.Edit_Heading, "EDIT");
         Layouts.Add
           (View.Sidebar, View.Grammar_Row,
            (Flow => Row, Align => Center, Height => 34.0, Shrink => 0.0, Gap => 4.0, others => <>));
         Layouts.Add (View.Grammar_Row, View.Grammar_Switch, (Height => 34.0, Grow => 1.0, Width => 0.0, others => <>));
         Buttons.Add (View.Grammar_Row, View.Grammar_Count, Buttons.Looks ("0", Focusable => True),
                      (Width => 36.0, Height => 28.0, Shrink => 0.0, others => <>));
         Switches.Set_Label (View.Grammar_Switch, "Show Grammar Suggestions");
         Switches.Set_On (View.Grammar_Switch, True);
         Switches.Set_Focusable (View.Grammar_Switch, True);
         Widgets.Set_Accessible_Name (View.Grammar_Count, "Fixable grammar suggestions: 0");
         Layouts.Add
           (View.Sidebar, View.Docs_Head,
            (Flow => Row, Align => Center, Gap => Index_Gap, Padding => (Right => Shadow_Room, others => <>),
             Margin => (Top => Heading_Top, others => <>), others => <>));
         Add_Heading (View.Docs_Head, View.Docs_Heading, "DOCUMENTS", Grow => 1.0, Width => 0.0);
         Buttons.Add
           (View.Docs_Head, View.Docs_Folder,
            Buttons.Looks ("New folder", Icon => Pomarine.Icons.Shown (Icon_Set.Folder), Icon_Points => Mic_Icon_Size),
            (Width => Add_Size, Height => Add_Size, others => <>));
         Buttons.Add
           (View.Docs_Head, View.Docs_Add,
            Buttons.Looks ("+", Icon => Pomarine.Icons.Shown (Icon_Set.Plus), Icon_Points => Mic_Icon_Size),
            (Width => Add_Size, Height => Add_Size, others => <>));
         Widgets.Set_Accessible_Name (View.Docs_Add, "Add document");
         Build_Index (View.Docs_Scroll, View.Docs_Content, View.Docs_None, No_Documents);

         --  Over the rows of the tree, out of their layout: the line where a
         --  document dragged would go between two, and the field to rename
         --  a directory by.
         Layouts.Add (View.Docs_Content, Item.Docs.Drop_Line,
                      (Place => Absolute, Height => Drop_Line_Height, others => <>));
         Panels.Set_Fill (Item.Docs.Drop_Line, Pomarine.Themes.Accent);
         Widgets.Set_Visible (Item.Docs.Drop_Line, False);
         Layouts.Add (View.Docs_Content, Item.Docs.Ghost,
                      (Place => Absolute, Flow => Row, Align => Center,
                       Padding => (Left | Right => Index_Pad, others => <>), others => <>));
         declare
            Fill : Themes.Color := Themes.Resolve (Colors, Row_Fill);
         begin
            --  The ghost of the row dragged: its name, in a box of the same
            --  outline, a little clear.
            Fill.Alpha := 225;
            Panels.Set_Fill_Color (Item.Docs.Ghost, Fill);
         end;
         Panels.Set_Border (Item.Docs.Ghost, Themes.Focus);
         Layouts.Add (Item.Docs.Ghost, Item.Docs.Ghost_Title,
                      (Grow => 1.0, Width => 0.0, Height => Index_Height, others => <>));
         Widgets.Set_Visible (Item.Docs.Ghost, False);
         Layouts.Add (View.Docs_Content, Item.Naming.Dir_Field,
                      (Place => Absolute, Height => Index_Height, others => <>));
         Text_Fields.Set_Shared
           (Item.Naming.Dir_Field, Item.Host.Doc_Resources'Unchecked_Access);
         Text_Fields.Configure
           (Item.Naming.Dir_Field, Pomarine.Line_Texts.Interface_Font, Edit_Size);
         Widgets.Set_Visible (Item.Naming.Dir_Field, False);
         Layouts.Add (View.Sidebar, View.Sources_Edge,
                      (Height => 16.0, Shrink => 0.0, Align => Center, Spread => Center, others => <>));
         Grips.Set_Fill (View.Sources_Edge, Side_Fill);
         Grips.Set_Hover_Fill (View.Sources_Edge, Edge_Fill);
         Grips.Set_Wanted_Cursor (View.Sources_Edge, SDL3.Cursors.Resize_Up_Down);
         Widgets.Set_Accessible_Name (View.Sources_Edge, "Drag to resize Sources");
         Layouts.Add (View.Sources_Edge, View.Sources_Grab,
                      (Width => 32.0, Height => 3.0, Shrink => 0.0, others => <>));
         Panels.Set_Fill (View.Sources_Grab, Quiet_Ink);
         Add_Heading (View.Sidebar, View.Sources_Heading, "SOURCES", Margin => (Top => Heading_Top, others => <>));
         Build_Index (View.Sources_Scroll, View.Sources_Content, View.Sources_None, No_Sources);
         Layouts.Add (View.Sources_Content, Item.Naming.Source_Field,
                      (Place => Absolute, Height => Index_Height, others => <>));
         Text_Fields.Set_Shared
           (Item.Naming.Source_Field, Item.Host.Doc_Resources'Unchecked_Access);
         Text_Fields.Configure
           (Item.Naming.Source_Field, Pomarine.Line_Texts.Interface_Font, Edit_Size);
         Widgets.Set_Visible (Item.Naming.Source_Field, False);
         Layouts.Add (View.Write_View, View.Sidebar_Edge,
                      (Width => Sidebar_Edge_Width, Shrink => 0.0, others => <>));
         Grips.Set_Fill (View.Sidebar_Edge, Side_Fill);
         Grips.Set_Hover_Fill (View.Sidebar_Edge, Edge_Fill);
         Grips.Set_Wanted_Cursor (View.Sidebar_Edge, SDL3.Cursors.Resize_Across);
         Layouts.Add (View.Write_View, View.Sidebar_Rule, (Width => Hairline, Shrink => 0.0, others => <>));
         Panels.Set_Fill (View.Sidebar_Rule, Themes.Border);

         --  The pages, scrolled, one above the next, and the button to add
         --  one after them.
         Layouts.Add (View.Write_View, View.Pages_Scroll, (Grow => 1.0, Width => 0.0, others => <>));
         Layouts.Add
           (View.Pages_Scroll, View.Pages_Content,
            (Flow => Column, Shrink => 0.0, Align => Start, Gap => Page_Gap,
             Padding => (Top => Page_Margin - Page_Gap, others => Page_Margin), others => <>));
         --  The spacer of the sections is first, so that the pages (and what
         --  is between them) are over it, and take the pointer.
         Layouts.Add (View.Pages_Content, Item.Section_View.Tail,
                      (Place => Flowing, Height => 0.0, Shrink => 0.0, others => <>));
         Widgets.Set_Visible (Item.Section_View.Tail, False);

         --  The pane: an edge to size it by, and the pinned source.
         Layouts.Add (View.Write_View, View.Pane, (Flow => Row, Shrink => 0.0, Width => Pane_Default, others => <>));
         if not Item.Shell.Windowed then
            Panels.Set_Fill (View.Pane, Desk);
         end if;
         View.Pane_Wide := Pane_Default;
         Layouts.Add (View.Pane, View.Pane_Edge, (Width => Pane_Edge_Width, Shrink => 0.0, others => <>));
         Grips.Set_Fill (View.Pane_Edge, Edge_Fill);
         Grips.Set_Wanted_Cursor (View.Pane_Edge, SDL3.Cursors.Resize_Across);
         Layouts.Add (View.Pane, View.Pane_Body, (Flow => Column, Grow => 1.0, Width => 0.0, others => <>));
         Widgets.Set_Visible (View.Pane, False);
         --  Over the rest, last.
         Layouts.Add (View.Write_View, View.Menu, (Place => Absolute, Width => Menu_Width, others => <>));
         Widgets.Set_Visible (View.Menu, False);
      end Assemble;

      --  The menus over the content, and the listeners of the other parts.
      procedure Hook_Up is
      begin
         Layouts.Add (Item.Toolbar.Content_Panel, Item.Context.Context_Menu,
                      (Place => Absolute, Width => Context_Width, others => <>));
         Widgets.Set_Visible (Item.Context.Context_Menu, False);
         Layouts.Add (Item.Toolbar.Content_Panel, Item.Section_Menu.Menu,
                      (Place => Absolute, Width => 220.0, others => <>));
         Widgets.Set_Visible (Item.Section_Menu.Menu, False);
         Section_Links.Listen (Item);
         Items.Readers.Build
           (Item.Reading.Pane_Reader, View.Pane_Body, Toolbar, Pixels,
            Pinned => True);
         Writing.Listen (Item);
         Grammar.Build (Item);
      end Hook_Up;

   begin
      Assemble;
      Hook_Up;
      Writing.Fit_Sidebar (Item);
   end Build_Write;

end Viewer.Build.Write_View;
