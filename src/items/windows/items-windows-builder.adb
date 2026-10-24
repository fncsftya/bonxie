with Word_Tools;
with Items.Sources;
with Pomarine.Boxes;
with Pomarine.Text_Areas;
with Icon_Set;
with Pomarine.Line_Texts;
with Pomarine.Widgets.Layouts;
with Items.Windows.Handlers;
with Items.Windows.Metrics;
with Pomarine.Icons;

package body Items.Windows.Builder is

   package Widgets renames Pomarine.Widgets;
   package Layouts renames Pomarine.Widgets.Layouts;
   package Panels renames Pomarine.Widgets.Panels;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Frames renames Pomarine.Widgets.Frames;
   package Editors renames Pomarine.Widgets.Editors;

   procedure Make_Parts
     (Item    : in out Window;
      Canvas  : in out Widgets.Widget'Class;
      Dock    : in out Widgets.Widget'Class;
      Bar     : Pomarine.Themes.Slot;
      Density : Float)
   is
      Pixels : constant Float := Density;
      Edge   : constant Float := Pomarine.Boxes.Edge (Metrics.Outline * Pixels);
      --  In whole pixels, as the outline is.

      function Size (Wide, High : Float) return Layouts.Style is
        (Width => Wide, Height => High, others => <>);
   begin
      Item.Pixels := Pixels;
      Frames.Build
        (Item.Chrome, Canvas, Bar, Pixels, Editable_Title => True,
         Dock => Dock'Unrestricted_Access);
      Frames.Add_Content (Item.Chrome, Item.Body_Text);
      Frames.Add_Content (Item.Chrome, Item.Picture);
      Frames.Add_Content (Item.Chrome, Item.Pages);
      Frames.Add_Content (Item.Chrome, Item.Text_View);
      Frames.Add_Content (Item.Chrome, Item.Wizard);
      Buttons.Add (Item.Wizard, Item.Link_Button,
                   Buttons.Looks ("From URL", Icon => Pomarine.Icons.Shown (Icon_Set.Link), Captioned => True),
                   Size (Metrics.Wizard_Button_Width, Metrics.Wizard_Button_Height));
      Buttons.Add (Item.Wizard, Item.File_Button,
                   Buttons.Looks ("From File", Icon => Pomarine.Icons.Shown (Icon_Set.Document), Captioned => True),
                   Size (Metrics.Wizard_Button_Width, Metrics.Wizard_Button_Height));
      Frames.Add_Status_Item (Item.Chrome, Item.Pager);
      Frames.Add_Status_Item (Item.Chrome, Item.Speak_Button);
      Frames.Add_Status_Item (Item.Chrome, Item.Status);
      Frames.Add_Status_Item (Item.Chrome, Item.Tools);
      Buttons.Add (Item.Tools, Item.Cursor_Button,
                   Buttons.Looks ("Ptr", Icon => Pomarine.Icons.Shown (Icon_Set.Cursor)),
                   Size (Metrics.Tool_Size, Metrics.Zoom_Row_Height));
      Buttons.Add (Item.Tools, Item.Marker_Button,
                   Buttons.Looks ("Mark", Icon => Pomarine.Icons.Shown (Icon_Set.Highlighter)),
                   Size (Metrics.Tool_Size, Metrics.Zoom_Row_Height));
      Buttons.Add (Item.Tools, Item.Eraser_Button,
                   Buttons.Looks ("Rub", Icon => Pomarine.Icons.Shown (Icon_Set.Eraser)),
                   Size (Metrics.Tool_Size, Metrics.Zoom_Row_Height));
      Frames.Add_Status_Item (Item.Chrome, Item.Outline_Button);
      Frames.Add_Status_Item (Item.Chrome, Item.Zoom_Button);
      Frames.Add_Over_Status (Item.Chrome, Item.Progress);
      Pomarine.Widgets.Progress_Bars.Set_Over (Item.Progress, Pomarine.Themes.Strip, Meter_Slot);

      Editors.Configure
        (Item.Body_Text, Pomarine.Line_Texts.Serif, Metrics.Text_Size, Metrics.Measure);
      Editors.Set_Paper (Item.Body_Text, Pomarine.Themes.Page);
      Editors.Set_Toolbar (Item.Body_Text);  --  not for a source's link, which is one line
      Word_Tools.Add (Item.Body_Text);
      Layouts.Set_Layout (Item.Body_Text, Grow => 1.0, Height => 0.0);
      --  Its own outline is the window's at the sides.
      Layouts.Set_Layout
        (Item.Body_Text, Margin => (Left | Right => -Edge, others => <>),
         Unit => Layouts.Device_Pixels);

      Layouts.Set_Layout (Item.Picture, Grow => 1.0, Height => 0.0);
      Layouts.Set_Layout (Item.Pages, Grow => 1.0, Height => 0.0);

      --  A text file's text: the page's paper, in the serif, as a note's,
      --  to be read and selected.
      Editors.Configure
        (Item.Text_View, Pomarine.Line_Texts.Serif, Metrics.Text_Size, Metrics.Measure);
      Editors.Set_Paper (Item.Text_View, Pomarine.Themes.Page);
      Pomarine.Text_Areas.Set_Read_Only (Editors.Area (Item.Text_View).all);
      Layouts.Set_Layout (Item.Text_View, Grow => 1.0, Height => 0.0);
      Layouts.Set_Layout
        (Item.Text_View, Margin => (Left | Right => -Edge, others => <>),
         Unit => Layouts.Device_Pixels);

      --  The two ways to say where a source is from, in the middle.
      Panels.Set_Fill (Item.Wizard, Pomarine.Themes.Page);
      Layouts.Set_Layout
        (Item.Wizard, Grow => 1.0, Height => 0.0, Flow => Layouts.Column,
         Align => Layouts.Center, Spread => Layouts.Center, Gap => Metrics.Wizard_Gap);

      Layouts.Set_Layout (Item.Status, Grow => 1.0, Width => 0.0, Height => Metrics.Label_Height);
      Frames.Add_Over_Content (Item.Chrome, Item.Zoom_Menu);
      Buttons.Add (Item.Pager, Item.Prev_Button,
                   Buttons.Looks ("Previous page", Icon => Pomarine.Icons.Shown (Icon_Set.Back)),
                   Size (Metrics.Tool_Size, Metrics.Zoom_Row_Height));
      Buttons.Add (Item.Pager, Item.Next_Button,
                   Buttons.Looks ("Next page", Icon => Pomarine.Icons.Shown (Icon_Set.Forward)),
                   Size (Metrics.Tool_Size, Metrics.Zoom_Row_Height));
      Frames.Add_Over_Content (Item.Chrome, Item.Fetch_Button);
      Layouts.Add (Item.Zoom_Menu, Item.Zoom_Slider, Size (Metrics.Zoom_Slider_Width, Metrics.Zoom_Row_Height));
      for Each of Item.Menu_Rows loop
         Layouts.Add (Item.Zoom_Menu, Each,
                      (Flow => Layouts.Row, Gap => Edge, Unit => Layouts.Device_Pixels, others => <>));
      end loop;
      for Which in Item.Menu_Buttons'Range loop
         Buttons.Add
           (Item.Menu_Rows (1 + (Which - 1) / 3), Item.Menu_Buttons (Which),
            Buttons.Looks (Items.Sources.Percent (Metrics.Preset_Zooms (Which))),
            Size (Metrics.Preset_Width, Metrics.Zoom_Row_Height));
      end loop;

      --  The progress bar, along the foot of the status line.
      Layouts.Set_Layout
        (Item.Progress, Place => Layouts.Absolute, Position => (Left | Right | Bottom => 0.0, others => <>),
         Height => Metrics.Progress_Height);

      --  The tools, in the status line.
      Layouts.Set_Layout (Item.Tools, Flow => Layouts.Row, Gap => Metrics.Button_Gap);
      Buttons.Set_Selected (Item.Cursor_Button, True);

      --  The zoom: the button for the menu, which has the slider.
      Buttons.Configure (Item.Zoom_Button, Buttons.Looks ("100%", Captioned => True, Shape => Buttons.Dropdown));
      Layouts.Set_Layout (Item.Zoom_Button, Size (Metrics.Zoom_Button_Width, Metrics.Zoom_Row_Height));

      --  The button to dictate, of a note.
      Buttons.Configure
        (Item.Speak_Button,
         Buttons.Looks
           ("Dictate",
            Icon => Pomarine.Icons.Shown (Icon_Set.Microphone),
            Icon_Points => Metrics.Speak_Icon_Size,
            Captioned => True));
      Layouts.Set_Layout (Item.Speak_Button, Size (Metrics.Speak_Width, Metrics.Zoom_Row_Height));

      --  The button of a note's link to the outline, at the right of its status line.
      Buttons.Configure (Item.Outline_Button, Buttons.Looks ("Section", Captioned => True, Shape => Buttons.Dropdown));
      Layouts.Set_Layout (Item.Outline_Button, Size (Metrics.Outline_Button_Width, Metrics.Zoom_Row_Height));

      --  The page buttons: at the left of the status line.
      Layouts.Set_Layout (Item.Pager, Flow => Layouts.Row, Gap => Metrics.Button_Gap);

      --  The menu: over the picture, at the right, with the window's
      --  outline between its buttons.
      Panels.Set_Fill (Item.Zoom_Menu, Pomarine.Themes.Border);
      Layouts.Set_Layout
        (Item.Zoom_Menu, Place => Layouts.Absolute,
         Position => (Right => (Metrics.Corner_Size + Edge) * Pixels,
                      Bottom => (Metrics.Status_Height + Edge) * Pixels,
                      others => <>),
         Flow => Layouts.Column, Padding => (others => Edge), Gap => Edge,
         Unit => Layouts.Device_Pixels);

      --  Over the right of the link, which leaves room for it (see
      --  Show_Fetch); its top is put by Fit_Zoom.
      Buttons.Configure (Item.Fetch_Button, Buttons.Looks ("Add", Buttons.Primary));
      Layouts.Set_Layout (Item.Fetch_Button, Size (Metrics.Fetch_Width, Metrics.Fetch_Height));
      Layouts.Set_Layout
        (Item.Fetch_Button, Place => Layouts.Absolute,
         Position => (Right => Edge + Pomarine.Boxes.Offset (Pixels) + Metrics.Fetch_Inset * Pixels,
                      others => <>),
         Unit => Layouts.Device_Pixels);

      Widgets.Set_Visible (Item.Fetch_Button, False);
      Widgets.Set_Visible (Item.Tools, False);
      Widgets.Set_Visible (Item.Zoom_Button, False);
      Widgets.Set_Visible (Item.Zoom_Menu, False);
      Widgets.Set_Visible (Item.Pager, False);
      Widgets.Set_Visible (Item.Text_View, False);
      Widgets.Set_Visible (Item.Wizard, False);
      Widgets.Set_Visible (Item.Picture, False);
      Widgets.Set_Visible (Item.Pages, False);
      Widgets.Set_Visible (Item.Progress, False);
      Handlers.Listen (Item);
   end Make_Parts;

end Items.Windows.Builder;
