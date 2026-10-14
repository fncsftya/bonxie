with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings.Unbounded;
with Items.Readers;
with Items.Windows;
with Preferences;
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
      Widgets.Add (Item.Window_Panel, Item.Header_Panel);
      Widgets.Add (Item.Header_Panel, Item.Header_Title);
      Set_Height
        (Widgets.Node (Item.Header_Panel), Header_Size * Item.Density);
      Widgets.Set_Visible (Item.Header_Panel, False);
   end Build_Header;

   procedure Build_Home (Item : in out Session);
   --  Add and style the home screen's widgets.

   procedure Build_Home (Item : in out Session) is
      use Yoga.Nodes;
      Pixels : constant Float := Item.Density;
      Top    : constant Float := (if Item.Windowed then Header_Size else 0.0);
      --  Clear of the window's own buttons.

      procedure Size (Part : in out Widgets.Widget'Class; Wide, High : Float)
      is
      begin
         Set_Width (Widgets.Node (Part), Wide * Pixels);
         Set_Height (Widgets.Node (Part), High * Pixels);
      end Size;
   begin
      Widgets.Add (Item.Window_Panel, Item.Home_Panel);
      Widgets.Add (Item.Home_Panel, Item.Home_Side);
      Widgets.Add (Item.Home_Side, Item.Logo);
      Widgets.Add (Item.Logo, Item.Logo_Name);
      Widgets.Add (Item.Home_Side, Item.New_Button);
      Widgets.Add (Item.Home_Side, Item.Side_Room);
      Widgets.Add (Item.Home_Side, Item.Settings_Button);
      Widgets.Add (Item.Home_Panel, Item.Home_Rule);
      Widgets.Add (Item.Home_Panel, Item.Recent_Panel);
      Widgets.Add (Item.Recent_Panel, Item.Recent_Title);
      Widgets.Add (Item.Recent_Panel, Item.Cards_Scroll);
      Widgets.Add (Item.Cards_Scroll, Item.Cards_Content);
      for Card of Item.Cards loop
         Widgets.Add (Item.Cards_Content, Card.Panel);
         Widgets.Add (Card.Panel, Card.Peek);
         Widgets.Add (Card.Peek, Card.Picture);
         Widgets.Add (Card.Panel, Card.Info);
         Widgets.Add (Card.Info, Card.Name);
         Widgets.Add (Card.Name, Card.Title);
         Widgets.Add (Card.Name, Card.Meta);
         Widgets.Add (Card.Info, Card.Rename);
         Widgets.Add (Card.Info, Card.Delete);
      end loop;
      Widgets.Add (Item.Cards_Content, Item.New_Card);
      Widgets.Add (Item.New_Card, Item.New_Card_Plus);
      Widgets.Add (Item.New_Card, Item.New_Card_Label);
      Widgets.Add (Item.Cards_Content, Item.No_Rows);

      Set_Flex_Direction (Widgets.Node (Item.Home_Panel), Yoga.Row);
      Set_Flex_Grow (Widgets.Node (Item.Home_Panel), 1.0);

      --  The sidebar: the name, New Project, and Settings at the foot.
      Panels.Set_Fill (Item.Home_Side, Mid_Panel);
      Set_Flex_Direction (Widgets.Node (Item.Home_Side), Yoga.Column);
      Set_Width (Widgets.Node (Item.Home_Side), Home_Side_Width * Pixels);
      Set_Flex_Shrink (Widgets.Node (Item.Home_Side), 0.0);
      Set_Padding
        (Widgets.Node (Item.Home_Side), Yoga.All_Edges, Side_Pad * Pixels);
      Set_Padding
        (Widgets.Node (Item.Home_Side), Yoga.Top, (Side_Pad + Top) * Pixels);
      Set_Flex_Direction (Widgets.Node (Item.Logo), Yoga.Row);
      Set_Align_Items (Widgets.Node (Item.Logo), Yoga.Center);
      Set_Height (Widgets.Node (Item.Logo), Logo_Height * Pixels);
      Set_Margin (Widgets.Node (Item.Logo), Yoga.Bottom, Logo_Gap * Pixels);
      Labels.Set_Text (Item.Logo_Name, "bonxie");
      Labels.Set_Style (Item.Logo_Name, UI.Line_Texts.Display);
      Set_Flex_Grow (Widgets.Node (Item.Logo_Name), 1.0);
      Set_Height (Widgets.Node (Item.Logo_Name), Logo_Height * Pixels);
      Buttons.Set_Label (Item.New_Button, "New project");
      Buttons.Set_Icon (Item.New_Button, UI.Icons.Plus);
      Buttons.Set_Captioned (Item.New_Button, True);
      Buttons.Set_Kind (Item.New_Button, Buttons.Primary);
      Set_Height (Widgets.Node (Item.New_Button), Action_Height * Pixels);
      Set_Flex_Grow (Widgets.Node (Item.Side_Room), 1.0);
      Buttons.Set_Label (Item.Settings_Button, "Settings");
      Buttons.Set_Icon (Item.Settings_Button, UI.Icons.Settings);
      Buttons.Set_Captioned (Item.Settings_Button, True);
      Set_Height
        (Widgets.Node (Item.Settings_Button), Action_Height * Pixels);
      Panels.Set_Fill (Item.Home_Rule, Themes.Border);
      Set_Width (Widgets.Node (Item.Home_Rule), UI.Boxes.Edge (Pixels));
      Set_Flex_Shrink (Widgets.Node (Item.Home_Rule), 0.0);

      --  The projects: a title, and the cards in rows that wrap. The title
      --  is on the line of the name, as the same height from the same top.
      Set_Flex_Direction (Widgets.Node (Item.Recent_Panel), Yoga.Column);
      Set_Flex_Grow (Widgets.Node (Item.Recent_Panel), 1.0);
      Set_Width (Widgets.Node (Item.Recent_Panel), 0.0);
      Set_Padding
        (Widgets.Node (Item.Recent_Panel), Yoga.Top,
         (Side_Pad + Top) * Pixels);
      Set_Padding
        (Widgets.Node (Item.Recent_Panel), Yoga.Left, Home_Margin * Pixels);
      Labels.Set_Text (Item.Recent_Title, "Recent projects");
      Labels.Set_Style (Item.Recent_Title, UI.Line_Texts.Display);
      Set_Height (Widgets.Node (Item.Recent_Title), Logo_Height * Pixels);
      Set_Margin
        (Widgets.Node (Item.Recent_Title), Yoga.Bottom, Logo_Gap * Pixels);
      Set_Flex_Grow (Widgets.Node (Item.Cards_Scroll), 1.0);
      Set_Height (Widgets.Node (Item.Cards_Scroll), 0.0);
      Set_Flex_Direction (Widgets.Node (Item.Cards_Content), Yoga.Row);
      Set_Wrap (Widgets.Node (Item.Cards_Content), Yoga.Wrap);
      Set_Align_Items (Widgets.Node (Item.Cards_Content), Yoga.Flex_Start);
      Set_Flex_Shrink (Widgets.Node (Item.Cards_Content), 0.0);
      Set_Gap
        (Widgets.Node (Item.Cards_Content), Yoga.All_Gutters,
         Card_Gap * Pixels);
      Set_Padding
        (Widgets.Node (Item.Cards_Content), Yoga.Right,
         (Home_Margin - Card_Gap) * Pixels);
      Set_Padding
        (Widgets.Node (Item.Cards_Content), Yoga.Bottom,
         Home_Margin * Pixels);
      Labels.Set_Text (Item.No_Rows, No_Projects);
      Labels.Set_Ink (Item.No_Rows, Quiet_Ink);
      Set_Height (Widgets.Node (Item.No_Rows), Title_Height * Pixels);
      Set_Width (Widgets.Node (Item.No_Rows), Card_Width * Pixels);

      for Card of Item.Cards loop
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
      Grips.Set_Border (Item.New_Card, Themes.Border, Dashed => True);
      Grips.Set_Wanted_Cursor (Item.New_Card, SDL3.Cursors.Pointer);
      Size (Item.New_Card, Card_Width - Themes.Shadow_Offset,
            Card_Height - Themes.Shadow_Offset);
      Set_Flex_Shrink (Widgets.Node (Item.New_Card), 0.0);
      Set_Flex_Direction (Widgets.Node (Item.New_Card), Yoga.Column);
      Set_Justify_Content (Widgets.Node (Item.New_Card), Yoga.Center);
      Set_Align_Items (Widgets.Node (Item.New_Card), Yoga.Center);
      Buttons.Set_Label (Item.New_Card_Plus, "New");
      Buttons.Set_Icon (Item.New_Card_Plus, UI.Icons.Plus);
      Buttons.Set_Kind (Item.New_Card_Plus, Buttons.Primary);
      Size (Item.New_Card_Plus, Plus_Size, Plus_Size);
      Labels.Set_Text (Item.New_Card_Label, "New project");
      Labels.Set_Style (Item.New_Card_Label, UI.Line_Texts.Strong);
      Labels.Set_Ink
        (Item.New_Card_Label,
         Themes.Primary_Mix);
      Labels.Set_Centered (Item.New_Card_Label, True);
      Size (Item.New_Card_Label, Card_Width / 2.0, Title_Height);
      Set_Margin
        (Widgets.Node (Item.New_Card_Label), Yoga.Top, Row_Gap * Pixels);
   end Build_Home;

   procedure Build_Project (Item : in out Session);
   --  Add and style the project screen's widgets.

   procedure Build_Project (Item : in out Session) is
      use Yoga.Nodes;
      Pixels : constant Float := Item.Density;

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
      Widgets.Add (Item.Window_Panel, Item.Project_Panel);
      Widgets.Add (Item.Project_Panel, Item.Toolbar_Panel);
      Widgets.Add (Item.Toolbar_Panel, Item.Toolbar_Start);
      Widgets.Add (Item.Toolbar_Start, Item.Close_Button);
      Widgets.Add (Item.Toolbar_Start, Item.Bar_Rule);
      Widgets.Add (Item.Toolbar_Start, Item.Project_Title);
      Widgets.Add (Item.Toolbar_Panel, Item.Tabs);
      Widgets.Add (Item.Tabs, Item.Canvas_Tab);
      Widgets.Add (Item.Tabs, Item.Write_Tab);
      Widgets.Add (Item.Toolbar_Panel, Item.Toolbar_End);
      Widgets.Add (Item.Toolbar_End, Item.Tool_List);
      Widgets.Add (Item.Project_Panel, Item.Content_Panel);
      Widgets.Add (Item.Content_Panel, Item.Canvas_View);
      Widgets.Add (Item.Project_Panel, Item.Dock_Panel);
      Widgets.Add (Item.Dock_Panel, Item.Dock_Scroll);
      Widgets.Add (Item.Dock_Scroll, Item.Dock_Content);

      Set_Flex_Direction (Widgets.Node (Item.Project_Panel), Yoga.Column);
      Set_Flex_Grow (Widgets.Node (Item.Project_Panel), 1.0);
      Set_Flex_Grow (Widgets.Node (Item.Content_Panel), 1.0);
      Set_Flex_Direction (Widgets.Node (Item.Content_Panel), Yoga.Column);
      --  The pages are taller than it: it takes what the bars leave.
      Set_Height (Widgets.Node (Item.Content_Panel), 0.0);
      Set_Flex_Grow (Widgets.Node (Item.Canvas_View), 1.0);

      --  The bar across the top: the way back and the project's name at the
      --  left, the tabs in the middle (the sides take equal shares), the
      --  list of items at the right.
      Panels.Set_Fill (Item.Toolbar_Panel, Toolbar);
      Set_Height (Widgets.Node (Item.Toolbar_Panel), Toolbar_Size * Pixels);
      Set_Flex_Shrink (Widgets.Node (Item.Toolbar_Panel), 0.0);
      Set_Flex_Direction (Widgets.Node (Item.Toolbar_Panel), Yoga.Row);
      Set_Align_Items (Widgets.Node (Item.Toolbar_Panel), Yoga.Center);
      Set_Padding
        (Widgets.Node (Item.Toolbar_Panel), Yoga.Left,
         (if Item.Windowed then Header_Inset else Bar_Inset) * Pixels);
      Set_Padding
        (Widgets.Node (Item.Toolbar_Panel), Yoga.Right, Bar_Inset * Pixels);
      Side (Item.Toolbar_Start, Yoga.Flex_Start);
      Side (Item.Toolbar_End, Yoga.Flex_End);
      Buttons.Set_Label (Item.Close_Button, "Projects");
      Buttons.Set_Icon (Item.Close_Button, UI.Icons.Back);
      Buttons.Set_Captioned (Item.Close_Button, True);
      Buttons.Set_Kind (Item.Close_Button, Buttons.Quiet);
      Size (Item.Close_Button, Back_Width, Tab_Height);
      Panels.Set_Fill (Item.Bar_Rule, Rule_Ink);
      Size (Item.Bar_Rule, 0.0, Bar_Rule_Height);
      Set_Width (Widgets.Node (Item.Bar_Rule), UI.Boxes.Edge (Pixels));
      Set_Margin
        (Widgets.Node (Item.Bar_Rule), Yoga.Horizontal, Name_Gap * Pixels);
      Labels.Set_Style (Item.Project_Title, UI.Line_Texts.Heading);
      Labels.Set_Ink (Item.Project_Title, Themes.Bar_Ink);
      Set_Flex_Grow (Widgets.Node (Item.Project_Title), 1.0);
      Set_Width (Widgets.Node (Item.Project_Title), 0.0);
      Set_Height (Widgets.Node (Item.Project_Title), Tab_Height * Pixels);

      Set_Flex_Direction (Widgets.Node (Item.Tabs), Yoga.Row);
      Set_Gap (Widgets.Node (Item.Tabs), Yoga.All_Gutters, Tab_Gap * Pixels);
      Buttons.Set_Label (Item.Canvas_Tab, "Canvas");
      Buttons.Set_Selected (Item.Canvas_Tab, True);
      Buttons.Set_Label (Item.Write_Tab, "Write");
      Size (Item.Canvas_Tab, Tab_Width, Tab_Height);
      Size (Item.Write_Tab, Tab_Width, Tab_Height);
      Buttons.Set_Label (Item.Tool_List, "Items");
      Buttons.Set_Icon (Item.Tool_List, UI.Icons.List);
      Buttons.Set_Captioned (Item.Tool_List, True);
      Size (Item.Tool_List, Items_Width, Tab_Height);

      --  The dock of minimised items, under the canvas, and the
      --  windows of the items: on the canvas, or as bars in the dock.
      Panels.Set_Fill (Item.Dock_Panel, Dock);
      Set_Height (Widgets.Node (Item.Dock_Panel), Dock_Height * Pixels);
      Set_Flex_Shrink (Widgets.Node (Item.Dock_Panel), 0.0);
      Set_Flex_Direction (Widgets.Node (Item.Dock_Panel), Yoga.Row);
      Scrollers.Set_Across (Item.Dock_Scroll, True);
      Set_Flex_Direction (Widgets.Node (Item.Dock_Scroll), Yoga.Row);
      Set_Flex_Grow (Widgets.Node (Item.Dock_Scroll), 1.0);
      Set_Width (Widgets.Node (Item.Dock_Scroll), 0.0);
      Set_Flex_Direction (Widgets.Node (Item.Dock_Content), Yoga.Row);
      Set_Flex_Shrink (Widgets.Node (Item.Dock_Content), 0.0);
      Set_Align_Items (Widgets.Node (Item.Dock_Content), Yoga.Center);
      Set_Padding
        (Widgets.Node (Item.Dock_Content), Yoga.Horizontal,
         Dock_Inset * Pixels);
      Set_Gap
        (Widgets.Node (Item.Dock_Content), Yoga.All_Gutters,
         Dock_Gap * Pixels);
      for Each of Item.Windows loop
         Items.Windows.Set_Shared
           (Each, Item.Doc_Resources'Unchecked_Access);
         Items.Windows.Build
           (Each, Item.Canvas_View, Item.Dock_Content, Toolbar, Pixels);
      end loop;
      Links.Build (Item);
   end Build_Project;

   procedure Build_Tray (Item : in out Session);
   --  Add and style the tray of the canvas's tools: over it, after the
   --  writing view, so over that too, at the foot (see
   --  Canvas_Items.Sync, which puts it in the middle).

   procedure Build_Tray (Item : in out Session) is
      use Yoga.Nodes;
      Pixels : constant Float := Item.Density;
   begin
      Widgets.Add (Item.Content_Panel, Item.Tools);
      Widgets.Add (Item.Tools, Item.Tool_Item);
      Widgets.Add (Item.Tools, Item.Tool_Source);
      Panels.Set_Fill (Item.Tools, Toolbar);
      Panels.Set_Shadow (Item.Tools, Themes.Shadow);
      Set_Position_Type (Widgets.Node (Item.Tools), Yoga.Absolute);
      Set_Position
        (Widgets.Node (Item.Tools), Yoga.Bottom,
         (Tray_Foot - Themes.Shadow_Offset) * Pixels);
      Set_Width (Widgets.Node (Item.Tools), Tray_Width * Pixels);
      Set_Height (Widgets.Node (Item.Tools), Tray_Height * Pixels);
      Set_Flex_Direction (Widgets.Node (Item.Tools), Yoga.Row);
      Set_Align_Items (Widgets.Node (Item.Tools), Yoga.Center);
      Set_Padding
        (Widgets.Node (Item.Tools), Yoga.All_Edges, Tray_Pad * Pixels);
      Set_Padding
        (Widgets.Node (Item.Tools), Yoga.Right,
         Tray_Pad * Pixels + UI.Boxes.Offset (Pixels));
      Set_Padding
        (Widgets.Node (Item.Tools), Yoga.Bottom,
         Tray_Pad * Pixels + UI.Boxes.Offset (Pixels));
      Set_Gap
        (Widgets.Node (Item.Tools), Yoga.All_Gutters, Tray_Gap * Pixels);
      Buttons.Set_Label (Item.Tool_Item, "Add document");
      Buttons.Set_Icon (Item.Tool_Item, UI.Icons.Document);
      Buttons.Set_Captioned (Item.Tool_Item, True);
      Buttons.Set_Label (Item.Tool_Source, "Add source");
      Buttons.Set_Icon (Item.Tool_Source, UI.Icons.Link);
      Buttons.Set_Captioned (Item.Tool_Source, True);
      Buttons.Set_Kind (Item.Tool_Source, Buttons.Primary);
      Set_Width (Widgets.Node (Item.Tool_Item), Wide_Tool_Width * Pixels);
      Set_Height (Widgets.Node (Item.Tool_Item), Tool_Height * Pixels);
      Set_Width (Widgets.Node (Item.Tool_Source), Tool_Width * Pixels);
      Set_Height (Widgets.Node (Item.Tool_Source), Tool_Height * Pixels);
   end Build_Tray;

   procedure Build_Write (Item : in out Session);
   --  Add and style the writing view's widgets.

   procedure Build_Write (Item : in out Session) is
      use Yoga.Nodes;
      Pixels : constant Float := Item.Density;
      Edge   : constant Float := UI.Boxes.Edge (Pixels);
      Offset : constant Float := UI.Boxes.Offset (Pixels);

      procedure Build_Index
        (Scroll   : in out Scrollers.Scroller;
         Content  : in out Panels.Panel;
         None     : in out Labels.Label;
         Empty    : String) is
      begin
         Widgets.Add (Item.Sidebar, Scroll);
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
      Widgets.Add (Item.Content_Panel, Item.Write_View);
      Widgets.Add (Item.Write_View, Item.Sidebar);
      Widgets.Add (Item.Sidebar, Item.Docs_Head);
      Widgets.Add (Item.Docs_Head, Item.Docs_Heading);
      Widgets.Add (Item.Docs_Head, Item.Docs_Folder);
      Widgets.Add (Item.Docs_Head, Item.Docs_Add);
      Build_Index
        (Item.Docs_Scroll, Item.Docs_Content, Item.Docs_None, No_Documents);
      for Each of Item.Doc_Rows loop
         Build_Row (Item.Docs_Content, Each, Counted => True);
         Panels.Set_Fill (Each.Tag, Quiet_Ink);
      end loop;
      Widgets.Add (Item.Docs_Content, Item.Docs_None);
      Set_Height (Widgets.Node (Item.Docs_None), Index_Height * Pixels);
      Widgets.Add (Item.Docs_Content, Item.Drop_Line);
      Widgets.Add (Item.Docs_Content, Item.Dir_Field);
      Widgets.Add (Item.Sidebar, Item.Sources_Heading);
      Build_Index
        (Item.Sources_Scroll, Item.Sources_Content, Item.Sources_None,
         No_Sources);
      for Each of Item.Source_Rows loop
         Build_Row (Item.Sources_Content, Each, Counted => False);
      end loop;
      Widgets.Add (Item.Sources_Content, Item.Sources_None);
      Widgets.Add (Item.Sources_Content, Item.Source_Field);
      Set_Height (Widgets.Node (Item.Sources_None), Index_Height * Pixels);
      Widgets.Add (Item.Write_View, Item.Sidebar_Rule);
      Widgets.Add (Item.Write_View, Item.Pages_Scroll);
      Widgets.Add (Item.Pages_Scroll, Item.Pages_Content);
      for Each of Item.Pages loop
         Widgets.Add (Item.Pages_Content, Each.Box);
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
      Widgets.Add (Item.Write_View, Item.Pane);
      Widgets.Add (Item.Pane, Item.Pane_Edge);
      Widgets.Add (Item.Pane, Item.Pane_Body);
      --  Over the rest, last.
      for Each of Item.Readers loop
         Items.Readers.Build
           (Each, Item.Write_View, Toolbar, Pixels);
      end loop;
      Widgets.Add (Item.Write_View, Item.Menu);
      Set_Position_Type (Widgets.Node (Item.Menu), Yoga.Absolute);
      Set_Width (Widgets.Node (Item.Menu), Menu_Width * Pixels);
      Widgets.Set_Visible (Item.Menu, False);
      Widgets.Add (Item.Content_Panel, Item.Context_Menu);
      Set_Position_Type (Widgets.Node (Item.Context_Menu), Yoga.Absolute);
      Set_Width (Widgets.Node (Item.Context_Menu), Context_Width * Pixels);
      Widgets.Set_Visible (Item.Context_Menu, False);
      Items.Readers.Build
        (Item.Pane_Reader, Item.Pane_Body, Toolbar, Pixels, Pinned => True);

      Panels.Set_Fill (Item.Write_View, Desk);
      Set_Flex_Direction (Widgets.Node (Item.Write_View), Yoga.Row);
      Set_Flex_Grow (Widgets.Node (Item.Write_View), 1.0);
      Set_Height (Widgets.Node (Item.Write_View), 0.0);

      --  The sidebar: two lists one above the other, with a line at its
      --  right.
      Panels.Set_Fill (Item.Sidebar, Side_Fill);
      Set_Width (Widgets.Node (Item.Sidebar), Sidebar_Width * Pixels);
      Set_Flex_Shrink (Widgets.Node (Item.Sidebar), 0.0);
      Set_Padding
        (Widgets.Node (Item.Sidebar), Yoga.All_Edges, Sidebar_Pad * Pixels);
      Set_Padding
        (Widgets.Node (Item.Sidebar), Yoga.Top,
         (Sidebar_Pad + Heading_Top) * Pixels);
      Set_Flex_Direction (Widgets.Node (Item.Sidebar), Yoga.Column);
      Set_Gap
        (Widgets.Node (Item.Sidebar), Yoga.All_Gutters, Sidebar_Gap * Pixels);
      Panels.Set_Fill (Item.Sidebar_Rule, Themes.Border);
      Set_Width (Widgets.Node (Item.Sidebar_Rule), Edge);
      Set_Flex_Shrink (Widgets.Node (Item.Sidebar_Rule), 0.0);
      Set_Flex_Direction (Widgets.Node (Item.Docs_Head), Yoga.Row);
      Set_Align_Items (Widgets.Node (Item.Docs_Head), Yoga.Center);
      Set_Padding (Widgets.Node (Item.Docs_Head), Yoga.Right, Offset);
      Heading (Item.Docs_Heading, "DOCUMENTS");
      Set_Flex_Grow (Widgets.Node (Item.Docs_Heading), 1.0);
      Heading (Item.Sources_Heading, "SOURCES");
      Set_Margin
        (Widgets.Node (Item.Sources_Heading), Yoga.Top,
         Heading_Top * Pixels);
      Buttons.Set_Label (Item.Docs_Add, "+");
      Buttons.Set_Icon (Item.Docs_Add, UI.Icons.Plus);
      Buttons.Set_Icon_Size (Item.Docs_Add, Mic_Icon_Size);
      Set_Width (Widgets.Node (Item.Docs_Add), Add_Size * Pixels);
      Set_Height (Widgets.Node (Item.Docs_Add), Add_Size * Pixels);
      Buttons.Set_Label (Item.Docs_Folder, "New folder");
      Buttons.Set_Icon (Item.Docs_Folder, UI.Icons.Folder);
      Buttons.Set_Icon_Size (Item.Docs_Folder, Mic_Icon_Size);
      Set_Width (Widgets.Node (Item.Docs_Folder), Add_Size * Pixels);
      Set_Height (Widgets.Node (Item.Docs_Folder), Add_Size * Pixels);
      Set_Gap
        (Widgets.Node (Item.Docs_Head), Yoga.All_Gutters,
         Index_Gap * Pixels);

      --  Over the rows of the tree, out of their layout: the line where a
      --  document dragged would go between two, and the field to rename
      --  a directory by.
      Panels.Set_Fill (Item.Drop_Line, UI.Themes.Accent);
      Set_Position_Type (Widgets.Node (Item.Drop_Line), Yoga.Absolute);
      Set_Height (Widgets.Node (Item.Drop_Line), Drop_Line_Height * Pixels);
      Widgets.Set_Visible (Item.Drop_Line, False);
      Text_Fields.Set_Shared
        (Item.Dir_Field, Item.Doc_Resources'Unchecked_Access);
      Text_Fields.Configure
        (Item.Dir_Field, UI.Line_Texts.Interface_Font, Edit_Size);
      Set_Position_Type (Widgets.Node (Item.Dir_Field), Yoga.Absolute);
      Set_Height (Widgets.Node (Item.Dir_Field), Index_Height * Pixels);
      Widgets.Set_Visible (Item.Dir_Field, False);
      Text_Fields.Set_Shared
        (Item.Source_Field, Item.Doc_Resources'Unchecked_Access);
      Text_Fields.Configure
        (Item.Source_Field, UI.Line_Texts.Interface_Font, Edit_Size);
      Set_Position_Type (Widgets.Node (Item.Source_Field), Yoga.Absolute);
      Set_Height (Widgets.Node (Item.Source_Field), Index_Height * Pixels);
      Widgets.Set_Visible (Item.Source_Field, False);

      --  The pages, scrolled, one above the next, and the button to add
      --  one after them.
      Set_Flex_Grow (Widgets.Node (Item.Pages_Scroll), 1.0);
      Set_Width (Widgets.Node (Item.Pages_Scroll), 0.0);
      Set_Flex_Direction (Widgets.Node (Item.Pages_Content), Yoga.Column);
      Set_Flex_Shrink (Widgets.Node (Item.Pages_Content), 0.0);
      Set_Align_Items (Widgets.Node (Item.Pages_Content), Yoga.Center);
      Set_Padding
        (Widgets.Node (Item.Pages_Content), Yoga.All_Edges,
         Page_Margin * Pixels);
      Set_Padding
        (Widgets.Node (Item.Pages_Content), Yoga.Top,
         (Page_Margin - Page_Gap) * Pixels);
      Set_Gap
        (Widgets.Node (Item.Pages_Content), Yoga.All_Gutters,
         Page_Gap * Pixels);
      for Each of Item.Pages loop
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
           (Each.Title_Field, Item.Doc_Resources'Unchecked_Access);
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
           (Each.Text, Item.Doc_Resources'Unchecked_Access);
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
      Panels.Set_Fill (Item.Pane, Desk);
      Set_Flex_Direction (Widgets.Node (Item.Pane), Yoga.Row);
      Set_Flex_Shrink (Widgets.Node (Item.Pane), 0.0);
      Item.Pane_Wide := Pane_Default;
      Set_Width (Widgets.Node (Item.Pane), Pane_Default * Pixels);
      Grips.Set_Fill (Item.Pane_Edge, Edge_Fill);
      Grips.Set_Wanted_Cursor (Item.Pane_Edge, SDL3.Cursors.Resize_Across);
      Set_Width (Widgets.Node (Item.Pane_Edge), Pane_Edge_Width * Pixels);
      Set_Flex_Shrink (Widgets.Node (Item.Pane_Edge), 0.0);
      Set_Flex_Direction (Widgets.Node (Item.Pane_Body), Yoga.Column);
      Set_Flex_Grow (Widgets.Node (Item.Pane_Body), 1.0);
      Set_Width (Widgets.Node (Item.Pane_Body), 0.0);
      Widgets.Set_Visible (Item.Pane, False);
   end Build_Write;

   procedure Build_Settings (Item : in out Session);
   --  Add and style the settings: a bar across the top that stays, and the
   --  form, as wide as a page in the writing view, centred and scrolled.

   procedure Build_Settings (Item : in out Session) is
      use Yoga.Nodes;
      Pixels : constant Float := Item.Density;
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
      Widgets.Add (Item.Window_Panel, Item.Settings_Panel);
      Widgets.Add (Item.Settings_Panel, Item.Settings_Bar);
      Widgets.Add (Item.Settings_Bar, Item.Settings_Title);
      Widgets.Add (Item.Settings_Bar, Item.Settings_Close);
      Widgets.Add (Item.Settings_Panel, Item.Settings_Scroll);
      Widgets.Add (Item.Settings_Scroll, Item.Settings_Content);
      Widgets.Add (Item.Settings_Content, Item.Settings_Form);
      Widgets.Add (Item.Settings_Form, Item.Display_Heading);
      Widgets.Add (Item.Settings_Form, Item.Theme_Name);
      Widgets.Add (Item.Settings_Form, Item.Theme_Light);
      Widgets.Add (Item.Settings_Form, Item.Theme_Dark);
      Widgets.Add (Item.Settings_Form, Item.Theme_System);
      Widgets.Add (Item.Settings_Form, Item.Speech_Heading);
      Widgets.Add (Item.Settings_Form, Item.Model_Name);
      Widgets.Add (Item.Settings_Form, Item.Model_Native);
      Widgets.Add (Item.Settings_Form, Item.Model_Parakeet);
      Widgets.Add (Item.Settings_Form, Item.Download_Row);
      Widgets.Add (Item.Download_Row, Item.Download_Button);
      Widgets.Add (Item.Download_Row, Item.Download_State);
      Widgets.Add (Item.Settings_Form, Item.Download_Bar);

      Set_Flex_Direction (Widgets.Node (Item.Settings_Panel), Yoga.Column);
      Set_Flex_Grow (Widgets.Node (Item.Settings_Panel), 1.0);
      Panels.Set_Fill (Item.Settings_Panel, Desk);

      --  The bar, outside what scrolls, so that it stays: the title at the
      --  left (clear of the window's own buttons) and Close at the right.
      Panels.Set_Fill (Item.Settings_Bar, Toolbar);
      Line (Item.Settings_Bar, Toolbar_Size);
      Set_Flex_Direction (Widgets.Node (Item.Settings_Bar), Yoga.Row);
      Set_Align_Items (Widgets.Node (Item.Settings_Bar), Yoga.Center);
      Set_Padding
        (Widgets.Node (Item.Settings_Bar), Yoga.Left,
         (if Item.Windowed then Header_Inset else Bar_Inset) * Pixels);
      Set_Padding
        (Widgets.Node (Item.Settings_Bar), Yoga.Right, Bar_Inset * Pixels);
      Labels.Set_Text (Item.Settings_Title, "Settings");
      Labels.Set_Style (Item.Settings_Title, UI.Line_Texts.Heading);
      Labels.Set_Ink (Item.Settings_Title, Themes.Bar_Ink);
      Set_Flex_Grow (Widgets.Node (Item.Settings_Title), 1.0);
      Set_Width (Widgets.Node (Item.Settings_Title), 0.0);
      Set_Height (Widgets.Node (Item.Settings_Title), Tab_Height * Pixels);
      Buttons.Set_Label (Item.Settings_Close, "Close");
      Buttons.Set_Icon (Item.Settings_Close, UI.Icons.Close);
      Buttons.Set_Captioned (Item.Settings_Close, True);
      Buttons.Set_Kind (Item.Settings_Close, Buttons.Quiet);
      Set_Width (Widgets.Node (Item.Settings_Close), Items_Width * Pixels);
      Set_Height (Widgets.Node (Item.Settings_Close), Tab_Height * Pixels);
      Set_Flex_Shrink (Widgets.Node (Item.Settings_Close), 0.0);

      --  The form, on a page of its own, in the middle.
      Set_Flex_Grow (Widgets.Node (Item.Settings_Scroll), 1.0);
      Set_Height (Widgets.Node (Item.Settings_Scroll), 0.0);
      Set_Flex_Direction (Widgets.Node (Item.Settings_Content), Yoga.Column);
      Set_Flex_Shrink (Widgets.Node (Item.Settings_Content), 0.0);
      Set_Align_Items (Widgets.Node (Item.Settings_Content), Yoga.Center);
      Set_Padding
        (Widgets.Node (Item.Settings_Content), Yoga.All_Edges,
         Page_Margin * Pixels);
      Panels.Set_Fill (Item.Settings_Form, Paper);
      Panels.Set_Border (Item.Settings_Form, Themes.Border);
      Panels.Set_Shadow (Item.Settings_Form, Themes.Shadow);
      Set_Flex_Direction (Widgets.Node (Item.Settings_Form), Yoga.Column);
      Set_Flex_Shrink (Widgets.Node (Item.Settings_Form), 0.0);
      Set_Width (Widgets.Node (Item.Settings_Form), Page_Width * Pixels);
      Item.Form_Wide := Page_Width;
      Set_Padding
        (Widgets.Node (Item.Settings_Form), Yoga.All_Edges,
         Dialog_Pad * Pixels);
      Set_Padding
        (Widgets.Node (Item.Settings_Form), Yoga.Right,
         Dialog_Pad * Pixels + Offset);
      Set_Padding
        (Widgets.Node (Item.Settings_Form), Yoga.Bottom,
         Dialog_Pad * Pixels + Offset);
      Set_Gap
        (Widgets.Node (Item.Settings_Form), Yoga.All_Gutters,
         Row_Gap * Pixels);

      --  Display: its one option, Theme.
      Labels.Set_Text (Item.Display_Heading, "DISPLAY");
      Labels.Set_Style (Item.Display_Heading, UI.Line_Texts.Caption);
      Line (Item.Display_Heading, Heading_Height);
      Labels.Set_Text (Item.Theme_Name, "Theme");
      Labels.Set_Style (Item.Theme_Name, UI.Line_Texts.Strong);
      Line (Item.Theme_Name, Settings_Line);
      Radio (Item.Theme_Light, "Light");
      Radio (Item.Theme_Dark, "Dark");
      Radio (Item.Theme_System, "System");

      --  Speech: its one option, Model.
      Labels.Set_Text (Item.Speech_Heading, "SPEECH");
      Labels.Set_Style (Item.Speech_Heading, UI.Line_Texts.Caption);
      Line (Item.Speech_Heading, Heading_Height);
      Set_Margin
        (Widgets.Node (Item.Speech_Heading), Yoga.Top, Heading_Top * Pixels);
      Labels.Set_Text (Item.Model_Name, "Model");
      Labels.Set_Style (Item.Model_Name, UI.Line_Texts.Strong);
      Line (Item.Model_Name, Settings_Line);
      Radio (Item.Model_Native, "MacOS");
      Radio (Item.Model_Parakeet, "Parakeet");

      Set_Flex_Direction (Widgets.Node (Item.Download_Row), Yoga.Row);
      Set_Align_Items (Widgets.Node (Item.Download_Row), Yoga.Center);
      Line (Item.Download_Row, Download_Height);
      Set_Margin
        (Widgets.Node (Item.Download_Row), Yoga.Top, Gap * Pixels);
      Set_Gap
        (Widgets.Node (Item.Download_Row), Yoga.All_Gutters, Gap * Pixels);
      Buttons.Set_Label (Item.Download_Button, "Download");
      Buttons.Set_Kind (Item.Download_Button, Buttons.Primary);
      Set_Width
        (Widgets.Node (Item.Download_Button), Download_Width * Pixels);
      Set_Height
        (Widgets.Node (Item.Download_Button), Download_Height * Pixels);
      Set_Flex_Shrink (Widgets.Node (Item.Download_Button), 0.0);
      Labels.Set_Ink (Item.Download_State, Quiet_Ink);
      Set_Flex_Grow (Widgets.Node (Item.Download_State), 1.0);
      Set_Width (Widgets.Node (Item.Download_State), 0.0);
      Set_Height
        (Widgets.Node (Item.Download_State), Download_Height * Pixels);
      Line (Item.Download_Bar, Progress_Height);
      Widgets.Set_Visible (Item.Download_Bar, False);
      Widgets.Set_Visible (Item.Settings_Panel, False);
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
      Pixels : constant Float := Item.Density;
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
   --  Style the outline round a dialog, which casts a shadow it leaves
   --  room for.

   procedure Build_Border
     (Item : in out Session; Border : in out Panels.Panel)
   is
      use Yoga.Nodes;
      Pixels : constant Float := Item.Density;
   begin
      Panels.Set_Fill (Border, Themes.Border);
      Panels.Set_Shadow (Border, Themes.Shadow);
      Set_Flex_Direction (Widgets.Node (Border), Yoga.Column);
      Set_Padding
        (Widgets.Node (Border), Yoga.All_Edges, UI.Boxes.Edge (Pixels));
      Set_Padding
        (Widgets.Node (Border), Yoga.Right,
         UI.Boxes.Edge (Pixels) + UI.Boxes.Offset (Pixels));
      Set_Padding
        (Widgets.Node (Border), Yoga.Bottom,
         UI.Boxes.Edge (Pixels) + UI.Boxes.Offset (Pixels));
   end Build_Border;

   procedure Build_Modal (Item : in out Session);
   --  Add and style the dialog to confirm a deletion: over all else.

   procedure Build_Modal (Item : in out Session) is
      use Yoga.Nodes;
      Pixels : constant Float := Item.Density;
   begin
      Widgets.Add (Item.Window_Panel, Item.Overlay);
      Widgets.Add (Item.Overlay, Item.Dialog_Border);
      Widgets.Add (Item.Dialog_Border, Item.Dialog_Bar);
      Widgets.Add (Item.Dialog_Bar, Item.Dialog_Title);
      Widgets.Add (Item.Dialog_Bar, Item.Dialog_Close);
      Widgets.Add (Item.Dialog_Border, Item.Dialog);
      Widgets.Add (Item.Dialog, Item.Confirm_Message);
      Widgets.Add (Item.Dialog, Item.Confirm_Note);
      Widgets.Add (Item.Dialog_Border, Item.Dialog_Rule);
      Widgets.Add (Item.Dialog_Border, Item.Confirm_Buttons);
      Widgets.Add (Item.Confirm_Buttons, Item.Confirm_Cancel);
      Widgets.Add (Item.Confirm_Buttons, Item.Confirm_Delete);

      Panels.Set_Fill (Item.Overlay, Themes.Scrim);
      Build_Border (Item, Item.Dialog_Border);
      Build_Dialog_Bar
        (Item, Item.Dialog_Bar, Item.Dialog_Title, Item.Dialog_Close,
         "Delete project");
      Panels.Set_Fill (Item.Dialog, Paper);
      Labels.Set_Text (Item.Confirm_Note, "This cannot be undone.");
      Buttons.Set_Label (Item.Confirm_Cancel, "Cancel");
      Buttons.Set_Label (Item.Confirm_Delete, "Delete");
      Buttons.Set_Icon (Item.Confirm_Delete, UI.Icons.Delete);
      Buttons.Set_Icon_Size (Item.Confirm_Delete, Mic_Icon_Size);
      Buttons.Set_Captioned (Item.Confirm_Delete, True);
      Buttons.Set_Kind (Item.Confirm_Delete, Buttons.Danger);
      Panels.Set_Fill (Item.Dialog_Rule, Themes.Border);
      Set_Height (Widgets.Node (Item.Dialog_Rule), UI.Boxes.Edge (Pixels));
      Panels.Set_Fill (Item.Confirm_Buttons, Themes.Tint);

      --  Not in the layout of the screens: over them, all of the window,
      --  with the dialog in the middle.
      Set_Position_Type (Widgets.Node (Item.Overlay), Yoga.Absolute);
      for Side in Yoga.Left .. Yoga.Bottom loop
         Set_Position (Widgets.Node (Item.Overlay), Side, 0.0);
      end loop;
      Set_Flex_Direction (Widgets.Node (Item.Overlay), Yoga.Column);
      Set_Justify_Content (Widgets.Node (Item.Overlay), Yoga.Center);
      Set_Align_Items (Widgets.Node (Item.Overlay), Yoga.Center);

      Set_Width (Widgets.Node (Item.Dialog_Border), Dialog_Width * Pixels);
      Set_Flex_Direction (Widgets.Node (Item.Dialog), Yoga.Column);
      Set_Padding
        (Widgets.Node (Item.Dialog), Yoga.All_Edges, Dialog_Pad * Pixels);
      Set_Height (Widgets.Node (Item.Confirm_Message), Dialog_Line * Pixels);
      Set_Height (Widgets.Node (Item.Confirm_Note), Dialog_Line * Pixels);

      Set_Flex_Direction (Widgets.Node (Item.Confirm_Buttons), Yoga.Row);
      Set_Justify_Content (Widgets.Node (Item.Confirm_Buttons), Yoga.Flex_End);
      Set_Padding
        (Widgets.Node (Item.Confirm_Buttons), Yoga.All_Edges,
         Dialog_Foot_Pad * Pixels);
      Set_Gap
        (Widgets.Node (Item.Confirm_Buttons), Yoga.All_Gutters,
         Row_Gap * Pixels);
      Set_Height
        (Widgets.Node (Item.Confirm_Cancel), Dialog_Button_Height * Pixels);
      Set_Height
        (Widgets.Node (Item.Confirm_Delete), Dialog_Button_Height * Pixels);
      Set_Width
        (Widgets.Node (Item.Confirm_Cancel), Dialog_Button_Width * Pixels);
      Set_Width
        (Widgets.Node (Item.Confirm_Delete), Dialog_Button_Width * Pixels);
   end Build_Modal;

   procedure Build_List (Item : in out Session);
   --  Add and style the list of items: a dialog over all else.

   procedure Build_List (Item : in out Session) is
      use Yoga.Nodes;
      Pixels : constant Float := Item.Density;
   begin
      Widgets.Add (Item.Window_Panel, Item.List_Overlay);
      Widgets.Add (Item.List_Overlay, Item.List_Border);
      Widgets.Add (Item.List_Border, Item.List_Head);
      Widgets.Add (Item.List_Head, Item.List_Heading);
      Widgets.Add (Item.List_Head, Item.List_Close);
      Widgets.Add (Item.List_Border, Item.List_Dialog);
      Widgets.Add (Item.List_Dialog, Item.List_Scroll);
      Widgets.Add (Item.List_Scroll, Item.List_Content);
      Widgets.Add (Item.List_Content, Item.List_None);
      for Row of Item.List_Rows loop
         Widgets.Add (Item.List_Content, Row.Panel);
         Widgets.Add (Row.Panel, Row.Name);
         Widgets.Add (Row.Name, Row.Caption);
         Widgets.Add (Row.Panel, Row.Toggle);
         Widgets.Add (Row.Panel, Row.Remove);
      end loop;

      Panels.Set_Fill (Item.List_Overlay, Themes.Scrim);
      Build_Border (Item, Item.List_Border);
      Build_Dialog_Bar
        (Item, Item.List_Head, Item.List_Heading, Item.List_Close, "Items");
      Panels.Set_Fill (Item.List_Dialog, Paper);
      Labels.Set_Text (Item.List_None, No_Items);

      Set_Position_Type (Widgets.Node (Item.List_Overlay), Yoga.Absolute);
      for Side in Yoga.Left .. Yoga.Bottom loop
         Set_Position (Widgets.Node (Item.List_Overlay), Side, 0.0);
      end loop;
      Set_Flex_Direction (Widgets.Node (Item.List_Overlay), Yoga.Column);
      Set_Justify_Content (Widgets.Node (Item.List_Overlay), Yoga.Center);
      Set_Align_Items (Widgets.Node (Item.List_Overlay), Yoga.Center);

      Set_Width (Widgets.Node (Item.List_Border), List_Width * Pixels);
      Set_Height (Widgets.Node (Item.List_Border), List_Height * Pixels);
      Set_Flex_Direction (Widgets.Node (Item.List_Dialog), Yoga.Column);
      Set_Flex_Grow (Widgets.Node (Item.List_Dialog), 1.0);
      Set_Height (Widgets.Node (Item.List_Dialog), 0.0);
      Set_Padding
        (Widgets.Node (Item.List_Dialog), Yoga.All_Edges, Dialog_Pad * Pixels);

      --  The scroller takes what the bar leaves; the rows go in a column
      --  in it, as tall as they are.
      Set_Flex_Grow (Widgets.Node (Item.List_Scroll), 1.0);
      Set_Height (Widgets.Node (Item.List_Scroll), 0.0);
      Set_Flex_Direction (Widgets.Node (Item.List_Content), Yoga.Column);
      Set_Flex_Shrink (Widgets.Node (Item.List_Content), 0.0);
      --  Room at the right for the scroll bar.
      Set_Padding
        (Widgets.Node (Item.List_Content), Yoga.Right,
         UI.Scrollbars.Thickness * Pixels);
      Set_Gap
        (Widgets.Node (Item.List_Content), Yoga.All_Gutters,
         List_Gap * Pixels);
      Set_Height (Widgets.Node (Item.List_None), Title_Height * Pixels);
      for Row of Item.List_Rows loop
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
      Projects.Open (Item.Store, Store_Path);
      Items.Prepare (Item.Store);
      Scripts.Load (Item.Script, Source, File_Name);
      Item.Config_Dir :=
        Ada.Strings.Unbounded.To_Unbounded_String
          (Preferences.Config_Directory (Store_Path));
      Item.Persist := Store_Path /= Projects.Memory;
      if Item.Persist then
         Item.Speech_Choice :=
           Preferences.Load_Speech_Model
             (Ada.Strings.Unbounded.To_String (Item.Config_Dir));
         Item.Theme_Chosen :=
           Preferences.Load_Theme
             (Ada.Strings.Unbounded.To_String (Item.Config_Dir));
      else
         --  Offscreen, the light theme, whatever the system's is.
         Item.Theme_Chosen := Preferences.Light;
      end if;
      Widgets.Set_Density (Item.Widgets, Item.Density);
      Widgets.Set_Line_Texts (Item.Widgets, Item.Lines);
      Widgets.Set_Icons (Item.Widgets, Item.Pictures);
      UI.Icons.Set_Directory (Item.Pictures, Share_Directory ("icons"));
      if Item.Windowed then
         Widgets.Set_Clipboard (Item.Widgets, Item.System_Board);
      else
         Widgets.Set_Clipboard (Item.Widgets, Item.Own_Board);
      end if;

      Widgets.Set_Root (Item.Widgets, Item.Window_Panel);
      Set_Flex_Direction (Widgets.Node (Item.Window_Panel), Yoga.Column);
      if Item.Windowed then
         Build_Header (Item);
      end if;
      Build_Home (Item);
      Build_Project (Item);
      Build_Write (Item);
      Build_Tray (Item);
      Build_Settings (Item);
      Build_Modal (Item);
      Build_List (Item);

      Buttons.Set_Label (Item.Ok_Button, "OK");
      Buttons.Set_Kind (Item.Ok_Button, Buttons.Primary);
      Buttons.Set_Label (Item.Cancel_Button, "Cancel");
      Text_Fields.Set_Shared
        (Item.Edit_Field, Item.Doc_Resources'Unchecked_Access);
      Text_Fields.Configure
        (Item.Edit_Field, UI.Line_Texts.Interface_Font, Edit_Size);

      --  It starts at the home screen.
      Widgets.Set_Visible (Item.Project_Panel, False);
      Widgets.Set_Visible (Item.Write_View, False);
      Widgets.Set_Visible (Item.Overlay, False);
      Widgets.Set_Visible (Item.List_Overlay, False);
      Widgets.Set_Visible (Item.Dock_Panel, False);
      Recent.Refresh (Item);
      --  Before any event: the widgets must know where they are.
      Widgets.Layout (Item.Widgets, Item.Target);
   end Set_Up;

end Viewer.Build;
