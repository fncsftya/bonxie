with Backgrounds;
with Preferences;
with Pomarine.View_Models;
with Pomarine.Widgets;
with Pomarine.Widgets.Bindings.For_Commands;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Checks;
with Pomarine.Widgets.Grips;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Panels;
with Pomarine.Widgets.Progress_Bars;
with Pomarine.Widgets.Scrollers;
with Pomarine.Widgets.Switches;
with Settings_VM;
with Settings_VM.Disk;
with Speech.Models;

--  The settings: their widgets, and the view-model they show with what ties them.
package View_Parts.Settings is

   Settings_Tag_Base : constant := 100;
   --  The tag of the settings' first command: the window's own are below it (see View.Command).

   package Binding is new Pomarine.Widgets.Bindings.For_Commands (Settings_VM.Commands, Settings_Tag_Base);

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
      Settings_Panel : Pomarine.Widgets.Panels.Panel;
      --  A column, in the home screen's place while the settings are shown: a
      --  bar across the top, which stays, and below it the form, scrolled.
      Settings_Bar   : Pomarine.Widgets.Panels.Panel;
      Settings_Title : Pomarine.Widgets.Labels.Label;
      Settings_Close : Pomarine.Widgets.Buttons.Button;
      Settings_Scroll  : Pomarine.Widgets.Scrollers.Scroller;
      Settings_Content : Pomarine.Widgets.Panels.Panel;
      --  Centres the form, which is as wide as a page in the writing view.
      Settings_Form  : Pomarine.Widgets.Panels.Panel;
      Form_Wide      : Float := 0.0;
      --  Its width, in points, as last set (see Settings_View.Fit).
      Speech_Heading : Pomarine.Widgets.Labels.Label;
      Model_Name     : Pomarine.Widgets.Labels.Label;
      Model_Native   : Pomarine.Widgets.Checks.Check;
      Model_Parakeet : Pomarine.Widgets.Checks.Check;
      --  Speech's one option, Model: a radio for each.
      Display_Heading : Pomarine.Widgets.Labels.Label;
      Theme_Name     : Pomarine.Widgets.Labels.Label;
      Theme_Light    : Pomarine.Widgets.Checks.Check;
      Theme_Dark     : Pomarine.Widgets.Checks.Check;
      Theme_System   : Pomarine.Widgets.Checks.Check;
      Background_Name : Pomarine.Widgets.Labels.Label;
      --  Display's options, Theme and Background: a radio for each theme, and for the background
      --  a row of cards, scrolled across, each a small picture of a window drawn on it, with its name
      --  below.
      Background_Scroll : Pomarine.Widgets.Scrollers.Scroller;
      Background_Row : Pomarine.Widgets.Panels.Panel;
      Cards          : Background_Card_Array;
      Download_Row   : Pomarine.Widgets.Panels.Panel;
      Download_Button : Pomarine.Widgets.Buttons.Button;
      Delete_Button  : Pomarine.Widgets.Buttons.Button;
      Download_State : Pomarine.Widgets.Labels.Label;
      Download_Bar   : Pomarine.Widgets.Progress_Bars.Progress_Bar;
      --  Under the radios, with Parakeet chosen: the button to fetch its
      --  file, shown while it is not there, or else the button to delete
      --  it; what is the matter with it, or how big it is, or, while it
      --  comes, how far.
      Graphics_Heading : Pomarine.Widgets.Labels.Label;
      VSync_Switch   : Pomarine.Widgets.Switches.Switch;
      --  Graphics' one option, VSync.
   end record;
   --  The widgets of the settings. What is chosen in them is Settings_Choices'.

   type Settings_Choices is limited record
      Model  : aliased Settings_VM.View_Model;
      --  What the settings mean: the choices, the download, when each command can be done.
      Files  : aliased Settings_VM.Disk.File_Store;
      Voice  : aliased Settings_VM.Disk.Speech_Files;
      --  Where the choices are kept, and the speech model's files.
      Judge  : aliased Binding.Judge;
      --  What the tree asks about the commands of the widgets.
      Seen   : Pomarine.View_Models.Watch;
      --  The model's version as the widgets last showed it.
      Download_Seen : Speech.Models.States := Speech.Models.Idle;
      --  How the download was when the form last showed it.
      Dark_Shown     : Boolean := False;
      --  Whether the windows are drawn in the dark theme, as last applied.
      Adaptive_Shown : Boolean := False;
      Mode_Shown     : Preferences.Background_Modes := Preferences.Fixed;
      --  Whether the windows are drawn in colours that go with a painted background, as last applied:
      --  what is chosen, if there is a painting to go with.
   end record;
   --  The view-model of the settings, and what the view has applied of it to the world.

end View_Parts.Settings;
