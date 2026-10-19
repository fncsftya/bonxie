with Items.Schema;
with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings.Unbounded;
with Items.Readers;
with Items.Windows;
with Preferences;
with Speech.Models;
with SDL3.Cursors;
with Pomarine.Boxes;
with Icon_Set;
with Pomarine.Icons;
with Pomarine.Line_Texts;
with Pomarine.Themes;
with Pomarine.Widgets;
with Pomarine.Widgets.Layouts;
with Pomarine.Widgets.Scrollers;
with Pomarine.Text_Areas;
with Viewer.Canvas_Items;
with Viewer.Links;
with Viewer.Outlines;
with Viewer.Section_Links;
with Viewer.Responses;
with Viewer.Recent;
with Viewer.Style;
with Viewer.Writing;
with Viewer.Grammar;

package body Viewer.Build is

   package Widgets renames Pomarine.Widgets;
   package Panels renames Pomarine.Widgets.Panels;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Labels renames Pomarine.Widgets.Labels;
   package Text_Fields renames Pomarine.Widgets.Text_Fields;
   package Grips renames Pomarine.Widgets.Grips;
   package Scrollers renames Pomarine.Widgets.Scrollers;
   package Editors renames Pomarine.Widgets.Editors;
   package Checks renames Pomarine.Widgets.Checks;
   package Selects renames Pomarine.Widgets.Selects;
   package Switches renames Pomarine.Widgets.Switches;
   package Themes renames Pomarine.Themes;

   use Style;
   use Pomarine.Widgets.Layouts;

   function Share_Directory (Folder : String) return String;
   --  Where the files of Folder in share/bonxie are: beside the
   --  executable's folder, as installed or built in place; or from the
   --  current directory, as the tests run in a folder of the project.
   --  "" if none is found.

   function Share_Directory (Folder : String) return String is
      Share : constant String := "share/bonxie/" & Folder;

      function Program_Folder return String is
      begin
         return Ada.Directories.Containing_Directory
                  (Ada.Command_Line.Command_Name);
      exception
         when Ada.Directories.Use_Error | Ada.Directories.Name_Error =>
            return ".";
      end Program_Folder;

      Beside : constant String := Program_Folder & "/../" & Share;
   begin
      if Ada.Directories.Exists (Beside) then
         return Beside;
      elsif Ada.Directories.Exists (Share) then
         return Share;
      elsif Ada.Directories.Exists ("../" & Share) then
         return "../" & Share;
      else
         return "";
      end if;
   end Share_Directory;

   procedure Build_Header (Item : in out Session);
   --  Add and style the bar across the top of a window.

   procedure Build_Header (Item : in out Session) is
   begin
      --  Not shown: the screens leave room for the window's own buttons
      --  (Header_Size above the home screen, Header_Inset at the left of
      --  the toolbar), and its title is the window's.
      Widgets.Add (Item.Root.Window_Panel, Item.Root.Header_Panel);
      Widgets.Add (Item.Root.Header_Panel, Item.Root.Header_Title);
      Set_Layout (Item.Root.Header_Panel, Height => Header_Size);
      Widgets.Set_Visible (Item.Root.Header_Panel, False);
   end Build_Header;

   procedure Build_Home (Item : in out Session);
   --  Add and style the home screen's widgets.

   procedure Build_Home (Item : in out Session) is
      Front : Home_Parts renames Item.Home_View;
      Top  : constant Float := (if Item.Shell.Windowed
                                then Header_Size else 0.0);
      --  Clear of the window's own buttons.
   begin
      Widgets.Add (Item.Root.Window_Panel, Front.Home_Panel);
      Widgets.Add (Front.Home_Panel, Front.Home_Side);
      Widgets.Add (Front.Home_Side, Front.Logo);
      Widgets.Add (Front.Logo, Front.Logo_Name);
      Widgets.Add (Front.Home_Side, Front.New_Button, Front.Side_Room, Front.Settings_Button);
      Widgets.Add (Front.Home_Panel, Front.Home_Rule, Front.Recent_Panel);
      Widgets.Add (Front.Recent_Panel, Front.Recent_Title, Front.Cards_Scroll);
      Widgets.Add (Front.Cards_Scroll, Front.Cards_Content);
      for Card of Front.Cards loop
         Widgets.Add (Front.Cards_Content, Card.Panel);
         Widgets.Add (Card.Panel, Card.Peek);
         Widgets.Add (Card.Peek, Card.Picture);
         Widgets.Add (Card.Panel, Card.Info);
         Widgets.Add (Card.Info, Card.Name, Card.Rename, Card.Delete);
         Widgets.Add (Card.Name, Card.Title, Card.Meta);
      end loop;
      Widgets.Add (Front.Cards_Content, Front.New_Card);
      Widgets.Add (Front.New_Card, Front.New_Card_Plus, Front.New_Card_Label);
      Widgets.Add (Front.Cards_Content, Front.No_Rows);

      Set_Layout (Front.Home_Panel, Flow => Row, Grow => 1.0);

      --  The sidebar: the name, New Project, and Settings at the foot.
      Panels.Set_Fill (Front.Home_Side, Mid_Panel);
      Set_Layout
        (Front.Home_Side, Flow => Column, Width => Home_Side_Width, Shrink => 0.0,
         Padding => (Top => Side_Pad + Top, others => Side_Pad));
      Set_Layout
        (Front.Logo, Flow => Row, Align => Center, Height => Logo_Height,
         Margin => (Bottom => Logo_Gap, others => <>));
      Labels.Set_Text (Front.Logo_Name, "bonxie");
      Labels.Set_Style (Front.Logo_Name, Pomarine.Line_Texts.Display);
      Set_Layout (Front.Logo_Name, Grow => 1.0, Height => Logo_Height);
      Buttons.Set_Label (Front.New_Button, "New project");
      Buttons.Set_Icon (Front.New_Button, Icon_Set.Plus);
      Buttons.Set_Captioned (Front.New_Button, True);
      Buttons.Set_Kind (Front.New_Button, Buttons.Primary);
      Set_Layout (Front.New_Button, Height => Action_Height);
      Set_Layout (Front.Side_Room, Grow => 1.0);
      Buttons.Set_Label (Front.Settings_Button, "Settings");
      Buttons.Set_Icon (Front.Settings_Button, Icon_Set.Settings);
      Buttons.Set_Captioned (Front.Settings_Button, True);
      Set_Layout (Front.Settings_Button, Height => Action_Height);
      Panels.Set_Fill (Front.Home_Rule, Themes.Border);
      Set_Layout (Front.Home_Rule, Width => Hairline, Shrink => 0.0);

      --  The projects: a title, and the cards in rows that wrap. The title
      --  is on the line of the name, as the same height from the same top.
      Set_Layout
        (Front.Recent_Panel, Flow => Column, Grow => 1.0, Width => 0.0,
         Padding => (Top => Side_Pad + Top, Left => Home_Margin, others => <>));
      Labels.Set_Text (Front.Recent_Title, "Recent projects");
      Labels.Set_Style (Front.Recent_Title, Pomarine.Line_Texts.Display);
      Set_Layout
        (Front.Recent_Title, Height => Logo_Height,
         Margin => (Bottom => Logo_Gap, others => <>));
      Set_Layout (Front.Cards_Scroll, Grow => 1.0, Height => 0.0);
      Set_Layout
        (Front.Cards_Content, Flow => Row, Wrap => True, Align => Start, Shrink => 0.0,
         Gap => Card_Gap,
         Padding => (Right => Home_Margin - Card_Gap, Bottom => Home_Margin, others => <>));
      Labels.Set_Text (Front.No_Rows, No_Projects);
      Labels.Set_Ink (Front.No_Rows, Quiet_Ink);
      Set_Layout (Front.No_Rows, Height => Title_Height, Width => Card_Width);

      for Card of Front.Cards loop
         --  Outlined, with a shadow, which the face leaves room for.
         Panels.Set_Fill (Card.Panel, Themes.Tint);
         Panels.Set_Border (Card.Panel, Themes.Border);
         Panels.Set_Shadow (Card.Panel, Themes.Shadow);
         Set_Layout
           (Card.Panel, Flow => Column, Width => Card_Width, Height => Card_Height, Shrink => 0.0,
            Outlined => True, Shadowed => True);
         --  A line between the picture and what is below it.
         Grips.Set_Fill (Card.Peek, Themes.Border);
         Grips.Set_Wanted_Cursor (Card.Peek, SDL3.Cursors.Pointer);
         Set_Layout (Card.Peek, Height => Thumb_Height, Flow => Column);
         Set_Layout (Card.Picture, Grow => 1.0, Margin => (Bottom => Hairline, others => <>));
         Panels.Set_Fill (Card.Info, Themes.Tint);
         Set_Layout
           (Card.Info, Grow => 1.0, Flow => Row, Align => Center, Gap => Row_Gap,
            Padding => (Left | Right => Card_Pad, others => <>));
         Grips.Set_Wanted_Cursor (Card.Name, SDL3.Cursors.Pointer);
         Set_Layout
           (Card.Name, Grow => 1.0, Width => 0.0, Flow => Column, Spread => Center,
            Align_Self => Stretch);
         Labels.Set_Style (Card.Title, Pomarine.Line_Texts.Heading);
         Set_Layout (Card.Title, Height => Card_Title_Height);
         Set_Layout (Card.Meta, Height => Card_Meta_Height);
         Buttons.Set_Label (Card.Rename, "Rename");
         Buttons.Set_Icon (Card.Rename, Icon_Set.Edit);
         Buttons.Set_Label (Card.Delete, "Delete");
         Buttons.Set_Icon (Card.Delete, Icon_Set.Delete);
         Buttons.Set_Kind (Card.Delete, Buttons.Danger);
         Set_Layout (Card.Rename, Width => Card_Button, Height => Card_Button);
         Set_Layout (Card.Delete, Width => Card_Button, Height => Card_Button);
      end loop;

      --  The outline of a card, to make a project.
      Grips.Set_Border (Front.New_Card, Themes.Border, Dashed => True);
      Grips.Set_Wanted_Cursor (Front.New_Card, SDL3.Cursors.Pointer);
      Set_Layout
        (Front.New_Card, Width => Card_Width - Themes.Shadow_Offset,
         Height => Card_Height - Themes.Shadow_Offset, Shrink => 0.0,
         Flow => Column, Spread => Center, Align => Center);
      Buttons.Set_Label (Front.New_Card_Plus, "New");
      Buttons.Set_Icon (Front.New_Card_Plus, Icon_Set.Plus);
      Buttons.Set_Kind (Front.New_Card_Plus, Buttons.Primary);
      Set_Layout (Front.New_Card_Plus, Width => Plus_Size, Height => Plus_Size);
      Labels.Set_Text (Front.New_Card_Label, "New project");
      Labels.Set_Style (Front.New_Card_Label, Pomarine.Line_Texts.Strong);
      Labels.Set_Ink (Front.New_Card_Label, Style.New_Project_Ink);
      Labels.Set_Centered (Front.New_Card_Label, True);
      Set_Layout
        (Front.New_Card_Label, Width => Card_Width / 2.0, Height => Title_Height,
         Margin => (Top => Row_Gap, others => <>));
   end Build_Home;

   procedure Build_Project (Item : in out Session);
   --  Add and style the project screen's widgets.

   procedure Build_Project (Item : in out Session) is
      Bar : Toolbar_Parts renames Item.Toolbar;
      Pixels : constant Float := Item.Shell.Density;

      procedure Size (Part : in out Widgets.Widget'Class; Wide, High : Float) is
      begin
         Set_Layout (Part, Width => Wide, Height => High, Shrink => 0.0);
      end Size;

      procedure Side (Part : in out Panels.Panel; Along : Spread_Kind) is
      begin
         Set_Layout (Part, Flow => Row, Align => Center, Spread => Along, Grow => 1.0, Width => 0.0);
      end Side;
   begin
      Widgets.Add (Item.Root.Window_Panel, Bar.Project_Panel);
      Widgets.Add (Bar.Project_Panel, Bar.Toolbar_Panel);
      Widgets.Add (Bar.Toolbar_Panel, Bar.Toolbar_Start);
      Widgets.Add (Bar.Toolbar_Start, Bar.Close_Button, Bar.Bar_Rule, Bar.Title_Area);
      Widgets.Add (Bar.Title_Area, Bar.Project_Title);
      Widgets.Add (Bar.Toolbar_Start, Bar.Title_Field);
      Widgets.Add (Bar.Toolbar_Panel, Bar.Tabs);
      Widgets.Add (Bar.Tabs, Bar.Outline_Tab, Bar.Canvas_Tab, Bar.Write_Tab);
      Widgets.Add (Bar.Toolbar_Panel, Bar.Toolbar_End);
      Widgets.Add (Bar.Toolbar_End, Item.Dock.Tool_List);
      Widgets.Add (Bar.Project_Panel, Bar.Content_Panel);
      Widgets.Add (Bar.Content_Panel, Item.Canvas_View);
      Widgets.Add (Bar.Project_Panel, Item.Dock.Dock_Panel);
      Widgets.Add (Item.Dock.Dock_Panel, Item.Dock.Dock_Scroll);
      Widgets.Add (Item.Dock.Dock_Scroll, Item.Dock.Dock_Content);

      Set_Layout (Bar.Project_Panel, Flow => Column, Grow => 1.0);
      --  The pages are taller than it: it takes what the bars leave.
      Set_Layout (Bar.Content_Panel, Grow => 1.0, Flow => Column, Height => 0.0);
      Set_Layout (Item.Canvas_View, Grow => 1.0);

      --  The bar across the top: the way back and the project's name at the
      --  left, the tabs in the middle (the sides take equal shares), the
      --  list of items at the right.
      Panels.Set_Fill (Bar.Toolbar_Panel, Toolbar);
      Set_Layout
        (Bar.Toolbar_Panel, Height => Toolbar_Size, Shrink => 0.0, Flow => Row, Align => Center,
         Padding => (Left  => (if Item.Shell.Windowed then Header_Inset else Bar_Inset),
                     Right => Bar_Inset,
                     others => <>));
      Side (Bar.Toolbar_Start, Start);
      Side (Bar.Toolbar_End, Finish);
      Buttons.Set_Label (Bar.Close_Button, "Projects");
      Buttons.Set_Icon (Bar.Close_Button, Icon_Set.Back);
      Buttons.Set_Captioned (Bar.Close_Button, True);
      Buttons.Set_Kind (Bar.Close_Button, Buttons.Quiet);
      Size (Bar.Close_Button, Back_Width, Tab_Height);
      Panels.Set_Fill (Bar.Bar_Rule, Rule_Ink);
      Set_Layout
        (Bar.Bar_Rule, Width => Hairline, Height => Bar_Rule_Height, Shrink => 0.0,
         Margin => (Left | Right => Name_Gap, others => <>));
      Labels.Set_Style (Bar.Project_Title, Pomarine.Line_Texts.Heading);
      Labels.Set_Ink (Bar.Project_Title, Themes.Bar_Ink);
      Set_Layout (Bar.Project_Title, Grow => 1.0, Width => 0.0, Height => Tab_Height);
      Grips.Set_Hover_Outline (Bar.Title_Area, Themes.Bar_Ink);
      Grips.Set_Wanted_Cursor (Bar.Title_Area, SDL3.Cursors.Pointer);
      Set_Layout
        (Bar.Title_Area, Flow => Row, Align => Center, Grow => 1.0, Width => 0.0,
         Height => Tab_Height);
      Text_Fields.Set_Shared
        (Bar.Title_Field, Item.Host.Doc_Resources'Unchecked_Access);
      Text_Fields.Configure
        (Bar.Title_Field, Pomarine.Line_Texts.Interface_Font,
         Pomarine.Line_Texts.Heading_Size);
      Set_Layout (Bar.Title_Field, Grow => 1.0, Width => 0.0, Height => Tab_Height);
      Widgets.Set_Visible (Bar.Title_Field, False);

      Set_Layout (Bar.Tabs, Flow => Row, Gap => Tab_Gap);
      Buttons.Set_Label (Bar.Outline_Tab, "Outline");
      Buttons.Set_Label (Bar.Canvas_Tab, "Canvas");
      Buttons.Set_Selected (Bar.Canvas_Tab, True);
      Buttons.Set_Focusable (Bar.Close_Button, True);
      Buttons.Set_Focusable (Bar.Outline_Tab, True);
      Buttons.Set_Focusable (Bar.Canvas_Tab, True);
      Buttons.Set_Focusable (Bar.Write_Tab, True);
      Buttons.Set_Label (Bar.Write_Tab, "Write");
      Size (Bar.Outline_Tab, Tab_Width, Tab_Height);
      Size (Bar.Canvas_Tab, Tab_Width, Tab_Height);
      Size (Bar.Write_Tab, Tab_Width, Tab_Height);
      Buttons.Set_Label (Item.Dock.Tool_List, "Items");
      Buttons.Set_Icon (Item.Dock.Tool_List, Icon_Set.List);
      Buttons.Set_Captioned (Item.Dock.Tool_List, True);
      Size (Item.Dock.Tool_List, Items_Width, Tab_Height);

      --  The dock of minimised items, under the canvas, and the
      --  windows of the items: on the canvas, or as bars in the dock.
      Panels.Set_Fill (Item.Dock.Dock_Panel, Dock);
      Set_Layout (Item.Dock.Dock_Panel, Height => Dock_Height, Shrink => 0.0, Flow => Row);
      Scrollers.Set_Across (Item.Dock.Dock_Scroll, True);
      Set_Layout (Item.Dock.Dock_Scroll, Flow => Row, Grow => 1.0, Width => 0.0);
      Set_Layout
        (Item.Dock.Dock_Content, Flow => Row, Shrink => 0.0, Align => Center, Gap => Dock_Gap,
         Padding => (Left | Right => Dock_Inset, others => <>));
      for Each of Item.Windows loop
         Items.Windows.Set_Shared
           (Each, Item.Host.Doc_Resources'Unchecked_Access);
         Items.Windows.Build
           (Each, Item.Canvas_View, Item.Dock.Dock_Content, Toolbar, Pixels);
      end loop;
      Links.Build (Item);
      Canvas_Items.Listen (Item);
   end Build_Project;

   procedure Build_Tray (Item : in out Session);
   --  Add and style the tray of the canvas's tools: over it, after the
   --  writing view, so over that too, at the foot (see
   --  Canvas_Items.Sync, which puts it in the middle).

   procedure Build_Tray (Item : in out Session) is
      Tray : Dock_Parts renames Item.Dock;
   begin
      Widgets.Add (Item.Toolbar.Content_Panel, Tray.Tools);
      Widgets.Add (Tray.Tools, Tray.Tool_Item, Tray.Tool_Source);
      Panels.Set_Fill (Tray.Tools, Toolbar);
      Panels.Set_Shadow (Tray.Tools, Themes.Shadow);
      Set_Layout
        (Tray.Tools, Place => Absolute,
         Position => (Bottom => Tray_Foot - Themes.Shadow_Offset, others => <>),
         Width => Tray_Width, Height => Tray_Height, Flow => Row, Align => Center,
         Padding => (others => Tray_Pad), Shadowed => True, Gap => Tray_Gap);
      Buttons.Set_Label (Tray.Tool_Item, "Add document");
      Buttons.Set_Icon (Tray.Tool_Item, Icon_Set.Document);
      Buttons.Set_Captioned (Tray.Tool_Item, True);
      Buttons.Set_Label (Tray.Tool_Source, "Add source");
      Buttons.Set_Icon (Tray.Tool_Source, Icon_Set.Link);
      Buttons.Set_Captioned (Tray.Tool_Source, True);
      Buttons.Set_Kind (Tray.Tool_Source, Buttons.Primary);
      Set_Layout (Tray.Tool_Item, Width => Wide_Tool_Width, Height => Tool_Height);
      Set_Layout (Tray.Tool_Source, Width => Tool_Width, Height => Tool_Height);
   end Build_Tray;

   procedure Build_Write (Item : in out Session);
   --  Add and style the writing view's widgets.

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

      procedure Build_Row
        (Content : in out Panels.Panel;
         Each    : in out Index_Row;
         Counted : Boolean) is
      begin
         Widgets.Add (Content, Each.Row);
         Widgets.Add (Each.Row, Each.Tag, Each.Caption, Each.Count);
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

      procedure Heading (Label : in out Labels.Label; Name : String) is
      begin
         Labels.Set_Text (Label, Name);
         Labels.Set_Style (Label, Pomarine.Line_Texts.Caption);
         Set_Layout (Label, Height => Heading_Height, Shrink => 0.0);
      end Heading;
   begin
      Widgets.Add (Item.Toolbar.Content_Panel, View.Write_View);
      Widgets.Add (View.Write_View, View.Sidebar);
      Widgets.Add (View.Sidebar, View.Grammar_Row);
      Widgets.Add (View.Grammar_Row, View.Grammar_Switch, View.Grammar_Count);
      Set_Layout (View.Grammar_Row, Flow => Row, Align => Center, Height => 52.0, Shrink => 0.0, Gap => 6.0);
      Switches.Set_Label (View.Grammar_Switch, "Show Grammar Suggestions");
      Switches.Set_On (View.Grammar_Switch, True);
      Switches.Set_Focusable (View.Grammar_Switch, True);
      Set_Layout (View.Grammar_Switch, Height => 52.0, Grow => 1.0, Width => 0.0);
      Buttons.Set_Label (View.Grammar_Count, "0");
      Buttons.Set_Focusable (View.Grammar_Count, True);
      Widgets.Set_Accessible_Name (View.Grammar_Count, "Fixable grammar suggestions: 0");
      Set_Layout (View.Grammar_Count, Width => 36.0, Height => 28.0, Shrink => 0.0);
      Widgets.Add (View.Sidebar, View.Docs_Head);
      Widgets.Add (View.Docs_Head, View.Docs_Heading, View.Docs_Folder, View.Docs_Add);
      Build_Index (View.Docs_Scroll, View.Docs_Content, View.Docs_None, No_Documents);
      for Each of Item.Docs.Doc_Rows loop
         Build_Row (View.Docs_Content, Each, Counted => True);
         Panels.Set_Fill (Each.Tag, Quiet_Ink);
      end loop;
      Widgets.Add (View.Docs_Content, View.Docs_None);
      Set_Layout (View.Docs_None, Height => Index_Height);
      Widgets.Add (View.Docs_Content, Item.Docs.Drop_Line);
      Widgets.Add (View.Docs_Content, Item.Docs.Ghost);
      Widgets.Add (Item.Docs.Ghost, Item.Docs.Ghost_Title);
      Widgets.Add (View.Docs_Content, Item.Naming.Dir_Field);
      Widgets.Add (View.Sidebar, View.Sources_Edge);
      Widgets.Add (View.Sources_Edge, View.Sources_Grab);
      Widgets.Add (View.Sidebar, View.Sources_Heading);
      Build_Index (View.Sources_Scroll, View.Sources_Content, View.Sources_None, No_Sources);
      for Each of Item.Reading.Source_Rows loop
         Build_Row (View.Sources_Content, Each, Counted => False);
      end loop;
      Widgets.Add (View.Sources_Content, View.Sources_None);
      Widgets.Add (View.Sources_Content, Item.Naming.Source_Field);
      Set_Layout (View.Sources_None, Height => Index_Height);
      Widgets.Add (View.Write_View, View.Sidebar_Edge, View.Sidebar_Rule, View.Pages_Scroll);
      Widgets.Add (View.Pages_Scroll, View.Pages_Content);
      --  The spacer of the sections is first, so that the pages (and what
      --  is between them) are over it, and take the pointer.
      Widgets.Add (View.Pages_Content, Item.Section_View.Tail);
      for Each of Item.Docs.Pages loop
         Widgets.Add (View.Pages_Content, Each.Box);
         Widgets.Add (Each.Box, Each.Bar);
         Widgets.Add (Each.Bar, Each.Heading_Area);
         Widgets.Add (Each.Heading_Area, Each.Swatch, Each.Heading);
         Widgets.Add (Each.Bar, Each.Title_Field, Each.Outline_Button, Each.Sources_Button);
         Widgets.Add (Each.Bar, Each.Mic_Button);
         Widgets.Add (Each.Box, Each.Sheet);
         Widgets.Add (Each.Sheet, Each.Text);
         Widgets.Add (Each.Box, Each.Words);
      end loop;
      declare
         Sections : Section_View_Parts renames Item.Section_View;
      begin
         --  After the pages, which they are among by their edges.
         for Each of Sections.Heads loop
            Widgets.Add (View.Pages_Content, Each.Row);
            Widgets.Add (Each.Row, Each.Bar, Each.Title, Each.Count, Each.Notes);
            Widgets.Add (Each.Row, Each.Add);
         end loop;
         for Each of Sections.Notes loop
            Widgets.Add (View.Pages_Content, Each.Box);
            Widgets.Add (Each.Box, Each.Text);
         end loop;
         for Each of Sections.Empties loop
            Widgets.Add (View.Pages_Content, Each.Box);
            Widgets.Add (Each.Box, Each.Note, Each.Add);
         end loop;
         for Each of Sections.Gaps loop
            Widgets.Add (View.Pages_Content, Each.Row);
            Widgets.Add (Each.Row, Each.Caption, Each.Rule);
         end loop;
      end;
      Widgets.Add (View.Write_View, View.Pane);
      Widgets.Add (View.Pane, View.Pane_Edge, View.Pane_Body);
      --  Over the rest, last.
      for Each of Item.Reading.Readers loop
         Items.Readers.Build (Each, View.Write_View, Toolbar, Pixels);
      end loop;
      Widgets.Add (View.Write_View, View.Menu);
      Set_Layout (View.Menu, Place => Absolute, Width => Menu_Width);
      Widgets.Set_Visible (View.Menu, False);
      declare
         Sections : Section_View_Parts renames Item.Section_View;
      begin
         Set_Layout (Sections.Tail, Place => Flowing, Height => 0.0, Shrink => 0.0);
         Widgets.Set_Visible (Sections.Tail, False);
         for Each of Sections.Heads loop
            Set_Layout
              (Each.Row, Place => Absolute, Flow => Row, Align => Center, Gap => Tool_Gap,
               Height => Section_Head_Height, Width => Page_Width);
            Set_Layout (Each.Bar, Width => Section_Bar, Height => Section_Head_Height - 12.0, Shrink => 0.0);
            Panels.Set_Fill (Each.Bar, Themes.Border);
            Labels.Set_Style (Each.Title, Pomarine.Line_Texts.Heading);
            Set_Layout (Each.Title, Grow => 1.0, Width => 0.0, Height => Section_Head_Height);
            Labels.Set_Ink (Each.Count, Quiet_Ink);
            Labels.Set_Trailing (Each.Count, True);
            Set_Layout (Each.Count, Width => 140.0, Height => Section_Head_Height);
            Buttons.Set_Label (Each.Notes, "Notes");
            Buttons.Set_Captioned (Each.Notes, True);
            Buttons.Set_Focusable (Each.Notes, True);
            Set_Layout (Each.Notes, Width => Notes_Width, Height => Outline_Button, Shrink => 0.0);
            Buttons.Set_Label (Each.Add, "Add document to this section");
            Buttons.Set_Icon (Each.Add, Icon_Set.Plus);
            Buttons.Set_Focusable (Each.Add, True);
            Set_Layout
              (Each.Add, Width => Outline_Button, Height => Outline_Button, Shrink => 0.0,
               Margin => (Right => Shadow_Room, others => <>));
            Widgets.Set_Visible (Each.Row, False);
         end loop;
         for Index in Sections.Notes'Range loop
            declare
               Each : Note_Box renames Sections.Notes (Index);
            begin
               Panels.Set_Fill (Each.Box, Side_Fill);
               Panels.Set_Border (Each.Box, Themes.Border);
               Set_Layout
                 (Each.Box, Place => Absolute, Flow => Column, Width => Page_Width, Outlined => True,
                  Padding => (others => Notes_Pad), Shrink => 0.0);
               Editors.Set_Shared (Each.Text, Item.Host.Doc_Resources'Unchecked_Access);
               Editors.Configure
                 (Each.Text, Pomarine.Line_Texts.Interface_Font, Edit_Size, 2000.0);
               Editors.Set_Paper (Each.Text, Side_Fill);
               Editors.Set_Borderless (Each.Text, True);
               Editors.Attach (Each.Text, Item.Outline_View.Blocks (Index).Notes_Doc'Unchecked_Access);
               Set_Layout (Each.Text, Shrink => 0.0, Height => Notes_Min_Height);
               Widgets.Set_Visible (Each.Box, False);
            end;
         end loop;
         for Each of Sections.Empties loop
            Panels.Set_Border (Each.Box, Themes.Border);
            Set_Layout
              (Each.Box, Place => Absolute, Flow => Column, Align => Center, Spread => Center,
               Gap => Tool_Gap, Height => Section_Empty_Height, Width => Page_Width, Outlined => True);
            Labels.Set_Text (Each.Note, "No documents in this section yet");
            Labels.Set_Ink (Each.Note, Quiet_Ink);
            Set_Layout (Each.Note, Height => Heading_Height);
            Buttons.Set_Label (Each.Add, "Add document");
            Buttons.Set_Icon (Each.Add, Icon_Set.Plus);
            Buttons.Set_Captioned (Each.Add, True);
            Buttons.Set_Focusable (Each.Add, True);
            Set_Layout (Each.Add, Width => Wide_Tool_Width, Height => Bar_Button_Height);
            Widgets.Set_Visible (Each.Box, False);
         end loop;
         for Each of Sections.Gaps loop
            Set_Layout
              (Each.Row, Place => Absolute, Flow => Row, Align => Center, Gap => Tool_Gap,
               Height => Gap_Mark_Height, Width => Page_Width);
            Labels.Set_Text (Each.Caption, "Not in a section");
            Labels.Set_Style (Each.Caption, Pomarine.Line_Texts.Caption);
            Labels.Set_Ink (Each.Caption, Quiet_Ink);
            Set_Layout (Each.Caption, Width => 120.0, Height => Gap_Mark_Height, Shrink => 0.0);
            Panels.Set_Fill (Each.Rule, Themes.Border);
            Set_Layout (Each.Rule, Grow => 1.0, Width => 0.0, Height => Hairline);
            Widgets.Set_Visible (Each.Row, False);
         end loop;
      end;
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

      Panels.Set_Fill (View.Write_View, Desk);
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
         Padding => (Right => Shadow_Room, others => <>));
      Heading (View.Docs_Heading, "DOCUMENTS");
      Set_Layout (View.Docs_Heading, Grow => 1.0);
      Heading (View.Sources_Heading, "SOURCES");
      Set_Layout (View.Sources_Heading, Margin => (Top => Heading_Top, others => <>));
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

      --  The pages, scrolled, one above the next, and the button to add
      --  one after them.
      Set_Layout (View.Pages_Scroll, Grow => 1.0, Width => 0.0);
      Set_Layout
        (View.Pages_Content, Flow => Column, Shrink => 0.0, Align => Center, Gap => Page_Gap,
         Padding => (Top => Page_Margin - Page_Gap, others => Page_Margin));
      for Each of Item.Docs.Pages loop
         Set_Layout (Each.Box, Flow => Column, Shrink => 0.0, Width => Page_Width);
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
            Padding => (Left | Right => Page_Margin - Page_Text_Inset,
                        Top | Bottom => Page_Top - Page_Text_Inset));
         Editors.Set_Shared
           (Each.Text, Item.Host.Doc_Resources'Unchecked_Access);
         Editors.Configure
           (Each.Text, Pomarine.Line_Texts.Serif, Page_Text_Size, 2000.0,
            Spacing => 0.35 * Page_Text_Size);
         Editors.Set_Paper (Each.Text, Paper);
         Pomarine.Text_Areas.Set_Grows (Editors.Area (Each.Text).all);
         Set_Layout (Each.Text, Shrink => 0.0, Height => Page_Min_Height);
         Labels.Set_Trailing (Each.Words, True);
         Labels.Set_Ink (Each.Words, Quiet_Ink);
         Set_Layout
           (Each.Words, Height => Page_Foot, Margin => (Right => Shadow_Room, others => <>));
         Widgets.Set_Visible (Each.Box, False);
      end loop;
      --  The pane: an edge to size it by, and the pinned source.
      Panels.Set_Fill (View.Pane, Desk);
      View.Pane_Wide := Pane_Default;
      Set_Layout (View.Pane, Flow => Row, Shrink => 0.0, Width => Pane_Default);
      Grips.Set_Fill (View.Pane_Edge, Edge_Fill);
      Grips.Set_Wanted_Cursor (View.Pane_Edge, SDL3.Cursors.Resize_Across);
      Set_Layout (View.Pane_Edge, Width => Pane_Edge_Width, Shrink => 0.0);
      Set_Layout (View.Pane_Body, Flow => Column, Grow => 1.0, Width => 0.0);
      Widgets.Set_Visible (View.Pane, False);
   end Build_Write;

   procedure Build_Outline (Item : in out Session);
   --  Add and style the outline view's widgets.

   procedure Build_Outline (Item : in out Session) is
      View   : Outline_Parts renames Item.Outline_View;
      Pixels : constant Float := Item.Shell.Density;
      Offset : constant Float := Pomarine.Boxes.Offset (Pixels);

      procedure Icon_Button
        (Part : in out Buttons.Button; Name : String; Icon : Pomarine.Icons.Icon) is
      begin
         Buttons.Set_Label (Part, Name);
         Buttons.Set_Icon (Part, Icon);
         Buttons.Set_Focusable (Part, True);
         Set_Layout (Part, Width => Outline_Button, Height => Outline_Button, Shrink => 0.0);
      end Icon_Button;
   begin
      Widgets.Add (Item.Toolbar.Content_Panel, View.View);
      Widgets.Add (View.View, View.Form, View.Sections);
      Widgets.Add (View.Form, View.Name_Label, View.Name_Field, View.Desc_Label);
      Widgets.Add (View.Form, View.Desc_Sheet);
      Widgets.Add (View.Desc_Sheet, View.Desc_Text);
      Widgets.Add (View.Sections, View.Head, View.Generate_Error, View.Scroll);
      Widgets.Add (View.Head, View.Heading, View.Add_Button, View.Generate_Button);
      Widgets.Add (View.Scroll, View.Content);

      Panels.Set_Fill (View.View, Desk);
      Set_Layout
        (View.View, Flow => Row, Grow => 1.0, Height => 0.0, Gap => Outline_Gap,
         Padding => (others => Outline_Gap));

      --  Two columns of the same width: the form, and the sections.
      Set_Layout (View.Form, Flow => Column, Grow => 1.0, Width => 0.0, Gap => Tool_Gap);
      Labels.Set_Text (View.Name_Label, "Title");
      Labels.Set_Style (View.Name_Label, Pomarine.Line_Texts.Caption);
      Set_Layout (View.Name_Label, Height => Heading_Height, Shrink => 0.0);
      Text_Fields.Set_Shared (View.Name_Field, Item.Host.Doc_Resources'Unchecked_Access);
      Text_Fields.Configure
        (View.Name_Field, Pomarine.Line_Texts.Interface_Font, Edit_Size);
      Text_Fields.Attach (View.Name_Field, View.Name_Doc'Unchecked_Access);
      Set_Layout (View.Name_Field, Height => Title_Height, Shrink => 0.0);
      Labels.Set_Text (View.Desc_Label, "Description");
      Labels.Set_Style (View.Desc_Label, Pomarine.Line_Texts.Caption);
      Set_Layout
        (View.Desc_Label, Height => Heading_Height, Shrink => 0.0,
         Margin => (Top => Tool_Gap, others => <>));
      Panels.Set_Fill (View.Desc_Sheet, Paper);
      --  The editor draws the outline.
      Set_Layout
        (View.Desc_Sheet, Flow => Column, Height => Outline_Description_Height,
         Shrink => 0.0);
      Editors.Set_Shared (View.Desc_Text, Item.Host.Doc_Resources'Unchecked_Access);
      Editors.Configure
        (View.Desc_Text, Pomarine.Line_Texts.Interface_Font, Edit_Size, 2000.0);
      Editors.Set_Paper (View.Desc_Text, Paper);
      Editors.Attach (View.Desc_Text, View.Desc_Doc'Unchecked_Access);
      Set_Layout (View.Desc_Text, Grow => 1.0, Height => 0.0);

      Set_Layout (View.Sections, Flow => Column, Grow => 1.0, Width => 0.0, Gap => Tool_Gap);
      Set_Layout
        (View.Head, Flow => Row, Align => Center, Height => Title_Height, Shrink => 0.0, Gap => Tool_Gap / 2.0);
      Labels.Set_Text (View.Heading, "Sections");
      Labels.Set_Style (View.Heading, Pomarine.Line_Texts.Caption);
      Set_Layout (View.Heading, Grow => 1.0, Width => 0.0, Height => Heading_Height);
      Buttons.Set_Label (View.Add_Button, "Add Section");
      Buttons.Set_Icon (View.Add_Button, Icon_Set.Plus);
      Buttons.Set_Captioned (View.Add_Button, True);
      Buttons.Set_Focusable (View.Add_Button, True);
      Set_Layout (View.Add_Button, Width => Add_Section_Width, Height => Bar_Button_Height, Shrink => 0.0);
      Buttons.Set_Label (View.Generate_Button, Outlines.Generate_Label (View.With_Notes));
      Buttons.Set_Dropdown (View.Generate_Button, True);
      Buttons.Set_Split (View.Generate_Button, True);
      Buttons.Set_Icon (View.Generate_Button, Icon_Set.Sparkles);
      Buttons.Set_Captioned (View.Generate_Button, True);
      Buttons.Set_Focusable (View.Generate_Button, True);
      Buttons.Set_Kind (View.Generate_Button, Buttons.AI);
      Set_Layout (View.Generate_Button, Width => Generate_Width, Height => Bar_Button_Height, Shrink => 0.0);
      Labels.Set_Ink (View.Generate_Error, Themes.Danger_Ink);
      Set_Layout (View.Generate_Error, Height => Heading_Height, Shrink => 0.0);
      Widgets.Set_Visible (View.Generate_Error, False);
      Set_Layout (View.Scroll, Grow => 1.0, Height => 0.0);
      Set_Layout
        (View.Content, Flow => Column, Shrink => 0.0,
         Gap => Index_Gap * Pixels - Offset, Unit => Device_Pixels);

      for Each in View.Blocks'Range loop
         declare
            Block : Section_Block renames View.Blocks (Each);
         begin
            Widgets.Add (View.Content, Block.Row);
            Widgets.Add (Block.Row, Block.Line, Block.Notes_Sheet);
            Widgets.Add (Block.Line, Block.Handle, Block.Swatch, Block.Field, Block.Notes);
            Widgets.Add (Block.Line, Block.Up, Block.Down, Block.Remove);
            Widgets.Add (Block.Notes_Sheet, Block.Notes_Text);
            Grips.Set_Fill (Block.Row, Row_Fill);
            Grips.Set_Hover_Fill (Block.Row, Row_Fill);
            Grips.Set_Border (Block.Row, Themes.Border);
            Grips.Set_Shadow (Block.Row, Side_Fill);
            Grips.Set_Wanted_Cursor (Block.Row, SDL3.Cursors.Grab);
            Set_Layout
              (Block.Row, Shrink => 0.0, Flow => Column,
               Padding => (Left | Right => Index_Pad, others => <>), Shadowed => True);
            Set_Layout
              (Block.Line, Shrink => 0.0, Flow => Row, Align => Center, Gap => Tool_Gap);
            Set_Layout
              (Block.Line, Height => Outline_Block_Height * Pixels, Unit => Device_Pixels);
            Buttons.Set_Label (Block.Notes, "Notes");
            Buttons.Set_Captioned (Block.Notes, True);
            Buttons.Set_Focusable (Block.Notes, True);
            Set_Layout (Block.Notes, Width => Notes_Width, Height => Outline_Button, Shrink => 0.0);
            Panels.Set_Fill (Block.Notes_Sheet, Paper);
            Set_Layout
              (Block.Notes_Sheet, Flow => Column, Height => Outline_Notes_Height, Shrink => 0.0,
               Margin => (Bottom => Tool_Gap, others => <>));
            Editors.Set_Shared (Block.Notes_Text, Item.Host.Doc_Resources'Unchecked_Access);
            Editors.Configure
              (Block.Notes_Text, Pomarine.Line_Texts.Interface_Font, Edit_Size, 2000.0);
            Editors.Set_Paper (Block.Notes_Text, Paper);
            Editors.Attach (Block.Notes_Text, Block.Notes_Doc'Unchecked_Access);
            Set_Layout (Block.Notes_Text, Grow => 1.0, Height => 0.0);
            Widgets.Set_Visible (Block.Notes_Sheet, False);
            Labels.Set_Text (Block.Handle, "::");
            Labels.Set_Ink (Block.Handle, Quiet_Ink);
            Set_Layout (Block.Handle, Width => Outline_Handle, Height => Index_Height, Shrink => 0.0);
            Set_Layout
              (Block.Swatch, Width => Section_Swatch, Height => Section_Swatch, Shrink => 0.0);
            Text_Fields.Set_Shared (Block.Field, Item.Host.Doc_Resources'Unchecked_Access);
            Text_Fields.Configure
              (Block.Field, Pomarine.Line_Texts.Interface_Font, Edit_Size);
            Text_Fields.Attach (Block.Field, Block.Doc'Unchecked_Access);
            Set_Layout (Block.Field, Grow => 1.0, Width => 0.0, Height => Outline_Field_Height);
            Icon_Button (Block.Up, "Move up", Pomarine.Icons.Chevron_Up);
            Icon_Button (Block.Down, "Move down", Pomarine.Icons.Chevron_Down);
            Icon_Button (Block.Remove, "Delete section", Icon_Set.Delete);
            Buttons.Set_Kind (Block.Remove, Buttons.Danger);
            Widgets.Set_Visible (Block.Row, False);
         end;
      end loop;
      Labels.Set_Text (View.None, "No sections yet");
      Labels.Set_Ink (View.None, Closed_Ink);
      Widgets.Add (View.Content, View.None);
      Set_Layout (View.None, Height => Index_Height);
      Widgets.Add (View.Content, View.Drop_Line);
      Panels.Set_Fill (View.Drop_Line, Pomarine.Themes.Accent);
      Set_Layout (View.Drop_Line, Place => Absolute, Height => Drop_Line_Height);
      Widgets.Set_Visible (View.Drop_Line, False);
      --  The ghost of the block dragged: its title, in a box of the same
      --  outline, a little clear.
      Widgets.Add (View.Content, View.Ghost);
      Widgets.Add (View.Ghost, View.Ghost_Title);
      declare
         Fill : Themes.Color := Themes.Resolve (Colors, Row_Fill);
      begin
         Fill.Alpha := 225;
         Panels.Set_Fill_Color (View.Ghost, Fill);
      end;
      Panels.Set_Border (View.Ghost, Themes.Focus);
      Set_Layout
        (View.Ghost, Place => Absolute, Flow => Row, Align => Center,
         Padding => (Left | Right => Index_Pad + Outline_Handle + Tool_Gap, others => <>));
      Set_Layout (View.Ghost_Title, Grow => 1.0, Width => 0.0, Height => Index_Height);
      Widgets.Set_Visible (View.Ghost, False);
      Outlines.Listen (Item);
      Widgets.Set_Visible (View.View, False);
   end Build_Outline;

   procedure Build_Settings (Item : in out Session);
   --  Add and style the settings: a bar across the top that stays, and the
   --  form, as wide as a page in the writing view, centred and scrolled.

   procedure Build_Settings (Item : in out Session) is
      Prefs : Settings_Parts renames Item.Prefs;

      procedure Line (Part : in out Widgets.Widget'Class; High : Float) is
      begin
         Set_Layout (Part, Height => High, Shrink => 0.0);
      end Line;

      procedure Radio (Part : in out Checks.Check; Name : String) is
      begin
         Checks.Set_Kind (Part, Checks.Radio);
         Checks.Set_Label (Part, Name);
         Checks.Set_Focusable (Part, True);
         Line (Part, Settings_Line);
      end Radio;
   begin
      Widgets.Add (Item.Root.Window_Panel, Prefs.Settings_Panel);
      Widgets.Add (Prefs.Settings_Panel, Prefs.Settings_Bar);
      Widgets.Add (Prefs.Settings_Bar, Prefs.Settings_Close, Prefs.Settings_Title);
      Widgets.Add (Prefs.Settings_Panel, Prefs.Settings_Scroll);
      Widgets.Add (Prefs.Settings_Scroll, Prefs.Settings_Content);
      Widgets.Add (Prefs.Settings_Content, Prefs.Settings_Form);
      Widgets.Add
        (Prefs.Settings_Form, Prefs.Display_Heading, Prefs.Theme_Name, Prefs.Theme_Light,
         Prefs.Theme_Dark, Prefs.Theme_System);
      Widgets.Add
        (Prefs.Settings_Form, Prefs.AI_Heading, Prefs.AI_Enable, Prefs.AI_Model_Name, Prefs.AI_Hub_Note,
         Prefs.AI_Select);
      Widgets.Add (Prefs.Settings_Form, Prefs.AI_Test_Row);
      Widgets.Add (Prefs.AI_Test_Row, Prefs.AI_Test_Button, Prefs.AI_Test_State);
      for Each of Prefs.AI_Notes loop
         Widgets.Add (Prefs.Settings_Form, Each);
      end loop;
      Widgets.Add (Prefs.Settings_Panel, Prefs.AI_Menu);
      Widgets.Add
        (Prefs.Settings_Form, Prefs.Speech_Heading, Prefs.Model_Name, Prefs.Model_Native,
         Prefs.Model_Parakeet, Prefs.Download_Row);
      Widgets.Add (Prefs.Download_Row, Prefs.Download_Button, Prefs.Delete_Button, Prefs.Download_State);
      Widgets.Add (Prefs.Settings_Form, Prefs.Download_Bar);

      Set_Layout (Prefs.Settings_Panel, Flow => Column, Grow => 1.0);
      Panels.Set_Fill (Prefs.Settings_Panel, Desk);

      --  The bar, outside what scrolls, so that it stays: the way back
      --  at the left (clear of the window's own buttons), as in a project, then the title.
      Panels.Set_Fill (Prefs.Settings_Bar, Toolbar);
      Set_Layout
        (Prefs.Settings_Bar, Height => Toolbar_Size, Shrink => 0.0, Flow => Row, Align => Center,
         Padding => (Left  => (if Item.Shell.Windowed then Header_Inset else Bar_Inset),
                     Right => Bar_Inset,
                     others => <>));
      Labels.Set_Text (Prefs.Settings_Title, "Settings");
      Labels.Set_Style (Prefs.Settings_Title, Pomarine.Line_Texts.Heading);
      Labels.Set_Ink (Prefs.Settings_Title, Themes.Bar_Ink);
      Set_Layout (Prefs.Settings_Title, Grow => 1.0, Width => 0.0, Height => Tab_Height);
      Buttons.Set_Label (Prefs.Settings_Close, "Projects");
      Buttons.Set_Icon (Prefs.Settings_Close, Icon_Set.Back);
      Buttons.Set_Captioned (Prefs.Settings_Close, True);
      Buttons.Set_Kind (Prefs.Settings_Close, Buttons.Quiet);
      Set_Layout
        (Prefs.Settings_Close, Width => Back_Width, Height => Tab_Height, Shrink => 0.0,
         Margin => (Right => Name_Gap, others => <>));

      --  The form, on a page of its own, in the middle.
      Set_Layout (Prefs.Settings_Scroll, Grow => 1.0, Height => 0.0);
      Set_Layout
        (Prefs.Settings_Content, Flow => Column, Shrink => 0.0, Align => Center,
         Padding => (others => Page_Margin));
      Panels.Set_Fill (Prefs.Settings_Form, Paper);
      Panels.Set_Border (Prefs.Settings_Form, Themes.Border);
      Panels.Set_Shadow (Prefs.Settings_Form, Themes.Shadow);
      Set_Layout
        (Prefs.Settings_Form, Flow => Column, Shrink => 0.0, Width => Page_Width,
         Padding => (others => Dialog_Pad), Shadowed => True, Gap => Row_Gap);
      Prefs.Form_Wide := Page_Width;

      --  Display: its one option, Theme.
      Labels.Set_Text (Prefs.Display_Heading, "DISPLAY");
      Labels.Set_Style (Prefs.Display_Heading, Pomarine.Line_Texts.Caption);
      Line (Prefs.Display_Heading, Heading_Height);
      Labels.Set_Text (Prefs.Theme_Name, "Theme");
      Labels.Set_Style (Prefs.Theme_Name, Pomarine.Line_Texts.Strong);
      Line (Prefs.Theme_Name, Settings_Line);
      Radio (Prefs.Theme_Light, "Light");
      Radio (Prefs.Theme_Dark, "Dark");
      Radio (Prefs.Theme_System, "System");

      --  AI: Enable, and, with it on, the model to run.
      Labels.Set_Text (Prefs.AI_Heading, "AI");
      Labels.Set_Style (Prefs.AI_Heading, Pomarine.Line_Texts.Caption);
      Line (Prefs.AI_Heading, Heading_Height);
      Set_Layout (Prefs.AI_Heading, Margin => (Top => Heading_Top, others => <>));
      Switches.Set_Label (Prefs.AI_Enable, "Enable");
      Switches.Set_Focusable (Prefs.AI_Enable, True);
      Line (Prefs.AI_Enable, Settings_Line);
      Labels.Set_Text (Prefs.AI_Model_Name, "Model");
      Labels.Set_Style (Prefs.AI_Model_Name, Pomarine.Line_Texts.Strong);
      Line (Prefs.AI_Model_Name, Settings_Line);
      Labels.Set_Text (Prefs.AI_Hub_Note, "Hugging Face support not detected");
      Labels.Set_Ink (Prefs.AI_Hub_Note, Quiet_Ink);
      Line (Prefs.AI_Hub_Note, Settings_Line);
      Selects.Set_Value (Prefs.AI_Select, None_Selected);
      Line (Prefs.AI_Select, Download_Height);
      Line (Prefs.AI_Test_Row, Download_Height);
      Set_Layout
        (Prefs.AI_Test_Row, Flow => Row, Align => Center, Gap => Gap,
         Margin => (Top => Gap, others => <>));
      Buttons.Set_Label (Prefs.AI_Test_Button, "Test");
      Buttons.Set_Kind (Prefs.AI_Test_Button, Buttons.Primary);
      Buttons.Set_Focusable (Prefs.AI_Test_Button, True);
      Set_Layout
        (Prefs.AI_Test_Button, Width => Download_Width, Height => Download_Height, Shrink => 0.0);
      Labels.Set_Ink (Prefs.AI_Test_State, Quiet_Ink);
      Set_Layout (Prefs.AI_Test_State, Grow => 1.0, Width => 0.0, Height => Download_Height);
      for Each of Prefs.AI_Notes loop
         Line (Each, Note_Line);
         Widgets.Set_Visible (Each, False);
      end loop;
      Set_Layout (Prefs.AI_Menu, Place => Absolute, Width => Menu_Width);
      Widgets.Set_Visible (Prefs.AI_Menu, False);

      --  Speech: its one option, Model.
      Labels.Set_Text (Prefs.Speech_Heading, "SPEECH");
      Labels.Set_Style (Prefs.Speech_Heading, Pomarine.Line_Texts.Caption);
      Line (Prefs.Speech_Heading, Heading_Height);
      Set_Layout (Prefs.Speech_Heading, Margin => (Top => Heading_Top, others => <>));
      Labels.Set_Text (Prefs.Model_Name, "Model");
      Labels.Set_Style (Prefs.Model_Name, Pomarine.Line_Texts.Strong);
      Line (Prefs.Model_Name, Settings_Line);
      Radio (Prefs.Model_Native, "MacOS");
      Radio (Prefs.Model_Parakeet, "Parakeet");

      Line (Prefs.Download_Row, Download_Height);
      Set_Layout
        (Prefs.Download_Row, Flow => Row, Align => Center, Gap => Gap,
         Margin => (Top => Gap, others => <>));
      Buttons.Set_Label (Prefs.Download_Button, "Download");
      Buttons.Set_Kind (Prefs.Download_Button, Buttons.Primary);
      Set_Layout
        (Prefs.Download_Button, Width => Download_Width, Height => Download_Height, Shrink => 0.0);
      Buttons.Set_Label (Prefs.Delete_Button, "Delete");
      Buttons.Set_Kind (Prefs.Delete_Button, Buttons.Danger);
      Buttons.Set_Focusable (Prefs.Download_Button, True);
      Buttons.Set_Focusable (Prefs.Delete_Button, True);
      Set_Layout
        (Prefs.Delete_Button, Width => Download_Width, Height => Download_Height, Shrink => 0.0);
      Widgets.Set_Visible (Prefs.Delete_Button, False);
      Labels.Set_Ink (Prefs.Download_State, Quiet_Ink);
      Set_Layout (Prefs.Download_State, Grow => 1.0, Width => 0.0, Height => Download_Height);
      Line (Prefs.Download_Bar, Progress_Height);
      Widgets.Set_Visible (Prefs.Download_Bar, False);
      Widgets.Set_Visible (Prefs.Settings_Panel, False);
   end Build_Settings;

   procedure Build_Dialog_Bar
     (Bar   : in out Panels.Panel;
      Named : in out Labels.Label;
      Close : in out Buttons.Button;
      Name  : String);
   --  Style the dark bar across the top of a dialog, as a window's: its
   --  title, white, and a small button to close it, at the right.

   procedure Build_Dialog_Bar
     (Bar   : in out Panels.Panel;
      Named : in out Labels.Label;
      Close : in out Buttons.Button;
      Name  : String) is
   begin
      Panels.Set_Fill (Bar, Toolbar);
      Set_Layout
        (Bar, Flow => Row, Align => Center, Height => Dialog_Bar_Height, Shrink => 0.0,
         Padding => (Left | Right => Dialog_Bar_Pad, others => <>));
      Labels.Set_Text (Named, Name);
      Labels.Set_Style (Named, Pomarine.Line_Texts.Strong);
      Labels.Set_Ink (Named, Themes.Bar_Ink);
      Set_Layout (Named, Grow => 1.0, Width => 0.0, Height => Dialog_Bar_Height);
      Buttons.Set_Label (Close, "Close");
      Buttons.Set_Icon (Close, Pomarine.Icons.Close);
      Buttons.Set_Icon_Size (Close, Dialog_Close_Icon);
      Set_Layout (Close, Width => Dialog_Close_Size, Height => Dialog_Close_Size, Shrink => 0.0);
   end Build_Dialog_Bar;

   procedure Build_Border (Border : in out Panels.Panel);
   --  Style the outline round a dialog.

   procedure Build_Border (Border : in out Panels.Panel) is
   begin
      Panels.Set_Fill (Border, Themes.Border);
      Set_Layout (Border, Flow => Column, Outlined => True);
   end Build_Border;

   procedure Build_Modal (Item : in out Session);
   --  Add and style the dialog to confirm a deletion: over all else.

   procedure Build_Modal (Item : in out Session) is
      Ask : Confirm_Parts renames Item.Confirm;
   begin
      Widgets.Add (Item.Root.Window_Panel, Ask.Overlay);
      Widgets.Add (Ask.Overlay, Ask.Dialog_Border);
      Widgets.Add (Ask.Dialog_Border, Ask.Dialog_Bar);
      Widgets.Add (Ask.Dialog_Bar, Ask.Dialog_Title, Ask.Dialog_Close);
      Widgets.Add (Ask.Dialog_Border, Ask.Dialog);
      Widgets.Add (Ask.Dialog, Ask.Confirm_Message, Ask.Confirm_Note);
      Widgets.Add (Ask.Dialog_Border, Ask.Dialog_Rule, Ask.Confirm_Buttons);
      Widgets.Add (Ask.Confirm_Buttons, Ask.Confirm_Cancel, Ask.Confirm_Delete);

      Panels.Set_Fill (Ask.Overlay, Themes.Scrim);
      Build_Border (Ask.Dialog_Border);
      Build_Dialog_Bar (Ask.Dialog_Bar, Ask.Dialog_Title, Ask.Dialog_Close, "Delete project");
      Panels.Set_Fill (Ask.Dialog, Paper);
      Labels.Set_Text (Ask.Confirm_Note, "This cannot be undone.");
      Buttons.Set_Label (Ask.Confirm_Cancel, "Cancel");
      Buttons.Set_Label (Ask.Confirm_Delete, "Delete");
      Buttons.Set_Icon (Ask.Confirm_Delete, Icon_Set.Delete);
      Buttons.Set_Icon_Size (Ask.Confirm_Delete, Mic_Icon_Size);
      Buttons.Set_Captioned (Ask.Confirm_Delete, True);
      Buttons.Set_Kind (Ask.Confirm_Delete, Buttons.Danger);
      Panels.Set_Fill (Ask.Dialog_Rule, Themes.Border);
      Set_Layout (Ask.Dialog_Rule, Height => Hairline);
      Panels.Set_Fill (Ask.Confirm_Buttons, Themes.Tint);

      --  Not in the layout of the screens: over them, all of the window,
      --  with the dialog in the middle.
      Set_Layout
        (Ask.Overlay, Place => Absolute, Position => (others => 0.0), Flow => Column,
         Spread => Center, Align => Center);

      Set_Layout (Ask.Dialog_Border, Width => Dialog_Width);
      Set_Layout (Ask.Dialog, Flow => Column, Padding => (others => Dialog_Pad));
      Set_Layout (Ask.Confirm_Message, Height => Dialog_Line);
      Set_Layout (Ask.Confirm_Note, Height => Dialog_Line);

      Set_Layout
        (Ask.Confirm_Buttons, Flow => Row, Spread => Finish,
         Padding => (others => Dialog_Foot_Pad), Gap => Row_Gap);
      Set_Layout (Ask.Confirm_Cancel, Height => Dialog_Button_Height, Width => Dialog_Button_Width);
      Set_Layout (Ask.Confirm_Delete, Height => Dialog_Button_Height, Width => Dialog_Button_Width);
   end Build_Modal;

   procedure Build_List (Item : in out Session);
   --  Add and style the list of items: a dialog over all else.

   procedure Build_List (Item : in out Session) is
      Items_View : List_Parts renames Item.Item_List;
   begin
      Widgets.Add (Item.Root.Window_Panel, Items_View.List_Overlay);
      Widgets.Add (Items_View.List_Overlay, Items_View.List_Border);
      Widgets.Add (Items_View.List_Border, Items_View.List_Head);
      Widgets.Add (Items_View.List_Head, Items_View.List_Heading, Items_View.List_Close);
      Widgets.Add (Items_View.List_Border, Items_View.List_Dialog);
      Widgets.Add (Items_View.List_Dialog, Items_View.List_View, Items_View.List_None);
      Items_View.List_Rows.Owner := Item'Unchecked_Access;
      Pomarine.Widgets.Lists.Set_Model
        (Items_View.List_View, Items_View.List_Rows'Unchecked_Access);
      Pomarine.Widgets.Lists.Set_Row_Height (Items_View.List_View, Row_Height);

      Panels.Set_Fill (Items_View.List_Overlay, Themes.Scrim);
      Build_Border (Items_View.List_Border);
      Build_Dialog_Bar
        (Items_View.List_Head, Items_View.List_Heading, Items_View.List_Close, "Items");
      Panels.Set_Fill (Items_View.List_Dialog, Paper);
      Labels.Set_Text (Items_View.List_None, No_Items);

      Set_Layout
        (Items_View.List_Overlay, Place => Absolute, Position => (others => 0.0),
         Flow => Column, Spread => Center, Align => Center);

      Set_Layout (Items_View.List_Border, Width => List_Width, Height => List_Height);
      Set_Layout
        (Items_View.List_Dialog, Flow => Column, Grow => 1.0, Height => 0.0,
         Padding => (others => Dialog_Pad));

      --  The list takes what the title bar and the border leave.
      Set_Layout (Items_View.List_View, Grow => 1.0, Height => 0.0);
      Set_Layout (Items_View.List_None, Height => Title_Height);
   end Build_List;

   procedure Make_Tab_Stops (Item : in out Session);
   --  Let Tab reach the buttons, and the cards that are clicked, as it
   --  does the fields: in the order they are in, which is the order of the
   --  screen. A click on one does not take the focus from a field.

   procedure Make_Tab_Stops (Item : in out Session) is
      procedure Stop (Part : in out Buttons.Button) is
      begin
         Buttons.Set_Focusable (Part, True);
      end Stop;

      procedure Stop (Part : in out Grips.Grip) is
      begin
         Grips.Set_Focusable (Part, True);
      end Stop;
   begin
      Stop (Item.Home_View.New_Button);
      Stop (Item.Home_View.Settings_Button);
      Stop (Item.Home_View.New_Card);
      Widgets.Set_Accessible_Name (Item.Home_View.New_Card, "New project");
      --  The plus in the card does what the card does: not a stop of its own,
      --  nor a button more to an assistive technology.
      Widgets.Hide_From_Accessibility (Item.Home_View.New_Card_Plus);
      Stop (Item.Home_View.Ok_Button);
      Stop (Item.Home_View.Cancel_Button);
      for Each of Item.Home_View.Cards loop
         Stop (Each.Peek);
         Stop (Each.Rename);
         Stop (Each.Delete);
      end loop;
      Stop (Item.Confirm.Dialog_Close);
      Stop (Item.Confirm.Confirm_Cancel);
      Stop (Item.Confirm.Confirm_Delete);
      Stop (Item.Prefs.Settings_Close);
      Stop (Item.Dock.Tool_Item);
      Stop (Item.Dock.Tool_Source);
      Stop (Item.Dock.Tool_List);
      Stop (Item.Item_List.List_Close);
      Stop (Item.Page_View.Docs_Add);
      Stop (Item.Page_View.Docs_Folder);
      for Each of Item.Docs.Pages loop
         Stop (Each.Sources_Button);
         Stop (Each.Mic_Button);
      end loop;
      for Each of Item.Reading.Source_Rows loop
         Stop (Each.Row);
      end loop;
   end Make_Tab_Stops;

   procedure Set_Up
     (Item       : in out Session;
      Source     : String;
      File_Name  : String;
      Store_Path : String)
   is
   begin
      Projects.Open (Item.Nav.Store, Store_Path);
      Items.Schema.Prepare (Item.Nav.Store);
      Scripts.Load (Item.Host.Script, Source, File_Name);
      Item.Prefs.Config_Dir :=
        Ada.Strings.Unbounded.To_Unbounded_String
          (Preferences.Config_Directory (Store_Path));
      Item.Prefs.Persist := Store_Path /= Projects.Memory;
      if Item.Prefs.Persist then
         declare
            Kept : constant Natural :=
              Preferences.Load_Sidebar_Width (Ada.Strings.Unbounded.To_String (Item.Prefs.Config_Dir));
         begin
            if Kept /= 0 then
               Item.Page_View.Sidebar_Wide :=
                 Float'Max (Sidebar_Least, Float'Min (Sidebar_Most, Float (Kept)));
            end if;
         end;
         Item.Prefs.Speech_Choice :=
           Preferences.Load_Speech_Model
             (Ada.Strings.Unbounded.To_String (Item.Prefs.Config_Dir));
         Item.Prefs.Theme_Chosen :=
           Preferences.Load_Theme
             (Ada.Strings.Unbounded.To_String (Item.Prefs.Config_Dir));
         Item.Prefs.AI_On :=
           Preferences.Load_AI_Enabled
             (Ada.Strings.Unbounded.To_String (Item.Prefs.Config_Dir));
         Item.Prefs.AI_Model :=
           Ada.Strings.Unbounded.To_Unbounded_String
             (Preferences.Load_AI_Model
                (Ada.Strings.Unbounded.To_String (Item.Prefs.Config_Dir)));
         Item.Outline_View.With_Notes :=
           Preferences.Load_Generate_Notes
             (Ada.Strings.Unbounded.To_String (Item.Prefs.Config_Dir));
         Outlines.Show_Choice (Item);
         --  The system may have let go of the compiled model: have it
         --  ready, in the background, before it is wanted.
         if Preferences."=" (Item.Prefs.Speech_Choice, Preferences.Parakeet) then
            Speech.Models.Preload
              (Preferences.Speech_Model_Directory
                 (Ada.Strings.Unbounded.To_String (Item.Prefs.Config_Dir)));
         end if;
      else
         --  Offscreen, the light theme, whatever the system's is.
         Item.Prefs.Theme_Chosen := Preferences.Light;
      end if;
      Widgets.Set_Density (Item.Root.Widgets, Item.Shell.Density);
      Widgets.Set_Line_Texts (Item.Root.Widgets, Item.Host.Lines);
      Widgets.Set_Icons (Item.Root.Widgets, Item.Host.Pictures);
      Icon_Set.Install (Item.Host.Pictures, Share_Directory ("icons"));
      if Item.Shell.Windowed then
         Widgets.Set_Clipboard (Item.Root.Widgets, Item.Shell.System_Board);
      else
         Widgets.Set_Clipboard (Item.Root.Widgets, Item.Shell.Own_Board);
      end if;

      --  Tab and Shift+Tab move the focus between the controls made
      --  focusable (see Make_Tab_Stops) and the text fields.
      Widgets.Set_Tab_Navigation (Item.Root.Widgets, True);
      Widgets.Set_Root (Item.Root.Widgets, Item.Root.Window_Panel);
      Set_Layout (Item.Root.Window_Panel, Flow => Column);
      if Item.Shell.Windowed then
         Build_Header (Item);
      end if;
      Build_Home (Item);
      Build_Project (Item);
      Build_Write (Item);
      Build_Outline (Item);
      Build_Tray (Item);
      Build_Settings (Item);
      Build_Modal (Item);
      Build_List (Item);

      Responses.Install (Item);
      Make_Tab_Stops (Item);
      Widgets.Set_Listener (Item.Root.Widgets, Item.Replies'Unchecked_Access);
      Item.Replies.Owner := Item'Unchecked_Access;
      Buttons.Set_Label (Item.Home_View.Ok_Button, "OK");
      Buttons.Set_Kind (Item.Home_View.Ok_Button, Buttons.Primary);
      Buttons.Set_Label (Item.Home_View.Cancel_Button, "Cancel");
      Text_Fields.Set_Shared
        (Item.Title_Edit.Edit_Field, Item.Host.Doc_Resources'Unchecked_Access);
      Text_Fields.Configure
        (Item.Title_Edit.Edit_Field, Pomarine.Line_Texts.Interface_Font, Edit_Size);

      --  It starts at the home screen.
      Widgets.Set_Visible (Item.Toolbar.Project_Panel, False);
      Widgets.Set_Visible (Item.Page_View.Write_View, False);
      Widgets.Set_Visible (Item.Outline_View.View, False);
      Widgets.Set_Visible (Item.Confirm.Overlay, False);
      Widgets.Set_Visible (Item.Item_List.List_Overlay, False);
      Widgets.Set_Visible (Item.Dock.Dock_Panel, False);
      Recent.Refresh (Item);
      --  Before any event: the widgets must know where they are.
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Set_Up;

end Viewer.Build;
