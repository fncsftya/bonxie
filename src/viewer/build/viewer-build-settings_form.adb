with Pomarine.Boxes;
with Pomarine.Widgets.Switches;
with Pomarine.Widgets.Selects;
with Pomarine.Widgets.Checks;
with Pomarine.Widgets.Grips;
with Pomarine.Widgets.Scrollers;
with Preferences;
with SDL3.Cursors;
with Icon_Set;
with Pomarine.Line_Texts;
with Pomarine.Themes;
with Pomarine.Widgets;
with Pomarine.Widgets.Layouts;
with Viewer.Style;

package body Viewer.Build.Settings_Form is

   package Widgets renames Pomarine.Widgets;
   package Panels renames Pomarine.Widgets.Panels;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Labels renames Pomarine.Widgets.Labels;
   package Checks renames Pomarine.Widgets.Checks;
   package Grips renames Pomarine.Widgets.Grips;
   package Scrollers renames Pomarine.Widgets.Scrollers;
   package Selects renames Pomarine.Widgets.Selects;
   package Switches renames Pomarine.Widgets.Switches;
   package Themes renames Pomarine.Themes;

   use Style;
   use Pomarine.Widgets.Layouts;

   procedure Build_Settings (Item : in out Session) is
      Prefs : Settings_Parts renames Item.Prefs;

      procedure Line (Part : in out Widgets.Widget'Class; High : Float) is
      begin
         Set_Layout (Part, Height => High, Shrink => 0.0);
      end Line;

      procedure Radio (Part : in out Checks.Check; Name : String) is
      begin
         Checks.Set_Kind (Part, Checks.Radio);
         Checks.Set_Label (Part, Name);
         Checks.Set_Focusable (Part, True);
         Line (Part, Settings_Line);
      end Radio;

      --  A choice of background: a picture, which is clicked, and a foot with its name, which is too.
      procedure Build_Card (Card : in out Background_Card; Words : String) is
      begin
         Panels.Set_Radius (Card.Whole, Themes.Large_Radius, Framed => True);
         Panels.Set_Fill (Card.Whole, Themes.Page);
         Panels.Set_Border (Card.Whole, Themes.Border);
         Set_Layout
           (Card.Whole, Flow => Column, Width => Background_Card_Width, Height => Background_Card_Height,
            Shrink => 0.0, Outlined => True, Shadowed => True);
         Grips.Set_Wanted_Cursor (Card.Peek, SDL3.Cursors.Pointer);
         Grips.Set_Focusable (Card.Peek, True);
         Set_Layout (Card.Peek, Grow => 1.0, Flow => Column);
         Panels.Set_Fill (Card.Foot, Themes.Tint);
         --  Its foot is as round as the card's own foot, or its square corner shows between the outline and the shadow.
         Panels.Set_Radius (Card.Foot, Themes.Large_Radius, Round => Pomarine.Boxes.Bottom_Corners);
         Set_Layout
           (Card.Foot, Height => Card_Foot_Height, Shrink => 0.0, Flow => Row, Align => Center, Gap => Row_Gap,
            Padding => (Left | Right => Card_Pad, others => <>));
         Grips.Set_Wanted_Cursor (Card.Pick, SDL3.Cursors.Pointer);
         Set_Layout
           (Card.Pick, Grow => 1.0, Width => 0.0, Flow => Column, Spread => Center, Align_Self => Stretch);
         Labels.Set_Text (Card.Name, Words);
         Labels.Set_Style (Card.Name, Pomarine.Line_Texts.Strong);
         Set_Layout (Card.Name, Height => Card_Title_Height);
      end Build_Card;
   begin
      Widgets.Add (Item.Root.Window_Panel, Prefs.Settings_Panel);
      Widgets.Add (Prefs.Settings_Panel, Prefs.Settings_Bar);
      Widgets.Add (Prefs.Settings_Bar, Prefs.Settings_Close, Prefs.Settings_Title);
      Widgets.Add (Prefs.Settings_Panel, Prefs.Settings_Scroll);
      Widgets.Add (Prefs.Settings_Scroll, Prefs.Settings_Content);
      Widgets.Add (Prefs.Settings_Content, Prefs.Settings_Form);
      Widgets.Add
        (Prefs.Settings_Form, Prefs.Display_Heading, Prefs.Theme_Name, Prefs.Theme_Light,
         Prefs.Theme_Dark, Prefs.Theme_System);
      Widgets.Add (Prefs.Settings_Form, Prefs.Background_Name, Prefs.Background_Scroll);
      Widgets.Add (Prefs.Background_Scroll, Prefs.Background_Row);
      for Mode in Preferences.Background_Modes loop
         declare
            Card : Background_Card renames Prefs.Cards (Mode);
         begin
            Widgets.Add (Prefs.Background_Row, Card.Whole);
            Widgets.Add (Card.Whole, Card.Peek, Card.Foot);
            Widgets.Add (Card.Peek, Card.Sample);
            Widgets.Add (Card.Foot, Card.Pick);
            Widgets.Add (Card.Pick, Card.Name);
            if Mode in Preferences.Pictures then
               Widgets.Add (Card.Foot, Card.Reseed);
            end if;
         end;
      end loop;
      Widgets.Add
        (Prefs.Settings_Form, Prefs.AI_Heading, Prefs.AI_Enable, Prefs.AI_Model_Name, Prefs.AI_Hub_Note,
         Prefs.AI_Select);
      Widgets.Add (Prefs.Settings_Form, Prefs.AI_Test_Row);
      Widgets.Add (Prefs.AI_Test_Row, Prefs.AI_Test_Button, Prefs.AI_Test_State);
      for Each of Prefs.AI_Notes loop
         Widgets.Add (Prefs.Settings_Form, Each);
      end loop;
      Widgets.Add (Prefs.Settings_Panel, Prefs.AI_Menu);
      Widgets.Add
        (Prefs.Settings_Form, Prefs.Speech_Heading, Prefs.Model_Name, Prefs.Model_Native,
         Prefs.Model_Parakeet, Prefs.Download_Row);
      Widgets.Add (Prefs.Download_Row, Prefs.Download_Button, Prefs.Delete_Button, Prefs.Download_State);
      Widgets.Add (Prefs.Settings_Form, Prefs.Download_Bar);

      Set_Layout (Prefs.Settings_Panel, Flow => Column, Grow => 1.0);
      if not Item.Shell.Windowed then
         Panels.Set_Fill (Prefs.Settings_Panel, Desk);
      end if;

      --  The bar, outside what scrolls, so that it stays: the way back
      --  at the left (clear of the window's own buttons), as in a project, then the title.
      Panels.Set_Fill (Prefs.Settings_Bar, Toolbar);
      Set_Layout
        (Prefs.Settings_Bar, Height => Toolbar_Size, Shrink => 0.0, Flow => Row, Align => Center,
         Padding => (Left  => (if Item.Shell.Windowed then Header_Inset else Bar_Inset),
                     Right => Bar_Inset,
                     others => <>));
      Labels.Set_Text (Prefs.Settings_Title, "Settings");
      Labels.Set_Style (Prefs.Settings_Title, Pomarine.Line_Texts.Heading);
      Labels.Set_Ink (Prefs.Settings_Title, Themes.Bar_Ink);
      Set_Layout (Prefs.Settings_Title, Grow => 1.0, Width => 0.0, Height => Tab_Height);
      Buttons.Set_Label (Prefs.Settings_Close, "Projects");
      Buttons.Set_Icon (Prefs.Settings_Close, Icon_Set.Back);
      Buttons.Set_Captioned (Prefs.Settings_Close, True);
      Buttons.Set_Kind (Prefs.Settings_Close, Buttons.Quiet);
      Set_Layout
        (Prefs.Settings_Close, Width => Back_Width, Height => Tab_Height, Shrink => 0.0,
         Margin => (Right => Name_Gap, others => <>));

      --  The form, on a page of its own, in the middle.
      Set_Layout (Prefs.Settings_Scroll, Grow => 1.0, Height => 0.0);
      Set_Layout
        (Prefs.Settings_Content, Flow => Column, Shrink => 0.0, Align => Center,
         Padding => (others => Page_Margin));
      Panels.Set_Fill (Prefs.Settings_Form, Paper);
      Panels.Set_Border (Prefs.Settings_Form, Themes.Border);
      Panels.Set_Shadow (Prefs.Settings_Form, Themes.Shadow);
      Set_Layout
        (Prefs.Settings_Form, Flow => Column, Shrink => 0.0, Width => Page_Width,
         Padding => (others => Dialog_Pad), Shadowed => True, Gap => Row_Gap);
      Prefs.Form_Wide := Page_Width;

      --  Display: Theme, and Background.
      Labels.Set_Text (Prefs.Display_Heading, "DISPLAY");
      Labels.Set_Style (Prefs.Display_Heading, Pomarine.Line_Texts.Caption);
      Line (Prefs.Display_Heading, Heading_Height);
      Labels.Set_Text (Prefs.Theme_Name, "Theme");
      Labels.Set_Style (Prefs.Theme_Name, Pomarine.Line_Texts.Strong);
      Line (Prefs.Theme_Name, Settings_Line);
      Radio (Prefs.Theme_Light, "Light");
      Radio (Prefs.Theme_Dark, "Dark");
      Radio (Prefs.Theme_System, "System");
      Labels.Set_Text (Prefs.Background_Name, "Background");
      Labels.Set_Style (Prefs.Background_Name, Pomarine.Line_Texts.Strong);
      Line (Prefs.Background_Name, Settings_Line);
      Set_Layout (Prefs.Background_Name, Margin => (Top => Gap, others => <>));
      --  The cards, side by side, in a row wider than the form, which is scrolled across.
      Scrollers.Set_Across (Prefs.Background_Scroll, True);
      Set_Layout
        (Prefs.Background_Scroll, Flow => Row, Height => Background_Card_Height + Scroll_Room, Shrink => 0.0);
      Set_Layout
        (Prefs.Background_Row, Flow => Row, Gap => Gap, Shrink => 0.0,
         Padding => (Bottom => Scroll_Room, others => <>));
      for Mode in Preferences.Background_Modes loop
         declare
            Card : Background_Card renames Prefs.Cards (Mode);
         begin
            Set_Layout (Card.Sample, Grow => 1.0);
            Build_Card (Card, Background_Name_Of (Mode));
            if Mode in Preferences.Pictures then
               Buttons.Set_Label (Card.Reseed, "New picture");
               Buttons.Set_Icon (Card.Reseed, Icon_Set.Refresh);
               Buttons.Set_Focusable (Card.Reseed, True);
               Set_Layout (Card.Reseed, Width => Card_Button, Height => Card_Button, Shrink => 0.0);
            end if;
         end;
      end loop;

      --  AI: Enable, and, with it on, the model to run.
      Labels.Set_Text (Prefs.AI_Heading, "AI");
      Labels.Set_Style (Prefs.AI_Heading, Pomarine.Line_Texts.Caption);
      Line (Prefs.AI_Heading, Heading_Height);
      Set_Layout (Prefs.AI_Heading, Margin => (Top => Heading_Top, others => <>));
      Switches.Set_Label (Prefs.AI_Enable, "Enable");
      Switches.Set_Focusable (Prefs.AI_Enable, True);
      Line (Prefs.AI_Enable, Settings_Line);
      Labels.Set_Text (Prefs.AI_Model_Name, "Model");
      Labels.Set_Style (Prefs.AI_Model_Name, Pomarine.Line_Texts.Strong);
      Line (Prefs.AI_Model_Name, Settings_Line);
      Labels.Set_Text (Prefs.AI_Hub_Note, "Hugging Face support not detected");
      Labels.Set_Ink (Prefs.AI_Hub_Note, Quiet_Ink);
      Line (Prefs.AI_Hub_Note, Settings_Line);
      Selects.Set_Value (Prefs.AI_Select, None_Selected);
      Line (Prefs.AI_Select, Download_Height);
      Line (Prefs.AI_Test_Row, Download_Height);
      Set_Layout
        (Prefs.AI_Test_Row, Flow => Row, Align => Center, Gap => Gap,
         Margin => (Top => Gap, others => <>));
      Buttons.Set_Label (Prefs.AI_Test_Button, "Test");
      Buttons.Set_Kind (Prefs.AI_Test_Button, Buttons.Primary);
      Buttons.Set_Focusable (Prefs.AI_Test_Button, True);
      Set_Layout
        (Prefs.AI_Test_Button, Width => Download_Width, Height => Download_Height, Shrink => 0.0);
      Labels.Set_Ink (Prefs.AI_Test_State, Quiet_Ink);
      Set_Layout (Prefs.AI_Test_State, Grow => 1.0, Width => 0.0, Height => Download_Height);
      for Each of Prefs.AI_Notes loop
         Line (Each, Note_Line);
         Widgets.Set_Visible (Each, False);
      end loop;
      Set_Layout (Prefs.AI_Menu, Place => Absolute, Width => Menu_Width);
      Widgets.Set_Visible (Prefs.AI_Menu, False);

      --  Speech: its one option, Model.
      Labels.Set_Text (Prefs.Speech_Heading, "SPEECH");
      Labels.Set_Style (Prefs.Speech_Heading, Pomarine.Line_Texts.Caption);
      Line (Prefs.Speech_Heading, Heading_Height);
      Set_Layout (Prefs.Speech_Heading, Margin => (Top => Heading_Top, others => <>));
      Labels.Set_Text (Prefs.Model_Name, "Model");
      Labels.Set_Style (Prefs.Model_Name, Pomarine.Line_Texts.Strong);
      Line (Prefs.Model_Name, Settings_Line);
      Radio (Prefs.Model_Native, "MacOS");
      Radio (Prefs.Model_Parakeet, "Parakeet");

      Line (Prefs.Download_Row, Download_Height);
      Set_Layout
        (Prefs.Download_Row, Flow => Row, Align => Center, Gap => Gap,
         Margin => (Top => Gap, others => <>));
      Buttons.Set_Label (Prefs.Download_Button, "Download");
      Buttons.Set_Kind (Prefs.Download_Button, Buttons.Primary);
      Set_Layout
        (Prefs.Download_Button, Width => Download_Width, Height => Download_Height, Shrink => 0.0);
      Buttons.Set_Label (Prefs.Delete_Button, "Delete");
      Buttons.Set_Kind (Prefs.Delete_Button, Buttons.Danger);
      Buttons.Set_Focusable (Prefs.Download_Button, True);
      Buttons.Set_Focusable (Prefs.Delete_Button, True);
      Set_Layout
        (Prefs.Delete_Button, Width => Download_Width, Height => Download_Height, Shrink => 0.0);
      Widgets.Set_Visible (Prefs.Delete_Button, False);
      Labels.Set_Ink (Prefs.Download_State, Quiet_Ink);
      Set_Layout (Prefs.Download_State, Grow => 1.0, Width => 0.0, Height => Download_Height);
      Line (Prefs.Download_Bar, Progress_Height);
      Widgets.Set_Visible (Prefs.Download_Bar, False);
      Widgets.Set_Visible (Prefs.Settings_Panel, False);
   end Build_Settings;

end Viewer.Build.Settings_Form;
