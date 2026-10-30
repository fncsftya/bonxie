with Backgrounds;
with Gallery_Pictures;
with Preferences;
with Pomarine.View_Models;
with Pomarine.Widgets;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Grips;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Panels;
with Pomarine.Widgets.Scrollers;
with Settings_VM;
with Settings_VM.Disk;
with Site_Filter_VM;
with Speech.Models;

--  The settings: their widgets, and the view-model they show with what ties them.

package View_Parts.Settings is

   type Gallery_Files is limited new Settings_VM.Gallery_Source with record
      Pictures : Gallery_Pictures.Source;
   end record;
   overriding
   function Gallery_State_Of (Self : Gallery_Files) return Settings_VM.Gallery_States;
   overriding
   function Gallery_Fraction_Of (Self : Gallery_Files) return Float;
   overriding
   function Gallery_Message_Of (Self : Gallery_Files) return String;
   overriding
   function Gallery_Present (Self : Gallery_Files) return Boolean;
   overriding
   procedure Start_Gallery (Self : in out Gallery_Files);
   overriding
   procedure Poll_Gallery (Self : in out Gallery_Files);

   type Background_Card is limited record
      Whole  : Pomarine.Widgets.Panels.Panel;
      Peek   : Pomarine.Widgets.Grips.Grip;
      --  The picture, clicked to choose it.
      Sample : Backgrounds.Sample;
      Foot   : Pomarine.Widgets.Panels.Panel;
      Pick   : Pomarine.Widgets.Grips.Grip;
      --  The name, which is clicked too, and the button to paint another picture, which a plain
      --  background has not.
      Name   : Pomarine.Widgets.Labels.Label;
      Reseed : Pomarine.Widgets.Buttons.Button;
   end record;
   --  A choice of background.

   type Background_Card_Array is array (Preferences.Background_Modes) of Background_Card;

   type Settings_Parts is limited record
      Settings_Panel    : Pomarine.Widgets.Panels.Panel;
      --  A column, in the home screen's place while the settings are shown: a
      --  bar across the top, which stays, and below it the form, scrolled.
      Settings_Bar      : Pomarine.Widgets.Panels.Panel;
      Settings_Title    : Pomarine.Widgets.Labels.Label;
      Settings_Scroll   : Pomarine.Widgets.Scrollers.Scroller;
      Settings_Content  : Pomarine.Widgets.Panels.Panel;
      --  Centres the form, which is as wide as a page in the writing view.
      Settings_Form     : Pomarine.Widgets.Panels.Panel;
      Form_Wide         : Float := 0.0;
      --  Its width, in points, as last set (see Settings_View.Fit).
      Sites_Box         : Pomarine.Widgets.Panels.Panel;
      --  The browser filter's list of sites, in a border.
      Background_Scroll : Pomarine.Widgets.Scrollers.Scroller;
      Background_Row    : Pomarine.Widgets.Panels.Panel;
      Cards             : Background_Card_Array;
      --  Display's Background: a row of cards, scrolled across, each a small picture of a window drawn on
      --  it, with its name below. The rest of the form (the choices of theme and speech model, the
      --  download, VSync) is the view's controls, bound to the view-model (see View.Build.Settings_Form).
   end record;
   --  The widgets of the settings. What is chosen in them is Settings_Choices'.

   type Settings_Choices is limited record
      Model              : aliased Settings_VM.View_Model;
      --  What the settings mean: the choices, the download, when each command can be done.
      Files              : aliased Settings_VM.Disk.File_Store;
      Voice              : aliased Settings_VM.Disk.Speech_Files;
      Gallery            : aliased Gallery_Files;
      Gallery_Seen       : Natural := 0;
      Gallery_State_Seen : Settings_VM.Gallery_States := Settings_VM.Idle;
      --  Where the choices are kept, and the speech model's files.
      Filter             : aliased Site_Filter_VM.Model;
      --  The browser's site filter: how it is set, the sites, and what is typed to add one.
      Seen               : Pomarine.View_Models.Watch;
      --  The model's version as the widgets last showed it.
      Filter_Seen        : Pomarine.View_Models.Watch;
      --  The filter's, as the browser's web view was last told it.
      Download_Seen      : Speech.Models.States := Speech.Models.Idle;
      --  How the download was when the form last showed it.
      Dark_Shown         : Boolean := False;
      --  Whether the windows are drawn in the dark theme, as last applied.
      Adaptive_Shown     : Boolean := False;
      Mode_Shown         : Preferences.Background_Modes := Preferences.Fixed;
      --  Whether the windows are drawn in colours that go with a painted background, as last applied:
      --  what is chosen, if there is a painting to go with.
   end record;
   --  The view-model of the settings, and what the view has applied of it to the world.

end View_Parts.Settings;
