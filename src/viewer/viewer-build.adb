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
with Pomarine.Scrollbars;
with Pomarine.Themes;
with Pomarine.Widgets;
with Pomarine.Widgets.Layouts;
with Pomarine.Widgets.Scrollers;
with Pomarine.Text_Areas;
with Viewer.Links;
with Viewer.Recent;
with Viewer.Style;

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
      Widgets.Add (Bar.Tabs, Bar.Canvas_Tab, Bar.Write_Tab);
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
      Buttons.Set_Label (Bar.Canvas_Tab, "Canvas");
      Buttons.Set_Selected (Bar.Canvas_Tab, True);
      Buttons.Set_Label (Bar.Write_Tab, "Write");
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
      Widgets.Add (View.Docs_Content, Item.Naming.Dir_Field);
      Widgets.Add (View.Sidebar, View.Sources_Heading);
      Build_Index (View.Sources_Scroll, View.Sources_Content, View.Sources_None, No_Sources);
      for Each of Item.Reading.Source_Rows loop
         Build_Row (View.Sources_Content, Each, Counted => False);
      end loop;
      Widgets.Add (View.Sources_Content, View.Sources_None);
      Widgets.Add (View.Sources_Content, Item.Naming.Source_Field);
      Set_Layout (View.Sources_None, Height => Index_Height);
      Widgets.Add (View.Write_View, View.Sidebar_Rule, View.Pages_Scroll);
      Widgets.Add (View.Pages_Scroll, View.Pages_Content);
      for Each of Item.Docs.Pages loop
         Widgets.Add (View.Pages_Content, Each.Box);
         Widgets.Add (Each.Box, Each.Bar);
         Widgets.Add (Each.Bar, Each.Heading_Area);
         Widgets.Add (Each.Heading_Area, Each.Heading);
         Widgets.Add (Each.Bar, Each.Title_Field, Each.Sources_Button, Each.Mic_Button);
         Widgets.Add (Each.Box, Each.Sheet);
         Widgets.Add (Each.Sheet, Each.Text);
         Widgets.Add (Each.Box, Each.Words);
      end loop;
      Widgets.Add (View.Write_View, View.Pane);
      Widgets.Add (View.Pane, View.Pane_Edge, View.Pane_Body);
      --  Over the rest, last.
      for Each of Item.Reading.Readers loop
         Items.Readers.Build (Each, View.Write_View, Toolbar, Pixels);
      end loop;
      Widgets.Add (View.Write_View, View.Menu);
      Set_Layout (View.Menu, Place => Absolute, Width => Menu_Width);
      Widgets.Set_Visible (View.Menu, False);
      Widgets.Add (Item.Toolbar.Content_Panel, Item.Context.Context_Menu);
      Set_Layout (Item.Context.Context_Menu, Place => Absolute, Width => Context_Width);
      Widgets.Set_Visible (Item.Context.Context_Menu, False);
      Items.Readers.Build
        (Item.Reading.Pane_Reader, View.Pane_Body, Toolbar, Pixels,
         Pinned => True);

      Panels.Set_Fill (View.Write_View, Desk);
      Set_Layout (View.Write_View, Flow => Row, Grow => 1.0, Height => 0.0);

      --  The sidebar: two lists one above the other, with a line at its
      --  right.
      Panels.Set_Fill (View.Sidebar, Side_Fill);
      Set_Layout
        (View.Sidebar, Width => Sidebar_Width, Shrink => 0.0, Flow => Column, Gap => Sidebar_Gap,
         Padding => (Top => Sidebar_Pad + Heading_Top, others => Sidebar_Pad));
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
         Line (Part, Settings_Line);
      end Radio;
   begin
      Widgets.Add (Item.Root.Window_Panel, Prefs.Settings_Panel);
      Widgets.Add (Prefs.Settings_Panel, Prefs.Settings_Bar);
      Widgets.Add (Prefs.Settings_Bar, Prefs.Settings_Title, Prefs.Settings_Close);
      Widgets.Add (Prefs.Settings_Panel, Prefs.Settings_Scroll);
      Widgets.Add (Prefs.Settings_Scroll, Prefs.Settings_Content);
      Widgets.Add (Prefs.Settings_Content, Prefs.Settings_Form);
      Widgets.Add
        (Prefs.Settings_Form, Prefs.Display_Heading, Prefs.Theme_Name, Prefs.Theme_Light,
         Prefs.Theme_Dark, Prefs.Theme_System);
      Widgets.Add
        (Prefs.Settings_Form, Prefs.Speech_Heading, Prefs.Model_Name, Prefs.Model_Native,
         Prefs.Model_Parakeet, Prefs.Download_Row);
      Widgets.Add (Prefs.Download_Row, Prefs.Download_Button, Prefs.Delete_Button, Prefs.Download_State);
      Widgets.Add (Prefs.Settings_Form, Prefs.Download_Bar);

      Set_Layout (Prefs.Settings_Panel, Flow => Column, Grow => 1.0);
      Panels.Set_Fill (Prefs.Settings_Panel, Desk);

      --  The bar, outside what scrolls, so that it stays: the title at the
      --  left (clear of the window's own buttons) and Close at the right.
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
      Buttons.Set_Label (Prefs.Settings_Close, "Close");
      Buttons.Set_Icon (Prefs.Settings_Close, Pomarine.Icons.Close);
      Buttons.Set_Captioned (Prefs.Settings_Close, True);
      Buttons.Set_Kind (Prefs.Settings_Close, Buttons.Quiet);
      Set_Layout (Prefs.Settings_Close, Width => Items_Width, Height => Tab_Height, Shrink => 0.0);

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
      Widgets.Add (Items_View.List_Dialog, Items_View.List_Scroll);
      Widgets.Add (Items_View.List_Scroll, Items_View.List_Content);
      Widgets.Add (Items_View.List_Content, Items_View.List_None);
      for Each of Items_View.List_Rows loop
         Widgets.Add (Items_View.List_Content, Each.Panel);
         Widgets.Add (Each.Panel, Each.Name);
         Widgets.Add (Each.Name, Each.Caption);
         Widgets.Add (Each.Panel, Each.Toggle, Each.Remove);
      end loop;

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

      --  The scroller takes what the bar leaves; the rows go in a column
      --  in it, as tall as they are.
      Set_Layout (Items_View.List_Scroll, Grow => 1.0, Height => 0.0);
      Set_Layout
        (Items_View.List_Content, Flow => Column, Shrink => 0.0, Gap => List_Gap,
         --  Room at the right for the scroll bar.
         Padding => (Right => Pomarine.Scrollbars.Thickness, others => <>));
      Set_Layout (Items_View.List_None, Height => Title_Height);
      for Each of Items_View.List_Rows loop
         Panels.Set_Fill (Each.Panel, Themes.Tint);
         Panels.Set_Border (Each.Panel, Themes.Border);
         Set_Layout
           (Each.Panel, Flow => Row, Align => Center, Height => Row_Height, Shrink => 0.0,
            Padding => (Left => Row_Gap, others => <>), Gap => Row_Gap);
         Set_Layout
           (Each.Name, Grow => 1.0, Width => 0.0, Height => Row_Height, Flow => Row, Align => Center,
            Padding => (Left => Row_Gap, others => <>));
         Grips.Set_Wanted_Cursor (Each.Name, SDL3.Cursors.Pointer);
         Grips.Set_Hover_Outline (Each.Name, Themes.Foreground);
         Set_Layout (Each.Caption, Grow => 1.0, Width => 0.0, Height => Row_Height);
         Set_Layout (Each.Toggle, Width => Toggle_Width, Height => Row_Height);
         Set_Layout (Each.Remove, Width => Remove_Width, Height => Row_Height);
         Buttons.Set_Label (Each.Remove, "Remove");
         Buttons.Set_Icon (Each.Remove, Icon_Set.Delete);
         Buttons.Set_Kind (Each.Remove, Buttons.Danger);
      end loop;
   end Build_List;

   procedure Bind_Commands (Item : in out Session);
   --  Say what the buttons, checks and menus are for: what each says when
   --  it is clicked, and which of many it is (see Viewer.Responses).

   procedure Bind_Commands (Item : in out Session) is
   begin
      --  The home screen
      Commands.Bind (Item.Home_View.New_Button, Start_Project);
      Commands.Bind (Item.Home_View.New_Card, Start_Project);
      Commands.Bind (Item.Home_View.New_Card_Plus, Start_Project);
      Commands.Bind (Item.Home_View.Settings_Button, Open_Settings);
      Commands.Bind (Item.Home_View.Ok_Button, Accept_Rename);
      Commands.Bind (Item.Home_View.Cancel_Button, Cancel_Rename);
      Commands.Bind (Item.Title_Edit.Edit_Field, Accept_Rename);
      for Card in Item.Home_View.Cards'Range loop
         Commands.Bind (Item.Home_View.Cards (Card).Peek, Open_Project, Card);
         Commands.Bind (Item.Home_View.Cards (Card).Name, Open_Project, Card);
         Commands.Bind (Item.Home_View.Cards (Card).Rename, Rename_Project, Card);
         Commands.Bind (Item.Home_View.Cards (Card).Delete, Delete_Project, Card);
      end loop;

      --  The dialog that asks before deleting
      Commands.Bind (Item.Confirm.Confirm_Delete, Confirm_Deletion);
      Commands.Bind (Item.Confirm.Confirm_Cancel, Cancel_Deletion);
      Commands.Bind (Item.Confirm.Dialog_Close, Cancel_Deletion);

      --  The settings
      Commands.Bind (Item.Prefs.Settings_Close, Close_Settings);
      Commands.Bind (Item.Prefs.Theme_Light, Choose_Light);
      Commands.Bind (Item.Prefs.Theme_Dark, Choose_Dark);
      Commands.Bind (Item.Prefs.Theme_System, Choose_System);
      Commands.Bind (Item.Prefs.Model_Native, Choose_MacOS);
      Commands.Bind (Item.Prefs.Model_Parakeet, Choose_Parakeet);
      Commands.Bind (Item.Prefs.Download_Button, Download_Model);
      Commands.Bind (Item.Prefs.Delete_Button, Delete_Model);

      --  A project: the bar, the tray, and the list of items
      Commands.Bind (Item.Toolbar.Close_Button, Leave_Project);
      Commands.Bind (Item.Toolbar.Canvas_Tab, Show_Canvas);
      Commands.Bind (Item.Toolbar.Write_Tab, Show_Writing);
      Commands.Bind (Item.Dock.Tool_Item, Add_Document);
      Commands.Bind (Item.Dock.Tool_Source, Add_Source);
      Commands.Bind (Item.Dock.Tool_List, Open_List);
      Commands.Bind (Item.Item_List.List_Close, Close_List);
      for Slot in Items.Slot loop
         Commands.Bind (Item.Item_List.List_Rows (Slot).Name, Reveal_Item, Slot);
         Commands.Bind (Item.Item_List.List_Rows (Slot).Toggle, Toggle_Item, Slot);
         Commands.Bind (Item.Item_List.List_Rows (Slot).Remove, Remove_Item, Slot);
      end loop;

      --  The writing view
      Commands.Bind (Item.Page_View.Docs_Add, Add_Page);
      Commands.Bind (Item.Page_View.Docs_Folder, Add_Folder);
      Commands.Bind (Item.Page_View.Menu, Choose_Source);
      Commands.Bind (Item.Context.Context_Menu, Choose_Context);
      for Rank in Items.Slot loop
         Commands.Bind (Item.Docs.Pages (Rank).Sources_Button, Open_Sources, Rank);
         Commands.Bind (Item.Docs.Pages (Rank).Mic_Button, Dictate, Rank);
         Commands.Bind (Item.Reading.Source_Rows (Rank).Row, Toggle_Source, Rank);
      end loop;
   end Bind_Commands;

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
         Item.Prefs.Speech_Choice :=
           Preferences.Load_Speech_Model
             (Ada.Strings.Unbounded.To_String (Item.Prefs.Config_Dir));
         Item.Prefs.Theme_Chosen :=
           Preferences.Load_Theme
             (Ada.Strings.Unbounded.To_String (Item.Prefs.Config_Dir));
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

      Widgets.Set_Root (Item.Root.Widgets, Item.Root.Window_Panel);
      Set_Layout (Item.Root.Window_Panel, Flow => Column);
      if Item.Shell.Windowed then
         Build_Header (Item);
      end if;
      Build_Home (Item);
      Build_Project (Item);
      Build_Write (Item);
      Build_Tray (Item);
      Build_Settings (Item);
      Build_Modal (Item);
      Build_List (Item);

      Bind_Commands (Item);
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
      Widgets.Set_Visible (Item.Confirm.Overlay, False);
      Widgets.Set_Visible (Item.Item_List.List_Overlay, False);
      Widgets.Set_Visible (Item.Dock.Dock_Panel, False);
      Recent.Refresh (Item);
      --  Before any event: the widgets must know where they are.
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Set_Up;

end Viewer.Build;
