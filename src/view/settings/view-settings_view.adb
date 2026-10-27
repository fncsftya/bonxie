with Backgrounds;
with Pomarine.Themes;
with Pomarine.Widgets;
with Pomarine.Widgets.Panels;
with Pomarine.Widgets.Scrollers;
with Pomarine.Events;
with Speech.Models;
with Nav_VM;
with View.Deletion;
with View.Navigation;
with View.Style;
with Pomarine.Widgets.Layouts;

package body View.Settings_View is

   package Widgets renames Pomarine.Widgets;
   package Themes renames Pomarine.Themes;
   package Panels renames Pomarine.Widgets.Panels;
   package Scrollers renames Pomarine.Widgets.Scrollers;

   use type Speech.Models.States;
   use type Preferences.Speech_Models;
   use type Preferences.Theme_Choices;
   use type Preferences.Background_Modes;

   use type Settings_VM.Command;

   package Model_Parts renames Settings_VM.Parts;

   function Downloading (Item : Session) return Boolean is
     (Settings_VM.Is_Showing (Item.Choices.Model)
      and then Settings_VM.Download_State (Item.Choices.Model) = Speech.Models.Running);

   function Choice_Of (Mode : Preferences.Background_Modes) return Natural is
     (Preferences.Background_Modes'Pos (Mode));

   function Style_Of (Mode : Preferences.Pictures) return Backgrounds.Styles is
     (Backgrounds.Styles'Val (Preferences.Background_Modes'Pos (Mode) - 1));

   --  How much of the picture's hue the greys take: the style's, and as bold as the seed's colours.
   function Tint_Of (Item : Session; Picture : Backgrounds.Styles) return Float is
     (Backgrounds.Tint_Strength (Picture, Backgrounds.Mood (Item.Host.Background)));

   --  The cards of backgrounds: each a picture of a window drawn the way it would be, the chosen one
   --  outlined in the accent, with a shadow.
   procedure Show_Backgrounds (Item : in out Session) is
      Prefs : Settings_Parts renames Item.Prefs;
      Dark  : constant Boolean := Item.Choices.Dark_Shown;
      Picked : constant Preferences.Background_Modes := Settings_VM.Background (Item.Choices.Model);
   begin
      for Mode in Preferences.Background_Modes loop
         declare
            Card   : Background_Card renames Prefs.Cards (Mode);
            Chosen : constant Boolean := Picked = Mode;
         begin
            Panels.Set_Border (Card.Whole, (if Chosen then Themes.Accent else Themes.Border));
            Panels.Set_Shadow (Card.Whole, (if Chosen then Themes.Accent else Themes.Shadow));
            if Mode = Preferences.Fixed then
               Card.Sample.Painting := null;
               Backgrounds.Set_Look (Card.Sample, Dark, View.Style.Make (Dark));
            else
               declare
                  Picture : constant Backgrounds.Styles := Style_Of (Mode);
               begin
                  Card.Sample.Painting := Item.Host.Background'Unchecked_Access;
                  Card.Sample.Style := Picture;
                  Backgrounds.Set_Look
                    (Card.Sample, Dark,
                     View.Style.Make
                       (Dark, Backgrounds.Hue (Item.Host.Background, Picture), Tint_Of (Item, Picture)));
               end;
            end if;
         end;
      end loop;
      Widgets.Invalidate (Prefs.Background_Row);
   end Show_Backgrounds;

   --  Scroll the row of cards, if need be, to show the chosen one whole.
   procedure Reveal_Background (Item : in out Session) is
      Prefs : Settings_Parts renames Item.Prefs;
      Pitch : constant Float := View.Style.Background_Card_Width + View.Style.Gap;
      Left  : constant Float :=
        Float (Choice_Of (Settings_VM.Background (Item.Choices.Model))) * Pitch;
      Room  : constant Float := Widgets.Width_Of (Prefs.Background_Scroll) / Widgets.Density (Prefs.Background_Scroll);
      Moved : constant Float := Scrollers.Offset (Prefs.Background_Scroll);
   begin
      if Widgets.Is_Attached (Prefs.Background_Scroll) and then Room > 0.0
        and then (Left < Moved or else Left + View.Style.Background_Card_Width > Moved + Room)
      then
         Scrollers.Scroll_To (Prefs.Background_Scroll, Float'Max (0.0, Left - View.Style.Gap));
      end if;
   end Reveal_Background;

   --  What the view-model says, in the widgets: the form's controls are the view's, which shows it; the
   --  cards are the application's.
   procedure Draw (Item : in out Session) is
   begin
      Show_Backgrounds (Item);
      Item.Choices.Download_Seen := Settings_VM.Download_State (Item.Choices.Model);
      Sync_Screen (Item, Settings_Region);
      --  The buttons the commands are on are turned on and off as the view-model says.
      Widgets.Revalidate (Item.Root.Widgets);
   end Draw;

   procedure Refresh (Item : in out Session) is
   begin
      Model_Parts.See (Item.Choices.Seen, Settings_VM.Version (Item.Choices.Model));
      Draw (Item);
   end Refresh;

   function Showing (Item : Session) return Boolean is (Settings_VM.Is_Showing (Item.Choices.Model));

   procedure Show_Form (Item : in out Session) is
   begin
      Widgets.Clear_Focus (Item.Root.Widgets);
      Widgets.Set_Visible (Home_Panel (Item).all, False);
      Widgets.Set_Visible (Item.Prefs.Settings_Panel, True);
      Refresh (Item);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      Reveal_Background (Item);
   end Show_Form;

   procedure Hide_Form (Item : in out Session) is
   begin
      Widgets.Clear_Focus (Item.Root.Widgets);
      Widgets.Set_Visible (Item.Prefs.Settings_Panel, False);
      Widgets.Set_Visible (Home_Panel (Item).all, True);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Hide_Form;

   procedure Open (Item : in out Session) is
   begin
      Navigation.Do_Command (Item, Nav_VM.Open_Settings);
   end Open;

   procedure Close (Item : in out Session) is
   begin
      Navigation.Do_Command (Item, Nav_VM.Close_Settings);
   end Close;

   --  The view-model does what is chosen and, as Settings_VM.Effects, says Done: what the world does is there.

   procedure Choose
     (Item : in out Session; To : Preferences.Speech_Models) is
   begin
      Settings_VM.Execute
        (Item.Choices.Model, Settings_VM.Choose_Speech_Model, Preferences.Speech_Models'Pos (To));
   end Choose;

   procedure Choose_Appearance
     (Item : in out Session; To : Preferences.Theme_Choices) is
   begin
      Settings_VM.Execute (Item.Choices.Model, Settings_VM.Choose_Theme, Preferences.Theme_Choices'Pos (To));
   end Choose_Appearance;

   procedure Choose_VSync (Item : in out Session; To : Boolean) is
   begin
      if Settings_VM.VSync (Item.Choices.Model) /= To then
         Settings_VM.Execute (Item.Choices.Model, Settings_VM.Toggle_VSync);
      end if;
   end Choose_VSync;

   procedure Choose_Background
     (Item : in out Session; To : Preferences.Background_Modes) is
   begin
      Settings_VM.Execute (Item.Choices.Model, Settings_VM.Choose_Background, Choice_Of (To));
   end Choose_Background;

   function New_Picture_Seed (Item : in out Session) return Natural is
   begin
      Backgrounds.Reseed (Item.Host.Background);
      return Backgrounds.Seed_Number (Item.Host.Background);
   end New_Picture_Seed;

   procedure Apply_Theme (Item : in out Session) is
      Dark : constant Boolean :=
        (case Settings_VM.Theme (Item.Choices.Model) is
            when Preferences.Light  => False,
            when Preferences.Dark   => True,
            when Preferences.System => Pomarine.Events.System_Is_Dark);
      Mode : constant Preferences.Background_Modes := Settings_VM.Background (Item.Choices.Model);
      --  Only a window has a painting to go with; offscreen, it is the theme's own colours.
      Adaptive : constant Boolean :=
        Mode in Preferences.Pictures and then Item.Shell.Windowed
        and then Backgrounds.Available (Item.Host.Background, Style_Of (Mode));
   begin
      if Adaptive then
         declare
            Picture : constant Backgrounds.Styles := Style_Of (Mode);
         begin
            View.Style.Use_Adaptive
              (Dark, Backgrounds.Hue (Item.Host.Background, Picture), Tint_Of (Item, Picture));
            Item.Root.Window_Panel.Style := Picture;
         end;
         Item.Root.Window_Panel.Painting := Item.Host.Background'Unchecked_Access;
      else
         View.Style.Use_Dark (Dark);
         Item.Root.Window_Panel.Painting := null;
      end if;
      Item.Canvas_View.Transparent := Adaptive;
      if Dark /= Item.Choices.Dark_Shown or else Adaptive /= Item.Choices.Adaptive_Shown
        or else Mode /= Item.Choices.Mode_Shown
      then
         Item.Choices.Dark_Shown := Dark;
         Item.Choices.Adaptive_Shown := Adaptive;
         Item.Choices.Mode_Shown := Mode;
         Widgets.Invalidate_All (Item.Root.Widgets);
         if Showing (Item) then
            Refresh (Item);
         end if;
      end if;
   end Apply_Theme;

   procedure Download (Item : in out Session) is
   begin
      if Settings_VM.Can_Execute (Item.Choices.Model, Settings_VM.Download_Model) then
         Settings_VM.Execute (Item.Choices.Model, Settings_VM.Download_Model);
      end if;
   end Download;

   procedure Ask_To_Delete (Item : in out Session) is
   begin
      if Settings_VM.Can_Execute (Item.Choices.Model, Settings_VM.Confirm_Delete) then
         Settings_VM.Execute (Item.Choices.Model, Settings_VM.Confirm_Delete);
      end if;
   end Ask_To_Delete;

   procedure Done (Item : in out Session; What : Settings_VM.Command) is
   begin
      case What is
         when Settings_VM.Choose_Theme =>
            Apply_Theme (Item);
            if Showing (Item) then
               Refresh (Item);
            end if;
         when Settings_VM.Choose_Background =>
            Apply_Theme (Item);
            if Showing (Item) then
               Refresh (Item);
               Reveal_Background (Item);
            end if;
         when Settings_VM.Choose_Speech_Model | Settings_VM.Download_Model | Settings_VM.Delete_Model =>
            if Showing (Item) then
               Refresh (Item);
               Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
            end if;
         when Settings_VM.Toggle_VSync =>
            if Item.Shell.Windowed then
               SDL3.Windows.Renderers.Set_VSync (Item.Host.Target, Settings_VM.VSync (Item.Choices.Model));
            end if;
            if Showing (Item) then
               Refresh (Item);
            end if;
         when Settings_VM.Reseed | Settings_VM.New_Picture =>
            Apply_Theme (Item);
            Widgets.Invalidate_All (Item.Root.Widgets);
            if Showing (Item) then
               Refresh (Item);
               if What = Settings_VM.New_Picture then
                  Reveal_Background (Item);
               end if;
            end if;
         when others =>
            null;
      end case;
   end Done;

   procedure Confirm_Delete (Item : in out Session; Size : String) is
   begin
      Deletion.Confirm_Model
        (Item, "Its " & Size & " of files go; they can be downloaded again.");
   end Confirm_Delete;

   procedure Delete_Files (Item : in out Session) is
   begin
      if Settings_VM.Can_Execute (Item.Choices.Model, Settings_VM.Delete_Model) then
         Settings_VM.Execute (Item.Choices.Model, Settings_VM.Delete_Model);
      end if;
   end Delete_Files;

   procedure Update (Item : in out Session) is
      Was : constant Speech.Models.States := Item.Choices.Download_Seen;
   begin
      Settings_VM.Poll (Item.Choices.Model);
      if Model_Parts.Changed (Item.Choices.Seen, Settings_VM.Version (Item.Choices.Model)) then
         Draw (Item);
         if Settings_VM.Download_State (Item.Choices.Model) /= Was then
            --  It has ended, or begun: the button and the bar change.
            Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
         end if;
      end if;
   end Update;

   procedure Fit (Item : in out Session) is
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Room   : constant Float :=
        Widgets.Width_Of (Item.Prefs.Settings_Content) / Pixels
        - 2.0 * Style.Page_Margin;
      Wide   : constant Float :=
        Float'Max (Style.Page_Min_Width, Float'Min (Style.Page_Width, Room));
   begin
      if Wide /= Item.Prefs.Form_Wide then
         Item.Prefs.Form_Wide := Wide;
         Pomarine.Widgets.Layouts.Set_Layout (Item.Prefs.Settings_Form,
                                              Width => Pomarine.Widgets.Layouts.Length_Of (Wide));
      end if;
   end Fit;

end View.Settings_View;
