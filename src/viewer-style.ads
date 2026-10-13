with UI.Themes;

--  How the screens look: the sizes of what is on them, and its colours.
private package Viewer.Style is

   --  The window

   Window_Width  : constant := 1000;
   Window_Height : constant := 800;
   Toolbar_Size  : constant Float := 32.0;
   Header_Size   : constant Float := 28.0;
   Header_Inset  : constant Float := 80.0;
   --  The header across the top, and what its title leaves clear at the
   --  left for the window's close, minimise and zoom buttons.

   --  The tools, in points

   Tool_Width    : constant Float := 112.0;
   Tool_Height   : constant Float := 24.0;
   Tab_Width     : constant Float := 80.0;

   Dock_Height   : constant Float := 40.0;
   Dock_Inset    : constant Float := 8.0;
   Dock_Gap      : constant Float := 6.0;
   --  The dock of minimised items, above the toolbar.
   Tool_Gap      : constant Float := 6.0;
   --  Between the tools.

   --  The list of items, in points

   List_Width    : constant Float := 440.0;
   List_Height   : constant Float := 380.0;
   List_Gap      : constant Float := 6.0;
   Toggle_Width  : constant Float := 44.0;
   Remove_Width  : constant Float := 44.0;
   --  Of the buttons to show or hide an item, and to remove it.

   --  The home screen, in points

   Home_Margin   : constant Float := 32.0;
   Title_Height  : constant Float := 28.0;
   Row_Height    : constant Float := 36.0;
   Row_Gap       : constant Float := 8.0;
   Rename_Width  : constant Float := 44.0;
   Delete_Width  : constant Float := 44.0;
   --  Of the buttons with icons.
   Dialog_Width  : constant Float := 320.0;
   Dialog_Pad    : constant Float := 24.0;
   Dialog_Line   : constant Float := 24.0;
   Dialog_Button_Width  : constant Float := 96.0;
   Dialog_Button_Height : constant Float := 36.0;
   Outline       : constant Float := 1.0;
   Ok_Width      : constant Float := 48.0;
   Cancel_Width  : constant Float := 64.0;
   Edit_Size     : constant Float := 14.0;
   --  Of the text in the field to rename a project.
   Button_Height : constant Float := 44.0;
   Action_Width  : constant Float := 240.0;
   Gap           : constant Float := 12.0;
   Close_Width   : constant Float := 72.0;
   Close_Height  : constant Float := 24.0;
   Bar_Margin    : constant Float := 4.0;
   Title_Margin  : constant Float := 12.0;
   --  Between the Close button and the toolbar's edge.

   No_Projects : constant String := "No projects yet";
   No_Items    : constant String := "No items yet";

   Colors  : constant UI.Themes.Theme := UI.Themes.Light;
   Toolbar : constant UI.Themes.Color :=
     UI.Themes.Mix (Colors.Foreground, Colors.Background, 0.15);
   --  Dark, from the theme: its text colour, a little toward its ground.
   Dock : constant UI.Themes.Color :=
     UI.Themes.Mix (Colors.Background, Colors.Foreground, 0.25);
   --  Behind the minimised items: between the canvas and the toolbar.
   Closed_Ink : constant UI.Themes.Color :=
     UI.Themes.Mix (Colors.Foreground, Colors.Background, 0.55);
   --  Of the title of an item that is not shown, in the list.

   --  The toolbar of a selected link, in points

   Link_Button_Size : constant Float := 22.0;
   Link_Bar_Gap     : constant Float := 2.0;
   Link_Bar_Pad     : constant Float := 4.0;
   Link_Group_Gap   : constant Float := 6.0;
   --  Added between the groups of buttons.
   Link_Bar_Width   : constant Float :=
     11.0 * Link_Button_Size + 10.0 * Link_Bar_Gap + 4.0 * Link_Group_Gap
     + 2.0 * Link_Bar_Pad;
   Link_Bar_Height  : constant Float := Link_Button_Size + 2.0 * Link_Bar_Pad;
   Link_Bar_Offset  : constant Float := 14.0;
   --  Below the lower end of the link, and centred across it.

   Link_Inks : constant array (Items.Link_Colors) of UI.Themes.Color :=
     [Colors.Foreground, Colors.Accent, Colors.Primary, Colors.Danger,
      (16#15#, 16#65#, 16#C0#, 255)];
   --  The colours a link can be drawn in: the theme's, and a blue.

end Viewer.Style;
