with Pomarine.Widgets.Panels;
with Writing_Sources_UI;
with Writing_Sources_VM;
with Writing_Actions_UI;
with Writing_VM.Actions;
with Sidebar_UI;
with Sidebar_VM;
with Nav_UI;
with Nav_VM;
with View.Menu_Commands;
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
with Pomarine.UI;
with Pomarine.Widgets.Scrollers;
with Pomarine.Text_Areas;
with View.Style;
with View.Writing;
with View.Grammar;
with Pomarine.Icons;

package body View.Build.Write_View is

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

   package UI renames Pomarine.UI;

   use Style;
   use Pomarine.Widgets.Layouts;

   function Form_Of (Item : Session) return access UI.View is (Item.Forms (Writing_Region).Screen);
   --  The view of this region's controls: everything here is put in a screen with the widgets the
   --  application keeps, borrowed, placed, and styled.

   function Line
     (Item : Session; Widget : in out Widgets.Widget'Class; Box : Layouts.Style) return UI.Layout is
     (UI.Styled (UI.Put (Form_Of (Item).all, Widget), Box));

   function Press
     (Item : Session; Part : in out Buttons.Button; Look : Buttons.Settings; Box : Layouts.Style)
      return UI.Layout is
   begin
      Buttons.Configure (Part, Look);
      return Line (Item, Part, Box);
   end Press;

   function Preceded (First : UI.Layout; Rest : UI.Layout_Array) return UI.Layout_Array is
      Result : UI.Layout_Array (1 .. Rest'Length + 1);
   begin
      Result (1) := First;
      for Number in Rest'Range loop
         Result (Number - Rest'First + 2) := Rest (Number);
      end loop;
      return Result;
   end Preceded;
   --  The layouts, with First put before them.

   function Holding
     (Item  : Session;
      Part  : in out Widgets.Widget'Class;
      Inside : UI.Layout_Array;
      Box   : Layouts.Style) return UI.Layout is
     (UI.Styled (UI.Put_In (Form_Of (Item).all, Part, Inside), Box));

   procedure Build_Row
     (Item    : Session;
      Content : in out Panels.Panel;
      Before  : in out Widgets.Widget'Class;
      Each    : in out Index_Row;
      Counted : Boolean;
      Source_Row : Natural := 0;
      Of_Tree    : Natural := 0)
   is
      pragma Unreferenced (Content);
      Pixels : constant Float := Item.Shell.Density;
      Bound : constant Writing_Sources_UI.Context'Class :=
        Writing_Sources_UI.Bind (Form_Of (Item).all, Item.Reading.Sources'Unrestricted_Access);
      Actions : constant Writing_Actions_UI.Context'Class :=
        Writing_Actions_UI.Bind (Form_Of (Item).all, Item.Page_View.Actions'Unrestricted_Access);
      Row_Control : constant UI.Widget_Handle :=
        (if Of_Tree /= 0 then Actions.Borrow_Widget (Each.Row) else Bound.Borrow_Widget (Each.Row));
      Whole  : constant UI.Layout :=
        UI.Styled (UI.Hold
          (Row_Control,
           [Line (Item, Each.Tag,
                  (Width => Tag_Size, Height => Tag_Size, Shrink => 0.0,
                   Margin => (Right => Layouts.Length_Of (Index_Pad), others => <>),
                   others => <>)),
            Line (Item, Each.Folder_Mark,
                  (Width => 18.0, Height => 18.0, Shrink => 0.0,
                   Margin => (Right => Layouts.Length_Of (Index_Pad), others => <>),
                   others => <>)),
            Line (Item, Each.Caption,
                  (Grow => 1.0, Width => 0.0, Height => Layouts.Length_Of (Index_Height), others => <>)),
            Line (Item, Each.Count,
                  (Width => Count_Width, Height => Layouts.Length_Of (Index_Height),
                   others => <>))]),
           (Shrink => 0.0, Flow => Row, Align => Center,
            Padding => (Left | Right => Layouts.Length_Of (Index_Pad * Pixels), others => <>),
            Shadowed => On, Height => Layouts.Length_Of (Index_Height * Pixels + Pomarine.Boxes.Offset (Pixels)),
              Unit => Device_Pixels,
            others => <>));
   begin
      if Source_Row /= 0 then
         Bound.On_Event (Row_Control, Widgets.Click, Writing_Sources_VM.Toggle_Source, Source_Row);
      end if;
      if Of_Tree /= 0 then
         Actions.On_Event (Row_Control, Widgets.Click, Writing_VM.Actions.Select_Row, Of_Tree);
         Actions.On_Event (Row_Control, Widgets.Double_Click, Writing_VM.Actions.Rename_Row, Of_Tree);
      end if;
      UI.Mount_Before (Form_Of (Item).all, Before, Whole);
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
      Build_Row (Item, Item.Page_View.Docs_Content, Item.Page_View.Docs_None, Each, Counted => True, Of_Tree => Index);
      Panels.Set_Fill (Each.Tag, Quiet_Ink);
   end Make_Tree_Row;

   procedure Make_Source_Row (Item : in out Session; Which : Items.Slot) is
   begin
      Build_Row
        (Item, Item.Page_View.Sources_Content, Item.Page_View.Sources_None,
         Item.Reading.Source_Rows (Which), Counted => False, Source_Row => Which);
   end Make_Source_Row;

   procedure Make_Page (Item : in out Session; Rank : Items.Slot) is
      Each : Doc_Page renames Item.Docs.Pages (Rank);
      Bound : constant Writing_Actions_UI.Context'Class :=
        Writing_Actions_UI.Bind (Form_Of (Item).all, Item.Page_View.Actions'Unrestricted_Access);
      function Command_Button
        (Part : in out Buttons.Button; Look : Buttons.Settings; What : Writing_VM.Actions.Command;
         Box : Layouts.Style) return UI.Layout is
      begin
         Buttons.Configure (Part, Look);
         return UI.Styled (Bound.Borrow_Button (Part, What, Rank), Box);
      end Command_Button;
   begin
      declare
         Heading_Control : constant UI.Widget_Handle := Bound.Borrow_Widget (Each.Heading_Area);
         Title_Control : constant UI.Widget_Handle := Bound.Borrow_Widget (Each.Title_Field);
         Bar : constant UI.Layout :=
           Holding
             (Item, Each.Bar,
              [UI.Styled
                 (UI.Hold
                    (Heading_Control,
                     [Line (Item, Each.Swatch,
                            (Width => Section_Swatch, Height => Section_Swatch,
                             Shrink => 0.0,
                             Margin => (Right => Layouts.Length_Of (Tool_Gap), others => <>), others => <>)),
                      Line (Item, Each.Heading,
                            (Grow => 1.0, Width => 0.0, Height => Page_Head, others => <>))]),
                  (Flow => Row, Align => Center, Grow => 1.0, Width => 0.0, Height => Page_Head,
                   others => <>)),
               UI.Place (Title_Control, Grow => 1.0, Width => 0.0, Height => Title_Height, Exact => True),
               Command_Button (Each.Outline_Button,
                      Buttons.Looks ("Section", Captioned => True, Shape => Buttons.Dropdown),
                      Writing_VM.Actions.Open_Section_Menu,
                      (Width => Outline_Link_Width,
                       Height => Layouts.Length_Of (Bar_Button_Height), others => <>)),
               Command_Button (Each.Sources_Button, Buttons.Looks ("Sources", Shape => Buttons.Dropdown),
                      Writing_VM.Actions.Open_Sources,
                      (Width => Sources_Width, Height => Layouts.Length_Of (Bar_Button_Height),
                       others => <>)),
               Command_Button (Each.Mic_Button,
                      Buttons.Looks ("Mic", Icon => Pomarine.Icons.Shown (Icon_Set.Microphone),
                                     Icon_Points => Mic_Icon_Size), Writing_VM.Actions.Toggle_Dictation,
                      (Width => Mic_Width, Height => Layouts.Length_Of (Bar_Button_Height),
                       others => <>)),
               Line (Item, Each.Level,
                     (Place => Absolute, Position => (Left | Bottom => 0.0, Right => Shadow_Room, others => <>),
                      Height => Level_Height, others => <>))],
              (Flow => Row, Align => Center, Height => Page_Head,
               Gap => Layouts.Length_Of (Tool_Gap),
               Padding => (Right => Shadow_Room, others => <>), others => <>));
         Page_Text : constant UI.Widget_Handle := Bound.Borrow_Widget (Each.Text);
         Sheet : constant UI.Layout :=
           Holding
             (Item, Each.Sheet,
              [UI.Place (Page_Text, Shrink => 0.0, Height => Layouts.Length_Of (Page_Min_Height), Exact => True)],
              (Flow => Column, Shrink => 0.0, Shadowed => On, Padding => (others => Layouts.Length_Of (Page_Border)),
               others => <>));
         Whole : constant UI.Layout :=
           Holding
             (Item, Each.Box,
              [Bar, Sheet,
               Line (Item, Each.Words,
                     (Height => Page_Foot, Margin => (Right => Shadow_Room, others => <>),
                                        others => <>))],
              (Flow => Column, Shrink => 0.0, Width => Layouts.Length_Of (Write_Width), others => <>));
      begin
         pragma Assert (Writing_VM.Actions.Tools_Per_Page = Editors.Tool_Capacity);
         Bound.On_Event (Heading_Control, Widgets.Double_Click, Writing_VM.Actions.Begin_Page_Title, Rank);
         Bound.On_Event (Title_Control, Widgets.Submit, Writing_VM.Actions.End_Page_Title, Rank);
         Bound.On_Event (Title_Control, Widgets.Blur, Writing_VM.Actions.End_Page_Title, Rank);
         Bound.On_Editor_Event (Page_Text, Writing_Actions_UI.Tool_Used, Writing_VM.Actions.Use_Tool, Rank, True);
         Bound.On_Editor_Event (Page_Text, Writing_Actions_UI.Link_Followed, Writing_VM.Actions.Follow_Link, Rank);
         Bound.On_Editor_Event (Page_Text, Writing_Actions_UI.Link_Asked, Writing_VM.Actions.Ask_Link, Rank);
         UI.Mount_Into (Form_Of (Item).all, Item.Page_View.Pages_Content, Whole);
      end;
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
      Pane     : Page_Parts renames Item.Page_View;
      Bound : constant Nav_UI.Context'Class :=
        Nav_UI.Bind (Form_Of (Item).all, Item.Nav_Model.Model'Unrestricted_Access);

      function Section_Button
        (Part : in out Buttons.Button; Look : Buttons.Settings; Box : Layouts.Style;
         What : Nav_VM.Command) return UI.Layout is
      begin
         Buttons.Configure (Part, Look);
         return UI.Styled (Bound.Borrow_Button (Part, What, Index), Box);
      end Section_Button;
   begin
      declare
         Head  : Section_Head renames Sections.Heads (Index);
         Notes : Note_Box renames Sections.Notes (Index);
         Empty : Section_Empty renames Sections.Empties (Index);
      begin
         declare
            Head_Layout : constant UI.Layout :=
              Holding
                (Item, Head.Row,
                 [Line (Item, Head.Bar,
                        (Width => Section_Bar,
                         Height => Layouts.Length_Of (Section_Head_Height - 12.0), Shrink => 0.0,
                                         others => <>)),
                  Line (Item, Head.Title,
                        (Grow => 1.0, Width => 0.0, Height => Layouts.Length_Of (Section_Head_Height), others => <>)),
                  Line (Item, Head.Count,
                        (Width => 140.0, Height => Layouts.Length_Of (Section_Head_Height), others => <>)),
                  Section_Button (Head.Notes, Buttons.Looks ("Notes", Captioned => True, Focusable => True),
                                  (Width => Notes_Width,
                                   Height => Outline_Button, Shrink => 0.0, others => <>),
                                  Nav_VM.Toggle_Section_Notes),
                  Section_Button (Head.Add,
                         Buttons.Looks ("Add document to this section", Icon => Pomarine.Icons.Shown (Icon_Set.Plus),
                                        Focusable => True),
                         (Width => Outline_Button, Height => Outline_Button,
                          Shrink => 0.0,
                          Margin => (Right => Shadow_Room, others => <>), others => <>), Nav_VM.Add_Document)],
                 (Place => Absolute, Flow => Row, Align => Center, Gap => Layouts.Length_Of (Tool_Gap),
                  Height => Layouts.Length_Of (Section_Head_Height),
                  Width => Layouts.Length_Of (Write_Width), others => <>));
            Notes_Layout : constant UI.Layout :=
              Holding
                (Item, Notes.Box, [Line (Item, Notes.Text,
                                         (Shrink => 0.0, Height => Layouts.Length_Of (Notes_Min_Height),
                                          others => <>))],
                 (Place => Absolute, Flow => Column, Width => Layouts.Length_Of (Write_Width), Outlined => On,
                  Padding => (others => Layouts.Length_Of (Notes_Pad)), Shrink => 0.0, others => <>));
            Empty_Layout : constant UI.Layout :=
              Holding
                (Item, Empty.Box,
                 [Line (Item, Empty.Note, (Height => Layouts.Length_Of (Heading_Height), others => <>)),
                  Section_Button (Empty.Add,
                         Buttons.Looks ("Add document", Icon => Pomarine.Icons.Shown (Icon_Set.Plus),
                                        Captioned => True, Focusable => True),
                         (Width => Layouts.Length_Of (Wide_Tool_Width),
                          Height => Layouts.Length_Of (Bar_Button_Height), others => <>), Nav_VM.Add_Document)],
                 (Place => Absolute, Flow => Column, Align => Center, Spread => Center,
                  Gap => Layouts.Length_Of (Tool_Gap),
                  Height => Layouts.Length_Of (Section_Empty_Height), Width => Layouts.Length_Of (Write_Width),
                    Outlined => On, others => <>));
         begin
            UI.Mount_Into (Form_Of (Item).all, Pane.Pages_Content, Head_Layout);
            UI.Mount_Into (Form_Of (Item).all, Pane.Pages_Content, Notes_Layout);
            UI.Mount_Into (Form_Of (Item).all, Pane.Pages_Content, Empty_Layout);
         end;

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
      UI.Mount_Into
        (Form_Of (Item).all, Item.Page_View.Pages_Content,
         Holding
           (Item, Each.Row,
            [Line (Item, Each.Caption,
                   (Width => 120.0, Height => Layouts.Length_Of (Gap_Mark_Height), Shrink => 0.0, others => <>)),
             Line (Item, Each.Rule, (Grow => 1.0, Width => 0.0, Height => Hairline, others => <>))],
            (Place => Absolute, Flow => Row, Align => Center, Gap => Layouts.Length_Of (Tool_Gap),
             Height => Layouts.Length_Of (Gap_Mark_Height),
             Width => Layouts.Length_Of (Write_Width), others => <>)));
      Labels.Set_Text (Each.Caption, "Not in a section");
      Labels.Set_Style (Each.Caption, Pomarine.Line_Texts.Caption);
      Labels.Set_Ink (Each.Caption, Quiet_Ink);
      Panels.Set_Fill (Each.Rule, Themes.Border);
      Widgets.Set_Visible (Each.Row, False);
   end Make_Gap;

   procedure Build_Write (Item : in out Session) is
      Pane   : Page_Parts renames Item.Page_View;
      Pixels : constant Float := Item.Shell.Density;
      Offset : constant Float := Pomarine.Boxes.Offset (Pixels);

      function Command_Button
        (Part : in out Buttons.Button; Look : Buttons.Settings; Box : Layouts.Style;
         What : Nav_VM.Command) return UI.Layout
      is
         Bound : constant Nav_UI.Context'Class :=
           Nav_UI.Bind (Form_Of (Item).all, Item.Nav_Model.Model'Unrestricted_Access);
      begin
         Buttons.Configure (Part, Look);
         return UI.Styled (Bound.Borrow_Button (Part, What), Box);
      end Command_Button;

      --  A list of rows, as tall as its rows, if there is room; the second list follows the first. The scroll
      --  bar, which is shown only while the pointer is over the list, is over the rows' right edge.
      function Index
        (Scroll  : in out Scrollers.Scroller;
         Content : in out Panels.Panel;
         None    : in out Labels.Label;
         Empty   : String;
         Over    : UI.Layout_Array) return UI.Layout is
      begin
         Labels.Set_Text (None, Empty);
         Labels.Set_Ink (None, Closed_Ink);
         return Holding
           (Item, Scroll,
            [Holding
               (Item, Content, Preceded (Line (Item, None, (Height => Layouts.Length_Of (Index_Height), others => <>)),
                                         Over),
                (Flow => Column, Shrink => 0.0, Gap => Layouts.Length_Of (Index_Gap * Pixels - Offset),
                 Unit => Device_Pixels,
                 others => <>))],
            (Shrink => 1.0, others => <>));
      end Index;

      --  The head of a section, which folds it.
      function Fold
        (Head   : in out Fold_Head;
         Name   : String;
         What   : Sidebar_VM.Command;
         Grow   : Layouts.Weight := Layouts.Unchanged;
         Width  : Layouts.Length := Unset;
         Margin : Layouts.Sides := (others => <>)) return UI.Layout
      is
         Bound : constant Sidebar_UI.Context'Class :=
           Sidebar_UI.Bind (Form_Of (Item).all, Pane.Folding'Unrestricted_Access);
      begin
         Labels.Set_Text (Head.Mark, " ");
         Labels.Set_Text (Head.Name, Name);
         Labels.Set_Style (Head.Name, Pomarine.Line_Texts.Caption);
         Grips.Set_Fill (Head.Bar, Side_Fill);
         Grips.Set_Hover_Fill (Head.Bar, Row_Hover);
         Grips.Set_Wanted_Cursor (Head.Bar, SDL3.Cursors.Pointer);
         Widgets.Set_Accessible_Name (Head.Bar, "Fold or unfold " & Name);
         return UI.Styled (Bound.Borrow_Holding
           (Head.Bar,
            [Line (Item, Head.Mark,
                   (Width => 18.0, Height => Layouts.Length_Of (Heading_Height), Shrink => 0.0, others => <>)),
             Line (Item, Head.Name,
                   (Grow => 1.0, Width => 0.0, Height => Layouts.Length_Of (Heading_Height), others => <>))],
            Click => What),
            (Flow => Row, Align => Center, Height => Layouts.Length_Of (Heading_Height), Shrink => 0.0, Grow => Grow,
             Width => Width,
             Margin => Margin, others => <>));
      end Fold;

      --  Put the widgets in each other, styled: the sidebar (its lists, its edges and the fields over its rows),
      --  the pages, scrolled, one above the next, and the pane of the pinned source.
      procedure Assemble is
         Ghost_Fill : Themes.Color := Themes.Resolve (Colors, Row_Fill);
      begin
         Switches.Set_Label (Pane.Grammar_Switch, "Show Grammar Suggestions");
         Switches.Set_On (Pane.Grammar_Switch, True);
         Switches.Set_Focusable (Pane.Grammar_Switch, True);
         Widgets.Set_Accessible_Name (Pane.Grammar_Count, "Fixable grammar suggestions: 0");
         Widgets.Set_Accessible_Name (Pane.Docs_Add, "Add document");
         Widgets.Set_Accessible_Name (Pane.Sources_Edge, "Drag to resize Sources");
         Grips.Set_Fill (Pane.Sources_Edge, Side_Fill);
         Grips.Set_Hover_Fill (Pane.Sources_Edge, Edge_Fill);
         Grips.Set_Wanted_Cursor (Pane.Sources_Edge, SDL3.Cursors.Resize_Up_Down);
         Grips.Set_Fill (Pane.Sidebar_Edge, Side_Fill);
         Grips.Set_Hover_Fill (Pane.Sidebar_Edge, Edge_Fill);
         Grips.Set_Wanted_Cursor (Pane.Sidebar_Edge, SDL3.Cursors.Resize_Across);
         Grips.Set_Fill (Pane.Pane_Edge, Edge_Fill);
         Grips.Set_Wanted_Cursor (Pane.Pane_Edge, SDL3.Cursors.Resize_Across);
         Pane.Pane_Wide := Pane_Default;
         Ghost_Fill.Alpha := 225;
         --  The ghost of the row dragged: its name, in a box of the same outline, a little clear.
         Panels.Set_Fill_Color (Item.Docs.Ghost, Ghost_Fill);
         Panels.Set_Border (Item.Docs.Ghost, Themes.Focus);
         Panels.Set_Fill (Item.Docs.Drop_Line, Pomarine.Themes.Accent);

         declare
            --  Over the rows of the tree, out of their layout: the line where a document dragged would go
            --  between two, the ghost of the row, and the field to rename a directory by.
            Actions : constant Writing_Actions_UI.Context'Class :=
              Writing_Actions_UI.Bind (Form_Of (Item).all, Pane.Actions'Unrestricted_Access);
            Dir_Control : constant UI.Widget_Handle := Actions.Borrow_Widget (Item.Naming.Dir_Field);
            Source_Control : constant UI.Widget_Handle := Actions.Borrow_Widget (Item.Naming.Source_Field);
            Docs_Over : constant UI.Layout_Array :=
              [Line (Item, Item.Docs.Drop_Line,
                     (Place => Absolute, Height => Layouts.Length_Of (Drop_Line_Height), others => <>)),
               Holding
                 (Item, Item.Docs.Ghost,
                  [Line (Item, Item.Docs.Ghost_Title,
                         (Grow => 1.0, Width => 0.0, Height => Layouts.Length_Of (Index_Height), others => <>))],
                  (Place => Absolute, Flow => Row, Align => Center,
                   Padding => (Left | Right => Layouts.Length_Of (Index_Pad), others => <>), others => <>)),
               UI.Styled (UI.Place (Dir_Control),
                          (Place => Absolute, Height => Layouts.Length_Of (Index_Height), others => <>))];
            Sources_Over : constant UI.Layout_Array :=
              [UI.Styled (UI.Place (Source_Control),
                          (Place => Absolute, Height => Layouts.Length_Of (Index_Height), others => <>))];

            --  The sidebar: two lists one above the other, with a line at its right.
            Sidebar : constant UI.Layout :=
              Holding
                (Item, Pane.Sidebar,
                 [Fold (Pane.Edit_Heading, "EDIT", Sidebar_VM.Toggle_Edit),
                  Holding
                    (Item, Pane.Grammar_Row,
                     [Line (Item, Pane.Grammar_Switch, (Height => 34.0, Grow => 1.0, Width => 0.0, others => <>)),
                      Press (Item, Pane.Grammar_Count, Buttons.Looks ("0", Focusable => True),
                             (Width => 36.0, Height => 28.0, Shrink => 0.0, others => <>))],
                     (Flow => Row, Align => Center, Height => 34.0, Shrink => 0.0, Gap => 4.0, others => <>)),
                  Holding
                    (Item, Pane.Docs_Head,
                     [Fold (Pane.Docs_Heading, "DOCUMENTS", Sidebar_VM.Toggle_Documents, Grow => 1.0, Width => 0.0),
                      Command_Button (Pane.Docs_Folder,
                             Buttons.Looks ("New folder", Icon => Pomarine.Icons.Shown (Icon_Set.Folder),
                                            Icon_Points => Mic_Icon_Size, Focusable => True),
                             (Width => Add_Size, Height => Add_Size,
                              others => <>), Nav_VM.Add_Folder),
                      Command_Button (Pane.Docs_Add,
                             Buttons.Looks ("+", Icon => Pomarine.Icons.Shown (Icon_Set.Plus),
                                            Icon_Points => Mic_Icon_Size, Focusable => True),
                             (Width => Add_Size, Height => Add_Size,
                              others => <>), Nav_VM.Add_Document)],
                     (Flow => Row, Align => Center, Gap => Layouts.Length_Of (Index_Gap),
                      Padding => (Right => Shadow_Room, others => <>),
                      Margin => (Top => Layouts.Length_Of (Heading_Top), others => <>), others => <>)),
                  Index (Pane.Docs_Scroll, Pane.Docs_Content, Pane.Docs_None, No_Documents, Docs_Over),
                  Holding
                    (Item, Pane.Sources_Edge,
                     [Line (Item, Pane.Sources_Grab, (Width => 32.0, Height => 3.0, Shrink => 0.0, others => <>))],
                     (Height => 16.0, Shrink => 0.0, Align => Center, Spread => Center, others => <>)),
                  Fold (Pane.Sources_Heading, "SOURCES", Sidebar_VM.Toggle_Sources,
                        Margin => (Top => Layouts.Length_Of (Heading_Top), others => <>)),
                  Index (Pane.Sources_Scroll, Pane.Sources_Content, Pane.Sources_None, No_Sources, Sources_Over)],
                 (Width => Layouts.Length_Of (Pane.Sidebar_Wide), Shrink => 0.0, Flow => Column,
                  Gap => Sidebar_Gap,
                  Padding => (Top => Layouts.Length_Of (Sidebar_Pad + Heading_Top),
                              others => Layouts.Length_Of (Sidebar_Pad)), others => <>));

            --  The pages, scrolled, one above the next. The spacer of the sections is first, so that the pages
            --  (and what is between them) are over it, and take the pointer.
            Pages : constant UI.Layout :=
              Holding
                (Item, Pane.Pages_Scroll,
                 [Holding
                    (Item, Pane.Pages_Content,
                     [Line (Item, Item.Section_View.Tail,
                            (Place => Flowing, Height => 0.0, Shrink => 0.0, others => <>))],
                     (Flow => Column, Shrink => 0.0, Align => Start, Gap => Layouts.Length_Of (Page_Gap),
                      Padding => (Top => Layouts.Length_Of (Page_Margin - Page_Gap),
                                  others => Layouts.Length_Of (Page_Margin)), others => <>))],
                 (Grow => 1.0, Width => 0.0, others => <>));

            --  The pane: an edge to size it by, and the pinned source.
            Pinned : constant UI.Layout :=
              Holding
                (Item, Pane.Pane,
                 [Line (Item, Pane.Pane_Edge,
                        (Width => Pane_Edge_Width, Shrink => 0.0, others => <>)),
                  Holding (Item, Pane.Pane_Body, [], (Flow => Column, Grow => 1.0, Width => 0.0, others => <>))],
                 (Flow => Row, Shrink => 0.0, Width => Layouts.Length_Of (Pane_Default), others => <>));

            Source_Menu : constant UI.Layout := Menu_Commands.Place
              (Item, Form_Of (Item).all, Pane.Menu, Menu_VM.Source_Menu,
               (Place => Absolute, Width => Layouts.Length_Of (Menu_Width), others => <>));
            Whole : constant UI.Layout :=
              Holding
                (Item, Pane.Write_View,
                 [Sidebar,
                  Line (Item, Pane.Sidebar_Edge,
                        (Width => Sidebar_Edge_Width, Shrink => 0.0, others => <>)),
                  Line (Item, Pane.Sidebar_Rule, (Width => Hairline, Shrink => 0.0, others => <>)),
                  Pages,
                  Pinned,
                  --  Over the rest, last.
                  Source_Menu],
                 (Flow => Row, Grow => 1.0, Height => 0.0, others => <>));
         begin
            Actions.On_Event (Dir_Control, Widgets.Submit, Writing_VM.Actions.End_Name_Edit);
            Actions.On_Event (Dir_Control, Widgets.Blur, Writing_VM.Actions.End_Name_Edit);
            Actions.On_Event (Source_Control, Widgets.Submit, Writing_VM.Actions.End_Source_Name_Edit);
            Actions.On_Event (Source_Control, Widgets.Blur, Writing_VM.Actions.End_Source_Name_Edit);
            UI.Mount_Into (Form_Of (Item).all, Content_Panel (Item).all, Whole);
         end;
         if not Item.Shell.Windowed then
            Panels.Set_Fill (Pane.Write_View, Desk);
            Panels.Set_Fill (Pane.Pane, Desk);
         end if;
         Panels.Set_Fill (Pane.Sidebar, Side_Fill);
         Panels.Set_Fill (Pane.Sources_Grab, Quiet_Ink);
         Panels.Set_Fill (Pane.Sidebar_Rule, Themes.Border);
         Widgets.Set_Visible (Item.Docs.Drop_Line, False);
         Widgets.Set_Visible (Item.Docs.Ghost, False);
         Text_Fields.Set_Shared
           (Item.Naming.Dir_Field, Item.Host.Doc_Resources'Unchecked_Access);
         Text_Fields.Configure
           (Item.Naming.Dir_Field, Pomarine.Line_Texts.Interface_Font, Edit_Size);
         Widgets.Set_Visible (Item.Naming.Dir_Field, False);
         Text_Fields.Set_Shared
           (Item.Naming.Source_Field, Item.Host.Doc_Resources'Unchecked_Access);
         Text_Fields.Configure
           (Item.Naming.Source_Field, Pomarine.Line_Texts.Interface_Font, Edit_Size);
         Widgets.Set_Visible (Item.Naming.Source_Field, False);
         Widgets.Set_Visible (Item.Section_View.Tail, False);
         Widgets.Set_Visible (Pane.Pane, False);
         Widgets.Set_Visible (Pane.Menu, False);
      end Assemble;

      --  The menus over the content, and the listeners of the other parts.
      procedure Hook_Up is
      begin
         UI.Mount_Into
           (Form_Of (Item).all, Content_Panel (Item).all,
            Menu_Commands.Place
              (Item, Form_Of (Item).all, Item.Context.Context_Menu, Menu_VM.Context_Menu,
               (Place => Absolute, Width => Layouts.Length_Of (Context_Width), others => <>)));
         Widgets.Set_Visible (Item.Context.Context_Menu, False);
         UI.Mount_Into
           (Form_Of (Item).all, Content_Panel (Item).all,
            Menu_Commands.Place
              (Item, Form_Of (Item).all, Item.Section_Menu.Menu, Menu_VM.Section_Menu,
               (Place => Absolute, Width => 220.0, others => <>)));
         Widgets.Set_Visible (Item.Section_Menu.Menu, False);
         Items.Readers.Build
           (Item.Reading.Pane_Reader, Pane.Pane_Body, Toolbar, Pixels,
            Pinned => True);
         UI.Observe (Form_Of (Item).all, Item.Sidebar_Watcher'Access);
         Writing.Listen (Item);
         Grammar.Build (Item);
      end Hook_Up;

   begin
      Menu_Commands.Initialize (Item);
      Open (Item.Forms (Writing_Region), Item.Root.Widgets'Unchecked_Access, Writing_Region);
      Assemble;
      Hook_Up;
      Writing.Fit_Sidebar (Item);
   end Build_Write;

end View.Build.Write_View;
