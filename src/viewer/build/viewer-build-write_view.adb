with Word_Tools;
with Pomarine.Widgets.Switches;
with Pomarine.Widgets.Menus;
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

package body Viewer.Build.Write_View is

   package Widgets renames Pomarine.Widgets;
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
      Widgets.Add_Before (Content, Each.Row, Before);
      Widgets.Add (Each.Row, Each.Tag, Each.Folder_Mark, Each.Caption, Each.Count);
      Labels.Set_Text (Each.Folder_Mark, " ");
      Labels.Set_Icon (Each.Folder_Mark, Icon_Set.Folder);
      Labels.Set_Ink (Each.Folder_Mark, Quiet_Ink);
      Set_Layout
        (Each.Folder_Mark, Width => 18.0, Height => 18.0, Shrink => 0.0,
         Margin => (Right => Index_Pad, others => <>));
      Widgets.Set_Visible (Each.Folder_Mark, False);
      --  Each row casts a shadow, inside its box: it is that much
      --  taller, and the gap less.
      Grips.Set_Fill (Each.Row, Row_Fill);
      Grips.Set_Hover_Fill (Each.Row, Row_Hover);
      Grips.Set_Border (Each.Row, Themes.Border);
      Grips.Set_Shadow (Each.Row, Side_Fill);
      Grips.Set_Wanted_Cursor (Each.Row, SDL3.Cursors.Pointer);
      Set_Layout
        (Each.Row, Shrink => 0.0, Flow => Row, Align => Center,
         Padding => (Left | Right => Index_Pad, others => <>), Shadowed => True);
      Set_Layout
        (Each.Row, Height => Index_Height * Pixels + Offset, Unit => Device_Pixels);
      Set_Layout
        (Each.Tag, Width => Tag_Size, Height => Tag_Size, Shrink => 0.0,
         Margin => (Right => Index_Pad, others => <>));
      Widgets.Set_Visible (Each.Tag, not Counted);
      Set_Layout (Each.Caption, Grow => 1.0, Width => 0.0, Height => Index_Height);
      Labels.Set_Trailing (Each.Count, True);
      Labels.Set_Ink (Each.Count, Quiet_Ink);
      Set_Layout (Each.Count, Width => Count_Width, Height => Index_Height);
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
      Widgets.Add (Item.Page_View.Pages_Content, Each.Box);
      Widgets.Add (Each.Box, Each.Bar);
      Widgets.Add (Each.Bar, Each.Heading_Area);
      Widgets.Add (Each.Heading_Area, Each.Swatch, Each.Heading);
      Widgets.Add (Each.Bar, Each.Title_Field, Each.Outline_Button, Each.Sources_Button);
      Widgets.Add (Each.Bar, Each.Mic_Button);
      Widgets.Add (Each.Bar, Each.Level);
      Widgets.Add (Each.Box, Each.Sheet);
      Widgets.Add (Each.Sheet, Each.Text);
      Widgets.Add (Each.Box, Each.Words);
         Set_Layout (Each.Box, Flow => Column, Shrink => 0.0, Width => Write_Width);
         Set_Layout
           (Each.Bar, Flow => Row, Align => Center, Height => Page_Head, Gap => Tool_Gap,
            Padding => (Right => Shadow_Room, others => <>));
         Labels.Set_Style (Each.Heading, Pomarine.Line_Texts.Heading);
         Set_Layout
           (Each.Heading_Area, Flow => Row, Align => Center, Grow => 1.0, Width => 0.0,
            Height => Page_Head);
         Set_Layout (Each.Heading, Grow => 1.0, Width => 0.0, Height => Page_Head);
         Text_Fields.Set_Shared
           (Each.Title_Field, Item.Host.Doc_Resources'Unchecked_Access);
         Text_Fields.Configure
           (Each.Title_Field, Pomarine.Line_Texts.Interface_Font,
            Pomarine.Line_Texts.Heading_Size);
         Set_Layout (Each.Title_Field, Grow => 1.0, Width => 0.0, Height => Title_Height);
         Widgets.Set_Visible (Each.Title_Field, False);
         Buttons.Set_Label (Each.Sources_Button, "Sources");
         Buttons.Set_Dropdown (Each.Sources_Button, True);
         Set_Layout (Each.Sources_Button, Width => Sources_Width, Height => Bar_Button_Height);
         Buttons.Set_Label (Each.Outline_Button, "Section");
         Buttons.Set_Captioned (Each.Outline_Button, True);
         Buttons.Set_Dropdown (Each.Outline_Button, True);
         Set_Layout (Each.Outline_Button, Width => Outline_Link_Width, Height => Bar_Button_Height);
         Panels.Set_Fill (Each.Swatch, Themes.Border);
         Set_Layout
           (Each.Swatch, Width => Section_Swatch, Height => Section_Swatch, Shrink => 0.0,
            Margin => (Right => Tool_Gap, others => <>));
         Widgets.Set_Visible (Each.Swatch, False);
         Set_Layout
           (Each.Level, Place => Absolute,
            Position => (Left | Bottom => 0.0, Right => Shadow_Room, others => <>),
            Height => Level_Height);
         Pomarine.Widgets.Progress_Bars.Set_Over (Each.Level, Rail, Items.Windows.Meter_Slot);
         Widgets.Set_Visible (Each.Level, False);
         Buttons.Set_Label (Each.Mic_Button, "Mic");
         Buttons.Set_Icon (Each.Mic_Button, Icon_Set.Microphone);
         Buttons.Set_Icon_Size (Each.Mic_Button, Mic_Icon_Size);
         Set_Layout (Each.Mic_Button, Width => Mic_Width, Height => Bar_Button_Height);
         --  The page: white, outlined, with a shadow it leaves room for.
         Panels.Set_Fill (Each.Sheet, Paper);
         Panels.Set_Border (Each.Sheet, Themes.Border);
         Panels.Set_Shadow (Each.Sheet, Themes.Shadow);
         Set_Layout
           (Each.Sheet, Flow => Column, Shrink => 0.0, Shadowed => True,
            Padding => (others => Page_Border));
         Editors.Set_Shared
           (Each.Text, Item.Host.Doc_Resources'Unchecked_Access);
         Editors.Configure
           (Each.Text, Pomarine.Line_Texts.Serif, Page_Text_Size, 2000.0,
            Spacing => 0.35 * Page_Text_Size);
         Editors.Set_Paper (Each.Text, Paper);
         Editors.Set_Toolbar (Each.Text);
         Editors.Set_Assist (Each.Text, "Find Sources");
         Word_Tools.Add (Each.Text);
         --  The page's margin is the text area's, so that its toolbar is the page's width.
         Editors.Set_Indent
           (Each.Text, (Write_Width - Write_Text_Width) / 2.0 - Page_Text_Inset - Page_Border);
         Pomarine.Text_Areas.Set_Grows (Editors.Area (Each.Text).all);
         Set_Layout (Each.Text, Shrink => 0.0, Height => Page_Min_Height);
         Labels.Set_Trailing (Each.Words, True);
         Labels.Set_Ink (Each.Words, Quiet_Ink);
         Set_Layout
           (Each.Words, Height => Page_Foot, Margin => (Right => Shadow_Room, others => <>));
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
         Widgets.Add (View.Pages_Content, Head.Row);
         Widgets.Add (Head.Row, Head.Bar, Head.Title, Head.Count, Head.Notes);
         Widgets.Add (Head.Row, Head.Add);
         Widgets.Add (View.Pages_Content, Notes.Box);
         Widgets.Add (Notes.Box, Notes.Text);
         Widgets.Add (View.Pages_Content, Empty.Box);
         Widgets.Add (Empty.Box, Empty.Note, Empty.Add);

         Set_Layout
           (Head.Row, Place => Absolute, Flow => Row, Align => Center, Gap => Tool_Gap,
            Height => Section_Head_Height, Width => Write_Width);
         Set_Layout (Head.Bar, Width => Section_Bar, Height => Section_Head_Height - 12.0, Shrink => 0.0);
         Panels.Set_Fill (Head.Bar, Themes.Border);
         Labels.Set_Style (Head.Title, Pomarine.Line_Texts.Heading);
         Set_Layout (Head.Title, Grow => 1.0, Width => 0.0, Height => Section_Head_Height);
         Labels.Set_Ink (Head.Count, Quiet_Ink);
         Labels.Set_Trailing (Head.Count, True);
         Set_Layout (Head.Count, Width => 140.0, Height => Section_Head_Height);
         Buttons.Set_Label (Head.Notes, "Notes");
         Buttons.Set_Captioned (Head.Notes, True);
         Buttons.Set_Focusable (Head.Notes, True);
         Set_Layout (Head.Notes, Width => Notes_Width, Height => Outline_Button, Shrink => 0.0);
         Buttons.Set_Label (Head.Add, "Add document to this section");
         Buttons.Set_Icon (Head.Add, Icon_Set.Plus);
         Buttons.Set_Focusable (Head.Add, True);
         Set_Layout
           (Head.Add, Width => Outline_Button, Height => Outline_Button, Shrink => 0.0,
            Margin => (Right => Shadow_Room, others => <>));
         Widgets.Set_Visible (Head.Row, False);

         Panels.Set_Fill (Notes.Box, Side_Fill);
         Panels.Set_Border (Notes.Box, Themes.Border);
         Set_Layout
           (Notes.Box, Place => Absolute, Flow => Column, Width => Write_Width, Outlined => True,
            Padding => (others => Notes_Pad), Shrink => 0.0);
         Editors.Set_Shared (Notes.Text, Item.Host.Doc_Resources'Unchecked_Access);
         Editors.Configure (Notes.Text, Pomarine.Line_Texts.Interface_Font, Edit_Size, 2000.0);
         Pomarine.Text_Areas.Set_Grows (Editors.Area (Notes.Text).all);
         Editors.Set_Paper (Notes.Text, Side_Fill);
         Editors.Set_Borderless (Notes.Text, True);
         Editors.Attach (Notes.Text, Item.Outline_View.Blocks (Index).Notes_Doc'Unchecked_Access);
         Set_Layout (Notes.Text, Shrink => 0.0, Height => Notes_Min_Height);
         Widgets.Set_Visible (Notes.Box, False);

         Panels.Set_Border (Empty.Box, Themes.Border);
         Set_Layout
           (Empty.Box, Place => Absolute, Flow => Column, Align => Center, Spread => Center,
            Gap => Tool_Gap, Height => Section_Empty_Height, Width => Write_Width, Outlined => True);
         Labels.Set_Text (Empty.Note, "No documents in this section yet");
         Labels.Set_Ink (Empty.Note, Quiet_Ink);
         Set_Layout (Empty.Note, Height => Heading_Height);
         Buttons.Set_Label (Empty.Add, "Add document");
         Buttons.Set_Icon (Empty.Add, Icon_Set.Plus);
         Buttons.Set_Captioned (Empty.Add, True);
         Buttons.Set_Focusable (Empty.Add, True);
         Set_Layout (Empty.Add, Width => Wide_Tool_Width, Height => Bar_Button_Height);
         Widgets.Set_Visible (Empty.Box, False);
      end;
   end Make_Section;

   procedure Make_Gap (Item : in out Session; Index : Natural) is
      Sections : Section_View_Parts renames Item.Section_View;
      Each     : Gap_Mark renames Sections.Gaps (Index + 1);
   begin
      Widgets.Add (Item.Page_View.Pages_Content, Each.Row);
      Widgets.Add (Each.Row, Each.Caption, Each.Rule);
      Set_Layout
        (Each.Row, Place => Absolute, Flow => Row, Align => Center, Gap => Tool_Gap,
         Height => Gap_Mark_Height, Width => Write_Width);
      Labels.Set_Text (Each.Caption, "Not in a section");
      Labels.Set_Style (Each.Caption, Pomarine.Line_Texts.Caption);
      Labels.Set_Ink (Each.Caption, Quiet_Ink);
      Set_Layout (Each.Caption, Width => 120.0, Height => Gap_Mark_Height, Shrink => 0.0);
      Panels.Set_Fill (Each.Rule, Themes.Border);
      Set_Layout (Each.Rule, Grow => 1.0, Width => 0.0, Height => Hairline);
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
         Widgets.Add (View.Sidebar, Scroll);
         Widgets.Add (Scroll, Content);
         Labels.Set_Text (None, Empty);
         Labels.Set_Ink (None, Closed_Ink);
         --  As tall as its rows, if there is room; the second list
         --  follows the first.
         Set_Layout (Scroll, Shrink => 1.0);
         --  The scroll bar, which is shown only while the pointer is
         --  over the list, is over the rows' right edge.
         Set_Layout (Content, Flow => Column, Shrink => 0.0);
         Set_Layout
           (Content, Gap => Index_Gap * Pixels - Offset, Unit => Device_Pixels);
      end Build_Index;

      --  The head of a section, which folds it.
      procedure Heading (Head : in out Fold_Head; Name : String) is
      begin
         Widgets.Add (Head.Bar, Head.Mark, Head.Name);
         Labels.Set_Text (Head.Mark, " ");
         Set_Layout (Head.Mark, Width => 18.0, Height => Heading_Height, Shrink => 0.0);
         Labels.Set_Text (Head.Name, Name);
         Labels.Set_Style (Head.Name, Pomarine.Line_Texts.Caption);
         Set_Layout (Head.Name, Grow => 1.0, Width => 0.0, Height => Heading_Height);
         Grips.Set_Fill (Head.Bar, Side_Fill);
         Grips.Set_Hover_Fill (Head.Bar, Row_Hover);
         Grips.Set_Wanted_Cursor (Head.Bar, SDL3.Cursors.Pointer);
         Widgets.Set_Accessible_Name (Head.Bar, "Fold or unfold " & Name);
         Set_Layout (Head.Bar, Flow => Row, Align => Center, Height => Heading_Height, Shrink => 0.0);
      end Heading;

      --  Put the widgets in each other.
      procedure Assemble is
      begin
         Widgets.Add (Item.Toolbar.Content_Panel, View.Write_View);
         Widgets.Add (View.Write_View, View.Sidebar);
         Widgets.Add (View.Sidebar, View.Edit_Heading.Bar);
         Widgets.Add (View.Sidebar, View.Grammar_Row);
         Widgets.Add (View.Grammar_Row, View.Grammar_Switch, View.Grammar_Count);
         Set_Layout (View.Grammar_Row, Flow => Row, Align => Center, Height => 34.0, Shrink => 0.0, Gap => 4.0);
         Switches.Set_Label (View.Grammar_Switch, "Show Grammar Suggestions");
         Switches.Set_On (View.Grammar_Switch, True);
         Switches.Set_Focusable (View.Grammar_Switch, True);
         Set_Layout (View.Grammar_Switch, Height => 34.0, Grow => 1.0, Width => 0.0);
         Buttons.Set_Label (View.Grammar_Count, "0");
         Buttons.Set_Focusable (View.Grammar_Count, True);
         Widgets.Set_Accessible_Name (View.Grammar_Count, "Fixable grammar suggestions: 0");
         Set_Layout (View.Grammar_Count, Width => 36.0, Height => 28.0, Shrink => 0.0);
         Widgets.Add (View.Sidebar, View.Docs_Head);
         Widgets.Add (View.Docs_Head, View.Docs_Heading.Bar, View.Docs_Folder, View.Docs_Add);
         Build_Index (View.Docs_Scroll, View.Docs_Content, View.Docs_None, No_Documents);
         Widgets.Add (View.Docs_Content, View.Docs_None);
         Set_Layout (View.Docs_None, Height => Index_Height);
         Widgets.Add (View.Docs_Content, Item.Docs.Drop_Line);
         Widgets.Add (View.Docs_Content, Item.Docs.Ghost);
         Widgets.Add (Item.Docs.Ghost, Item.Docs.Ghost_Title);
         Widgets.Add (View.Docs_Content, Item.Naming.Dir_Field);
         Widgets.Add (View.Sidebar, View.Sources_Edge);
         Widgets.Add (View.Sources_Edge, View.Sources_Grab);
         Widgets.Add (View.Sidebar, View.Sources_Heading.Bar);
         Build_Index (View.Sources_Scroll, View.Sources_Content, View.Sources_None, No_Sources);
         Widgets.Add (View.Sources_Content, View.Sources_None);
         Widgets.Add (View.Sources_Content, Item.Naming.Source_Field);
         Set_Layout (View.Sources_None, Height => Index_Height);
         Widgets.Add (View.Write_View, View.Sidebar_Edge, View.Sidebar_Rule, View.Pages_Scroll);
         Widgets.Add (View.Pages_Scroll, View.Pages_Content);
         --  The spacer of the sections is first, so that the pages (and what
         --  is between them) are over it, and take the pointer.
         Widgets.Add (View.Pages_Content, Item.Section_View.Tail);
         Widgets.Add (View.Write_View, View.Pane);
         Widgets.Add (View.Pane, View.Pane_Edge, View.Pane_Body);
         --  Over the rest, last.
         Widgets.Add (View.Write_View, View.Menu);
         Set_Layout (View.Menu, Place => Absolute, Width => Menu_Width);
         Widgets.Set_Visible (View.Menu, False);
      end Assemble;

      --  The headings, notes and gaps of the sections among the pages.
      procedure Style_Sections is
      begin
         declare
            Sections : Section_View_Parts renames Item.Section_View;
         begin
            Set_Layout (Sections.Tail, Place => Flowing, Height => 0.0, Shrink => 0.0);
            Widgets.Set_Visible (Sections.Tail, False);
         end;
      end Style_Sections;

      --  The menus over the content, and the listeners of the other parts.
      procedure Hook_Up is
      begin
         Widgets.Add (Item.Toolbar.Content_Panel, Item.Context.Context_Menu);
         Set_Layout (Item.Context.Context_Menu, Place => Absolute, Width => Context_Width);
         Widgets.Set_Visible (Item.Context.Context_Menu, False);
         Widgets.Add (Item.Toolbar.Content_Panel, Item.Outline_View.Generate_Menu);
         Set_Layout (Item.Outline_View.Generate_Menu, Place => Absolute, Width => Generate_Menu_Width);
         Pomarine.Widgets.Menus.Set_Accented (Item.Outline_View.Generate_Menu, True);
         Widgets.Set_Visible (Item.Outline_View.Generate_Menu, False);
         Widgets.Add (Item.Toolbar.Content_Panel, Item.Section_Menu.Menu);
         Set_Layout (Item.Section_Menu.Menu, Place => Absolute, Width => 220.0);
         Widgets.Set_Visible (Item.Section_Menu.Menu, False);
         Section_Links.Listen (Item);
         Items.Readers.Build
           (Item.Reading.Pane_Reader, View.Pane_Body, Toolbar, Pixels,
            Pinned => True);
         Writing.Listen (Item);
         Grammar.Build (Item);
      end Hook_Up;

      --  The sidebar: its lists, its edges and the fields over its rows.
      procedure Style_Sidebar is
      begin
         if not Item.Shell.Windowed then
            Panels.Set_Fill (View.Write_View, Desk);
         end if;
         Set_Layout (View.Write_View, Flow => Row, Grow => 1.0, Height => 0.0);

         --  The sidebar: two lists one above the other, with a line at its
         --  right.
         Panels.Set_Fill (View.Sidebar, Side_Fill);
         Set_Layout
           (View.Sidebar, Width => View.Sidebar_Wide, Shrink => 0.0, Flow => Column, Gap => Sidebar_Gap,
            Padding => (Top => Sidebar_Pad + Heading_Top, others => Sidebar_Pad));
         Grips.Set_Fill (View.Sidebar_Edge, Side_Fill);
         Grips.Set_Hover_Fill (View.Sidebar_Edge, Edge_Fill);
         Grips.Set_Wanted_Cursor (View.Sidebar_Edge, SDL3.Cursors.Resize_Across);
         Set_Layout (View.Sidebar_Edge, Width => Sidebar_Edge_Width, Shrink => 0.0);
         Grips.Set_Fill (View.Sources_Edge, Side_Fill);
         Grips.Set_Hover_Fill (View.Sources_Edge, Edge_Fill);
         Grips.Set_Wanted_Cursor (View.Sources_Edge, SDL3.Cursors.Resize_Up_Down);
         Widgets.Set_Accessible_Name (View.Sources_Edge, "Drag to resize Sources");
         Set_Layout (View.Sources_Edge, Height => 16.0, Shrink => 0.0, Align => Center, Spread => Center);
         Panels.Set_Fill (View.Sources_Grab, Quiet_Ink);
         Set_Layout (View.Sources_Grab, Width => 32.0, Height => 3.0, Shrink => 0.0);
         Panels.Set_Fill (View.Sidebar_Rule, Themes.Border);
         Set_Layout (View.Sidebar_Rule, Width => Hairline, Shrink => 0.0);
         Set_Layout
           (View.Docs_Head, Flow => Row, Align => Center, Gap => Index_Gap,
            Padding => (Right => Shadow_Room, others => <>),
            Margin => (Top => Heading_Top, others => <>));
         Heading (View.Edit_Heading, "EDIT");
         Heading (View.Docs_Heading, "DOCUMENTS");
         Set_Layout (View.Docs_Heading.Bar, Grow => 1.0, Width => 0.0);
         Heading (View.Sources_Heading, "SOURCES");
         Set_Layout (View.Sources_Heading.Bar, Margin => (Top => Heading_Top, others => <>));
         Buttons.Set_Label (View.Docs_Add, "+");
         Buttons.Set_Icon (View.Docs_Add, Icon_Set.Plus);
         Buttons.Set_Icon_Size (View.Docs_Add, Mic_Icon_Size);
         Set_Layout (View.Docs_Add, Width => Add_Size, Height => Add_Size);
         Buttons.Set_Label (View.Docs_Folder, "New folder");
         Buttons.Set_Icon (View.Docs_Folder, Icon_Set.Folder);
         Buttons.Set_Icon_Size (View.Docs_Folder, Mic_Icon_Size);
         Set_Layout (View.Docs_Folder, Width => Add_Size, Height => Add_Size);

         --  Over the rows of the tree, out of their layout: the line where a
         --  document dragged would go between two, and the field to rename
         --  a directory by.
         declare
            Fill : Themes.Color := Themes.Resolve (Colors, Row_Fill);
         begin
            --  The ghost of the row dragged: its name, in a box of the same
            --  outline, a little clear.
            Fill.Alpha := 225;
            Panels.Set_Fill_Color (Item.Docs.Ghost, Fill);
         end;
         Panels.Set_Border (Item.Docs.Ghost, Themes.Focus);
         Set_Layout
           (Item.Docs.Ghost, Place => Absolute, Flow => Row, Align => Center,
            Padding => (Left | Right => Index_Pad, others => <>));
         Set_Layout (Item.Docs.Ghost_Title, Grow => 1.0, Width => 0.0, Height => Index_Height);
         Widgets.Set_Visible (Item.Docs.Ghost, False);
         Panels.Set_Fill (Item.Docs.Drop_Line, Pomarine.Themes.Accent);
         Set_Layout (Item.Docs.Drop_Line, Place => Absolute, Height => Drop_Line_Height);
         Widgets.Set_Visible (Item.Docs.Drop_Line, False);
         Text_Fields.Set_Shared
           (Item.Naming.Dir_Field, Item.Host.Doc_Resources'Unchecked_Access);
         Text_Fields.Configure
           (Item.Naming.Dir_Field, Pomarine.Line_Texts.Interface_Font, Edit_Size);
         Set_Layout (Item.Naming.Dir_Field, Place => Absolute, Height => Index_Height);
         Widgets.Set_Visible (Item.Naming.Dir_Field, False);
         Text_Fields.Set_Shared
           (Item.Naming.Source_Field, Item.Host.Doc_Resources'Unchecked_Access);
         Text_Fields.Configure
           (Item.Naming.Source_Field, Pomarine.Line_Texts.Interface_Font, Edit_Size);
         Set_Layout (Item.Naming.Source_Field, Place => Absolute, Height => Index_Height);
         Widgets.Set_Visible (Item.Naming.Source_Field, False);
      end Style_Sidebar;

      --  The pages, scrolled, one above the next.
      procedure Style_Pages is
      begin
         --  The pages, scrolled, one above the next, and the button to add
         --  one after them.
         Set_Layout (View.Pages_Scroll, Grow => 1.0, Width => 0.0);
         Set_Layout
           (View.Pages_Content, Flow => Column, Shrink => 0.0, Align => Start, Gap => Page_Gap,
            Padding => (Top => Page_Margin - Page_Gap, others => Page_Margin));
      end Style_Pages;

      --  The pane of the pinned source.
      procedure Style_Pane is
      begin
         --  The pane: an edge to size it by, and the pinned source.
         if not Item.Shell.Windowed then
            Panels.Set_Fill (View.Pane, Desk);
         end if;
         View.Pane_Wide := Pane_Default;
         Set_Layout (View.Pane, Flow => Row, Shrink => 0.0, Width => Pane_Default);
         Grips.Set_Fill (View.Pane_Edge, Edge_Fill);
         Grips.Set_Wanted_Cursor (View.Pane_Edge, SDL3.Cursors.Resize_Across);
         Set_Layout (View.Pane_Edge, Width => Pane_Edge_Width, Shrink => 0.0);
         Set_Layout (View.Pane_Body, Flow => Column, Grow => 1.0, Width => 0.0);
         Widgets.Set_Visible (View.Pane, False);
      end Style_Pane;

   begin
      Assemble;
      Style_Sections;
      Hook_Up;
      Style_Sidebar;
      Style_Pages;
      Style_Pane;
      Writing.Fit_Sidebar (Item);
   end Build_Write;

end Viewer.Build.Write_View;
