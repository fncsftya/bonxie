with Goldens;
with Pomarine.Events;
with Pomarine.Testing;
with Preferences;
with Viewer;
with Viewer.Settings;

package body Settings_Tests is

   package Events renames Pomarine.Events;
   package Settings renames Viewer.Settings;
   package Testing renames Pomarine.Testing;

   use type Preferences.Background_Modes;
   use type Preferences.Speech_Models;
   use type Preferences.Theme_Choices;

   use type Pomarine.Events.Milliseconds;

   --  The session, taken events as it does and drawn when time passes.

   type Driver (App : not null access Viewer.Session) is limited new Testing.Application with record
      Clock : Events.Milliseconds := 0;
      Image : Goldens.Images.Image;
   end record;

   overriding procedure Take (Self : in out Driver; Event : Events.Event);

   overriding procedure Settle (Self : in out Driver; Milliseconds : Natural);

   overriding procedure Take (Self : in out Driver; Event : Events.Event) is
   begin
      Viewer.Handle (Self.App.all, Event);
   end Take;

   overriding procedure Settle (Self : in out Driver; Milliseconds : Natural) is
   begin
      Self.Clock := Self.Clock + Events.Milliseconds (Milliseconds);
      Viewer.Tick (Self.App.all, Self.Clock);
      Viewer.Render (Self.App.all, Self.Image);
   end Settle;

   function Image (Value : Boolean) return String is (Value'Image);

   procedure Check (Name : String; Expected, Actual : String) renames Goldens.Check_Text;

   Mode_Names : constant array (Preferences.Background_Modes) of access constant String :=
     [Preferences.Fixed       => new String'("Fixed"),
      Preferences.Watercolour => new String'("Watercolour"),
      Preferences.Paper       => new String'("Paper"),
      Preferences.Ink_Wash    => new String'("Ink wash"),
      Preferences.Mist        => new String'("Mist"),
      Preferences.Grain       => new String'("Grain"),
      Preferences.Marbling    => new String'("Marbling"),
      Preferences.Risograph   => new String'("Risograph"),
      Preferences.Contours    => new String'("Contours"),
      Preferences.Bauhaus     => new String'("Bauhaus")];

   procedure By_Name is
      Session : aliased Viewer.Session;
      Ears    : aliased Driver (Session'Access);
      Window  : Testing.Session;
   begin
      Viewer.Open (Session, "", 1000, 800);
      Testing.Attach (Window, Viewer.Widget_Tree (Session).all, Ears'Access);

      Testing.Click_On (Window, "Settings");
      Check ("settings-name-open", "TRUE", Image (Settings.Is_Settings_Open (Session)));

      --  Theme: its radio shows which is chosen, and the windows are dark or light.
      Testing.Click_On (Window, "Dark");
      Check ("settings-name-dark", "TRUE",
             Image (Settings.Theme_Choice (Session) = Preferences.Dark and then Settings.Is_Dark (Session)
                    and then Testing.Shows (Window, "radio button 'Dark' ON")
                    and then Testing.Shows (Window, "radio button 'Light' OFF")));
      Testing.Click_On (Window, "Light");
      Check ("settings-name-light", "TRUE",
             Image (Settings.Theme_Choice (Session) = Preferences.Light and then not Settings.Is_Dark (Session)
                    and then Testing.Shows (Window, "radio button 'Light' ON")
                    and then Testing.Shows (Window, "radio button 'Dark' OFF")));
      Testing.Click_On (Window, "System");
      Check ("settings-name-system", "TRUE",
             Image (Settings.Theme_Choice (Session) = Preferences.System
                    and then Testing.Shows (Window, "radio button 'System' ON")));
      Testing.Click_On (Window, "Light");

      --  The button on a painted card paints another, and chooses its style.
      declare
         Before : constant Natural := Settings.Watercolour_Seed (Session);
      begin
         Testing.Click_On (Window, "New picture");
         Check ("settings-name-reseeded", "TRUE",
                Image (Settings.Watercolour_Seed (Session) /= Before
                       and then Settings.Background_Choice (Session) = Preferences.Watercolour));
      end;

      --  Background: a card is clicked in its name, each a little further along the row, which is
      --  scrolled to keep the one chosen in view.
      for Mode in Preferences.Background_Modes loop
         Testing.Click_On (Window, Mode_Names (Mode).all);
         Check ("settings-name-" & Mode_Names (Mode).all, "TRUE",
                Image (Settings.Background_Choice (Session) = Mode));
      end loop;
      Settings.Choose_Background (Session, Preferences.Fixed);

      --  Speech: the model's file is to be fetched, if it is not there, and only for Parakeet.
      Check ("settings-name-macos-no-download", "FALSE", Image (Testing.Exists (Window, "Download")));
      Testing.Click_On (Window, "Parakeet");
      Check ("settings-name-parakeet", "TRUE",
             Image (Settings.Speech_Model (Session) = Preferences.Parakeet
                    and then Testing.Shows (Window, "radio button 'Parakeet' ON")
                    and then Testing.Shows (Window, "radio button 'MacOS' OFF")));
      Check ("settings-name-download-offered", "TRUE",
             Image (Testing.Exists (Window, "Download") and then not Testing.Is_Disabled (Window, "Download")
                    and then Testing.Shows (Window, "Model not downloaded")
                    and then not Testing.Exists (Window, "Delete")));
      Testing.Click_On (Window, "MacOS");
      Check ("settings-name-macos", "FALSE",
             Image (Settings.Speech_Model (Session) = Preferences.Parakeet
                    or else Testing.Exists (Window, "Download")));

      --  Graphics: VSync is a switch.
      Check ("settings-name-vsync-off", "FALSE", Image (Settings.VSync_Choice (Session)));
      Testing.Click_On (Window, "VSync");
      Check ("settings-name-vsync-on", "TRUE",
             Image (Settings.VSync_Choice (Session) and then Testing.Shows (Window, "switch 'VSync' ON")));
      Testing.Click_On (Window, "VSync");
      Check ("settings-name-vsync-again", "TRUE",
             Image (not Settings.VSync_Choice (Session) and then Testing.Shows (Window, "switch 'VSync' OFF")));

      --  Leaving: the way back, and Escape.
      Testing.Click_On (Window, "Projects");
      Check ("settings-name-closed", "FALSE", Image (Settings.Is_Settings_Open (Session)));
      Testing.Click_On (Window, "Settings");
      Testing.Press (Window, Events.Key_Escape);
      Check ("settings-name-escaped", "FALSE", Image (Settings.Is_Settings_Open (Session)));
   end By_Name;

end Settings_Tests;
