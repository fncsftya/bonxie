with Items.Schema;
with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings.Unbounded;
with Items.Readers;
with Items.Windows;
with Preferences;
with Speech.Models;
with SDL3.Cursors;
with UI.Boxes;
with UI.Icons;
with UI.Line_Texts;
with UI.Scrollbars;
with UI.Themes;
with UI.Widgets;
with UI.Widgets.Scrollers;
with UI.Text_Areas;
with Viewer.Links;
with Viewer.Recent;
with Viewer.Style;
with Yoga.Nodes;

package body Viewer.Build is

   package Widgets renames UI.Widgets;
   package Panels renames UI.Widgets.Panels;
   package Buttons renames UI.Widgets.Buttons;
   package Labels renames UI.Widgets.Labels;
   package Text_Fields renames UI.Widgets.Text_Fields;
   package Grips renames UI.Widgets.Grips;
   package Scrollers renames UI.Widgets.Scrollers;
   package Editors renames UI.Widgets.Editors;
   package Checks renames UI.Widgets.Checks;
   package Themes renames UI.Themes;

   use Style;

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
      use Yoga.Nodes;
   begin
      --  Not shown: the screens leave room for the window's own buttons
      --  (Header_Size above the home screen, Header_Inset at the left of
      --  the toolbar), and its title is the window's.
      Widgets.Add (Item.Root.Window_Panel, Item.Root.Header_Panel);
      Widgets.Add (Item.Root.Header_Panel, Item.Root.Header_Title);
      Set_Height
        (Widgets.Node (Item.Root.Header_Panel),
         Header_Size * Item.Shell.Density);
      Widgets.Set_Visible (Item.Root.Header_Panel, False);
   end Build_Header;

   procedure Build_Home (Item : in out Session);
   --  Add and style the home screen's widgets.

   procedure Build_Home (Item : in out Session) is
      use Yoga.Nodes;
      Pixels : constant Float := Item.Shell.Density;
      Top    : constant Float := (if Item.Shell.Windowed
                                  then Header_Size else 0.0);
      --  Clear of the window's own buttons.

      procedure Size (Part : in out Widgets.Widget'Class; Wide, High : Float)
      is
      begin
         Set_Width (Widgets.Node (Part), Wide * Pixels);
         Set_Height (Widgets.Node (Part), High * Pixels);
      end Size;
   begin
      Widgets.Add (Item.Root.Window_Panel, Item.Home_View.Home_Panel);
      Widgets.Add (Item.Home_View.Home_Panel, Item.Home_View.Home_Side);
      Widgets.Add (Item.Home_View.Home_Side, Item.Home_View.Logo);
      Widgets.Add (Item.Home_View.Logo, Item.Home_View.Logo_Name);
      Widgets.Add (Item.Home_View.Home_Side, Item.Home_View.New_Button);
      Widgets.Add (Item.Home_View.Home_Side, Item.Home_View.Side_Room);
      Widgets.Add (Item.Home_View.Home_Side, Item.Home_View.Settings_Button);
      Widgets.Add (Item.Home_View.Home_Panel, Item.Home_View.Home_Rule);
      Widgets.Add (Item.Home_View.Home_Panel, Item.Home_View.Recent_Panel);
      Widgets.Add (Item.Home_View.Recent_Panel, Item.Home_View.Recent_Title);
      Widgets.Add (Item.Home_View.Recent_Panel, Item.Home_View.Cards_Scroll);
      Widgets.Add (Item.Home_View.Cards_Scroll, Item.Home_View.Cards_Content);
      for Card of Item.Home_View.Cards loop
         Widgets.Add (Item.Home_View.Cards_Content, Card.Panel);
         Widgets.Add (Card.Panel, Card.Peek);
         Widgets.Add (Card.Peek, Card.Picture);
         Widgets.Add (Card.Panel, Card.Info);
         Widgets.Add (Card.Info, Card.Name);
         Widgets.Add (Card.Name, Card.Title);
         Widgets.Add (Card.Name, Card.Meta);
         Widgets.Add (Card.Info, Card.Rename);
         Widgets.Add (Card.Info, Card.Delete);
      end loop;
      Widgets.Add (Item.Home_View.Cards_Content, Item.Home_View.New_Card);
      Widgets.Add (Item.Home_View.New_Card, Item.Home_View.New_Card_Plus);
      Widgets.Add (Item.Home_View.New_Card, Item.Home_View.New_Card_Label);
      Widgets.Add (Item.Home_View.Cards_Content, Item.Home_View.No_Rows);

      Set_Flex_Direction (Widgets.Node (Item.Home_View.Home_Panel), Yoga.Row);
      Set_Flex_Grow (Widgets.Node (Item.Home_View.Home_Panel), 1.0);

      --  The sidebar: the name, New Project, and Settings at the foot.
      Panels.Set_Fill (Item.Home_View.Home_Side, Mid_Panel);
      Set_Flex_Direction (Widgets.Node (Item.Home_View.Home_Side),
                          Yoga.Column);
      Set_Width (Widgets.Node (Item.Home_View.Home_Side),
                 Home_Side_Width * Pixels);
      Set_Flex_Shrink (Widgets.Node (Item.Home_View.Home_Side), 0.0);
      Set_Padding
        (Widgets.Node (Item.Home_View.Home_Side), Yoga.All_Edges,
         Side_Pad * Pixels);
      Set_Padding
        (Widgets.Node (Item.Home_View.Home_Side), Yoga.Top, (Side_Pad
           + Top) * Pixels);
      Set_Flex_Direction (Widgets.Node (Item.Home_View.Logo), Yoga.Row);
      Set_Align_Items (Widgets.Node (Item.Home_View.Logo), Yoga.Center);
      Set_Height (Widgets.Node (Item.Home_View.Logo), Logo_Height * Pixels);
      Set_Margin (Widgets.Node (Item.Home_View.Logo), Yoga.Bottom,
                  Logo_Gap * Pixels);
      Labels.Set_Text (Item.Home_View.Logo_Name, "bonxie");
      Labels.Set_Style (Item.Home_View.Logo_Name, UI.Line_Texts.Display);
      Set_Flex_Grow (Widgets.Node (Item.Home_View.Logo_Name), 1.0);
      Set_Height (Widgets.Node (Item.Home_View.Logo_Name),
                  Logo_Height * Pixels);
      Buttons.Set_Label (Item.Home_View.New_Button, "New project");
      Buttons.Set_Icon (Item.Home_View.New_Button, UI.Icons.Plus);
      Buttons.Set_Captioned (Item.Home_View.New_Button, True);
      Buttons.Set_Kind (Item.Home_View.New_Button, Buttons.Primary);
      Set_Height (Widgets.Node (Item.Home_View.New_Button),
                  Action_Height * Pixels);
      Set_Flex_Grow (Widgets.Node (Item.Home_View.Side_Room), 1.0);
      Buttons.Set_Label (Item.Home_View.Settings_Button, "Settings");
      Buttons.Set_Icon (Item.Home_View.Settings_Button, UI.Icons.Settings);
      Buttons.Set_Captioned (Item.Home_View.Settings_Button, True);
      Set_Height
        (Widgets.Node (Item.Home_View.Settings_Button),
         Action_Height * Pixels);
      Panels.Set_Fill (Item.Home_View.Home_Rule, Themes.Border);
      Set_Width (Widgets.Node (Item.Home_View.Home_Rule),
                 UI.Boxes.Edge (Pixels));
      Set_Flex_Shrink (Widgets.Node (Item.Home_View.Home_Rule), 0.0);

      --  The projects: a title, and the cards in rows that wrap. The title
      --  is on the line of the name, as the same height from the same top.
      Set_Flex_Direction (Widgets.Node (Item.Home_View.Recent_Panel),
                          Yoga.Column);
      Set_Flex_Grow (Widgets.Node (Item.Home_View.Recent_Panel), 1.0);
      Set_Width (Widgets.Node (Item.Home_View.Recent_Panel), 0.0);
      Set_Padding
        (Widgets.Node (Item.Home_View.Recent_Panel), Yoga.Top,
         (Side_Pad + Top) * Pixels);
      Set_Padding
        (Widgets.Node (Item.Home_View.Recent_Panel), Yoga.Left,
         Home_Margin * Pixels);
      Labels.Set_Text (Item.Home_View.Recent_Title, "Recent projects");
      Labels.Set_Style (Item.Home_View.Recent_Title, UI.Line_Texts.Display);
      Set_Height (Widgets.Node (Item.Home_View.Recent_Title),
                  Logo_Height * Pixels);
      Set_Margin
        (Widgets.Node (Item.Home_View.Recent_Title), Yoga.Bottom,
         Logo_Gap * Pixels);
      Set_Flex_Grow (Widgets.Node (Item.Home_View.Cards_Scroll), 1.0);
      Set_Height (Widgets.Node (Item.Home_View.Cards_Scroll), 0.0);
      Set_Flex_Direction (Widgets.Node (Item.Home_View.Cards_Content),
                          Yoga.Row);
      Set_Wrap (Widgets.Node (Item.Home_View.Cards_Content), Yoga.Wrap);
      Set_Align_Items (Widgets.Node (Item.Home_View.Cards_Content),
                       Yoga.Flex_Start);
      Set_Flex_Shrink (Widgets.Node (Item.Home_View.Cards_Content), 0.0);
      Set_Gap
        (Widgets.Node (Item.Home_View.Cards_Content), Yoga.All_Gutters,
         Card_Gap * Pixels);
      Set_Padding
        (Widgets.Node (Item.Home_View.Cards_Content), Yoga.Right,
         (Home_Margin - Card_Gap) * Pixels);
      Set_Padding
        (Widgets.Node (Item.Home_View.Cards_Content), Yoga.Bottom,
         Home_Margin * Pixels);
      Labels.Set_Text (Item.Home_View.No_Rows, No_Projects);
      Labels.Set_Ink (Item.Home_View.No_Rows, Quiet_Ink);
      Set_Height (Widgets.Node (Item.Home_View.No_Rows),
                  Title_Height * Pixels);
      Set_Width (Widgets.Node (Item.Home_View.No_Rows), Card_Width * Pixels);

      for Card of Item.Home_View.Cards loop
         --  Outlined, with a shadow, which the face leaves room for.
         Panels.Set_Fill (Card.Panel, Themes.Tint);
         Panels.Set_Border (Card.Panel, Themes.Border);
         Panels.Set_Shadow (Card.Panel, Themes.Shadow);
         Set_Flex_Direction (Widgets.Node (Card.Panel), Yoga.Column);
         Size (Card.Panel, Card_Width, Card_Height);
         Set_Flex_Shrink (Widgets.Node (Card.Panel), 0.0);
         for Side in Yoga.Left .. Yoga.Bottom loop
            Set_Padding
              (Widgets.Node (Card.Panel), Side,
               UI.Boxes.Edge (Pixels)
               + (if Side in Yoga.Right | Yoga.Bottom
                  then UI.Boxes.Offset (Pixels) else 0.0));
         end loop;
         --  A line between the picture and what is below it.
         Grips.Set_Fill (Card.Peek, Themes.Border);
         Grips.Set_Wanted_Cursor (Card.Peek, SDL3.Cursors.Pointer);
         Set_Height (Widgets.Node (Card.Peek), Thumb_Height * Pixels);
         Set_Flex_Direction (Widgets.Node (Card.Peek), Yoga.Column);
         Set_Flex_Grow (Widgets.Node (Card.Picture), 1.0);
         Set_Margin
           (Widgets.Node (Card.Picture), Yoga.Bottom, UI.Boxes.Edge (Pixels));
         Panels.Set_Fill (Card.Info, Themes.Tint);
         Set_Flex_Grow (Widgets.Node (Card.Info), 1.0);
         Set_Flex_Direction (Widgets.Node (Card.Info), Yoga.Row);
         Set_Align_Items (Widgets.Node (Card.Info), Yoga.Center);
         Set_Padding
           (Widgets.Node (Card.Info), Yoga.Horizontal, Card_Pad * Pixels);
         Set_Gap
           (Widgets.Node (Card.Info), Yoga.All_Gutters, Row_Gap * Pixels);
         Grips.Set_Wanted_Cursor (Card.Name, SDL3.Cursors.Pointer);
         Set_Flex_Grow (Widgets.Node (Card.Name), 1.0);
         Set_Width (Widgets.Node (Card.Name), 0.0);
         Set_Flex_Direction (Widgets.Node (Card.Name), Yoga.Column);
         Set_Justify_Content (Widgets.Node (Card.Name), Yoga.Center);
         Set_Align_Self (Widgets.Node (Card.Name), Yoga.Stretch);
         Labels.Set_Style (Card.Title, UI.Line_Texts.Heading);
         Set_Height (Widgets.Node (Card.Title), Card_Title_Height * Pixels);
         Set_Height (Widgets.Node (Card.Meta), Card_Meta_Height * Pixels);
         Buttons.Set_Label (Card.Rename, "Rename");
         Buttons.Set_Icon (Card.Rename, UI.Icons.Edit);
         Buttons.Set_Label (Card.Delete, "Delete");
         Buttons.Set_Icon (Card.Delete, UI.Icons.Delete);
         Buttons.Set_Kind (Card.Delete, Buttons.Danger);
         Size (Card.Rename, Card_Button, Card_Button);
         Size (Card.Delete, Card_Button, Card_Button);
      end loop;

      --  The outline of a card, to make a project.
      Grips.Set_Border (Item.Home_View.New_Card, Themes.Border,
                        Dashed => True);
      Grips.Set_Wanted_Cursor (Item.Home_View.New_Card, SDL3.Cursors.Pointer);
      Size (Item.Home_View.New_Card, Card_Width - Themes.Shadow_Offset,
            Card_Height - Themes.Shadow_Offset);
      Set_Flex_Shrink (Widgets.Node (Item.Home_View.New_Card), 0.0);
      Set_Flex_Direction (Widgets.Node (Item.Home_View.New_Card), Yoga.Column);
      Set_Justify_Content (Widgets.Node (Item.Home_View.New_Card),
                           Yoga.Center);
      Set_Align_Items (Widgets.Node (Item.Home_View.New_Card), Yoga.Center);
      Buttons.Set_Label (Item.Home_View.New_Card_Plus, "New");
      Buttons.Set_Icon (Item.Home_View.New_Card_Plus, UI.Icons.Plus);
      Buttons.Set_Kind (Item.Home_View.New_Card_Plus, Buttons.Primary);
      Size (Item.Home_View.New_Card_Plus, Plus_Size, Plus_Size);
      Labels.Set_Text (Item.Home_View.New_Card_Label, "New project");
      Labels.Set_Style (Item.Home_View.New_Card_Label, UI.Line_Texts.Strong);
      Labels.Set_Ink
        (Item.Home_View.New_Card_Label,
         Themes.Primary_Mix);
      Labels.Set_Centered (Item.Home_View.New_Card_Label, True);
      Size (Item.Home_View.New_Card_Label, Card_Width / 2.0, Title_Height);
      Set_Margin
        (Widgets.Node (Item.Home_View.New_Card_Label), Yoga.Top,
         Row_Gap * Pixels);
   end Build_Home;

   procedure Build_Project (Item : in out Session);
   --  Add and style the project screen's widgets.

   procedure Build_Project (Item : in out Session) is
      use Yoga.Nodes;
      Pixels : constant Float := Item.Shell.Density;

      procedure Size (Part : in out Widgets.Widget'Class; Wide, High : Float)
      is
      begin
         Set_Width (Widgets.Node (Part), Wide * Pixels);
         Set_Height (Widgets.Node (Part), High * Pixels);
         Set_Flex_Shrink (Widgets.Node (Part), 0.0);
      end Size;

      procedure Side (Part : in out Panels.Panel; Justify : Yoga.Justify) is
      begin
         Set_Flex_Direction (Widgets.Node (Part), Yoga.Row);
         Set_Align_Items (Widgets.Node (Part), Yoga.Center);
         Set_Justify_Content (Widgets.Node (Part), Justify);
         Set_Flex_Grow (Widgets.Node (Part), 1.0);
         Set_Width (Widgets.Node (Part), 0.0);
      end Side;
   begin
      Widgets.Add (Item.Root.Window_Panel, Item.Toolbar.Project_Panel);
      Widgets.Add (Item.Toolbar.Project_Panel, Item.Toolbar.Toolbar_Panel);
      Widgets.Add (Item.Toolbar.Toolbar_Panel, Item.Toolbar.Toolbar_Start);
      Widgets.Add (Item.Toolbar.Toolbar_Start, Item.Toolbar.Close_Button);
      Widgets.Add (Item.Toolbar.Toolbar_Start, Item.Toolbar.Bar_Rule);
      Widgets.Add (Item.Toolbar.Toolbar_Start, Item.Toolbar.Title_Area);
      Widgets.Add (Item.Toolbar.Title_Area, Item.Toolbar.Project_Title);
      Widgets.Add (Item.Toolbar.Toolbar_Start, Item.Toolbar.Title_Field);
      Widgets.Add (Item.Toolbar.Toolbar_Panel, Item.Toolbar.Tabs);
      Widgets.Add (Item.Toolbar.Tabs, Item.Toolbar.Canvas_Tab);
      Widgets.Add (Item.Toolbar.Tabs, Item.Toolbar.Write_Tab);
      Widgets.Add (Item.Toolbar.Toolbar_Panel, Item.Toolbar.Toolbar_End);
      Widgets.Add (Item.Toolbar.Toolbar_End, Item.Dock.Tool_List);
      Widgets.Add (Item.Toolbar.Project_Panel, Item.Toolbar.Content_Panel);
      Widgets.Add (Item.Toolbar.Content_Panel, Item.Canvas_View);
      Widgets.Add (Item.Toolbar.Project_Panel, Item.Dock.Dock_Panel);
      Widgets.Add (Item.Dock.Dock_Panel, Item.Dock.Dock_Scroll);
      Widgets.Add (Item.Dock.Dock_Scroll, Item.Dock.Dock_Content);

      Set_Flex_Direction (Widgets.Node (Item.Toolbar.Project_Panel),
                          Yoga.Column);
      Set_Flex_Grow (Widgets.Node (Item.Toolbar.Project_Panel), 1.0);
      Set_Flex_Grow (Widgets.Node (Item.Toolbar.Content_Panel), 1.0);
      Set_Flex_Direction (Widgets.Node (Item.Toolbar.Content_Panel),
                          Yoga.Column);
      --  The pages are taller than it: it takes what the bars leave.
      Set_Height (Widgets.Node (Item.Toolbar.Content_Panel), 0.0);
      Set_Flex_Grow (Widgets.Node (Item.Canvas_View), 1.0);

      --  The bar across the top: the way back and the project's name at the
      --  left, the tabs in the middle (the sides take equal shares), the
      --  list of items at the right.
      Panels.Set_Fill (Item.Toolbar.Toolbar_Panel, Toolbar);
      Set_Height (Widgets.Node (Item.Toolbar.Toolbar_Panel),
                  Toolbar_Size * Pixels);
      Set_Flex_Shrink (Widgets.Node (Item.Toolbar.Toolbar_Panel), 0.0);
      Set_Flex_Direction (Widgets.Node (Item.Toolbar.Toolbar_Panel), Yoga.Row);
      Set_Align_Items (Widgets.Node (Item.Toolbar.Toolbar_Panel), Yoga.Center);
      Set_Padding
        (Widgets.Node (Item.Toolbar.Toolbar_Panel), Yoga.Left,
         (if Item.Shell.Windowed then Header_Inset else Bar_Inset) * Pixels);
      Set_Padding
        (Widgets.Node (Item.Toolbar.Toolbar_Panel), Yoga.Right,
         Bar_Inset * Pixels);
      Side (Item.Toolbar.Toolbar_Start, Yoga.Flex_Start);
      Side (Item.Toolbar.Toolbar_End, Yoga.Flex_End);
      Buttons.Set_Label (Item.Toolbar.Close_Button, "Projects");
      Buttons.Set_Icon (Item.Toolbar.Close_Button, UI.Icons.Back);
      Buttons.Set_Captioned (Item.Toolbar.Close_Button, True);
      Buttons.Set_Kind (Item.Toolbar.Close_Button, Buttons.Quiet);
      Size (Item.Toolbar.Close_Button, Back_Width, Tab_Height);
      Panels.Set_Fill (Item.Toolbar.Bar_Rule, Rule_Ink);
      Size (Item.Toolbar.Bar_Rule, 0.0, Bar_Rule_Height);
      Set_Width (Widgets.Node (Item.Toolbar.Bar_Rule), UI.Boxes.Edge (Pixels));
      Set_Margin
        (Widgets.Node (Item.Toolbar.Bar_Rule), Yoga.Horizontal,
         Name_Gap * Pixels);
      Labels.Set_Style (Item.Toolbar.Project_Title, UI.Line_Texts.Heading);
      Labels.Set_Ink (Item.Toolbar.Project_Title, Themes.Bar_Ink);
      Set_Flex_Grow (Widgets.Node (Item.Toolbar.Project_Title), 1.0);
      Set_Width (Widgets.Node (Item.Toolbar.Project_Title), 0.0);
      Set_Height (Widgets.Node (Item.Toolbar.Project_Title),
                  Tab_Height * Pixels);
      Grips.Set_Hover_Outline (Item.Toolbar.Title_Area, Themes.Bar_Ink);
      Grips.Set_Wanted_Cursor (Item.Toolbar.Title_Area, SDL3.Cursors.Pointer);
      Set_Flex_Direction (Widgets.Node (Item.Toolbar.Title_Area), Yoga.Row);
      Set_Align_Items (Widgets.Node (Item.Toolbar.Title_Area), Yoga.Center);
      Set_Flex_Grow (Widgets.Node (Item.Toolbar.Title_Area), 1.0);
      Set_Width (Widgets.Node (Item.Toolbar.Title_Area), 0.0);
      Set_Height (Widgets.Node (Item.Toolbar.Title_Area), Tab_Height * Pixels);
      Text_Fields.Set_Shared
        (Item.Toolbar.Title_Field, Item.Host.Doc_Resources'Unchecked_Access);
      Text_Fields.Configure
        (Item.Toolbar.Title_Field, UI.Line_Texts.Interface_Font,
         UI.Line_Texts.Heading_Size);
      Set_Flex_Grow (Widgets.Node (Item.Toolbar.Title_Field), 1.0);
      Set_Width (Widgets.Node (Item.Toolbar.Title_Field), 0.0);
      Set_Height (Widgets.Node (Item.Toolbar.Title_Field),
                  Tab_Height * Pixels);
      Widgets.Set_Visible (Item.Toolbar.Title_Field, False);

      Set_Flex_Direction (Widgets.Node (Item.Toolbar.Tabs), Yoga.Row);
      Set_Gap (Widgets.Node (Item.Toolbar.Tabs), Yoga.All_Gutters,
               Tab_Gap * Pixels);
      Buttons.Set_Label (Item.Toolbar.Canvas_Tab, "Canvas");
      Buttons.Set_Selected (Item.Toolbar.Canvas_Tab, True);
      Buttons.Set_Label (Item.Toolbar.Write_Tab, "Write");
      Size (Item.Toolbar.Canvas_Tab, Tab_Width, Tab_Height);
      Size (Item.Toolbar.Write_Tab, Tab_Width, Tab_Height);
      Buttons.Set_Label (Item.Dock.Tool_List, "Items");
      Buttons.Set_Icon (Item.Dock.Tool_List, UI.Icons.List);
      Buttons.Set_Captioned (Item.Dock.Tool_List, True);
      Size (Item.Dock.Tool_List, Items_Width, Tab_Height);

      --  The dock of minimised items, under the canvas, and the
      --  windows of the items: on the canvas, or as bars in the dock.
      Panels.Set_Fill (Item.Dock.Dock_Panel, Dock);
      Set_Height (Widgets.Node (Item.Dock.Dock_Panel), Dock_Height * Pixels);
      Set_Flex_Shrink (Widgets.Node (Item.Dock.Dock_Panel), 0.0);
      Set_Flex_Direction (Widgets.Node (Item.Dock.Dock_Panel), Yoga.Row);
      Scrollers.Set_Across (Item.Dock.Dock_Scroll, True);
      Set_Flex_Direction (Widgets.Node (Item.Dock.Dock_Scroll), Yoga.Row);
      Set_Flex_Grow (Widgets.Node (Item.Dock.Dock_Scroll), 1.0);
      Set_Width (Widgets.Node (Item.Dock.Dock_Scroll), 0.0);
      Set_Flex_Direction (Widgets.Node (Item.Dock.Dock_Content), Yoga.Row);
      Set_Flex_Shrink (Widgets.Node (Item.Dock.Dock_Content), 0.0);
      Set_Align_Items (Widgets.Node (Item.Dock.Dock_Content), Yoga.Center);
      Set_Padding
        (Widgets.Node (Item.Dock.Dock_Content), Yoga.Horizontal,
         Dock_Inset * Pixels);
      Set_Gap
        (Widgets.Node (Item.Dock.Dock_Content), Yoga.All_Gutters,
         Dock_Gap * Pixels);
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
      use Yoga.Nodes;
      Pixels : constant Float := Item.Shell.Density;
   begin
      Widgets.Add (Item.Toolbar.Content_Panel, Item.Dock.Tools);
      Widgets.Add (Item.Dock.Tools, Item.Dock.Tool_Item);
      Widgets.Add (Item.Dock.Tools, Item.Dock.Tool_Source);
      Panels.Set_Fill (Item.Dock.Tools, Toolbar);
      Panels.Set_Shadow (Item.Dock.Tools, Themes.Shadow);
      Set_Position_Type (Widgets.Node (Item.Dock.Tools), Yoga.Absolute);
      Set_Position
        (Widgets.Node (Item.Dock.Tools), Yoga.Bottom,
         (Tray_Foot - Themes.Shadow_Offset) * Pixels);
      Set_Width (Widgets.Node (Item.Dock.Tools), Tray_Width * Pixels);
      Set_Height (Widgets.Node (Item.Dock.Tools), Tray_Height * Pixels);
      Set_Flex_Direction (Widgets.Node (Item.Dock.Tools), Yoga.Row);
      Set_Align_Items (Widgets.Node (Item.Dock.Tools), Yoga.Center);
      Set_Padding
        (Widgets.Node (Item.Dock.Tools), Yoga.All_Edges, Tray_Pad * Pixels);
      Set_Padding
        (Widgets.Node (Item.Dock.Tools), Yoga.Right,
         Tray_Pad * Pixels + UI.Boxes.Offset (Pixels));
      Set_Padding
        (Widgets.Node (Item.Dock.Tools), Yoga.Bottom,
         Tray_Pad * Pixels + UI.Boxes.Offset (Pixels));
      Set_Gap
        (Widgets.Node (Item.Dock.Tools), Yoga.All_Gutters, Tray_Gap * Pixels);
      Buttons.Set_Label (Item.Dock.Tool_Item, "Add document");
      Buttons.Set_Icon (Item.Dock.Tool_Item, UI.Icons.Document);
      Buttons.Set_Captioned (Item.Dock.Tool_Item, True);
      Buttons.Set_Label (Item.Dock.Tool_Source, "Add source");
      Buttons.Set_Icon (Item.Dock.Tool_Source, UI.Icons.Link);
      Buttons.Set_Captioned (Item.Dock.Tool_Source, True);
      Buttons.Set_Kind (Item.Dock.Tool_Source, Buttons.Primary);
      Set_Width (Widgets.Node (Item.Dock.Tool_Item), Wide_Tool_Width * Pixels);
      Set_Height (Widgets.Node (Item.Dock.Tool_Item), Tool_Height * Pixels);
      Set_Width (Widgets.Node (Item.Dock.Tool_Source), Tool_Width * Pixels);
      Set_Height (Widgets.Node (Item.Dock.Tool_Source), Tool_Height * Pixels);
   end Build_Tray;

   procedure Build_Write (Item : in out Session);
   --  Add and style the writing view's widgets.

   procedure Build_Write (Item : in out Session) is
      use Yoga.Nodes;
      Pixels : constant Float := Item.Shell.Density;
      Edge   : constant Float := UI.Boxes.Edge (Pixels);
      Offset : constant Float := UI.Boxes.Offset (Pixels);

      procedure Build_Index
        (Scroll   : in out Scrollers.Scroller;
         Content  : in out Panels.Panel;
         None     : in out Labels.Label;
         Empty    : String) is
      begin
         Widgets.Add (Item.Page_View.Sidebar, Scroll);
         Widgets.Add (Scroll, Content);
         Labels.Set_Text (None, Empty);
         Labels.Set_Ink (None, Closed_Ink);
         --  As tall as its rows, if there is room; the second list
         --  follows the first.
         Set_Flex_Shrink (Widgets.Node (Scroll), 1.0);
         --  The scroll bar, which is shown only while the pointer is
         --  over the list, is over the rows' right edge.
         Set_Flex_Direction (Widgets.Node (Content), Yoga.Column);
         Set_Flex_Shrink (Widgets.Node (Content), 0.0);
         Set_Gap
           (Widgets.Node (Content), Yoga.All_Gutters,
            Index_Gap * Pixels - Offset);
      end Build_Index;

      procedure Build_Row
        (Content : in out Panels.Panel;
         Each    : in out Index_Row;
         Counted : Boolean) is
      begin
         Widgets.Add (Content, Each.Row);
         Widgets.Add (Each.Row, Each.Tag);
         Widgets.Add (Each.Row, Each.Caption);
         Widgets.Add (Each.Row, Each.Count);
         --  Each row casts a shadow, inside its box: it is that much
         --  taller, and the gap less.
         Grips.Set_Fill (Each.Row, Row_Fill);
         Grips.Set_Hover_Fill (Each.Row, Row_Hover);
         Grips.Set_Border (Each.Row, Themes.Border);
         Grips.Set_Shadow (Each.Row, Side_Fill);
         Grips.Set_Wanted_Cursor (Each.Row, SDL3.Cursors.Pointer);
         Set_Height
           (Widgets.Node (Each.Row), Index_Height * Pixels + Offset);
         Set_Flex_Shrink (Widgets.Node (Each.Row), 0.0);
         Set_Flex_Direction (Widgets.Node (Each.Row), Yoga.Row);
         Set_Align_Items (Widgets.Node (Each.Row), Yoga.Center);
         Set_Padding
           (Widgets.Node (Each.Row), Yoga.Left, Index_Pad * Pixels);
         Set_Padding
           (Widgets.Node (Each.Row), Yoga.Right,
            Index_Pad * Pixels + Offset);
         Set_Padding (Widgets.Node (Each.Row), Yoga.Bottom, Offset);
         Set_Width (Widgets.Node (Each.Tag), Tag_Size * Pixels);
         Set_Height (Widgets.Node (Each.Tag), Tag_Size * Pixels);
         Set_Flex_Shrink (Widgets.Node (Each.Tag), 0.0);
         Set_Margin
           (Widgets.Node (Each.Tag), Yoga.Right, Index_Pad * Pixels);
         Widgets.Set_Visible (Each.Tag, not Counted);
         Set_Flex_Grow (Widgets.Node (Each.Caption), 1.0);
         Set_Width (Widgets.Node (Each.Caption), 0.0);
         Set_Height (Widgets.Node (Each.Caption), Index_Height * Pixels);
         Labels.Set_Trailing (Each.Count, True);
         Labels.Set_Ink (Each.Count, Quiet_Ink);
         Set_Width (Widgets.Node (Each.Count), Count_Width * Pixels);
         Set_Height (Widgets.Node (Each.Count), Index_Height * Pixels);
         Widgets.Set_Visible (Each.Count, Counted);
      end Build_Row;

      procedure Heading (Label : in out Labels.Label; Name : String) is
      begin
         Labels.Set_Text (Label, Name);
         Labels.Set_Style (Label, UI.Line_Texts.Caption);
         Set_Height (Widgets.Node (Label), Heading_Height * Pixels);
         Set_Flex_Shrink (Widgets.Node (Label), 0.0);
      end Heading;
   begin
      Widgets.Add (Item.Toolbar.Content_Panel, Item.Page_View.Write_View);
      Widgets.Add (Item.Page_View.Write_View, Item.Page_View.Sidebar);
      Widgets.Add (Item.Page_View.Sidebar, Item.Page_View.Docs_Head);
      Widgets.Add (Item.Page_View.Docs_Head, Item.Page_View.Docs_Heading);
      Widgets.Add (Item.Page_View.Docs_Head, Item.Page_View.Docs_Folder);
      Widgets.Add (Item.Page_View.Docs_Head, Item.Page_View.Docs_Add);
      Build_Index
        (Item.Page_View.Docs_Scroll, Item.Page_View.Docs_Content,
         Item.Page_View.Docs_None, No_Documents);
      for Each of Item.Docs.Doc_Rows loop
         Build_Row (Item.Page_View.Docs_Content, Each, Counted => True);
         Panels.Set_Fill (Each.Tag, Quiet_Ink);
      end loop;
      Widgets.Add (Item.Page_View.Docs_Content, Item.Page_View.Docs_None);
      Set_Height (Widgets.Node (Item.Page_View.Docs_None),
                  Index_Height * Pixels);
      Widgets.Add (Item.Page_View.Docs_Content, Item.Docs.Drop_Line);
      Widgets.Add (Item.Page_View.Docs_Content, Item.Naming.Dir_Field);
      Widgets.Add (Item.Page_View.Sidebar, Item.Page_View.Sources_Heading);
      Build_Index
        (Item.Page_View.Sources_Scroll, Item.Page_View.Sources_Content,
         Item.Page_View.Sources_None,
         No_Sources);
      for Each of Item.Reading.Source_Rows loop
         Build_Row (Item.Page_View.Sources_Content, Each, Counted => False);
      end loop;
      Widgets.Add (Item.Page_View.Sources_Content,
                   Item.Page_View.Sources_None);
      Widgets.Add (Item.Page_View.Sources_Content, Item.Naming.Source_Field);
      Set_Height (Widgets.Node (Item.Page_View.Sources_None),
                  Index_Height * Pixels);
      Widgets.Add (Item.Page_View.Write_View, Item.Page_View.Sidebar_Rule);
      Widgets.Add (Item.Page_View.Write_View, Item.Page_View.Pages_Scroll);
      Widgets.Add (Item.Page_View.Pages_Scroll, Item.Page_View.Pages_Content);
      for Each of Item.Docs.Pages loop
         Widgets.Add (Item.Page_View.Pages_Content, Each.Box);
         Widgets.Add (Each.Box, Each.Bar);
         Widgets.Add (Each.Bar, Each.Heading_Area);
         Widgets.Add (Each.Heading_Area, Each.Heading);
         Widgets.Add (Each.Bar, Each.Title_Field);
         Widgets.Add (Each.Bar, Each.Sources_Button);
         Widgets.Add (Each.Bar, Each.Mic_Button);
         Widgets.Add (Each.Box, Each.Sheet);
         Widgets.Add (Each.Sheet, Each.Text);
         Widgets.Add (Each.Box, Each.Words);
      end loop;
      Widgets.Add (Item.Page_View.Write_View, Item.Page_View.Pane);
      Widgets.Add (Item.Page_View.Pane, Item.Page_View.Pane_Edge);
      Widgets.Add (Item.Page_View.Pane, Item.Page_View.Pane_Body);
      --  Over the rest, last.
      for Each of Item.Reading.Readers loop
         Items.Readers.Build
           (Each, Item.Page_View.Write_View, Toolbar, Pixels);
      end loop;
      Widgets.Add (Item.Page_View.Write_View, Item.Page_View.Menu);
      Set_Position_Type (Widgets.Node (Item.Page_View.Menu), Yoga.Absolute);
      Set_Width (Widgets.Node (Item.Page_View.Menu), Menu_Width * Pixels);
      Widgets.Set_Visible (Item.Page_View.Menu, False);
      Widgets.Add (Item.Toolbar.Content_Panel, Item.Context.Context_Menu);
      Set_Position_Type (Widgets.Node (Item.Context.Context_Menu),
                         Yoga.Absolute);
      Set_Width (Widgets.Node (Item.Context.Context_Menu),
                 Context_Width * Pixels);
      Widgets.Set_Visible (Item.Context.Context_Menu, False);
      Items.Readers.Build
        (Item.Reading.Pane_Reader, Item.Page_View.Pane_Body, Toolbar, Pixels,
         Pinned => True);

      Panels.Set_Fill (Item.Page_View.Write_View, Desk);
      Set_Flex_Direction (Widgets.Node (Item.Page_View.Write_View), Yoga.Row);
      Set_Flex_Grow (Widgets.Node (Item.Page_View.Write_View), 1.0);
      Set_Height (Widgets.Node (Item.Page_View.Write_View), 0.0);

      --  The sidebar: two lists one above the other, with a line at its
      --  right.
      Panels.Set_Fill (Item.Page_View.Sidebar, Side_Fill);
      Set_Width (Widgets.Node (Item.Page_View.Sidebar),
                 Sidebar_Width * Pixels);
      Set_Flex_Shrink (Widgets.Node (Item.Page_View.Sidebar), 0.0);
      Set_Padding
        (Widgets.Node (Item.Page_View.Sidebar), Yoga.All_Edges,
         Sidebar_Pad * Pixels);
      Set_Padding
        (Widgets.Node (Item.Page_View.Sidebar), Yoga.Top,
         (Sidebar_Pad + Heading_Top) * Pixels);
      Set_Flex_Direction (Widgets.Node (Item.Page_View.Sidebar), Yoga.Column);
      Set_Gap
        (Widgets.Node (Item.Page_View.Sidebar), Yoga.All_Gutters,
         Sidebar_Gap * Pixels);
      Panels.Set_Fill (Item.Page_View.Sidebar_Rule, Themes.Border);
      Set_Width (Widgets.Node (Item.Page_View.Sidebar_Rule), Edge);
      Set_Flex_Shrink (Widgets.Node (Item.Page_View.Sidebar_Rule), 0.0);
      Set_Flex_Direction (Widgets.Node (Item.Page_View.Docs_Head), Yoga.Row);
      Set_Align_Items (Widgets.Node (Item.Page_View.Docs_Head), Yoga.Center);
      Set_Padding (Widgets.Node (Item.Page_View.Docs_Head), Yoga.Right,
                   Offset);
      Heading (Item.Page_View.Docs_Heading, "DOCUMENTS");
      Set_Flex_Grow (Widgets.Node (Item.Page_View.Docs_Heading), 1.0);
      Heading (Item.Page_View.Sources_Heading, "SOURCES");
      Set_Margin
        (Widgets.Node (Item.Page_View.Sources_Heading), Yoga.Top,
         Heading_Top * Pixels);
      Buttons.Set_Label (Item.Page_View.Docs_Add, "+");
      Buttons.Set_Icon (Item.Page_View.Docs_Add, UI.Icons.Plus);
      Buttons.Set_Icon_Size (Item.Page_View.Docs_Add, Mic_Icon_Size);
      Set_Width (Widgets.Node (Item.Page_View.Docs_Add), Add_Size * Pixels);
      Set_Height (Widgets.Node (Item.Page_View.Docs_Add), Add_Size * Pixels);
      Buttons.Set_Label (Item.Page_View.Docs_Folder, "New folder");
      Buttons.Set_Icon (Item.Page_View.Docs_Folder, UI.Icons.Folder);
      Buttons.Set_Icon_Size (Item.Page_View.Docs_Folder, Mic_Icon_Size);
      Set_Width (Widgets.Node (Item.Page_View.Docs_Folder), Add_Size * Pixels);
      Set_Height (Widgets.Node (Item.Page_View.Docs_Folder),
                  Add_Size * Pixels);
      Set_Gap
        (Widgets.Node (Item.Page_View.Docs_Head), Yoga.All_Gutters,
         Index_Gap * Pixels);

      --  Over the rows of the tree, out of their layout: the line where a
      --  document dragged would go between two, and the field to rename
      --  a directory by.
      Panels.Set_Fill (Item.Docs.Drop_Line, UI.Themes.Accent);
      Set_Position_Type (Widgets.Node (Item.Docs.Drop_Line), Yoga.Absolute);
      Set_Height (Widgets.Node (Item.Docs.Drop_Line),
                  Drop_Line_Height * Pixels);
      Widgets.Set_Visible (Item.Docs.Drop_Line, False);
      Text_Fields.Set_Shared
        (Item.Naming.Dir_Field, Item.Host.Doc_Resources'Unchecked_Access);
      Text_Fields.Configure
        (Item.Naming.Dir_Field, UI.Line_Texts.Interface_Font, Edit_Size);
      Set_Position_Type (Widgets.Node (Item.Naming.Dir_Field), Yoga.Absolute);
      Set_Height (Widgets.Node (Item.Naming.Dir_Field), Index_Height * Pixels);
      Widgets.Set_Visible (Item.Naming.Dir_Field, False);
      Text_Fields.Set_Shared
        (Item.Naming.Source_Field, Item.Host.Doc_Resources'Unchecked_Access);
      Text_Fields.Configure
        (Item.Naming.Source_Field, UI.Line_Texts.Interface_Font, Edit_Size);
      Set_Position_Type (Widgets.Node (Item.Naming.Source_Field),
                         Yoga.Absolute);
      Set_Height (Widgets.Node (Item.Naming.Source_Field),
                  Index_Height * Pixels);
      Widgets.Set_Visible (Item.Naming.Source_Field, False);

      --  The pages, scrolled, one above the next, and the button to add
      --  one after them.
      Set_Flex_Grow (Widgets.Node (Item.Page_View.Pages_Scroll), 1.0);
      Set_Width (Widgets.Node (Item.Page_View.Pages_Scroll), 0.0);
      Set_Flex_Direction (Widgets.Node (Item.Page_View.Pages_Content),
                          Yoga.Column);
      Set_Flex_Shrink (Widgets.Node (Item.Page_View.Pages_Content), 0.0);
      Set_Align_Items (Widgets.Node (Item.Page_View.Pages_Content),
                       Yoga.Center);
      Set_Padding
        (Widgets.Node (Item.Page_View.Pages_Content), Yoga.All_Edges,
         Page_Margin * Pixels);
      Set_Padding
        (Widgets.Node (Item.Page_View.Pages_Content), Yoga.Top,
         (Page_Margin - Page_Gap) * Pixels);
      Set_Gap
        (Widgets.Node (Item.Page_View.Pages_Content), Yoga.All_Gutters,
         Page_Gap * Pixels);
      for Each of Item.Docs.Pages loop
         Set_Flex_Direction (Widgets.Node (Each.Box), Yoga.Column);
         Set_Flex_Shrink (Widgets.Node (Each.Box), 0.0);
         Set_Width (Widgets.Node (Each.Box), Page_Width * Pixels);
         Set_Flex_Direction (Widgets.Node (Each.Bar), Yoga.Row);
         Set_Align_Items (Widgets.Node (Each.Bar), Yoga.Center);
         Set_Height (Widgets.Node (Each.Bar), Page_Head * Pixels);
         Set_Gap
           (Widgets.Node (Each.Bar), Yoga.All_Gutters, Tool_Gap * Pixels);
         Set_Padding (Widgets.Node (Each.Bar), Yoga.Right, Offset);
         Labels.Set_Style (Each.Heading, UI.Line_Texts.Heading);
         Set_Flex_Direction (Widgets.Node (Each.Heading_Area), Yoga.Row);
         Set_Align_Items (Widgets.Node (Each.Heading_Area), Yoga.Center);
         Set_Flex_Grow (Widgets.Node (Each.Heading_Area), 1.0);
         Set_Width (Widgets.Node (Each.Heading_Area), 0.0);
         Set_Height (Widgets.Node (Each.Heading_Area), Page_Head * Pixels);
         Set_Flex_Grow (Widgets.Node (Each.Heading), 1.0);
         Set_Width (Widgets.Node (Each.Heading), 0.0);
         Set_Height (Widgets.Node (Each.Heading), Page_Head * Pixels);
         Text_Fields.Set_Shared
           (Each.Title_Field, Item.Host.Doc_Resources'Unchecked_Access);
         Text_Fields.Configure
           (Each.Title_Field, UI.Line_Texts.Interface_Font,
            UI.Line_Texts.Heading_Size);
         Set_Flex_Grow (Widgets.Node (Each.Title_Field), 1.0);
         Set_Width (Widgets.Node (Each.Title_Field), 0.0);
         Set_Height (Widgets.Node (Each.Title_Field), Title_Height * Pixels);
         Widgets.Set_Visible (Each.Title_Field, False);
         Buttons.Set_Label (Each.Sources_Button, "Sources");
         Buttons.Set_Dropdown (Each.Sources_Button, True);
         Set_Width
           (Widgets.Node (Each.Sources_Button), Sources_Width * Pixels);
         Set_Height
           (Widgets.Node (Each.Sources_Button), Bar_Button_Height * Pixels);
         Buttons.Set_Label (Each.Mic_Button, "Mic");
         Buttons.Set_Icon (Each.Mic_Button, UI.Icons.Microphone);
         Buttons.Set_Icon_Size (Each.Mic_Button, Mic_Icon_Size);
         Set_Width (Widgets.Node (Each.Mic_Button), Mic_Width * Pixels);
         Set_Height
           (Widgets.Node (Each.Mic_Button), Bar_Button_Height * Pixels);
         --  The page: white, outlined, with a shadow it leaves room for.
         Panels.Set_Fill (Each.Sheet, Paper);
         Panels.Set_Border (Each.Sheet, Themes.Border);
         Panels.Set_Shadow (Each.Sheet, Themes.Shadow);
         Set_Flex_Direction (Widgets.Node (Each.Sheet), Yoga.Column);
         Set_Flex_Shrink (Widgets.Node (Each.Sheet), 0.0);
         Set_Padding
           (Widgets.Node (Each.Sheet), Yoga.Left,
            (Page_Margin - Page_Text_Inset) * Pixels);
         Set_Padding
           (Widgets.Node (Each.Sheet), Yoga.Right,
            (Page_Margin - Page_Text_Inset) * Pixels + Offset);
         Set_Padding
           (Widgets.Node (Each.Sheet), Yoga.Top,
            (Page_Top - Page_Text_Inset) * Pixels);
         Set_Padding
           (Widgets.Node (Each.Sheet), Yoga.Bottom,
            (Page_Top - Page_Text_Inset) * Pixels + Offset);
         Editors.Set_Shared
           (Each.Text, Item.Host.Doc_Resources'Unchecked_Access);
         Editors.Configure
           (Each.Text, UI.Line_Texts.Serif, Page_Text_Size, 2000.0,
            Spacing => 0.35 * Page_Text_Size);
         Editors.Set_Paper (Each.Text, Paper);
         UI.Text_Areas.Set_Grows (Editors.Area (Each.Text).all);
         Set_Flex_Shrink (Widgets.Node (Each.Text), 0.0);
         Set_Height (Widgets.Node (Each.Text), Page_Min_Height * Pixels);
         Labels.Set_Trailing (Each.Words, True);
         Labels.Set_Ink (Each.Words, Quiet_Ink);
         Set_Height (Widgets.Node (Each.Words), Page_Foot * Pixels);
         Set_Margin (Widgets.Node (Each.Words), Yoga.Right, Offset);
         Widgets.Set_Visible (Each.Box, False);
      end loop;
      --  The pane: an edge to size it by, and the pinned source.
      Panels.Set_Fill (Item.Page_View.Pane, Desk);
      Set_Flex_Direction (Widgets.Node (Item.Page_View.Pane), Yoga.Row);
      Set_Flex_Shrink (Widgets.Node (Item.Page_View.Pane), 0.0);
      Item.Page_View.Pane_Wide := Pane_Default;
      Set_Width (Widgets.Node (Item.Page_View.Pane), Pane_Default * Pixels);
      Grips.Set_Fill (Item.Page_View.Pane_Edge, Edge_Fill);
      Grips.Set_Wanted_Cursor (Item.Page_View.Pane_Edge,
                               SDL3.Cursors.Resize_Across);
      Set_Width (Widgets.Node (Item.Page_View.Pane_Edge),
                 Pane_Edge_Width * Pixels);
      Set_Flex_Shrink (Widgets.Node (Item.Page_View.Pane_Edge), 0.0);
      Set_Flex_Direction (Widgets.Node (Item.Page_View.Pane_Body),
                          Yoga.Column);
      Set_Flex_Grow (Widgets.Node (Item.Page_View.Pane_Body), 1.0);
      Set_Width (Widgets.Node (Item.Page_View.Pane_Body), 0.0);
      Widgets.Set_Visible (Item.Page_View.Pane, False);
   end Build_Write;

   procedure Build_Settings (Item : in out Session);
   --  Add and style the settings: a bar across the top that stays, and the
   --  form, as wide as a page in the writing view, centred and scrolled.

   procedure Build_Settings (Item : in out Session) is
      use Yoga.Nodes;
      Pixels : constant Float := Item.Shell.Density;
      Offset : constant Float := UI.Boxes.Offset (Pixels);

      procedure Line (Part : in out Widgets.Widget'Class; High : Float) is
      begin
         Set_Height (Widgets.Node (Part), High * Pixels);
         Set_Flex_Shrink (Widgets.Node (Part), 0.0);
      end Line;

      procedure Radio (Part : in out Checks.Check; Name : String) is
      begin
         Checks.Set_Kind (Part, Checks.Radio);
         Checks.Set_Label (Part, Name);
         Line (Part, Settings_Line);
      end Radio;
   begin
      Widgets.Add (Item.Root.Window_Panel, Item.Prefs.Settings_Panel);
      Widgets.Add (Item.Prefs.Settings_Panel, Item.Prefs.Settings_Bar);
      Widgets.Add (Item.Prefs.Settings_Bar, Item.Prefs.Settings_Title);
      Widgets.Add (Item.Prefs.Settings_Bar, Item.Prefs.Settings_Close);
      Widgets.Add (Item.Prefs.Settings_Panel, Item.Prefs.Settings_Scroll);
      Widgets.Add (Item.Prefs.Settings_Scroll, Item.Prefs.Settings_Content);
      Widgets.Add (Item.Prefs.Settings_Content, Item.Prefs.Settings_Form);
      Widgets.Add (Item.Prefs.Settings_Form, Item.Prefs.Display_Heading);
      Widgets.Add (Item.Prefs.Settings_Form, Item.Prefs.Theme_Name);
      Widgets.Add (Item.Prefs.Settings_Form, Item.Prefs.Theme_Light);
      Widgets.Add (Item.Prefs.Settings_Form, Item.Prefs.Theme_Dark);
      Widgets.Add (Item.Prefs.Settings_Form, Item.Prefs.Theme_System);
      Widgets.Add (Item.Prefs.Settings_Form, Item.Prefs.Speech_Heading);
      Widgets.Add (Item.Prefs.Settings_Form, Item.Prefs.Model_Name);
      Widgets.Add (Item.Prefs.Settings_Form, Item.Prefs.Model_Native);
      Widgets.Add (Item.Prefs.Settings_Form, Item.Prefs.Model_Parakeet);
      Widgets.Add (Item.Prefs.Settings_Form, Item.Prefs.Download_Row);
      Widgets.Add (Item.Prefs.Download_Row, Item.Prefs.Download_Button);
      Widgets.Add (Item.Prefs.Download_Row, Item.Prefs.Delete_Button);
      Widgets.Add (Item.Prefs.Download_Row, Item.Prefs.Download_State);
      Widgets.Add (Item.Prefs.Settings_Form, Item.Prefs.Download_Bar);

      Set_Flex_Direction (Widgets.Node (Item.Prefs.Settings_Panel),
                          Yoga.Column);
      Set_Flex_Grow (Widgets.Node (Item.Prefs.Settings_Panel), 1.0);
      Panels.Set_Fill (Item.Prefs.Settings_Panel, Desk);

      --  The bar, outside what scrolls, so that it stays: the title at the
      --  left (clear of the window's own buttons) and Close at the right.
      Panels.Set_Fill (Item.Prefs.Settings_Bar, Toolbar);
      Line (Item.Prefs.Settings_Bar, Toolbar_Size);
      Set_Flex_Direction (Widgets.Node (Item.Prefs.Settings_Bar), Yoga.Row);
      Set_Align_Items (Widgets.Node (Item.Prefs.Settings_Bar), Yoga.Center);
      Set_Padding
        (Widgets.Node (Item.Prefs.Settings_Bar), Yoga.Left,
         (if Item.Shell.Windowed then Header_Inset else Bar_Inset) * Pixels);
      Set_Padding
        (Widgets.Node (Item.Prefs.Settings_Bar), Yoga.Right,
         Bar_Inset * Pixels);
      Labels.Set_Text (Item.Prefs.Settings_Title, "Settings");
      Labels.Set_Style (Item.Prefs.Settings_Title, UI.Line_Texts.Heading);
      Labels.Set_Ink (Item.Prefs.Settings_Title, Themes.Bar_Ink);
      Set_Flex_Grow (Widgets.Node (Item.Prefs.Settings_Title), 1.0);
      Set_Width (Widgets.Node (Item.Prefs.Settings_Title), 0.0);
      Set_Height (Widgets.Node (Item.Prefs.Settings_Title),
                  Tab_Height * Pixels);
      Buttons.Set_Label (Item.Prefs.Settings_Close, "Close");
      Buttons.Set_Icon (Item.Prefs.Settings_Close, UI.Icons.Close);
      Buttons.Set_Captioned (Item.Prefs.Settings_Close, True);
      Buttons.Set_Kind (Item.Prefs.Settings_Close, Buttons.Quiet);
      Set_Width (Widgets.Node (Item.Prefs.Settings_Close),
                 Items_Width * Pixels);
      Set_Height (Widgets.Node (Item.Prefs.Settings_Close),
                  Tab_Height * Pixels);
      Set_Flex_Shrink (Widgets.Node (Item.Prefs.Settings_Close), 0.0);

      --  The form, on a page of its own, in the middle.
      Set_Flex_Grow (Widgets.Node (Item.Prefs.Settings_Scroll), 1.0);
      Set_Height (Widgets.Node (Item.Prefs.Settings_Scroll), 0.0);
      Set_Flex_Direction (Widgets.Node (Item.Prefs.Settings_Content),
                          Yoga.Column);
      Set_Flex_Shrink (Widgets.Node (Item.Prefs.Settings_Content), 0.0);
      Set_Align_Items (Widgets.Node (Item.Prefs.Settings_Content),
                       Yoga.Center);
      Set_Padding
        (Widgets.Node (Item.Prefs.Settings_Content), Yoga.All_Edges,
         Page_Margin * Pixels);
      Panels.Set_Fill (Item.Prefs.Settings_Form, Paper);
      Panels.Set_Border (Item.Prefs.Settings_Form, Themes.Border);
      Panels.Set_Shadow (Item.Prefs.Settings_Form, Themes.Shadow);
      Set_Flex_Direction (Widgets.Node (Item.Prefs.Settings_Form),
                          Yoga.Column);
      Set_Flex_Shrink (Widgets.Node (Item.Prefs.Settings_Form), 0.0);
      Set_Width (Widgets.Node (Item.Prefs.Settings_Form), Page_Width * Pixels);
      Item.Prefs.Form_Wide := Page_Width;
      Set_Padding
        (Widgets.Node (Item.Prefs.Settings_Form), Yoga.All_Edges,
         Dialog_Pad * Pixels);
      Set_Padding
        (Widgets.Node (Item.Prefs.Settings_Form), Yoga.Right,
         Dialog_Pad * Pixels + Offset);
      Set_Padding
        (Widgets.Node (Item.Prefs.Settings_Form), Yoga.Bottom,
         Dialog_Pad * Pixels + Offset);
      Set_Gap
        (Widgets.Node (Item.Prefs.Settings_Form), Yoga.All_Gutters,
         Row_Gap * Pixels);

      --  Display: its one option, Theme.
      Labels.Set_Text (Item.Prefs.Display_Heading, "DISPLAY");
      Labels.Set_Style (Item.Prefs.Display_Heading, UI.Line_Texts.Caption);
      Line (Item.Prefs.Display_Heading, Heading_Height);
      Labels.Set_Text (Item.Prefs.Theme_Name, "Theme");
      Labels.Set_Style (Item.Prefs.Theme_Name, UI.Line_Texts.Strong);
      Line (Item.Prefs.Theme_Name, Settings_Line);
      Radio (Item.Prefs.Theme_Light, "Light");
      Radio (Item.Prefs.Theme_Dark, "Dark");
      Radio (Item.Prefs.Theme_System, "System");

      --  Speech: its one option, Model.
      Labels.Set_Text (Item.Prefs.Speech_Heading, "SPEECH");
      Labels.Set_Style (Item.Prefs.Speech_Heading, UI.Line_Texts.Caption);
      Line (Item.Prefs.Speech_Heading, Heading_Height);
      Set_Margin
        (Widgets.Node (Item.Prefs.Speech_Heading), Yoga.Top,
         Heading_Top * Pixels);
      Labels.Set_Text (Item.Prefs.Model_Name, "Model");
      Labels.Set_Style (Item.Prefs.Model_Name, UI.Line_Texts.Strong);
      Line (Item.Prefs.Model_Name, Settings_Line);
      Radio (Item.Prefs.Model_Native, "MacOS");
      Radio (Item.Prefs.Model_Parakeet, "Parakeet");

      Set_Flex_Direction (Widgets.Node (Item.Prefs.Download_Row), Yoga.Row);
      Set_Align_Items (Widgets.Node (Item.Prefs.Download_Row), Yoga.Center);
      Line (Item.Prefs.Download_Row, Download_Height);
      Set_Margin
        (Widgets.Node (Item.Prefs.Download_Row), Yoga.Top, Gap * Pixels);
      Set_Gap
        (Widgets.Node (Item.Prefs.Download_Row), Yoga.All_Gutters,
         Gap * Pixels);
      Buttons.Set_Label (Item.Prefs.Download_Button, "Download");
      Buttons.Set_Kind (Item.Prefs.Download_Button, Buttons.Primary);
      Set_Width
        (Widgets.Node (Item.Prefs.Download_Button), Download_Width * Pixels);
      Set_Height
        (Widgets.Node (Item.Prefs.Download_Button), Download_Height * Pixels);
      Set_Flex_Shrink (Widgets.Node (Item.Prefs.Download_Button), 0.0);
      Buttons.Set_Label (Item.Prefs.Delete_Button, "Delete");
      Buttons.Set_Kind (Item.Prefs.Delete_Button, Buttons.Danger);
      Set_Width
        (Widgets.Node (Item.Prefs.Delete_Button), Download_Width * Pixels);
      Set_Height
        (Widgets.Node (Item.Prefs.Delete_Button), Download_Height * Pixels);
      Set_Flex_Shrink (Widgets.Node (Item.Prefs.Delete_Button), 0.0);
      Widgets.Set_Visible (Item.Prefs.Delete_Button, False);
      Labels.Set_Ink (Item.Prefs.Download_State, Quiet_Ink);
      Set_Flex_Grow (Widgets.Node (Item.Prefs.Download_State), 1.0);
      Set_Width (Widgets.Node (Item.Prefs.Download_State), 0.0);
      Set_Height
        (Widgets.Node (Item.Prefs.Download_State), Download_Height * Pixels);
      Line (Item.Prefs.Download_Bar, Progress_Height);
      Widgets.Set_Visible (Item.Prefs.Download_Bar, False);
      Widgets.Set_Visible (Item.Prefs.Settings_Panel, False);
   end Build_Settings;

   procedure Build_Dialog_Bar
     (Item  : in out Session;
      Bar   : in out Panels.Panel;
      Named : in out Labels.Label;
      Close : in out Buttons.Button;
      Name  : String);
   --  Style the dark bar across the top of a dialog, as a window's: its
   --  title, white, and a small button to close it, at the right.

   procedure Build_Dialog_Bar
     (Item  : in out Session;
      Bar   : in out Panels.Panel;
      Named : in out Labels.Label;
      Close : in out Buttons.Button;
      Name  : String)
   is
      use Yoga.Nodes;
      Pixels : constant Float := Item.Shell.Density;
   begin
      Panels.Set_Fill (Bar, Toolbar);
      Set_Flex_Direction (Widgets.Node (Bar), Yoga.Row);
      Set_Align_Items (Widgets.Node (Bar), Yoga.Center);
      Set_Height (Widgets.Node (Bar), Dialog_Bar_Height * Pixels);
      Set_Flex_Shrink (Widgets.Node (Bar), 0.0);
      Set_Padding
        (Widgets.Node (Bar), Yoga.Horizontal, Dialog_Bar_Pad * Pixels);
      Labels.Set_Text (Named, Name);
      Labels.Set_Style (Named, UI.Line_Texts.Strong);
      Labels.Set_Ink (Named, Themes.Bar_Ink);
      Set_Flex_Grow (Widgets.Node (Named), 1.0);
      Set_Width (Widgets.Node (Named), 0.0);
      Set_Height (Widgets.Node (Named), Dialog_Bar_Height * Pixels);
      Buttons.Set_Label (Close, "Close");
      Buttons.Set_Icon (Close, UI.Icons.Close);
      Buttons.Set_Icon_Size (Close, Dialog_Close_Icon);
      Set_Width (Widgets.Node (Close), Dialog_Close_Size * Pixels);
      Set_Height (Widgets.Node (Close), Dialog_Close_Size * Pixels);
      Set_Flex_Shrink (Widgets.Node (Close), 0.0);
   end Build_Dialog_Bar;

   procedure Build_Border
     (Item : in out Session; Border : in out Panels.Panel);
   --  Style the outline round a dialog.

   procedure Build_Border
     (Item : in out Session; Border : in out Panels.Panel)
   is
      use Yoga.Nodes;
      Pixels : constant Float := Item.Shell.Density;
   begin
      Panels.Set_Fill (Border, Themes.Border);
      Set_Flex_Direction (Widgets.Node (Border), Yoga.Column);
      Set_Padding
        (Widgets.Node (Border), Yoga.All_Edges, UI.Boxes.Edge (Pixels));
   end Build_Border;

   procedure Build_Modal (Item : in out Session);
   --  Add and style the dialog to confirm a deletion: over all else.

   procedure Build_Modal (Item : in out Session) is
      use Yoga.Nodes;
      Pixels : constant Float := Item.Shell.Density;
   begin
      Widgets.Add (Item.Root.Window_Panel, Item.Confirm.Overlay);
      Widgets.Add (Item.Confirm.Overlay, Item.Confirm.Dialog_Border);
      Widgets.Add (Item.Confirm.Dialog_Border, Item.Confirm.Dialog_Bar);
      Widgets.Add (Item.Confirm.Dialog_Bar, Item.Confirm.Dialog_Title);
      Widgets.Add (Item.Confirm.Dialog_Bar, Item.Confirm.Dialog_Close);
      Widgets.Add (Item.Confirm.Dialog_Border, Item.Confirm.Dialog);
      Widgets.Add (Item.Confirm.Dialog, Item.Confirm.Confirm_Message);
      Widgets.Add (Item.Confirm.Dialog, Item.Confirm.Confirm_Note);
      Widgets.Add (Item.Confirm.Dialog_Border, Item.Confirm.Dialog_Rule);
      Widgets.Add (Item.Confirm.Dialog_Border, Item.Confirm.Confirm_Buttons);
      Widgets.Add (Item.Confirm.Confirm_Buttons, Item.Confirm.Confirm_Cancel);
      Widgets.Add (Item.Confirm.Confirm_Buttons, Item.Confirm.Confirm_Delete);

      Panels.Set_Fill (Item.Confirm.Overlay, Themes.Scrim);
      Build_Border (Item, Item.Confirm.Dialog_Border);
      Build_Dialog_Bar
        (Item, Item.Confirm.Dialog_Bar, Item.Confirm.Dialog_Title,
         Item.Confirm.Dialog_Close,
         "Delete project");
      Panels.Set_Fill (Item.Confirm.Dialog, Paper);
      Labels.Set_Text (Item.Confirm.Confirm_Note, "This cannot be undone.");
      Buttons.Set_Label (Item.Confirm.Confirm_Cancel, "Cancel");
      Buttons.Set_Label (Item.Confirm.Confirm_Delete, "Delete");
      Buttons.Set_Icon (Item.Confirm.Confirm_Delete, UI.Icons.Delete);
      Buttons.Set_Icon_Size (Item.Confirm.Confirm_Delete, Mic_Icon_Size);
      Buttons.Set_Captioned (Item.Confirm.Confirm_Delete, True);
      Buttons.Set_Kind (Item.Confirm.Confirm_Delete, Buttons.Danger);
      Panels.Set_Fill (Item.Confirm.Dialog_Rule, Themes.Border);
      Set_Height (Widgets.Node (Item.Confirm.Dialog_Rule),
                  UI.Boxes.Edge (Pixels));
      Panels.Set_Fill (Item.Confirm.Confirm_Buttons, Themes.Tint);

      --  Not in the layout of the screens: over them, all of the window,
      --  with the dialog in the middle.
      Set_Position_Type (Widgets.Node (Item.Confirm.Overlay), Yoga.Absolute);
      for Side in Yoga.Left .. Yoga.Bottom loop
         Set_Position (Widgets.Node (Item.Confirm.Overlay), Side, 0.0);
      end loop;
      Set_Flex_Direction (Widgets.Node (Item.Confirm.Overlay), Yoga.Column);
      Set_Justify_Content (Widgets.Node (Item.Confirm.Overlay), Yoga.Center);
      Set_Align_Items (Widgets.Node (Item.Confirm.Overlay), Yoga.Center);

      Set_Width (Widgets.Node (Item.Confirm.Dialog_Border),
                 Dialog_Width * Pixels);
      Set_Flex_Direction (Widgets.Node (Item.Confirm.Dialog), Yoga.Column);
      Set_Padding
        (Widgets.Node (Item.Confirm.Dialog), Yoga.All_Edges,
         Dialog_Pad * Pixels);
      Set_Height (Widgets.Node (Item.Confirm.Confirm_Message),
                  Dialog_Line * Pixels);
      Set_Height (Widgets.Node (Item.Confirm.Confirm_Note),
                  Dialog_Line * Pixels);

      Set_Flex_Direction (Widgets.Node (Item.Confirm.Confirm_Buttons),
                          Yoga.Row);
      Set_Justify_Content (Widgets.Node (Item.Confirm.Confirm_Buttons),
                           Yoga.Flex_End);
      Set_Padding
        (Widgets.Node (Item.Confirm.Confirm_Buttons), Yoga.All_Edges,
         Dialog_Foot_Pad * Pixels);
      Set_Gap
        (Widgets.Node (Item.Confirm.Confirm_Buttons), Yoga.All_Gutters,
         Row_Gap * Pixels);
      Set_Height
        (Widgets.Node (Item.Confirm.Confirm_Cancel),
         Dialog_Button_Height * Pixels);
      Set_Height
        (Widgets.Node (Item.Confirm.Confirm_Delete),
         Dialog_Button_Height * Pixels);
      Set_Width
        (Widgets.Node (Item.Confirm.Confirm_Cancel),
         Dialog_Button_Width * Pixels);
      Set_Width
        (Widgets.Node (Item.Confirm.Confirm_Delete),
         Dialog_Button_Width * Pixels);
   end Build_Modal;

   procedure Build_List (Item : in out Session);
   --  Add and style the list of items: a dialog over all else.

   procedure Build_List (Item : in out Session) is
      use Yoga.Nodes;
      Pixels : constant Float := Item.Shell.Density;
   begin
      Widgets.Add (Item.Root.Window_Panel, Item.Item_List.List_Overlay);
      Widgets.Add (Item.Item_List.List_Overlay, Item.Item_List.List_Border);
      Widgets.Add (Item.Item_List.List_Border, Item.Item_List.List_Head);
      Widgets.Add (Item.Item_List.List_Head, Item.Item_List.List_Heading);
      Widgets.Add (Item.Item_List.List_Head, Item.Item_List.List_Close);
      Widgets.Add (Item.Item_List.List_Border, Item.Item_List.List_Dialog);
      Widgets.Add (Item.Item_List.List_Dialog, Item.Item_List.List_Scroll);
      Widgets.Add (Item.Item_List.List_Scroll, Item.Item_List.List_Content);
      Widgets.Add (Item.Item_List.List_Content, Item.Item_List.List_None);
      for Row of Item.Item_List.List_Rows loop
         Widgets.Add (Item.Item_List.List_Content, Row.Panel);
         Widgets.Add (Row.Panel, Row.Name);
         Widgets.Add (Row.Name, Row.Caption);
         Widgets.Add (Row.Panel, Row.Toggle);
         Widgets.Add (Row.Panel, Row.Remove);
      end loop;

      Panels.Set_Fill (Item.Item_List.List_Overlay, Themes.Scrim);
      Build_Border (Item, Item.Item_List.List_Border);
      Build_Dialog_Bar
        (Item, Item.Item_List.List_Head, Item.Item_List.List_Heading,
         Item.Item_List.List_Close, "Items");
      Panels.Set_Fill (Item.Item_List.List_Dialog, Paper);
      Labels.Set_Text (Item.Item_List.List_None, No_Items);

      Set_Position_Type (Widgets.Node (Item.Item_List.List_Overlay),
                         Yoga.Absolute);
      for Side in Yoga.Left .. Yoga.Bottom loop
         Set_Position (Widgets.Node (Item.Item_List.List_Overlay), Side, 0.0);
      end loop;
      Set_Flex_Direction (Widgets.Node (Item.Item_List.List_Overlay),
                          Yoga.Column);
      Set_Justify_Content (Widgets.Node (Item.Item_List.List_Overlay),
                           Yoga.Center);
      Set_Align_Items (Widgets.Node (Item.Item_List.List_Overlay),
                       Yoga.Center);

      Set_Width (Widgets.Node (Item.Item_List.List_Border),
                 List_Width * Pixels);
      Set_Height (Widgets.Node (Item.Item_List.List_Border),
                  List_Height * Pixels);
      Set_Flex_Direction (Widgets.Node (Item.Item_List.List_Dialog),
                          Yoga.Column);
      Set_Flex_Grow (Widgets.Node (Item.Item_List.List_Dialog), 1.0);
      Set_Height (Widgets.Node (Item.Item_List.List_Dialog), 0.0);
      Set_Padding
        (Widgets.Node (Item.Item_List.List_Dialog), Yoga.All_Edges,
         Dialog_Pad * Pixels);

      --  The scroller takes what the bar leaves; the rows go in a column
      --  in it, as tall as they are.
      Set_Flex_Grow (Widgets.Node (Item.Item_List.List_Scroll), 1.0);
      Set_Height (Widgets.Node (Item.Item_List.List_Scroll), 0.0);
      Set_Flex_Direction (Widgets.Node (Item.Item_List.List_Content),
                          Yoga.Column);
      Set_Flex_Shrink (Widgets.Node (Item.Item_List.List_Content), 0.0);
      --  Room at the right for the scroll bar.
      Set_Padding
        (Widgets.Node (Item.Item_List.List_Content), Yoga.Right,
         UI.Scrollbars.Thickness * Pixels);
      Set_Gap
        (Widgets.Node (Item.Item_List.List_Content), Yoga.All_Gutters,
         List_Gap * Pixels);
      Set_Height (Widgets.Node (Item.Item_List.List_None),
                  Title_Height * Pixels);
      for Row of Item.Item_List.List_Rows loop
         Panels.Set_Fill (Row.Panel, Themes.Tint);
         Panels.Set_Border (Row.Panel, Themes.Border);
         Set_Flex_Direction (Widgets.Node (Row.Panel), Yoga.Row);
         Set_Align_Items (Widgets.Node (Row.Panel), Yoga.Center);
         Set_Height (Widgets.Node (Row.Panel), Row_Height * Pixels);
         Set_Flex_Shrink (Widgets.Node (Row.Panel), 0.0);
         Set_Padding
           (Widgets.Node (Row.Panel), Yoga.Left, Row_Gap * Pixels);
         Set_Gap
           (Widgets.Node (Row.Panel), Yoga.All_Gutters, Row_Gap * Pixels);
         Set_Flex_Grow (Widgets.Node (Row.Name), 1.0);
         Set_Width (Widgets.Node (Row.Name), 0.0);
         Set_Height (Widgets.Node (Row.Name), Row_Height * Pixels);
         Set_Flex_Direction (Widgets.Node (Row.Name), Yoga.Row);
         Set_Align_Items (Widgets.Node (Row.Name), Yoga.Center);
         Set_Padding (Widgets.Node (Row.Name), Yoga.Left, Row_Gap * Pixels);
         Grips.Set_Wanted_Cursor (Row.Name, SDL3.Cursors.Pointer);
         Grips.Set_Hover_Outline (Row.Name, Themes.Foreground);
         Set_Flex_Grow (Widgets.Node (Row.Caption), 1.0);
         Set_Width (Widgets.Node (Row.Caption), 0.0);
         Set_Height (Widgets.Node (Row.Caption), Row_Height * Pixels);
         Set_Width (Widgets.Node (Row.Toggle), Toggle_Width * Pixels);
         Set_Height (Widgets.Node (Row.Toggle), Row_Height * Pixels);
         Set_Width (Widgets.Node (Row.Remove), Remove_Width * Pixels);
         Set_Height (Widgets.Node (Row.Remove), Row_Height * Pixels);
         Buttons.Set_Label (Row.Remove, "Remove");
         Buttons.Set_Icon (Row.Remove, UI.Icons.Delete);
         Buttons.Set_Kind (Row.Remove, Buttons.Danger);
      end loop;
   end Build_List;

   procedure Set_Up
     (Item       : in out Session;
      Source     : String;
      File_Name  : String;
      Store_Path : String)
   is
      use Yoga.Nodes;
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
      UI.Icons.Set_Directory (Item.Host.Pictures, Share_Directory ("icons"));
      if Item.Shell.Windowed then
         Widgets.Set_Clipboard (Item.Root.Widgets, Item.Shell.System_Board);
      else
         Widgets.Set_Clipboard (Item.Root.Widgets, Item.Shell.Own_Board);
      end if;

      Widgets.Set_Root (Item.Root.Widgets, Item.Root.Window_Panel);
      Set_Flex_Direction (Widgets.Node (Item.Root.Window_Panel), Yoga.Column);
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

      Buttons.Set_Label (Item.Home_View.Ok_Button, "OK");
      Buttons.Set_Kind (Item.Home_View.Ok_Button, Buttons.Primary);
      Buttons.Set_Label (Item.Home_View.Cancel_Button, "Cancel");
      Text_Fields.Set_Shared
        (Item.Title_Edit.Edit_Field, Item.Host.Doc_Resources'Unchecked_Access);
      Text_Fields.Configure
        (Item.Title_Edit.Edit_Field, UI.Line_Texts.Interface_Font, Edit_Size);

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
