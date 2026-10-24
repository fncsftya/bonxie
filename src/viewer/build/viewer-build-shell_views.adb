with Canvas_VM;
with Pomarine.Boxes;
with Pomarine.Widgets.Menus;
with Pomarine.Widgets.Selects;
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
with Pomarine.Icons;

package body Viewer.Build.Shell_Views is

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
   package Selects renames Pomarine.Widgets.Selects;
   package Menus renames Pomarine.Widgets.Menus;
   package Themes renames Pomarine.Themes;

   use Style;
   use Pomarine.Widgets.Layouts;

   procedure Build_Header (Item : in out Session) is
   begin
      --  Not shown: the screens leave room for the window's own buttons
      --  (Header_Size above the home screen, Header_Inset at the left of
      --  the toolbar), and its title is the window's.
      Layouts.Add (Item.Root.Window_Panel, Item.Root.Header_Panel, (Height => Header_Size, others => <>));
      Widgets.Add (Item.Root.Header_Panel, Item.Root.Header_Title);
      Widgets.Set_Visible (Item.Root.Header_Panel, False);
   end Build_Header;

   procedure Build_Home (Item : in out Session) is
      Front : Home_Parts renames Item.Home_View;
      Top  : constant Float := (if Item.Shell.Windowed
                                then Header_Size else 0.0);
      --  Clear of the window's own buttons.
   begin
      Layouts.Add (Item.Root.Window_Panel, Front.Home_Panel, (Flow => Row, Grow => 1.0, others => <>));
      Layouts.Add (Front.Home_Panel, Front.Home_Side,
                   (Flow => Column, Width => Home_Side_Width, Shrink => 0.0,
                    Padding => (Top => Side_Pad + Top, others => Side_Pad), others => <>));
      Layouts.Add (Front.Home_Side, Front.Logo,
                   (Flow => Row, Align => Center, Height => Logo_Height, Margin => (Bottom => Logo_Gap, others => <>),
                    others => <>));
      Layouts.Add (Front.Logo, Front.Logo_Name, (Grow => 1.0, Height => Logo_Height, others => <>));
      Buttons.Add (Front.Home_Side, Front.New_Button,
                   Buttons.Looks ("New project", Buttons.Primary, Icon => Pomarine.Icons.Shown (Icon_Set.Plus),
                                  Captioned => True),
                   (Height => Action_Height, others => <>));
      Layouts.Add (Front.Home_Side, Front.Side_Room, (Grow => 1.0, others => <>));
      Buttons.Add (Front.Home_Side, Front.Settings_Button,
                   Buttons.Looks ("Settings", Icon => Pomarine.Icons.Shown (Icon_Set.Settings), Captioned => True),
                   (Height => Action_Height, others => <>));
      Layouts.Add (Front.Home_Panel, Front.Home_Rule, (Width => Hairline, Shrink => 0.0, others => <>));
      Layouts.Add (Front.Home_Panel, Front.Recent_Panel,
                   (Flow => Column, Grow => 1.0, Width => 0.0,
                    Padding => (Top => Side_Pad + Top, Left => Home_Margin, others => <>), others => <>));
      Layouts.Add (Front.Recent_Panel, Front.Recent_Title,
                   (Height => Logo_Height, Margin => (Bottom => Logo_Gap, others => <>), others => <>));
      Layouts.Add (Front.Recent_Panel, Front.Cards_Scroll, (Grow => 1.0, Height => 0.0, others => <>));
      Layouts.Add (Front.Cards_Scroll, Front.Cards_Content,
                   (Flow => Row, Wrap => True, Align => Start, Shrink => 0.0, Gap => Card_Gap,
                    Padding => (Right => Home_Margin - Card_Gap, Bottom => Home_Margin, others => <>), others => <>));
      for Card of Front.Cards loop
         --  Outlined, with a shadow, which the face leaves room for.
         Layouts.Add (Front.Cards_Content, Card.Panel,
                      (Flow => Column, Width => Card_Width, Height => Card_Height, Shrink => 0.0, Outlined => True,
                       Shadowed => True, others => <>));
         Panels.Set_Fill (Card.Panel, Themes.Tint);
         Panels.Set_Border (Card.Panel, Themes.Border);
         Panels.Set_Shadow (Card.Panel, Themes.Shadow);
         Panels.Set_Radius (Card.Panel, Themes.Large_Radius, Framed => True);
         Layouts.Add (Card.Panel, Card.Peek, (Height => Thumb_Height, Flow => Column, others => <>));
         Grips.Set_Fill (Card.Peek, Themes.Border);
         Grips.Set_Radius (Card.Peek, Themes.Large_Radius, Round => Pomarine.Boxes.Top_Corners);
         Grips.Set_Wanted_Cursor (Card.Peek, SDL3.Cursors.Pointer);
         --  A line between the picture and what is below it.
         Layouts.Add (Card.Peek, Card.Picture,
                      (Grow => 1.0, Margin => (Bottom => Hairline, others => <>), others => <>));
         Card.Picture.Set_Corners (Themes.Large_Radius, Pomarine.Boxes.Top_Corners);
         Layouts.Add (Card.Panel, Card.Info,
                      (Grow => 1.0, Flow => Row, Align => Center, Gap => Row_Gap,
                       Padding => (Left | Right => Card_Pad, others => <>), others => <>));
         Panels.Set_Fill (Card.Info, Themes.Tint);
         --  As round as the card's own foot, or its square corner shows between the outline and the shadow.
         Panels.Set_Radius (Card.Info, Themes.Large_Radius, Round => Pomarine.Boxes.Bottom_Corners);
         Layouts.Add (Card.Info, Card.Name,
                      (Grow => 1.0, Width => 0.0, Flow => Column, Spread => Center, Align_Self => Stretch,
                       others => <>));
         Grips.Set_Wanted_Cursor (Card.Name, SDL3.Cursors.Pointer);
         Layouts.Add (Card.Name, Card.Title, (Height => Card_Title_Height, others => <>));
         Labels.Set_Style (Card.Title, Pomarine.Line_Texts.Heading);
         Layouts.Add (Card.Name, Card.Meta, (Height => Card_Meta_Height, others => <>));
         Buttons.Add (Card.Info, Card.Rename, Buttons.Looks ("Rename", Icon => Pomarine.Icons.Shown (Icon_Set.Edit)),
                      (Width => Card_Button, Height => Card_Button, others => <>));
         Buttons.Add (Card.Info, Card.Delete,
                      Buttons.Looks ("Delete", Buttons.Danger, Icon => Pomarine.Icons.Shown (Icon_Set.Delete)),
                      (Width => Card_Button, Height => Card_Button, others => <>));
      end loop;
      Layouts.Add (Front.Cards_Content, Front.New_Card,
                   (Width => Card_Width - Themes.Shadow_Offset, Height => Card_Height - Themes.Shadow_Offset,
                    Shrink => 0.0, Flow => Column, Spread => Center, Align => Center, others => <>));
      Buttons.Add (Front.New_Card, Front.New_Card_Plus,
                   Buttons.Looks ("New", Buttons.Primary, Icon => Pomarine.Icons.Shown (Icon_Set.Plus)),
                   (Width => Plus_Size, Height => Plus_Size, others => <>));
      Layouts.Add (Front.New_Card, Front.New_Card_Label,
                   (Width => Card_Width / 2.0, Height => Title_Height, Margin => (Top => Row_Gap, others => <>),
                    others => <>));
      Layouts.Add (Front.Cards_Content, Front.No_Rows, (Height => Title_Height, Width => Card_Width, others => <>));

      --  The sidebar: the name, New Project, and Settings at the foot.
      if not Item.Shell.Windowed then
         Panels.Set_Fill (Front.Home_Side, Mid_Panel);
      end if;
      Labels.Set_Text (Front.Logo_Name, "bonxie");
      Labels.Set_Style (Front.Logo_Name, Pomarine.Line_Texts.Display);
      Panels.Set_Fill (Front.Home_Rule, Themes.Border);

      --  The projects: a title, and the cards in rows that wrap. The title
      --  is on the line of the name, as the same height from the same top.
      Labels.Set_Text (Front.Recent_Title, "Recent projects");
      Labels.Set_Style (Front.Recent_Title, Pomarine.Line_Texts.Display);
      Labels.Set_Text (Front.No_Rows, No_Projects);
      Labels.Set_Ink (Front.No_Rows, Quiet_Ink);

      --  The outline of a card, to make a project.
      Grips.Set_Border (Front.New_Card, Style.Dashed_Edge, Dashed => True);
      Grips.Set_Radius (Front.New_Card, Themes.Large_Radius);
      Grips.Set_Wanted_Cursor (Front.New_Card, SDL3.Cursors.Pointer);
      Labels.Set_Text (Front.New_Card_Label, "New project");
      Labels.Set_Style (Front.New_Card_Label, Pomarine.Line_Texts.Strong);
      Labels.Set_Ink (Front.New_Card_Label, Style.New_Project_Ink);
      Labels.Set_Centered (Front.New_Card_Label, True);
   end Build_Home;

   procedure Build_Project (Item : in out Session) is
      Bar : Toolbar_Parts renames Item.Toolbar;

      function Size (Wide, High : Float) return Layouts.Style is
        (Width => Wide, Height => High, Shrink => 0.0, others => <>);

      function Side (Along : Spread_Kind) return Layouts.Style is
        (Flow => Row, Align => Center, Spread => Along, Grow => 1.0, Width => 0.0, others => <>);
   begin
      Layouts.Add (Item.Root.Window_Panel, Bar.Project_Panel, (Flow => Column, Grow => 1.0, others => <>));
      Layouts.Add (Bar.Project_Panel, Bar.Toolbar_Panel,
                   (Height => Toolbar_Size, Shrink => 0.0, Flow => Row, Align => Center,
                    Padding => (Left  => (if Item.Shell.Windowed then Header_Inset else Bar_Inset), Right => Bar_Inset,
                                others => <>),
                    others => <>));
      Layouts.Add (Bar.Toolbar_Panel, Bar.Toolbar_Start, Side (Start));
      Buttons.Add (Bar.Toolbar_Start, Bar.Close_Button,
                   Buttons.Looks ("Projects", Buttons.Quiet, Icon => Pomarine.Icons.Shown (Icon_Set.Back),
                                  Captioned => True, Focusable => True),
                   Size (Back_Width, Tab_Height));
      Layouts.Add (Bar.Toolbar_Start, Bar.Bar_Rule,
                   (Width => Hairline, Height => Bar_Rule_Height, Shrink => 0.0,
                    Margin => (Left | Right => Name_Gap, others => <>), others => <>));
      Layouts.Add (Bar.Toolbar_Start, Bar.Title_Area,
                   (Flow => Row, Align => Center, Shrink => 0.0, Height => Tab_Height, others => <>));
      Layouts.Add (Bar.Title_Area, Bar.Project_Title, (Shrink => 0.0, Height => Tab_Height, others => <>));
      Layouts.Add (Bar.Toolbar_Start, Bar.Title_Field, (Grow => 1.0, Width => 0.0, Height => Tab_Height, others => <>));
      Layouts.Add (Bar.Toolbar_Panel, Bar.Tabs, (Flow => Row, Gap => Tab_Gap, others => <>));
      Buttons.Add (Bar.Tabs, Bar.Outline_Tab, Buttons.Looks ("Outline", Focusable => True),
                   Size (Tab_Width, Tab_Height));
      Buttons.Add (Bar.Tabs, Bar.Canvas_Tab, Buttons.Looks ("Canvas", Focusable => True),
                   Size (Tab_Width, Tab_Height));
      Buttons.Add (Bar.Tabs, Bar.Write_Tab, Buttons.Looks ("Write", Focusable => True),
                   Size (Tab_Width, Tab_Height));
      Buttons.Add (Bar.Tabs, Bar.Publish_Tab, Buttons.Looks ("Publish", Focusable => True),
                   Size (Tab_Width, Tab_Height));
      Layouts.Add (Bar.Toolbar_Panel, Bar.Toolbar_End, Side (Finish));
      Buttons.Add (Bar.Toolbar_End, Item.Dock.Tool_List,
                   Buttons.Looks ("Items", Icon => Pomarine.Icons.Shown (Icon_Set.List), Captioned => True),
                   Size (Items_Width, Tab_Height));
      Layouts.Add (Bar.Project_Panel, Bar.Content_Panel, (Grow => 1.0, Flow => Column, Height => 0.0, others => <>));
      Layouts.Add (Bar.Content_Panel, Item.Canvas_View, (Grow => 1.0, others => <>));
      Layouts.Add (Bar.Project_Panel, Item.Dock.Dock_Panel,
                   (Height => Dock_Height, Shrink => 0.0, Flow => Row, others => <>));
      Layouts.Add (Item.Dock.Dock_Panel, Item.Dock.Dock_Scroll, (Flow => Row, Grow => 1.0, Width => 0.0, others => <>));
      Layouts.Add (Item.Dock.Dock_Scroll, Item.Dock.Dock_Content,
                   (Flow => Row, Shrink => 0.0, Align => Center, Gap => Dock_Gap,
                    Padding => (Left | Right => Dock_Inset, others => <>), others => <>));

      --  The pages are taller than it: it takes what the bars leave.

      --  The bar across the top: the way back and the project's name at the
      --  left, the tabs in the middle (the sides take equal shares), the
      --  list of items at the right.
      Panels.Set_Fill (Bar.Toolbar_Panel, Toolbar);
      Panels.Set_Fill (Bar.Bar_Rule, Rule_Ink);
      Labels.Set_Style (Bar.Project_Title, Pomarine.Line_Texts.Heading);
      Labels.Set_Ink (Bar.Project_Title, Themes.Bar_Ink);
      Labels.Set_Intrinsic (Bar.Project_Title);
      Grips.Set_Hover_Outline (Bar.Title_Area, Themes.Rule);
      Grips.Set_Wanted_Cursor (Bar.Title_Area, SDL3.Cursors.Pointer);
      Text_Fields.Set_Shared
        (Bar.Title_Field, Item.Host.Doc_Resources'Unchecked_Access);
      Text_Fields.Configure
        (Bar.Title_Field, Pomarine.Line_Texts.Interface_Font,
         Pomarine.Line_Texts.Heading_Size);
      Widgets.Set_Visible (Bar.Title_Field, False);

      Buttons.Set_Selected (Bar.Canvas_Tab, True);

      --  The dock of minimised items, under the canvas, and the
      --  windows of the items: on the canvas, or as bars in the dock.
      Panels.Set_Fill (Item.Dock.Dock_Panel, Dock);
      Scrollers.Set_Across (Item.Dock.Dock_Scroll, True);
      Links.Build (Item);
   end Build_Project;

   procedure Make_Window (Item : in out Session; Which : Items.Slot) is
   begin
      Items.Windows.Set_Shared
        (Item.Windows (Which), Item.Host.Doc_Resources'Unchecked_Access);
      Items.Windows.Build
        (Item.Windows (Which), Item.Models (Which).Item, Canvas_VM.Shown_Camera (Item.Canvas_Model.Model),
         Item.Canvas_View, Item.Dock.Dock_Content, Toolbar,
         Item.Shell.Density);
   end Make_Window;

   procedure Build_Tray (Item : in out Session) is
      Tray : Dock_Parts renames Item.Dock;
   begin
      Layouts.Add (Item.Toolbar.Content_Panel, Tray.Tools,
                   (Place => Absolute, Position => (Bottom => Tray_Foot - Themes.Shadow_Offset, others => <>),
                    Width => Tray_Width, Height => Tray_Height, Flow => Row, Align => Center,
                    Padding => (others => Tray_Pad), Shadowed => True, Gap => Tray_Gap, others => <>));
      Buttons.Add (Tray.Tools, Tray.Tool_Item,
                   Buttons.Looks ("Add document", Icon => Pomarine.Icons.Shown (Icon_Set.Document), Captioned => True),
                   (Width => Wide_Tool_Width, Height => Tool_Height, others => <>));
      Buttons.Add (Tray.Tools, Tray.Tool_Source,
                   Buttons.Looks ("Add source", Buttons.Primary, Icon => Pomarine.Icons.Shown (Icon_Set.Link),
                                  Captioned => True),
                   (Width => Tool_Width, Height => Tool_Height, others => <>));
      Panels.Set_Fill (Tray.Tools, Toolbar);
      Panels.Set_Shadow (Tray.Tools, Themes.Shadow);
   end Build_Tray;

   procedure Build_Publish (Item : in out Session) is
      View : Publish_Parts renames Item.Publish_View;
   begin
      Layouts.Add (Item.Toolbar.Content_Panel, View.View, (Flow => Row, Grow => 1.0, Height => 0.0, others => <>));
      Layouts.Add (View.View, View.Sidebar,
                   (Flow => Column, Width => Item.Page_View.Sidebar_Wide, Shrink => 0.0,
                    Padding => (Top => Sidebar_Pad + Heading_Top, others => Sidebar_Pad), others => <>));
      Layouts.Add (View.View, View.Rule, (Width => Hairline, Shrink => 0.0, others => <>));
      Layouts.Add (View.View, View.Source_Scroll, (Grow => 1.0, Width => 0.0, others => <>));
      Layouts.Add (View.View, View.Split_Rule, (Width => Hairline, Shrink => 0.0, others => <>));
      Layouts.Add (View.View, View.Scroll, (Grow => 1.0, Width => 0.0, others => <>));
      Layouts.Add (View.View, View.Format_Menu, (Place => Absolute, Width => Menu_Width, others => <>));
      Layouts.Add (View.Scroll, View.Content,
                   (Flow => Column, Shrink => 0.0, Align => Start,
                    Padding => (Left => Page_Inset, others => Page_Margin), others => <>));
      Layouts.Add (View.Source_Scroll, View.Source_Content,
                   (Flow => Column, Shrink => 0.0, Align => Start,
                    Padding => (Left => Page_Inset, others => Page_Margin), others => <>));
      Layouts.Add (View.Source_Content, View.Source_Text,
                   (Shrink => 0.0, Height => Page_Min_Height, Width => Page_Width, others => <>));
      Panels.Set_Fill (View.Split_Rule, Themes.Border);
      Layouts.Add (View.Content, View.Text,
                   (Shrink => 0.0, Height => Page_Min_Height, Width => Page_Width, others => <>));
      Layouts.Add (View.Sidebar, View.Format, (Height => 32.0, Margin => (Bottom => 8.0, others => <>), others => <>));
      Layouts.Add (View.Sidebar, View.Section_Headings, (Height => 32.0, others => <>));
      Layouts.Add (View.Sidebar, View.Document_Headings, (Height => 32.0, others => <>));
      Layouts.Add (View.Sidebar, View.Divider,
                   (Height => Hairline, Shrink => 0.0, Margin => (Top => 12.0, Bottom => 12.0, others => <>),
                    others => <>));
      Buttons.Add (View.Sidebar, View.Export, Buttons.Looks ("Export", Focusable => True),
                   (Height => Tab_Height, others => <>));
      Buttons.Add (View.Sidebar, View.Copy, Buttons.Looks ("Copy to Clipboard", Focusable => True),
                   (Height => Tab_Height, Margin => (Top => 8.0, others => <>), others => <>));
      Selects.Set_Value (View.Format, "Choose a format");
      Widgets.Set_Visible (View.Format_Menu, False);
      Menus.Add (View.Format_Menu, Menus.Check, "Markdown");
      Panels.Set_Fill (View.Divider, Themes.Border);
      Switches.Set_Label (View.Section_Headings, "Include section headings");
      Switches.Set_Label (View.Document_Headings, "Include document headings");
      Switches.Set_Focusable (View.Section_Headings, True);
      Switches.Set_Focusable (View.Document_Headings, True);
      if not Item.Shell.Windowed then
         Panels.Set_Fill (View.View, Desk);
      end if;
      Panels.Set_Fill (View.Sidebar, Side_Fill);
      Panels.Set_Fill (View.Rule, Themes.Border);
      Buttons.Set_Enabled (View.Export, False);
      Buttons.Set_Enabled (View.Copy, False);
      Editors.Set_Shared (View.Source_Text, Item.Host.Doc_Resources'Unchecked_Access);
      Editors.Configure (View.Source_Text, "Menlo", Source_Text_Size, 2000.0, Spacing => 0.35 * Source_Text_Size);
      Editors.Set_Paper (View.Source_Text, Paper);
      Editors.Set_Borderless (View.Source_Text, True);
      Editors.Set_Indent (View.Source_Text, Page_Margin - Page_Text_Inset - Page_Border);
      Editors.Attach (View.Source_Text, View.Source_Doc'Unchecked_Access);
      Pomarine.Text_Areas.Set_Grows (Editors.Area (View.Source_Text).all);
      Pomarine.Text_Areas.Set_Read_Only (Editors.Area (View.Source_Text).all);
      Pomarine.Text_Areas.Set_Caret_Visible (Editors.Area (View.Source_Text).all, False);
      Pomarine.Text_Areas.Set_Keyboard_Navigation (Editors.Area (View.Source_Text).all, False);
      View.Source_Wide := Page_Width;
      View.Source_High := Page_Min_Height;
      Widgets.Set_Visible (View.Source_Scroll, False);
      Widgets.Set_Visible (View.Split_Rule, False);
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
      View.Wide := Page_Width;
      View.High := Page_Min_Height;
      Widgets.Set_Visible (View.View, False);
   end Build_Publish;

end Viewer.Build.Shell_Views;
