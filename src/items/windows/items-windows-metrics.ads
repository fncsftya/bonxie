--  The sizes of a window's parts, in points.
private package Items.Windows.Metrics is

   package Frames renames Pomarine.Widgets.Frames;

   Outline       : constant Float := Frames.Outline;

   Button_Size   : constant Float := Frames.Button_Size;

   Button_Gap    : constant Float := Frames.Button_Gap;

   Label_Height  : constant Float := Frames.Label_Height;

   Status_Height : constant Float := Frames.Status_Height;

   Corner_Size   : constant Float := Frames.Corner_Size;

   Bar_Height    : constant Float := Frames.Bar_Height;

   Text_Size     : constant Float := 15.0;

   Link_Size     : constant Float := 12.0;
   --  Of the text of a note, in the serif, and of the link of a source.

   Measure       : constant Float := 2000.0;

   Zoom_Row_Height : constant Float := 19.0;

   Zoom_Button_Width : constant Float := 44.0;

   Zoom_Slider_Width : constant Float := 56.0;

   Progress_Height   : constant Float := 3.0;

   Preset_Width  : constant Float := 44.0;

   Speak_Icon_Size : constant Float := 12.0;

   Outline_Button_Width : constant Float := 76.0;
   --  Of the button of a note's link to the outline.

   Level_Steps   : constant Float := 20.0;
   --  How many sizes of the bar that shows how loud the speech is.

   Tools_Width   : constant Float := 3.0 * Button_Size + 2.0 * Button_Gap;

   Pager_Width   : constant Float := 2.0 * Button_Size + Button_Gap;

   Pager_Lift    : constant Float := 6.0;

   Wizard_Gap    : constant Float := 10.0;

   Wizard_Button_Width  : constant Float := 150.0;

   Wizard_Button_Height : constant Float := 32.0;
   --  The page buttons' width, and how far they are above the status line.

   Preset_Zooms : constant array (Preset_Index) of Float :=
     [0.5, 0.75, 1.0, 1.5, 2.0, 3.0];
   --  The menu's, in two rows of three.

   Url_Height    : constant Float := 30.0;

   Fetch_Width   : constant Float := 40.0;

   Fetch_Height  : constant Float := 22.0;

   Fetch_Inset   : constant Float := 4.0;
   --  The button to take the picture of a link, at the right of it.

   Compact_Below : constant Float := 0.75;
   --  Under this zoom a window shows only what it says: no status line,
   --  and a source no link.

   Min_Chrome    : constant Float := 0.6;
   --  How small the bar of a window gets, as a part of its size, when
   --  zoomed out, so that its title is not large over the text.

end Items.Windows.Metrics;
