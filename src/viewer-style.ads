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

   --  The tools bar, in points: as high as the toolbar, Toolbar_Size

   Tools_Inset   : constant Float := 8.0;
   --  From the left edge to the first item.
   Tool_Width    : constant Float := 112.0;
   Tool_Height   : constant Float := 24.0;
   Tab_Width     : constant Float := 80.0;

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

   Colors  : constant UI.Themes.Theme := UI.Themes.Light;
   Toolbar : constant UI.Themes.Color :=
     UI.Themes.Mix (Colors.Foreground, Colors.Background, 0.15);
   --  Dark, from the theme: its text colour, a little toward its ground.
   Tools_Bar : constant UI.Themes.Color :=
     UI.Themes.Mix (Toolbar, Colors.Background, 0.2);
   --  A lighter shade of the same.

end Viewer.Style;
