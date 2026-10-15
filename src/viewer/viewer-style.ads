with Items.Links;
with Pomarine.Themes;

--  How the screens look: the sizes of what is on them, and its colours.
private package Viewer.Style is

   --  The window

   Window_Width  : constant := 1000;
   Window_Height : constant := 800;
   Header_Size   : constant Float := 28.0;
   Header_Inset  : constant Float := 80.0;
   --  Of a window's own title bar, which the screens leave clear at the
   --  top, and of its close, minimise and zoom buttons at the left.

   --  The bar across the top of a project, in points

   Toolbar_Size  : constant Float := 44.0;
   Bar_Inset     : constant Float := 12.0;
   --  At each end of the bar.
   Back_Width    : constant Float := 92.0;
   Bar_Rule_Height : constant Float := 22.0;
   --  The line between the way back and the project's name.
   Name_Gap      : constant Float := 10.0;
   Tab_Width     : constant Float := 72.0;
   Tab_Height    : constant Float := 26.0;
   Tab_Gap       : constant Float := 5.0;
   Items_Width   : constant Float := 80.0;

   --  The tray of tools over the canvas, at the foot, in points

   Tray_Pad      : constant Float := 6.0;
   Tray_Gap      : constant Float := 6.0;
   Tray_Foot     : constant Float := 18.0;
   --  Between it and the foot of the canvas.
   Tool_Height   : constant Float := 31.0;
   Wide_Tool_Width : constant Float := 132.0;
   --  Of the tool to add a document, whose name is longer.
   Tool_Width    : constant Float := 112.0;
   Tray_Width    : constant Float :=
     Wide_Tool_Width + Tool_Width + Tray_Gap + 2.0 * Tray_Pad
     + Pomarine.Themes.Shadow_Offset;
   Tray_Height   : constant Float :=
     Tool_Height + 2.0 * Tray_Pad + Pomarine.Themes.Shadow_Offset;
   --  With its shadow, which is inside its box.

   Dock_Height   : constant Float := 40.0;
   Dock_Inset    : constant Float := 8.0;
   Dock_Gap      : constant Float := 6.0;
   --  The dock of minimised items, at the foot of the canvas.
   Tool_Gap      : constant Float := 6.0;

   --  The list of items, in points

   List_Width    : constant Float := 440.0;
   List_Height   : constant Float := 380.0;
   --  Of the buttons to show or hide an item, and to remove it.

   --  The writing view, in points

   Sidebar_Width   : constant Float := 206.0;
   Sidebar_Margin  : constant Float := 0.0;
   Sidebar_Pad     : constant Float := 11.0;
   Sidebar_Gap     : constant Float := 8.0;
   Heading_Height  : constant Float := 22.0;
   Heading_Top     : constant Float := 14.0;
   --  Above the name of each list.
   Add_Size        : constant Float := 22.0;
   --  The button to add a document, at the right of the name of the list.
   Index_Height    : constant Float := 31.0;
   Index_Gap       : constant Float := 7.0;
   --  A row of the lists in the sidebar, and between them.
   Index_Pitch     : constant Float := Index_Height + Index_Gap;
   Index_Pad       : constant Float := 10.0;
   Count_Width     : constant Float := 32.0;
   --  Of the count of a document's words, at the right of its row.
   Tree_Indent     : constant Float := 14.0;
   --  How far in the documents of a directory are, in the tree.
   Drop_Line_Height : constant Float := 2.0;
   --  Of the line where a document dragged would go between two.
   Tag_Size        : constant Float := 8.0;
   --  The square of a source's colour, in its row.
   Page_Width      : constant Float := 760.0;
   Page_Min_Width  : constant Float := 160.0;
   Page_Min_Height : constant Float := 240.0;
   Page_Margin     : constant Float := 40.0;
   --  Round the pages, in the view, and inside each at the sides.
   Page_Gap        : constant Float := 22.0;
   Page_Head       : constant Float := 40.0;
   Page_Foot       : constant Float := 26.0;
   Sources_Width   : constant Float := 120.0;
   Bar_Button_Height : constant Float := 26.0;
   Mic_Width       : constant Float := Bar_Button_Height;
   Mic_Icon_Size   : constant Float := 13.0;
   --  The button to dictate is as tall as the Sources button.
   Menu_Width      : constant Float := 240.0;
   Menu_Gap        : constant Float := 2.0;
   Context_Width   : constant Float := 140.0;
   --  Of the menu of a row of the tree, at the pointer.
   --  The menu of a page's sources, below its button.
   Page_Text_Size  : constant Float := 17.0;
   Page_Text_Inset : constant Float := 12.0;
   --  The padding of a text area.
   Page_Top        : constant Float := 28.0;
   --  Above the text, in the page.
   Pane_Default    : constant Float := 420.0;
   Pane_Share      : constant Float := 0.4;
   Pane_Least      : constant Float := 260.0;
   Pane_Edge_Width : constant Float := 6.0;
   --  The pane of the pinned source, and the edge to size it by: it starts
   --  as wide as that, or that share of the view if less.
   Reader_Cascade  : constant Float := 24.0;
   Reader_Count    : constant := 5;
   --  Each source opened is put this far down and left of the last, for so
   --  many.
   Reader_Margin   : constant Float := 24.0;

   No_Documents : constant String := "No documents yet";
   No_Sources   : constant String := "No sources yet";

   --  The settings, in points

   Settings_Line   : constant Float := 28.0;
   --  A line of the form: a name, a radio.
   Download_Height : constant Float := 34.0;
   Download_Width  : constant Float := 112.0;
   Note_Line       : constant Float := 20.0;
   --  A line of what is said under the AI model.
   None_Selected   : constant String := "None Selected";
   Progress_Height : constant Float := 12.0;

   --  The home screen, in points

   Home_Side_Width : constant Float := 218.0;
   Side_Pad      : constant Float := 19.0;
   Logo_Height   : constant Float := 44.0;
   --  The name and the title of the projects, which share a line.
   Logo_Gap      : constant Float := 22.0;
   Action_Height : constant Float := 36.0;
   Home_Margin   : constant Float := 44.0;
   Title_Height  : constant Float := 28.0;
   Card_Width    : constant Float := 330.0;
   Card_Height   : constant Float := 212.0;
   Card_Gap      : constant Float := 22.0;
   Thumb_Height  : constant Float := 138.0;
   Card_Pad      : constant Float := 14.0;
   Card_Button   : constant Float := 31.0;
   Card_Title_Height : constant Float := 22.0;
   Card_Meta_Height  : constant Float := 18.0;
   Plus_Size     : constant Float := 34.0;
   Row_Height    : constant Float := 36.0;
   Row_Gap       : constant Float := 8.0;
   Dialog_Width  : constant Float := 320.0;
   Dialog_Bar_Height : constant Float := 30.0;
   Dialog_Bar_Pad    : constant Float := 8.0;
   Dialog_Close_Size : constant Float := 18.0;
   Dialog_Close_Icon : constant Float := 11.0;
   Dialog_Foot_Pad   : constant Float := 10.0;
   --  The dark bar across the top of a dialog, its button to close it,
   --  and the padding of the foot, round its buttons.
   Dialog_Pad    : constant Float := 24.0;
   Dialog_Line   : constant Float := 24.0;
   Dialog_Button_Width  : constant Float := 96.0;
   Dialog_Button_Height : constant Float := 34.0;
   Ok_Width      : constant Float := 48.0;
   Cancel_Width  : constant Float := 64.0;
   Edit_Size     : constant Float := 14.0;
   --  Of the text in the field to rename a project.
   Gap           : constant Float := 12.0;

   No_Projects : constant String := "No projects yet";
   No_Items    : constant String := "No items yet";

   --  The colours. Widgets keep slots of the theme (as Toolbar and
   --  Mid_Panel), resolved as they are drawn, so that the window changes
   --  theme without being built again; what is drawn at once takes Colors,
   --  the theme in use.

   function Colors return Pomarine.Themes.Theme;
   --  The theme of the window shown: the library's Light, or Dark, as
   --  Use_Dark says, and the colours of the screens' own, below.

   function Is_Dark return Boolean;
   --  Whether the theme in use is the dark.

   function Make (Dark : Boolean) return Pomarine.Themes.Theme;
   --  Light or Dark, with the slots of the application set.

   procedure Use_Dark (Dark : Boolean)
     with Post => Is_Dark = Dark;
   --  Draw in the dark theme, or in the light.

   --  The application's own slots of the theme.

   Rail         : constant Pomarine.Themes.Slot := Pomarine.Themes.Custom (0);
   --  The side rail, and the writing view's desk.
   Dock_Back    : constant Pomarine.Themes.Slot := Pomarine.Themes.Custom (1);
   --  Behind the minimised items.
   Grid_Dot     : constant Pomarine.Themes.Slot := Pomarine.Themes.Custom (2);
   --  The dots of the canvas's grid.
   Closed       : constant Pomarine.Themes.Slot := Pomarine.Themes.Custom (3);
   --  The title of an item that is not shown.
   New_Project_Ink : constant Pomarine.Themes.Slot := Pomarine.Themes.Custom (4);
   --  The primary colour, a little toward the text, as a label.
   Source_1     : constant Pomarine.Themes.Slot := Pomarine.Themes.Custom (5);
   --  The first source's colour is the theme's own blue, lighter in the
   --  dark; Source_2 .. Source_8 are the same in both themes.

   Source_Count : constant := 8;
   Source_First : constant := 5;
   --  Offset of Source_1 among the application's slots.

   Toolbar : constant Pomarine.Themes.Slot := Pomarine.Themes.Bar;
   --  The dark bars: across the top, and of the windows' titles.
   Mid_Panel : constant Pomarine.Themes.Slot := Rail;
   --  Behind the pages, and of the home screen's sidebar.
   Dock : constant Pomarine.Themes.Slot := Dock_Back;
   --  Behind the minimised items.
   Desk : constant Pomarine.Themes.Slot := Rail;
   Paper : constant Pomarine.Themes.Slot := Pomarine.Themes.Page;
   Side_Fill : constant Pomarine.Themes.Slot := Pomarine.Themes.Background;
   --  Of the writing view's sidebar.
   Row_Fill : constant Pomarine.Themes.Slot := Pomarine.Themes.Face;
   Row_Open : constant Pomarine.Themes.Slot := Pomarine.Themes.Page;
   Row_Hover : constant Pomarine.Themes.Slot := Pomarine.Themes.Hover_Row;
   --  A row of a list; the one chosen: a source that is open, or a
   --  document that is being put elsewhere in the order; and one under
   --  the pointer.
   Edge_Fill : constant Pomarine.Themes.Slot := Pomarine.Themes.Border;
   Closed_Ink : constant Pomarine.Themes.Slot := Closed;
   --  Of the title of an item that is not shown, in the list.
   Quiet_Ink : constant Pomarine.Themes.Slot := Pomarine.Themes.Hint;
   --  Of what is said of something, after its name: a count.
   Rule_Ink : constant Pomarine.Themes.Slot := Pomarine.Themes.Rule;
   --  A line on the dark bar.

   Source_Inks : constant array (1 .. Source_Count) of Pomarine.Themes.Slot :=
     [for K in 1 .. Source_Count => Pomarine.Themes.Custom (Source_First + K - 1)];
   --  Of the sources, in the order they were made, and round again.

   function Source_Ink (Rank : Natural) return Pomarine.Themes.Slot is
     (Source_Inks (1 + (Integer'Max (1, Rank) - 1) mod Source_Inks'Length));

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

   Link_Inks : constant array (Items.Links.Link_Colors) of Pomarine.Themes.Slot :=
     [Pomarine.Themes.Bar, Pomarine.Themes.Accent, Pomarine.Themes.Primary, Pomarine.Themes.Danger,
      Source_1];
   --  The colours a link between documents can be drawn in: the theme's,
   --  and a blue.

end Viewer.Style;
