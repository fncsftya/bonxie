with Pomarine.Boxes;
with Pomarine.Widgets.Checks;
with Pomarine.Widgets.Grips;
with Pomarine.Widgets.Scrollers;
with Pomarine.Widgets.Switches;
with Preferences;
with Settings_VM;
with SDL3.Cursors;
with Icon_Set;
with Pomarine.Line_Texts;
with Pomarine.Themes;
with Pomarine.Widgets;
with Pomarine.Widgets.Layouts;
with Viewer.Style;
with Pomarine.Icons;

package body Viewer.Build.Settings_Form is

   package Widgets renames Pomarine.Widgets;
   package Layouts renames Pomarine.Widgets.Layouts;
   package Panels renames Pomarine.Widgets.Panels;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Labels renames Pomarine.Widgets.Labels;
   package Checks renames Pomarine.Widgets.Checks;
   package Grips renames Pomarine.Widgets.Grips;
   package Switches renames Pomarine.Widgets.Switches;
   package Scrollers renames Pomarine.Widgets.Scrollers;
   package Themes renames Pomarine.Themes;

   use Style;
   use Pomarine.Widgets.Layouts;

   procedure Build_Settings (Item : in out Session) is
      Prefs : Settings_Parts renames Item.Prefs;

      function Line (High : Float; Margin : Layouts.Sides := (others => <>)) return Layouts.Style is
        (Height => High, Shrink => 0.0, Margin => Margin, others => <>);

      procedure Add_Radio (Part : in out Checks.Check; Name : String) is
      begin
         Layouts.Add (Prefs.Settings_Form, Part, Line (Settings_Line));
         Checks.Set_Kind (Part, Checks.Radio);
         Checks.Set_Label (Part, Name);
         Checks.Set_Focusable (Part, True);
      end Add_Radio;

      --  A choice of background: a picture, which is clicked, and a foot with its name, which is too.
      procedure Add_Card (Card : in out Background_Card; Words : String; Pictured : Boolean) is
      begin
         Layouts.Add (Prefs.Background_Row, Card.Whole,
                      (Flow => Column, Width => Background_Card_Width, Height => Background_Card_Height,
                       Shrink => 0.0, Outlined => True, Shadowed => True, others => <>));
         Panels.Set_Radius (Card.Whole, Themes.Large_Radius, Framed => True);
         Panels.Set_Fill (Card.Whole, Themes.Page);
         Panels.Set_Border (Card.Whole, Themes.Border);
         Layouts.Add (Card.Whole, Card.Peek, (Grow => 1.0, Flow => Column, others => <>));
         Grips.Set_Wanted_Cursor (Card.Peek, SDL3.Cursors.Pointer);
         Grips.Set_Focusable (Card.Peek, True);
         Layouts.Add (Card.Whole, Card.Foot,
                      (Height => Card_Foot_Height, Shrink => 0.0, Flow => Row, Align => Center, Gap => Row_Gap,
                       Padding => (Left | Right => Card_Pad, others => <>), others => <>));
         Panels.Set_Fill (Card.Foot, Themes.Tint);
         --  Its foot is as round as the card's own foot, or its square corner shows between the outline and the shadow.
         Panels.Set_Radius (Card.Foot, Themes.Large_Radius, Round => Pomarine.Boxes.Bottom_Corners);
         Layouts.Add (Card.Peek, Card.Sample, (Grow => 1.0, others => <>));
         Card.Sample.Radius := Themes.Large_Radius;
         Layouts.Add (Card.Foot, Card.Pick,
                      (Grow => 1.0, Width => 0.0, Flow => Column, Spread => Center, Align_Self => Stretch,
                       others => <>));
         Grips.Set_Wanted_Cursor (Card.Pick, SDL3.Cursors.Pointer);
         Layouts.Add (Card.Pick, Card.Name, (Height => Card_Title_Height, others => <>));
         Labels.Set_Text (Card.Name, Words);
         Labels.Set_Style (Card.Name, Pomarine.Line_Texts.Strong);
         if Pictured then
            Buttons.Add (Card.Foot, Card.Reseed,
                         Buttons.Looks ("New picture", Icon => Pomarine.Icons.Shown (Icon_Set.Refresh),
                                        Focusable => True),
                         (Width => Card_Button, Height => Card_Button, Shrink => 0.0, others => <>));
         end if;
      end Add_Card;
   begin
      Layouts.Add (Item.Root.Window_Panel, Prefs.Settings_Panel, (Flow => Column, Grow => 1.0, others => <>));
      Layouts.Add (Prefs.Settings_Panel, Prefs.Settings_Bar,
                   (Height => Toolbar_Size, Shrink => 0.0, Flow => Row, Align => Center,
                    Padding => (Left  => (if Item.Shell.Windowed then Header_Inset else Bar_Inset), Right => Bar_Inset,
                                others => <>),
                    others => <>));
      Buttons.Add (Prefs.Settings_Bar, Prefs.Settings_Close,
                   Buttons.Looks ("Projects", Buttons.Quiet, Icon => Pomarine.Icons.Shown (Icon_Set.Back),
                                  Captioned => True),
                   (Width => Back_Width, Height => Tab_Height, Shrink => 0.0,
                    Margin => (Right => Name_Gap, others => <>), others => <>));
      Layouts.Add (Prefs.Settings_Bar, Prefs.Settings_Title,
                   (Grow => 1.0, Width => 0.0, Height => Tab_Height, others => <>));
      Layouts.Add (Prefs.Settings_Panel, Prefs.Settings_Scroll, (Grow => 1.0, Height => 0.0, others => <>));
      Layouts.Add (Prefs.Settings_Scroll, Prefs.Settings_Content,
                   (Flow => Column, Shrink => 0.0, Align => Center, Padding => (others => Page_Margin), others => <>));
      Layouts.Add (Prefs.Settings_Content, Prefs.Settings_Form,
                   (Flow => Column, Shrink => 0.0, Width => Page_Width, Padding => (others => Dialog_Pad),
                    Shadowed => True, Gap => Row_Gap, others => <>));
      if not Item.Shell.Windowed then
         Panels.Set_Fill (Prefs.Settings_Panel, Desk);
      end if;

      --  The bar, outside what scrolls, so that it stays: the way back
      --  at the left (clear of the window's own buttons), as in a project, then the title.
      Panels.Set_Fill (Prefs.Settings_Bar, Toolbar);
      Labels.Set_Text (Prefs.Settings_Title, "Settings");
      Labels.Set_Style (Prefs.Settings_Title, Pomarine.Line_Texts.Heading);
      Labels.Set_Ink (Prefs.Settings_Title, Themes.Bar_Ink);

      --  The form, on a page of its own, in the middle.
      Panels.Set_Fill (Prefs.Settings_Form, Paper);
      Panels.Set_Border (Prefs.Settings_Form, Themes.Border);
      Panels.Set_Shadow (Prefs.Settings_Form, Themes.Shadow);
      Prefs.Form_Wide := Page_Width;

      --  Display: Theme, and Background.
      Layouts.Add (Prefs.Settings_Form, Prefs.Display_Heading, Line (Heading_Height));
      Labels.Set_Text (Prefs.Display_Heading, "DISPLAY");
      Labels.Set_Style (Prefs.Display_Heading, Pomarine.Line_Texts.Caption);
      Layouts.Add (Prefs.Settings_Form, Prefs.Theme_Name, Line (Settings_Line));
      Labels.Set_Text (Prefs.Theme_Name, "Theme");
      Labels.Set_Style (Prefs.Theme_Name, Pomarine.Line_Texts.Strong);
      Add_Radio (Prefs.Theme_Light, "Light");
      Add_Radio (Prefs.Theme_Dark, "Dark");
      Add_Radio (Prefs.Theme_System, "System");
      Layouts.Add (Prefs.Settings_Form, Prefs.Background_Name, Line (Settings_Line, (Top => Gap, others => <>)));
      Labels.Set_Text (Prefs.Background_Name, "Background");
      Labels.Set_Style (Prefs.Background_Name, Pomarine.Line_Texts.Strong);
      Layouts.Add (Prefs.Settings_Form, Prefs.Background_Scroll,
                   (Flow => Row, Height => Background_Card_Height + Scroll_Room, Shrink => 0.0, others => <>));
      --  The cards, side by side, in a row wider than the form, which is scrolled across.
      Scrollers.Set_Across (Prefs.Background_Scroll, True);
      Layouts.Add (Prefs.Background_Scroll, Prefs.Background_Row,
                   (Flow => Row, Gap => Gap, Shrink => 0.0, Padding => (Bottom => Scroll_Room, others => <>),
                    others => <>));
      for Mode in Preferences.Background_Modes loop
         Add_Card (Prefs.Cards (Mode), Background_Name_Of (Mode), Pictured => Mode in Preferences.Pictures);
      end loop;

      --  Speech: its one option, Model.
      Layouts.Add (Prefs.Settings_Form, Prefs.Speech_Heading,
                   Line (Heading_Height, (Top => Heading_Top, others => <>)));
      Labels.Set_Text (Prefs.Speech_Heading, "SPEECH");
      Labels.Set_Style (Prefs.Speech_Heading, Pomarine.Line_Texts.Caption);
      Layouts.Add (Prefs.Settings_Form, Prefs.Model_Name, Line (Settings_Line));
      Labels.Set_Text (Prefs.Model_Name, "Model");
      Labels.Set_Style (Prefs.Model_Name, Pomarine.Line_Texts.Strong);
      Add_Radio (Prefs.Model_Native, "MacOS");
      Add_Radio (Prefs.Model_Parakeet, "Parakeet");

      Layouts.Add (Prefs.Settings_Form, Prefs.Download_Row,
                   (Height => Download_Height, Shrink => 0.0, Flow => Row, Align => Center, Gap => Gap,
                    Margin => (Top => Gap, others => <>), others => <>));
      Buttons.Add (Prefs.Download_Row, Prefs.Download_Button,
                   Buttons.Looks ("Download", Buttons.Primary, Focusable => True),
                   (Width => Download_Width, Height => Download_Height, Shrink => 0.0, others => <>));
      Buttons.Add (Prefs.Download_Row, Prefs.Delete_Button, Buttons.Looks ("Delete", Buttons.Danger, Focusable => True),
                   (Width => Download_Width, Height => Download_Height, Shrink => 0.0, others => <>));
      Widgets.Set_Visible (Prefs.Delete_Button, False);
      --  Each is on while the view-model says its command can be done (it fetches files that are not
      --  there; it deletes those that are, and none are coming).
      Binding.Bind (Prefs.Download_Button, Settings_VM.Download_Model);
      Binding.Bind (Prefs.Delete_Button, Settings_VM.Delete_Model);
      Layouts.Add (Prefs.Download_Row, Prefs.Download_State,
                   (Grow => 1.0, Width => 0.0, Height => Download_Height, others => <>));
      Labels.Set_Ink (Prefs.Download_State, Quiet_Ink);
      Layouts.Add (Prefs.Settings_Form, Prefs.Download_Bar, Line (Progress_Height));
      Widgets.Set_Visible (Prefs.Download_Bar, False);

      --  Graphics: its one option, VSync.
      Layouts.Add
        (Prefs.Settings_Form, Prefs.Graphics_Heading, Line (Heading_Height, (Top => Heading_Top, others => <>)));
      Labels.Set_Text (Prefs.Graphics_Heading, "GRAPHICS");
      Labels.Set_Style (Prefs.Graphics_Heading, Pomarine.Line_Texts.Caption);
      Layouts.Add (Prefs.Settings_Form, Prefs.VSync_Switch, Line (Settings_Line));
      Switches.Set_Label (Prefs.VSync_Switch, "VSync");
      Switches.Set_Focusable (Prefs.VSync_Switch, True);
      Widgets.Set_Visible (Prefs.Settings_Panel, False);
   end Build_Settings;

end Viewer.Build.Settings_Form;
