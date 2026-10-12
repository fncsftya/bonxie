with Ada.Command_Line;
with Ada.Directories;
with UI.Icons;
with UI.Line_Texts;
with UI.Themes;
with UI.Widgets;
with Viewer.Recent;
with Viewer.Style;
with Yoga.Nodes;

package body Viewer.Build is

   package Widgets renames UI.Widgets;
   package Palettes renames UI.Widgets.Palettes;
   package Panels renames UI.Widgets.Panels;
   package Buttons renames UI.Widgets.Buttons;
   package Labels renames UI.Widgets.Labels;
   package Text_Fields renames UI.Widgets.Text_Fields;

   use Style;

   function Icon_Directory return String;
   --  Where the SVG files are, in share/bonxie/icons: beside the
   --  executable's folder, as installed or built in place; or from the
   --  current directory, as the tests run in a folder of the project.
   --  "" if none is found.

   function Icon_Directory return String is
      Share : constant String := "share/bonxie/icons";

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
   end Icon_Directory;

   procedure Build_Header (Item : in out Session);
   --  Add and style the bar across the top of a window.

   procedure Build_Header (Item : in out Session) is
      use Yoga.Nodes;
   begin
      Widgets.Add (Item.Window_Panel, Item.Header_Panel);
      Widgets.Add (Item.Header_Panel, Item.Header_Title);
      Panels.Set_Fill (Item.Header_Panel, Colors.Background);
      Labels.Set_Style (Item.Header_Title, UI.Line_Texts.Strong);
      Set_Height
        (Widgets.Node (Item.Header_Panel), Header_Size * Item.Density);
      Set_Flex_Direction (Widgets.Node (Item.Header_Panel), Yoga.Row);
      Set_Align_Items (Widgets.Node (Item.Header_Panel), Yoga.Center);
      Set_Padding
        (Widgets.Node (Item.Header_Panel), Yoga.Left,
         Header_Inset * Item.Density);
      Set_Flex_Grow (Widgets.Node (Item.Header_Title), 1.0);
      Set_Width (Widgets.Node (Item.Header_Title), 0.0);
      Set_Height
        (Widgets.Node (Item.Header_Title), Close_Height * Item.Density);
   end Build_Header;

   procedure Build_Home (Item : in out Session);
   --  Add and style the home screen's widgets.

   procedure Build_Home (Item : in out Session) is
      use Yoga.Nodes;
      Pixels : constant Float := Item.Density;

      procedure Halve (Half : Yoga.Nodes.Node) is
      begin
         Set_Flex_Direction (Half, Yoga.Column);
         Set_Flex_Grow (Half, 1.0);
         Set_Width (Half, 0.0);
         Set_Padding (Half, Yoga.All_Edges, Home_Margin * Pixels);
         Set_Gap (Half, Yoga.All_Gutters, Gap * Pixels);
      end Halve;
   begin
      Widgets.Add (Item.Window_Panel, Item.Home_Panel);
      Widgets.Add (Item.Home_Panel, Item.Recent_Panel);
      Widgets.Add (Item.Recent_Panel, Item.Recent_Title);
      Widgets.Add (Item.Recent_Panel, Item.No_Rows);
      for I in Item.Row_Panels'Range loop
         Widgets.Add (Item.Recent_Panel, Item.Row_Panels (I));
         Widgets.Add (Item.Row_Panels (I), Item.Recent_Rows (I));
         Widgets.Add (Item.Row_Panels (I), Item.Rename_Buttons (I));
         Widgets.Add (Item.Row_Panels (I), Item.Delete_Buttons (I));
      end loop;
      Widgets.Add (Item.Home_Panel, Item.Actions_Panel);
      Widgets.Add (Item.Actions_Panel, Item.New_Button);
      Widgets.Add (Item.Actions_Panel, Item.Settings_Button);

      Labels.Set_Text (Item.Recent_Title, "Recent projects");
      Labels.Set_Style (Item.Recent_Title, UI.Line_Texts.Heading);
      Buttons.Set_Label (Item.New_Button, "New Project");
      Buttons.Set_Kind (Item.New_Button, Buttons.Primary);
      Buttons.Set_Label (Item.Settings_Button, "Settings");
      Panels.Set_Fill
        (Item.Actions_Panel,
         UI.Themes.Mix (Colors.Background, Colors.Foreground, 0.06));

      --  Two halves: a width of nothing to grow from, to share equally.
      Set_Flex_Direction (Widgets.Node (Item.Home_Panel), Yoga.Row);
      Set_Flex_Grow (Widgets.Node (Item.Home_Panel), 1.0);
      Halve (Widgets.Node (Item.Recent_Panel));
      Halve (Widgets.Node (Item.Actions_Panel));

      Labels.Set_Text (Item.No_Rows, No_Projects);
      Set_Height (Widgets.Node (Item.Recent_Title), Title_Height * Pixels);
      Set_Height (Widgets.Node (Item.No_Rows), Title_Height * Pixels);
      for I in Item.Row_Panels'Range loop
         Set_Flex_Direction (Widgets.Node (Item.Row_Panels (I)), Yoga.Row);
         Set_Height (Widgets.Node (Item.Row_Panels (I)), Row_Height * Pixels);
         Set_Gap
           (Widgets.Node (Item.Row_Panels (I)), Yoga.All_Gutters,
            Row_Gap * Pixels);
         Set_Flex_Grow (Widgets.Node (Item.Recent_Rows (I)), 1.0);
         Set_Width (Widgets.Node (Item.Recent_Rows (I)), 0.0);
         Set_Width
           (Widgets.Node (Item.Rename_Buttons (I)), Rename_Width * Pixels);
         Buttons.Set_Label (Item.Rename_Buttons (I), "Rename");
         Buttons.Set_Icon (Item.Rename_Buttons (I), UI.Icons.Edit);
         Set_Width
           (Widgets.Node (Item.Delete_Buttons (I)), Delete_Width * Pixels);
         Buttons.Set_Label (Item.Delete_Buttons (I), "Delete");
         Buttons.Set_Icon (Item.Delete_Buttons (I), UI.Icons.Delete);
         Buttons.Set_Kind (Item.Delete_Buttons (I), Buttons.Danger);
      end loop;
      --  The actions, in the middle: wide, but not the width of the half.
      Set_Justify_Content (Widgets.Node (Item.Actions_Panel), Yoga.Center);
      Set_Align_Items (Widgets.Node (Item.Actions_Panel), Yoga.Center);
      Set_Width (Widgets.Node (Item.New_Button), Action_Width * Pixels);
      Set_Height (Widgets.Node (Item.New_Button), Button_Height * Pixels);
      Set_Width (Widgets.Node (Item.Settings_Button), Action_Width * Pixels);
      Set_Height
        (Widgets.Node (Item.Settings_Button), Button_Height * Pixels);
   end Build_Home;

   procedure Build_Project (Item : in out Session);
   --  Add and style the project screen's widgets.

   procedure Build_Project (Item : in out Session) is
      use Yoga.Nodes;
   begin
      Widgets.Add (Item.Window_Panel, Item.Project_Panel);
      Widgets.Add (Item.Project_Panel, Item.Content_Panel);
      Widgets.Add (Item.Content_Panel, Item.Canvas_View);
      Widgets.Add (Item.Content_Panel, Item.Tools);
      Widgets.Add (Item.Tools, Item.Tool_Item);
      Widgets.Add (Item.Project_Panel, Item.Toolbar_Panel);
      Widgets.Add (Item.Toolbar_Panel, Item.Project_Title);
      Widgets.Add (Item.Toolbar_Panel, Item.Canvas_Tab);
      Widgets.Add (Item.Toolbar_Panel, Item.Close_Button);
      Panels.Set_Fill (Item.Toolbar_Panel, Toolbar);
      Buttons.Set_Label (Item.Canvas_Tab, "Canvas");
      Buttons.Set_Selected (Item.Canvas_Tab, True);
      Buttons.Set_Label (Item.Close_Button, "Close");
      Buttons.Set_Label (Item.Tool_Item, "New Item");
      Buttons.Set_Icon (Item.Tool_Item, UI.Icons.Window);
      Buttons.Set_Captioned (Item.Tool_Item, True);
      Labels.Set_Style (Item.Project_Title, UI.Line_Texts.Strong);
      Labels.Set_Ink (Item.Project_Title, Colors.Background);

      Set_Flex_Direction (Widgets.Node (Item.Project_Panel), Yoga.Column);
      Set_Flex_Grow (Widgets.Node (Item.Project_Panel), 1.0);
      Set_Flex_Grow (Widgets.Node (Item.Content_Panel), 1.0);
      Set_Flex_Direction (Widgets.Node (Item.Content_Panel), Yoga.Column);
      Set_Flex_Grow (Widgets.Node (Item.Canvas_View), 1.0);

      --  The floating toolbar is not in the layout: over the canvas, at
      --  its top left, until it is dragged.
      Set_Position_Type (Widgets.Node (Item.Tools), Yoga.Absolute);
      Set_Position
        (Widgets.Node (Item.Tools), Yoga.Left, Tools_Margin * Item.Density);
      Set_Position
        (Widgets.Node (Item.Tools), Yoga.Top, Tools_Margin * Item.Density);
      Set_Width (Widgets.Node (Item.Tools), Tools_Width * Item.Density);
      Set_Flex_Direction (Widgets.Node (Item.Tools), Yoga.Column);
      Set_Padding
        (Widgets.Node (Item.Tools), Yoga.All_Edges, Tools_Pad * Item.Density);
      Set_Padding
        (Widgets.Node (Item.Tools), Yoga.Top,
         (Palettes.Grip_Height + 2.0) * Item.Density);
      Set_Height (Widgets.Node (Item.Tool_Item), Tool_Height * Item.Density);

      --  The tabs and the Close button at the right, in the middle of the
      --  bar.
      Set_Height
        (Widgets.Node (Item.Toolbar_Panel), Toolbar_Size * Item.Density);
      Set_Flex_Direction (Widgets.Node (Item.Toolbar_Panel), Yoga.Row);
      Set_Align_Items (Widgets.Node (Item.Toolbar_Panel), Yoga.Center);
      Set_Padding
        (Widgets.Node (Item.Toolbar_Panel), Yoga.Right,
         Bar_Margin * Item.Density);
      Set_Padding
        (Widgets.Node (Item.Toolbar_Panel), Yoga.Left,
         Title_Margin * Item.Density);
      --  The title takes what the Close button leaves.
      Set_Flex_Grow (Widgets.Node (Item.Project_Title), 1.0);
      Set_Width (Widgets.Node (Item.Project_Title), 0.0);
      Set_Height
        (Widgets.Node (Item.Project_Title), Close_Height * Item.Density);
      Set_Width (Widgets.Node (Item.Canvas_Tab), Tab_Width * Item.Density);
      Set_Height
        (Widgets.Node (Item.Canvas_Tab), Close_Height * Item.Density);
      Set_Margin
        (Widgets.Node (Item.Canvas_Tab), Yoga.Right, Gap * Item.Density);
      Set_Width (Widgets.Node (Item.Close_Button), Close_Width * Item.Density);
      Set_Height
        (Widgets.Node (Item.Close_Button), Close_Height * Item.Density);
   end Build_Project;

   procedure Build_Modal (Item : in out Session);
   --  Add and style the dialog to confirm a deletion: over all else.

   procedure Build_Modal (Item : in out Session) is
      use Yoga.Nodes;
      Pixels : constant Float := Item.Density;
   begin
      Widgets.Add (Item.Window_Panel, Item.Overlay);
      Widgets.Add (Item.Overlay, Item.Dialog_Border);
      Widgets.Add (Item.Dialog_Border, Item.Dialog);
      Widgets.Add (Item.Dialog, Item.Confirm_Message);
      Widgets.Add (Item.Dialog, Item.Confirm_Name);
      Widgets.Add (Item.Dialog, Item.Confirm_Note);
      Widgets.Add (Item.Dialog, Item.Confirm_Buttons);
      Widgets.Add (Item.Confirm_Buttons, Item.Confirm_Cancel);
      Widgets.Add (Item.Confirm_Buttons, Item.Confirm_Delete);

      Panels.Set_Fill (Item.Overlay, UI.Themes.Scrim (Colors));
      Panels.Set_Fill (Item.Dialog_Border, Colors.Foreground);
      Panels.Set_Fill (Item.Dialog, Colors.Background);
      Labels.Set_Text (Item.Confirm_Message, "Delete this project?");
      Labels.Set_Text (Item.Confirm_Note, "This cannot be undone.");
      Buttons.Set_Label (Item.Confirm_Cancel, "Cancel");
      Buttons.Set_Label (Item.Confirm_Delete, "Delete");
      Buttons.Set_Kind (Item.Confirm_Delete, Buttons.Danger);

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
      Set_Padding
        (Widgets.Node (Item.Dialog_Border), Yoga.All_Edges, Outline * Pixels);
      Set_Flex_Direction (Widgets.Node (Item.Dialog), Yoga.Column);
      Set_Padding
        (Widgets.Node (Item.Dialog), Yoga.All_Edges, Dialog_Pad * Pixels);
      Set_Gap (Widgets.Node (Item.Dialog), Yoga.All_Gutters, Gap * Pixels);
      Set_Height (Widgets.Node (Item.Confirm_Message), Dialog_Line * Pixels);
      Set_Height (Widgets.Node (Item.Confirm_Name), Dialog_Line * Pixels);
      Set_Height (Widgets.Node (Item.Confirm_Note), Dialog_Line * Pixels);

      Set_Flex_Direction (Widgets.Node (Item.Confirm_Buttons), Yoga.Row);
      Set_Justify_Content (Widgets.Node (Item.Confirm_Buttons), Yoga.Flex_End);
      Set_Height
        (Widgets.Node (Item.Confirm_Buttons), Dialog_Button_Height * Pixels);
      Set_Gap
        (Widgets.Node (Item.Confirm_Buttons), Yoga.All_Gutters,
         Row_Gap * Pixels);
      Set_Width
        (Widgets.Node (Item.Confirm_Cancel), Dialog_Button_Width * Pixels);
      Set_Width
        (Widgets.Node (Item.Confirm_Delete), Dialog_Button_Width * Pixels);
   end Build_Modal;

   procedure Set_Up
     (Item       : in out Session;
      Source     : String;
      File_Name  : String;
      Store_Path : String)
   is
      use Yoga.Nodes;
   begin
      Projects.Open (Item.Store, Store_Path);
      Scripts.Load (Item.Script, Source, File_Name);
      Widgets.Set_Density (Item.Widgets, Item.Density);
      Widgets.Set_Line_Texts (Item.Widgets, Item.Lines);
      Widgets.Set_Icons (Item.Widgets, Item.Pictures);
      UI.Icons.Set_Directory (Item.Pictures, Icon_Directory);
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
      Build_Modal (Item);

      Buttons.Set_Label (Item.Ok_Button, "OK");
      Buttons.Set_Label (Item.Cancel_Button, "Cancel");
      Text_Fields.Configure
        (Item.Edit_Field, UI.Line_Texts.System_UI, Edit_Size);

      --  It starts at the home screen.
      Widgets.Set_Visible (Item.Project_Panel, False);
      Widgets.Set_Visible (Item.Overlay, False);
      Recent.Refresh (Item);
      --  Before any event: the widgets must know where they are.
      Widgets.Layout (Item.Widgets, Item.Target);
   end Set_Up;

end Viewer.Build;
