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
with Site_Filter_VM;
with Site_Filters;
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
   use type Preferences.Background_Modes;

   --  The controls of the form, bound to the view-model (Pomarine.UI): a binding is a pointer to an adapter
   --  that is there as long as the program is, so they are made here, not in the procedure.

   package Settings_UI is new Pomarine.UI.Contexts (Settings_VM.Commands, Settings_VM.View_Model);

   function Theme_Of (Item : Settings_VM.View_Model) return Preferences.Theme_Choices
   is (Settings_VM.Theme (Item));
   function Voice_Of (Item : Settings_VM.View_Model) return Preferences.Speech_Models
   is (Settings_VM.Speech_Model (Item));

   package Filter_UI is new Pomarine.UI.Contexts (Site_Filter_VM.Commands, Site_Filter_VM.Model);

   function Mode_Of (Item : Site_Filter_VM.Model) return Site_Filters.Modes
   is (Site_Filter_VM.Mode (Item));

   package Mode_Is is new Filter_UI.Choosing_Among (Site_Filters.Modes, Mode_Of);

   Site_Draft  : constant Filter_UI.Text_Property :=
     Filter_UI.Editing (Site_Filter_VM.Draft'Access, Site_Filter_VM.Set_Draft'Access);
   Site_Hint   : constant Filter_UI.Text_Property := Filter_UI.Showing (Site_Filter_VM.Hint'Access);
   Site_Rows   : constant Filter_UI.Rows_Property := Filter_UI.Listing (Site_Filter_VM.Rows'Access);
   Site_Choice : constant Filter_UI.Choice_Property :=
     Filter_UI.Choosing (Site_Filter_VM.Selected_Site'Access, Site_Filter_VM.Select_Site'Access);
   Site_List   : constant Filter_UI.Flag_Property := Filter_UI.Showing (Site_Filter_VM.List_Shown'Access);

   Sites_Height : constant Float := 96.0;
   --  The list of sites, in points.

   package Theme_Is is new Settings_UI.Choosing_Among (Preferences.Theme_Choices, Theme_Of);
   package Voice_Is is new Settings_UI.Choosing_Among (Preferences.Speech_Models, Voice_Of);

   VSync_Flag          : constant Settings_UI.Flag_Property := Settings_UI.Showing (Settings_VM.VSync'Access);
   Row_Flag            : constant Settings_UI.Flag_Property :=
     Settings_UI.Showing (Settings_VM.Download_Row_Shown'Access);
   Download_Flag       : constant Settings_UI.Flag_Property :=
     Settings_UI.Showing (Settings_VM.Download_Button_Shown'Access);
   Delete_Flag         : constant Settings_UI.Flag_Property :=
     Settings_UI.Showing (Settings_VM.Delete_Button_Shown'Access);
   Bar_Flag            : constant Settings_UI.Flag_Property :=
     Settings_UI.Showing (Settings_VM.Download_Bar_Shown'Access);
   Status_Text         : constant Settings_UI.Text_Property := Settings_UI.Showing (Settings_VM.Download_Status'Access);
   Fraction_Value      : constant Settings_UI.Fraction_Property :=
     Settings_UI.Showing (Settings_VM.Download_Fraction'Access);
   Gallery_Bar_Flag    : constant Settings_UI.Flag_Property :=
     Settings_UI.Showing (Settings_VM.Gallery_Bar_Shown'Access);
   Gallery_Status_Flag : constant Settings_UI.Flag_Property :=
     Settings_UI.Showing (Settings_VM.Gallery_Status_Shown'Access);
   Gallery_Status      : constant Settings_UI.Text_Property := Settings_UI.Showing (Settings_VM.Gallery_Status'Access);
   Gallery_Fraction    : constant Settings_UI.Fraction_Property :=
     Settings_UI.Showing (Settings_VM.Gallery_Fraction'Access);

   procedure Build_Settings (Item : in out Session) is
      Prefs : Settings_Parts renames Item.Prefs;
   begin
      Open_Screen (Item, Settings_Region);
      declare
         Form  : UI.View renames Screen_Of (Item, Settings_Region).all;
         Bound : constant Settings_UI.Context'Class := Settings_UI.Bind (Form, Item.Choices.Model);
         Navs  : constant Nav_UI.Context'Class := Nav_UI.Bind (Form, Item.Nav_Model.Model);
         Sites : constant Filter_UI.Context'Class := Filter_UI.Bind (Form, Item.Choices.Filter);

         function Line (High : Float; Top : Layouts.Length := Unset) return Layouts.Style
         is (Height => Layouts.Length_Of (High), Shrink => 0.0, Margin => (Top => Top, others => <>), others => <>);

         function Heading (Words : String; Top : Layouts.Length := Unset) return UI.Layout is
            Made : constant UI.Label_Handle := Bound.Label (Words, Style => Pomarine.Line_Texts.Caption);
         begin
            return UI.Styled (UI.Place (Made), Line (Heading_Height, Top));
         end Heading;

         function Name (Words : String; Top : Layouts.Length := Unset) return UI.Layout is
            Made : constant UI.Label_Handle := Bound.Label (Words, Style => Pomarine.Line_Texts.Strong);
         begin
            return UI.Styled (UI.Place (Made), Line (Settings_Line, Top));
         end Name;

         function Radio
           (Words : String; Chosen : Settings_UI.Flag_Property; What : Settings_VM.Command; Index : Natural)
            return UI.Layout
         is (UI.Styled
               (UI.Place (Bound.Check (Words, Chosen, What, Form => Checks.Radio, Index => Index)),
                Line (Settings_Line)));

         function Sized (Made : UI.Button_Handle) return UI.Layout
         is (UI.Place (Made, Width => Download_Width, Height => Download_Height, Shrink => 0.0, Exact => True));

         --  A choice of background: a picture, which is clicked, and a foot with its name, which is too.
         function Card_Of (Mode : Preferences.Background_Modes) return UI.Layout is
            Card     : Background_Card renames Prefs.Cards (Mode);
            Pictured : constant Boolean := Mode in Preferences.Pictures or else Mode = Preferences.Gallery;
            Words    : constant String := Background_Name_Of (Mode);
            Choice   : constant Natural := Preferences.Background_Modes'Pos (Mode);

            function New_Picture return UI.Layout is
            begin
               if not Pictured then
                  return UI.Nothing;
               end if;
               Buttons.Configure
                 (Card.Reseed,
                  Buttons.Looks ("New picture", Icon => Pomarine.Icons.Shown (Icon_Set.Refresh), Focusable => True));
               return
                 Bound.Borrow_Button
                   (Card.Reseed,
                    (if Mode = Preferences.Gallery then Settings_VM.New_Gallery_Picture else Settings_VM.New_Picture),
                    Choice,
                    Width  => Card_Button,
                    Height => Card_Button,
                    Shrink => 0.0,
                    Exact  => True);
            end New_Picture;

            Naming    : constant UI.Layout :=
              UI.Styled
                (Bound.Borrow_Holding
                   (Card.Pick,
                    [UI.Styled (UI.Put (Form, Card.Name), (Height => Card_Title_Height, others => <>))],
                    Click => Settings_VM.Choose_Background,
                    Index => Choice),
                 (Grow => 1.0, Width => 0.0, Flow => Column, Spread => Center, Align_Self => Stretch, others => <>));
            Reseeding : constant UI.Layout := New_Picture;
            Foot      : constant UI.Layout :=
              UI.Styled
                (UI.Put_In (Form, Card.Foot, (if Pictured then [Naming, Reseeding] else [Naming])),
                 (Height  => Card_Foot_Height,
                  Shrink  => 0.0,
                  Flow    => Row,
                  Align   => Center,
                  Gap     => Row_Gap,
                  Padding => (Left | Right => Layouts.Length_Of (Card_Pad), others => <>),
                  others  => <>));
            Peek      : constant UI.Layout :=
              UI.Styled
                (Bound.Borrow_Holding
                   (Card.Peek,
                    [UI.Styled (UI.Put (Form, Card.Sample), (Grow => 1.0, others => <>))],
                    Click => Settings_VM.Choose_Background,
                    Index => Choice),
                 (Grow => 1.0, Flow => Column, others => <>));
         begin
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
            return
              UI.Styled
                (UI.Put_In (Form, Card.Whole, [Peek, Foot]),
                 (Flow     => Column,
                  Width    => Layouts.Length_Of (Background_Card_Width),
                  Height   => Layouts.Length_Of (Background_Card_Height),
                  Shrink   => 0.0,
                  Outlined => On,
                  Shadowed => On,
                  others   => <>));
         end Card_Of;

         Download : constant UI.Button_Handle :=
           Bound.Button ("Download", Settings_VM.Download_Model, Buttons.Primary, Focusable => True);
         Delete   : constant UI.Button_Handle :=
           Bound.Button ("Delete", Settings_VM.Confirm_Delete, Buttons.Danger, Focusable => True);

         function Filter_Radio (Words : String; Mode : Site_Filters.Modes) return UI.Layout
         is (UI.Styled
               (Sites.Check
                  (Words,
                   Mode_Is.Is_Value (Mode),
                   Site_Filter_VM.Choose_Mode,
                   Form  => Checks.Radio,
                   Index => Site_Filters.Modes'Pos (Mode)),
                Line (Settings_Line)));

         --  Typed in a field: Return, or the buttons, add the site, change the chosen one to what is typed, or
         --  remove it; they are on as the view-model says.
         Site_Entry : constant UI.Layout :=
           UI.Styled
             (UI.Row
                ([Sites.Text_Field
                    (Site_Draft,
                     Site_Filter_VM.Add_Site,
                     Placeholder => "https://example.com",
                     Name        => "Site",
                     Grow        => 1.0,
                     Width       => Layouts.Length_Of (0.0),
                     Height      => Download_Height),
                  Sites.Button ("Add", Site_Filter_VM.Add_Site, Buttons.Primary, Width => Download_Width),
                  Sites.Button ("Change", Site_Filter_VM.Change_Site, Width => Download_Width),
                  Sites.Button ("Remove", Site_Filter_VM.Remove_Site, Buttons.Danger, Width => Download_Width)]),
              (Height => Download_Height,
               Shrink => 0.0,
               Flow   => Layouts.Row,
               Align  => Center,
               Gap    => Layouts.Length_Of (Gap),
               others => <>));

         Site_Editor : constant UI.Layout :=
           UI.Styled
             (UI.Column
                ([Site_Entry,
                  UI.Styled
                    (Sites.Label (Site_Hint, Ink => Quiet_Ink),
                     (Height => Layouts.Length_Of (Settings_Line), Shrink => 0.0, others => <>)),
                  UI.Styled
                    (UI.Put_In
                       (Form,
                        Prefs.Sites_Box,
                        [Sites.List (Site_Rows, Site_Choice, Name => "Sites", Grow => 1.0, Shrink => 0.0)]),
                     (Height => Layouts.Length_Of (Sites_Height), Shrink => 0.0, Flow => Column, others => <>))],
                 Gap => Layouts.Length_Of (Gap)),
              (Shrink => 0.0, Margin => (Top => Layouts.Length_Of (Gap), others => <>), others => <>));

         Status     : constant UI.Label_Handle := Bound.Label (Status_Text, Ink => Quiet_Ink);
         Bar        : constant UI.Progress_Handle := Bound.Progress (Fraction_Value);
         Art_Bar    : constant UI.Progress_Handle := Bound.Progress (Gallery_Fraction);
         Art_Status : constant UI.Label_Handle := Bound.Label (Gallery_Status, Ink => Quiet_Ink);
         Switch     : constant UI.Switch_Handle := Bound.Switch ("VSync", VSync_Flag, Settings_VM.Toggle_VSync);
         Close      : constant UI.Button_Handle :=
           Navs.Button
             (Buttons.Looks
                ("Projects",
                 Buttons.Quiet,
                 Icon      => Pomarine.Icons.Shown (Icon_Set.Back),
                 Captioned => True,
                 Focusable => True),
              Nav_VM.Close_Settings);

         Download_Row : constant UI.Layout :=
           UI.Styled
             (UI.Row
                ([Sized (Download),
                  Sized (Delete),
                  UI.Place (Status, Grow => 1.0, Width => 0.0, Height => Download_Height, Exact => True)]),
              (Height => Download_Height,
               Shrink => 0.0,
               Flow   => Layouts.Row,
               Align  => Center,
               Gap    => Layouts.Length_Of (Gap),
               Margin => (Top => Layouts.Length_Of (Gap), others => <>),
               others => <>));

         --  The cards, side by side, in a row wider than the form, which is scrolled across.
         function Every_Card return UI.Layout_Array is
            Result : UI.Layout_Array (1 .. Preferences.Background_Modes'Pos (Preferences.Background_Modes'Last) + 1);
         begin
            for Mode in Preferences.Background_Modes loop
               Result (Preferences.Background_Modes'Pos (Mode) + 1) := Card_Of (Mode);
            end loop;
            return Result;
         end Every_Card;

         Every     : constant UI.Layout_Array := Every_Card;
         Cards_Row : constant UI.Layout :=
           UI.Styled
             (UI.Put_In (Form, Prefs.Background_Row, Every, Flow => Layouts.Row),
              (Flow    => Row,
               Gap     => Layouts.Length_Of (Gap),
               Shrink  => 0.0,
               Padding => (Bottom => Layouts.Length_Of (Scroll_Room), others => <>),
               others  => <>));
         Cards     : constant UI.Layout :=
           UI.Styled
             (UI.Put_In (Form, Prefs.Background_Scroll, [Cards_Row]),
              (Flow   => Layouts.Row,
               Height => Layouts.Length_Of (Background_Card_Height + Scroll_Room),
               Shrink => 0.0,
               others => <>));

         Choices : constant UI.Layout_Array :=
           [Heading ("DISPLAY"),
            Name ("Theme"),
            Radio
              ("Light",
               Theme_Is.Is_Value (Preferences.Light),
               Settings_VM.Choose_Theme,
               Preferences.Theme_Choices'Pos (Preferences.Light)),
            Radio
              ("Dark",
               Theme_Is.Is_Value (Preferences.Dark),
               Settings_VM.Choose_Theme,
               Preferences.Theme_Choices'Pos (Preferences.Dark)),
            Radio
              ("System",
               Theme_Is.Is_Value (Preferences.System),
               Settings_VM.Choose_Theme,
               Preferences.Theme_Choices'Pos (Preferences.System)),
            Name ("Background", Top => Layouts.Length_Of (Gap)),
            Cards,
            UI.Styled (UI.Place (Art_Status), Line (Settings_Line)),
            UI.Styled (UI.Place (Art_Bar), Line (Progress_Height)),
            Heading ("SPEECH", Top => Layouts.Length_Of (Heading_Top)),
            Name ("Model"),
            Radio
              ("MacOS",
               Voice_Is.Is_Value (Preferences.MacOS),
               Settings_VM.Choose_Speech_Model,
               Preferences.Speech_Models'Pos (Preferences.MacOS)),
            Radio
              ("Parakeet",
               Voice_Is.Is_Value (Preferences.Parakeet),
               Settings_VM.Choose_Speech_Model,
               Preferences.Speech_Models'Pos (Preferences.Parakeet)),
            Download_Row,
            UI.Styled (UI.Place (Bar), Line (Progress_Height)),
            Heading ("GRAPHICS", Top => Layouts.Length_Of (Heading_Top)),
            UI.Styled (UI.Place (Switch), Line (Settings_Line)),
            Heading ("BROWSER", Top => Layouts.Length_Of (Heading_Top)),
            Name ("Site filter"),
            Filter_Radio ("Off", Site_Filters.Off),
            Filter_Radio ("Block the sites listed", Site_Filters.Use_Blocked),
            Filter_Radio ("Allow only the sites listed", Site_Filters.Use_Allowed),
            Site_Editor];

         --  The form, on a page of its own, in the middle, scrolled.
         Page  : constant UI.Layout :=
           UI.Styled
             (UI.Put_In (Form, Prefs.Settings_Form, Choices),
              (Flow     => Column,
               Shrink   => 0.0,
               Width    => Layouts.Length_Of (Page_Width),
               Padding  => (others => Dialog_Pad),
               Shadowed => On,
               Gap      => Row_Gap,
               others   => <>));
         Sheet : constant UI.Layout :=
           UI.Styled
             (UI.Put_In
                (Form,
                 Prefs.Settings_Scroll,
                 [UI.Styled
                    (UI.Put_In (Form, Prefs.Settings_Content, [Page]),
                     (Flow    => Column,
                      Shrink  => 0.0,
                      Align   => Center,
                      Padding => (others => Layouts.Length_Of (Page_Margin)),
                      others  => <>))]),
              (Grow => 1.0, Height => 0.0, others => <>));

         --  The bar, outside what scrolls, so that it stays: the way back at the left (clear of the window's
         --  own buttons), as in a project, then the title.
         Title_Bar : constant UI.Layout :=
           UI.Styled
             (UI.Put_In
                (Form,
                 Prefs.Settings_Bar,
                 [UI.Styled
                    (UI.Place (Close),
                     (Width  => Layouts.Length_Of (Back_Width),
                      Height => Layouts.Length_Of (Tab_Height),
                      Shrink => 0.0,
                      Margin => (Right => Name_Gap, others => <>),
                      others => <>)),
                  UI.Styled
                    (UI.Put (Form, Prefs.Settings_Title),
                     (Grow => 1.0, Width => 0.0, Height => Layouts.Length_Of (Tab_Height), others => <>))],
                 Flow => Layouts.Row),
              (Height  => Layouts.Length_Of (Toolbar_Size),
               Shrink  => 0.0,
               Flow    => Row,
               Align   => Center,
               Padding =>
                 (Left   => (Layouts.Length_Of (if Item.Shell.Windowed then Header_Inset else Bar_Inset)),
                  Right  => Layouts.Length_Of (Bar_Inset),
                  others => <>),
               others  => <>));

         Whole : constant UI.Layout :=
           UI.Styled
             (UI.Put_In (Form, Prefs.Settings_Panel, [Title_Bar, Sheet]), (Flow => Column, Grow => 1.0, others => <>));
      begin
         Bound.Show_When (Download_Row, Row_Flag);
         Bound.Show_When (UI.Any (Download), Download_Flag);
         Bound.Show_When (UI.Any (Bar), Bar_Flag);
         Bound.Show_When (UI.Any (Art_Bar), Gallery_Bar_Flag);
         Bound.Show_When (UI.Any (Art_Status), Gallery_Status_Flag);
         Bound.Show_When (UI.Any (Delete), Delete_Flag);
         Sites.Show_When (Site_Editor, Site_List);
         Panels.Set_Border (Prefs.Sites_Box, Themes.Border);
         Panels.Set_Radius (Prefs.Sites_Box, Themes.Small_Radius, Framed => True);
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
