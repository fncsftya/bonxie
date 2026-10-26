with Pomarine.Widgets.Panels;
with Pomarine.Boxes;
with Nav_UI;
with Nav_VM;
with Pomarine.UI.Contexts;
with Pomarine.Widgets.Checks;
with Pomarine.Widgets.Grips;
with Pomarine.Widgets.Scrollers;
with Preferences;
with Settings_VM;
with SDL3.Cursors;
with Icon_Set;
with Pomarine.Line_Texts;
with Pomarine.Themes;
with Pomarine.Widgets;
with Pomarine.Widgets.Layouts;
with View.Style;
with Pomarine.Icons;

package body View.Build.Settings_Form is

   package Widgets renames Pomarine.Widgets;
   package Layouts renames Pomarine.Widgets.Layouts;
   package Panels renames Pomarine.Widgets.Panels;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Labels renames Pomarine.Widgets.Labels;
   package Checks renames Pomarine.Widgets.Checks;
   package Grips renames Pomarine.Widgets.Grips;
   package Scrollers renames Pomarine.Widgets.Scrollers;
   package Themes renames Pomarine.Themes;

   package UI renames Pomarine.UI;

   use Style;
   use Pomarine.Widgets.Layouts;

   --  The controls of the form, bound to the view-model (Pomarine.UI): a binding is a pointer to an adapter
   --  that is there as long as the program is, so they are made here, not in the procedure.

   package Settings_UI is new Pomarine.UI.Contexts (Settings_VM.Commands, Settings_VM.View_Model);

   function Is_Theme (Item : Settings_VM.View_Model; To : Preferences.Theme_Choices) return Boolean is
     (Preferences."=" (Settings_VM.Theme (Item), To));
   function Is_Voice (Item : Settings_VM.View_Model; To : Preferences.Speech_Models) return Boolean is
     (Preferences."=" (Settings_VM.Speech_Model (Item), To));

   function Is_Light (Item : Settings_VM.View_Model) return Boolean is (Is_Theme (Item, Preferences.Light));
   function Is_Dark (Item : Settings_VM.View_Model) return Boolean is (Is_Theme (Item, Preferences.Dark));
   function Is_System (Item : Settings_VM.View_Model) return Boolean is (Is_Theme (Item, Preferences.System));
   function Is_MacOS (Item : Settings_VM.View_Model) return Boolean is (Is_Voice (Item, Preferences.MacOS));
   function Is_Parakeet (Item : Settings_VM.View_Model) return Boolean is (Is_Voice (Item, Preferences.Parakeet));

   package Light_Flag is new Settings_UI.Read_Flag (Is_Light);
   package Dark_Flag is new Settings_UI.Read_Flag (Is_Dark);
   package System_Flag is new Settings_UI.Read_Flag (Is_System);
   package MacOS_Flag is new Settings_UI.Read_Flag (Is_MacOS);
   package Parakeet_Flag is new Settings_UI.Read_Flag (Is_Parakeet);
   package VSync_Flag is new Settings_UI.Read_Flag (Settings_VM.VSync);
   package Row_Flag is new Settings_UI.Read_Flag (Settings_VM.Download_Row_Shown);
   package Download_Flag is new Settings_UI.Read_Flag (Settings_VM.Download_Button_Shown);
   package Delete_Flag is new Settings_UI.Read_Flag (Settings_VM.Delete_Button_Shown);
   package Bar_Flag is new Settings_UI.Read_Flag (Settings_VM.Download_Bar_Shown);
   package Status_Text is new Settings_UI.Read_Text (Settings_VM.Download_Status);
   package Fraction_Value is new Settings_UI.Read_Fraction (Settings_VM.Download_Fraction);

   procedure Build_Settings (Item : in out Session) is
      Prefs : Settings_Parts renames Item.Prefs;
   begin
      Open (Item.Forms (Settings_Region), Item.Root.Widgets'Unchecked_Access, Settings_Region);
      declare
         Form  : UI.View renames Item.Forms (Settings_Region).Screen.all;
         Bound : constant Settings_UI.Context'Class :=
           Settings_UI.Bind (Form, Item.Choices.Model'Unrestricted_Access);
         Navs  : constant Nav_UI.Context'Class := Nav_UI.Bind (Form, Item.Nav_Model.Model'Unrestricted_Access);

         function Line
           (High : Float; Top : Float := Unset) return Layouts.Style is
           (Height => High, Shrink => 0.0, Margin => (Top => Top, others => <>), others => <>);

         function Heading (Words : String; Top : Float := Unset) return UI.Layout is
            Made : constant UI.Label_Handle := Bound.Label (Words);
         begin
            Labels.Set_Style (UI.Widget_Of (Form, Made).all, Pomarine.Line_Texts.Caption);
            return UI.Styled (UI.Place (Made), Line (Heading_Height, Top));
         end Heading;

         function Name (Words : String; Top : Float := Unset) return UI.Layout is
            Made : constant UI.Label_Handle := Bound.Label (Words);
         begin
            Labels.Set_Style (UI.Widget_Of (Form, Made).all, Pomarine.Line_Texts.Strong);
            return UI.Styled (UI.Place (Made), Line (Settings_Line, Top));
         end Name;

         function Radio
           (Words : String; Chosen : Settings_UI.Flag_Property; What : Settings_VM.Command; Index : Natural)
            return UI.Layout is
           (UI.Styled
              (UI.Place
                 (Bound.Check (Words, Chosen, What, Form => Checks.Radio, Index => Index)),
               Line (Settings_Line)));

         function Sized (Made : UI.Button_Handle) return UI.Layout is
           (UI.Styled
              (UI.Place (Made),
               (Width => Download_Width, Height => Download_Height, Shrink => 0.0, others => <>)));

         --  A choice of background: a picture, which is clicked, and a foot with its name, which is too.
         function Card_Of (Mode : Preferences.Background_Modes) return UI.Layout is
            Card     : Background_Card renames Prefs.Cards (Mode);
            Pictured : constant Boolean := Mode in Preferences.Pictures;
            Words    : constant String := Background_Name_Of (Mode);
            Choice   : constant Natural := Preferences.Background_Modes'Pos (Mode);
            Pick_Control : constant UI.Widget_Handle := Bound.Borrow_Widget (Card.Pick);
            Peek_Control : constant UI.Widget_Handle := Bound.Borrow_Widget (Card.Peek);

            function New_Picture return UI.Layout is
            begin
               if not Pictured then
                  return UI.Nothing;
               end if;
               declare
                  Button : constant UI.Button_Handle := Bound.Borrow_Button
                    (Card.Reseed, Settings_VM.New_Picture, Choice);
               begin
                  Buttons.Configure
                    (Card.Reseed,
                     Buttons.Looks ("New picture", Icon => Pomarine.Icons.Shown (Icon_Set.Refresh), Focusable => True));
                  return UI.Styled
                    (UI.Place (Button), (Width => Card_Button, Height => Card_Button, Shrink => 0.0, others => <>));
               end;
            end New_Picture;

            Naming : constant UI.Layout :=
              UI.Styled
                (UI.Hold
                   (Pick_Control,
                    [UI.Styled (UI.Put (Form, Card.Name), (Height => Card_Title_Height, others => <>))]),
                 (Grow => 1.0, Width => 0.0, Flow => Column, Spread => Center, Align_Self => Stretch, others => <>));
            Reseeding : constant UI.Layout := New_Picture;
            Foot  : constant UI.Layout :=
              UI.Styled
                (UI.Put_In (Form, Card.Foot, (if Pictured then [Naming, Reseeding] else [Naming])),
                 (Height => Card_Foot_Height, Shrink => 0.0, Flow => Row, Align => Center, Gap => Row_Gap,
                  Padding => (Left | Right => Card_Pad, others => <>), others => <>));
            Peek  : constant UI.Layout :=
              UI.Styled
                (UI.Hold (Peek_Control, [UI.Styled (UI.Put (Form, Card.Sample), (Grow => 1.0, others => <>))]),
                 (Grow => 1.0, Flow => Column, others => <>));
         begin
            Bound.On_Event (Pick_Control, Widgets.Click, Settings_VM.Choose_Background, Choice);
            Bound.On_Event (Peek_Control, Widgets.Click, Settings_VM.Choose_Background, Choice);
            Panels.Set_Radius (Card.Whole, Themes.Large_Radius, Framed => True);
            Panels.Set_Fill (Card.Whole, Themes.Page);
            Panels.Set_Border (Card.Whole, Themes.Border);
            Grips.Set_Wanted_Cursor (Card.Peek, SDL3.Cursors.Pointer);
            Grips.Set_Focusable (Card.Peek, True);
            Widgets.Set_Accessible_Name (Card.Peek, "Choose " & Words & " background");
            Panels.Set_Fill (Card.Foot, Themes.Tint);
            --  Its foot is as round as the card's own foot, or its square corner shows between the outline
            --  and the shadow.
            Panels.Set_Radius (Card.Foot, Themes.Large_Radius, Round => Pomarine.Boxes.Bottom_Corners);
            Card.Sample.Radius := Themes.Large_Radius;
            Grips.Set_Wanted_Cursor (Card.Pick, SDL3.Cursors.Pointer);
            Labels.Set_Text (Card.Name, Words);
            Labels.Set_Style (Card.Name, Pomarine.Line_Texts.Strong);
            return UI.Styled
              (UI.Put_In (Form, Card.Whole, [Peek, Foot]),
               (Flow => Column, Width => Background_Card_Width, Height => Background_Card_Height, Shrink => 0.0,
                Outlined => True, Shadowed => True, others => <>));
         end Card_Of;

         Download : constant UI.Button_Handle :=
           Bound.Button ("Download", Settings_VM.Download_Model, Buttons.Primary, Focusable => True);
         Delete   : constant UI.Button_Handle :=
           Bound.Button ("Delete", Settings_VM.Confirm_Delete, Buttons.Danger, Focusable => True);

         Status : constant UI.Label_Handle := Bound.Label (Status_Text.Property);
         Bar    : constant UI.Progress_Handle := Bound.Progress (Fraction_Value.Property);
         Switch : constant UI.Switch_Handle := Bound.Switch ("VSync", VSync_Flag.Property, Settings_VM.Toggle_VSync);
         Close  : constant UI.Button_Handle :=
           Navs.Button
             (Buttons.Looks ("Projects", Buttons.Quiet, Icon => Pomarine.Icons.Shown (Icon_Set.Back),
                             Captioned => True, Focusable => True),
              Nav_VM.Close_Settings);

         Download_Row : constant UI.Layout :=
           UI.Styled
             (UI.Row
                ([Sized (Download), Sized (Delete),
                  UI.Styled
                    (UI.Place (Status), (Grow => 1.0, Width => 0.0, Height => Download_Height, others => <>))]),
              (Height => Download_Height, Shrink => 0.0, Flow => Layouts.Row, Align => Center, Gap => Gap,
               Margin => (Top => Gap, others => <>), others => <>));

         --  The cards, side by side, in a row wider than the form, which is scrolled across.
         function Every_Card return UI.Layout_Array is
            Result : UI.Layout_Array (1 .. Preferences.Background_Modes'Pos (Preferences.Background_Modes'Last) + 1);
         begin
            for Mode in Preferences.Background_Modes loop
               Result (Preferences.Background_Modes'Pos (Mode) + 1) := Card_Of (Mode);
            end loop;
            return Result;
         end Every_Card;

         Every       : constant UI.Layout_Array := Every_Card;
         Cards_Row   : constant UI.Layout :=
           UI.Styled
             (UI.Put_In (Form, Prefs.Background_Row, Every, Flow => Layouts.Row),
              (Flow => Row, Gap => Gap, Shrink => 0.0, Padding => (Bottom => Scroll_Room, others => <>),
               others => <>));
         Cards : constant UI.Layout :=
           UI.Styled
             (UI.Put_In (Form, Prefs.Background_Scroll, [Cards_Row]),
              (Flow => Layouts.Row, Height => Background_Card_Height + Scroll_Room, Shrink => 0.0, others => <>));

         Choices : constant UI.Layout_Array :=
           [Heading ("DISPLAY"),
            Name ("Theme"),
            Radio ("Light", Light_Flag.Property, Settings_VM.Choose_Theme,
                   Preferences.Theme_Choices'Pos (Preferences.Light)),
            Radio ("Dark", Dark_Flag.Property, Settings_VM.Choose_Theme,
                   Preferences.Theme_Choices'Pos (Preferences.Dark)),
            Radio ("System", System_Flag.Property, Settings_VM.Choose_Theme,
                   Preferences.Theme_Choices'Pos (Preferences.System)),
            Name ("Background", Top => Gap),
            Cards,
            Heading ("SPEECH", Top => Heading_Top),
            Name ("Model"),
            Radio ("MacOS", MacOS_Flag.Property, Settings_VM.Choose_Speech_Model,
                   Preferences.Speech_Models'Pos (Preferences.MacOS)),
            Radio ("Parakeet", Parakeet_Flag.Property, Settings_VM.Choose_Speech_Model,
                   Preferences.Speech_Models'Pos (Preferences.Parakeet)),
            Download_Row,
            UI.Styled (UI.Place (Bar), Line (Progress_Height)),
            Heading ("GRAPHICS", Top => Heading_Top),
            UI.Styled (UI.Place (Switch), Line (Settings_Line))];

         --  The form, on a page of its own, in the middle, scrolled.
         Page : constant UI.Layout :=
           UI.Styled
             (UI.Put_In (Form, Prefs.Settings_Form, Choices),
              (Flow => Column, Shrink => 0.0, Width => Page_Width, Padding => (others => Dialog_Pad),
               Shadowed => True, Gap => Row_Gap, others => <>));
         Sheet : constant UI.Layout :=
           UI.Styled
             (UI.Put_In
                (Form, Prefs.Settings_Scroll,
                 [UI.Styled
                    (UI.Put_In (Form, Prefs.Settings_Content, [Page]),
                     (Flow => Column, Shrink => 0.0, Align => Center, Padding => (others => Page_Margin),
                      others => <>))]),
              (Grow => 1.0, Height => 0.0, others => <>));

         --  The bar, outside what scrolls, so that it stays: the way back at the left (clear of the window's
         --  own buttons), as in a project, then the title.
         Title_Bar : constant UI.Layout :=
           UI.Styled
             (UI.Put_In
                (Form, Prefs.Settings_Bar,
                 [UI.Styled
                    (UI.Place (Close),
                     (Width => Back_Width, Height => Tab_Height, Shrink => 0.0,
                      Margin => (Right => Name_Gap, others => <>), others => <>)),
                  UI.Styled
                    (UI.Put (Form, Prefs.Settings_Title), (Grow => 1.0, Width => 0.0, Height => Tab_Height,
                                                           others => <>))],
                 Flow => Layouts.Row),
              (Height => Toolbar_Size, Shrink => 0.0, Flow => Row, Align => Center,
               Padding => (Left  => (if Item.Shell.Windowed then Header_Inset else Bar_Inset), Right => Bar_Inset,
                           others => <>),
               others => <>));

         Whole : constant UI.Layout :=
           UI.Styled (UI.Put_In (Form, Prefs.Settings_Panel, [Title_Bar, Sheet]), (Flow => Column, Grow => 1.0,
                                                                                       others => <>));
      begin
         Labels.Set_Ink (UI.Widget_Of (Form, Status).all, Quiet_Ink);
         Bound.Show_When (Download_Row, Row_Flag.Property);
         Bound.Show_When (UI.Any (Download), Download_Flag.Property);
         Bound.Show_When (UI.Any (Bar), Bar_Flag.Property);
         Bound.Show_When (UI.Any (Delete), Delete_Flag.Property);
         Scrollers.Set_Across (Prefs.Background_Scroll, True);
         Panels.Set_Fill (Prefs.Settings_Bar, Toolbar);
         Labels.Set_Text (Prefs.Settings_Title, "Settings");
         Labels.Set_Style (Prefs.Settings_Title, Pomarine.Line_Texts.Heading);
         Labels.Set_Ink (Prefs.Settings_Title, Themes.Bar_Ink);
         if not Item.Shell.Windowed then
            Panels.Set_Fill (Prefs.Settings_Panel, Desk);
         end if;
         Panels.Set_Fill (Prefs.Settings_Form, Paper);
         Panels.Set_Border (Prefs.Settings_Form, Themes.Border);
         Panels.Set_Shadow (Prefs.Settings_Form, Themes.Shadow);
         Prefs.Form_Wide := Page_Width;
         UI.Mount_Into (Form, Item.Root.Window_Panel, Whole);
      end;
      Widgets.Set_Visible (Prefs.Settings_Panel, False);
   end Build_Settings;

end View.Build.Settings_Form;
