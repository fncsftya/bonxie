with Pomarine.Boxes;
with Pomarine.Widgets.Switches;
with Pomarine.Widgets.Editors;
with Items.Windows;
with SDL3.Cursors;
with Icon_Set;
with Pomarine.Line_Texts;
with Pomarine.Themes;
with Pomarine.Widgets;
with Pomarine.Widgets.Layouts;
with Pomarine.Widgets.Scrollers;
with Pomarine.Text_Areas;
with Viewer.Links;
with Viewer.Style;

package body Viewer.Build.Shell_Views is

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
      if not Item.Shell.Windowed then
         Panels.Set_Fill (Front.Home_Side, Mid_Panel);
      end if;
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
         Panels.Set_Radius (Card.Panel, Themes.Large_Radius, Framed => True);
         Set_Layout
           (Card.Panel, Flow => Column, Width => Card_Width, Height => Card_Height, Shrink => 0.0,
            Outlined => True, Shadowed => True);
         --  A line between the picture and what is below it.
         Card.Picture.Set_Corners (Themes.Large_Radius, Pomarine.Boxes.Top_Corners);
         Grips.Set_Fill (Card.Peek, Themes.Border);
         Grips.Set_Radius (Card.Peek, Themes.Large_Radius, Round => Pomarine.Boxes.Top_Corners);
         Grips.Set_Wanted_Cursor (Card.Peek, SDL3.Cursors.Pointer);
         Set_Layout (Card.Peek, Height => Thumb_Height, Flow => Column);
         Set_Layout (Card.Picture, Grow => 1.0, Margin => (Bottom => Hairline, others => <>));
         Panels.Set_Fill (Card.Info, Themes.Tint);
         --  As round as the card's own foot, or its square corner shows between the outline and the shadow.
         Panels.Set_Radius (Card.Info, Themes.Large_Radius, Round => Pomarine.Boxes.Bottom_Corners);
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
      Grips.Set_Border (Front.New_Card, Style.Dashed_Edge, Dashed => True);
      Grips.Set_Radius (Front.New_Card, Themes.Large_Radius);
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

   procedure Build_Project (Item : in out Session) is
      Bar : Toolbar_Parts renames Item.Toolbar;
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
      Widgets.Add (Bar.Tabs, Bar.Publish_Tab);
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
      Labels.Set_Intrinsic (Bar.Project_Title);
      Set_Layout (Bar.Project_Title, Shrink => 0.0, Height => Tab_Height);
      Grips.Set_Hover_Outline (Bar.Title_Area, Themes.Rule);
      Grips.Set_Wanted_Cursor (Bar.Title_Area, SDL3.Cursors.Pointer);
      Set_Layout
        (Bar.Title_Area, Flow => Row, Align => Center, Shrink => 0.0, Height => Tab_Height);
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
      Buttons.Set_Label (Bar.Publish_Tab, "Publish");
      Buttons.Set_Focusable (Bar.Publish_Tab, True);
      Size (Bar.Publish_Tab, Tab_Width, Tab_Height);
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
      Links.Build (Item);
   end Build_Project;

   procedure Make_Window (Item : in out Session; Which : Items.Slot) is
   begin
      Items.Windows.Set_Shared
        (Item.Windows (Which), Item.Host.Doc_Resources'Unchecked_Access);
      Items.Windows.Build
        (Item.Windows (Which), Item.Canvas_View, Item.Dock.Dock_Content, Toolbar, Item.Shell.Density);
   end Make_Window;

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

   procedure Build_Publish (Item : in out Session) is
      View : Publish_Parts renames Item.Publish_View;
   begin
      Widgets.Add (Item.Toolbar.Content_Panel, View.View);
      Widgets.Add (View.View, View.Sidebar, View.Rule, View.Scroll);
      Widgets.Add (View.Scroll, View.Content);
      Set_Layout (View.Scroll, Grow => 1.0, Width => 0.0);
      Widgets.Add (View.Content, View.Text);
      Set_Layout
        (View.Content, Flow => Column, Shrink => 0.0, Align => Center,
         Padding => (others => Page_Margin));
      Widgets.Add (View.Sidebar, View.Section_Headings, View.Document_Headings, View.Export);
      Switches.Set_Label (View.Section_Headings, "Include section headings");
      Switches.Set_Label (View.Document_Headings, "Include document headings");
      Switches.Set_Focusable (View.Section_Headings, True);
      Switches.Set_Focusable (View.Document_Headings, True);
      Set_Layout (View.Section_Headings, Height => 32.0);
      Set_Layout (View.Document_Headings, Height => 32.0);
      if not Item.Shell.Windowed then
         Panels.Set_Fill (View.View, Desk);
      end if;
      Set_Layout (View.View, Flow => Row, Grow => 1.0, Height => 0.0);
      Panels.Set_Fill (View.Sidebar, Side_Fill);
      Set_Layout
        (View.Sidebar, Flow => Column, Width => Item.Page_View.Sidebar_Wide, Shrink => 0.0,
         Padding => (Top => Sidebar_Pad + Heading_Top, others => Sidebar_Pad));
      Panels.Set_Fill (View.Rule, Themes.Border);
      Set_Layout (View.Rule, Width => Hairline, Shrink => 0.0);
      Buttons.Set_Label (View.Export, "Export");
      Buttons.Set_Focusable (View.Export, True);
      Set_Layout (View.Export, Height => Tab_Height);
      Editors.Set_Shared (View.Text, Item.Host.Doc_Resources'Unchecked_Access);
      Editors.Configure
        (View.Text, Pomarine.Line_Texts.Serif, Page_Text_Size, 2000.0,
         Spacing => 0.35 * Page_Text_Size);
      Editors.Set_Paper (View.Text, Paper);
      Editors.Set_Borderless (View.Text, True);
      Editors.Set_Indent (View.Text, Page_Margin - Page_Text_Inset - Page_Border);
      Editors.Attach (View.Text, View.Doc'Unchecked_Access);
      Pomarine.Text_Areas.Set_Grows (Editors.Area (View.Text).all);
      Pomarine.Text_Areas.Set_Read_Only (Editors.Area (View.Text).all);
      Pomarine.Text_Areas.Set_Caret_Visible (Editors.Area (View.Text).all, False);
      Pomarine.Text_Areas.Set_Keyboard_Navigation (Editors.Area (View.Text).all, False);
      Set_Layout
        (View.Text, Shrink => 0.0, Height => Page_Min_Height, Width => Page_Width);
      View.Wide := Page_Width;
      View.High := Page_Min_Height;
      Widgets.Set_Visible (View.View, False);
   end Build_Publish;

end Viewer.Build.Shell_Views;
