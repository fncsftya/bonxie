with Goldens;
with Pomarine.Events;
with Pomarine.Semantics;
with Pomarine.Testing;
with Preferences;
with View;
with View_Driver;
with View.Settings;

package body Settings_Tests is

   package Events renames Pomarine.Events;
   package Images renames Goldens.Images;
   package Settings renames View.Settings;
   package Testing renames Pomarine.Testing;

   use type Preferences.Background_Modes;
   use type Preferences.Speech_Models;
   use type Preferences.Theme_Choices;

   function Image (Value : Boolean) return String
   is (Value'Image);

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
      Session : aliased View.Session;
      Ears    : aliased View_Driver.Driver (Session'Access);
      Window  : Testing.Session;
   begin
      View.Open (Session, "", 1000, 800);
      Testing.Attach (Window, View.Widget_Tree (Session).all, Ears'Access);

      Testing.Click_On (Window, "Settings");
      Check ("settings-name-open", "TRUE", Image (Settings.Is_Settings_Open (Session)));

      --  Theme: its radio shows which is chosen, and the windows are dark or light.
      Testing.Click_On (Window, "Dark");
      Check
        ("settings-name-dark",
         "TRUE",
         Image
           (Settings.Theme_Choice (Session) = Preferences.Dark
            and then Settings.Is_Dark (Session)
            and then Testing.Shows (Window, "radio button 'Dark' ON")
            and then Testing.Shows (Window, "radio button 'Light' OFF")));
      Testing.Click_On (Window, "Light");
      Check
        ("settings-name-light",
         "TRUE",
         Image
           (Settings.Theme_Choice (Session) = Preferences.Light
            and then not Settings.Is_Dark (Session)
            and then Testing.Shows (Window, "radio button 'Light' ON")
            and then Testing.Shows (Window, "radio button 'Dark' OFF")));
      Testing.Click_On (Window, "System");
      Check
        ("settings-name-system",
         "TRUE",
         Image
           (Settings.Theme_Choice (Session) = Preferences.System
            and then Testing.Shows (Window, "radio button 'System' ON")));
      Testing.Click_On (Window, "Light");

      --  Both the picture and its name choose a style. Reseeding another card chooses that style too.
      Testing.Click_On (Window, "Choose Fixed background");
      Check ("settings-name-picture-choice", "TRUE", Image (Settings.Background_Choice (Session) = Preferences.Fixed));
      --  The button on a painted card paints another, and chooses its style.
      declare
         Before : constant Natural := Settings.Watercolour_Seed (Session);
      begin
         Testing.Click_On (Window, "New picture");
         Check
           ("settings-name-reseeded",
            "TRUE",
            Image
              (Settings.Watercolour_Seed (Session) /= Before
               and then Settings.Background_Choice (Session) = Preferences.Watercolour));
      end;

      --  Background: a card is clicked in its name, each a little further along the row, which is
      --  scrolled to keep the one chosen in view.
      for Mode in Preferences.Background_Modes loop
         Testing.Click_On (Window, Mode_Names (Mode).all);
         Check ("settings-name-" & Mode_Names (Mode).all, "TRUE", Image (Settings.Background_Choice (Session) = Mode));
      end loop;
      Settings.Choose_Background (Session, Preferences.Fixed);

      --  Speech: the model's file is to be fetched, if it is not there, and only for Parakeet.
      Check ("settings-name-macos-no-download", "FALSE", Image (Testing.Exists (Window, "Download")));
      Testing.Click_On (Window, "Parakeet");
      Check
        ("settings-name-parakeet",
         "TRUE",
         Image
           (Settings.Speech_Model (Session) = Preferences.Parakeet
            and then Testing.Shows (Window, "radio button 'Parakeet' ON")
            and then Testing.Shows (Window, "radio button 'MacOS' OFF")));
      Check
        ("settings-name-download-offered",
         "TRUE",
         Image
           (Testing.Exists (Window, "Download")
            and then not Testing.Is_Disabled (Window, "Download")
            and then Testing.Shows (Window, "Model not downloaded")
            and then not Testing.Exists (Window, "Delete")));
      Testing.Click_On (Window, "MacOS");
      Check
        ("settings-name-macos",
         "FALSE",
         Image (Settings.Speech_Model (Session) = Preferences.Parakeet or else Testing.Exists (Window, "Download")));

      --  Graphics: VSync is a switch.
      Check ("settings-name-vsync-off", "FALSE", Image (Settings.VSync_Choice (Session)));
      Testing.Click_On (Window, "VSync");
      Check
        ("settings-name-vsync-on",
         "TRUE",
         Image (Settings.VSync_Choice (Session) and then Testing.Shows (Window, "switch 'VSync' ON")));
      Testing.Click_On (Window, "VSync");
      Check
        ("settings-name-vsync-again",
         "TRUE",
         Image (not Settings.VSync_Choice (Session) and then Testing.Shows (Window, "switch 'VSync' OFF")));

      --  Leaving: the way back, and Escape.
      Testing.Click_On (Window, "Projects");
      Check ("settings-name-closed", "FALSE", Image (Settings.Is_Settings_Open (Session)));
      Testing.Click_On (Window, "Settings");
      declare
         Before : constant Natural := Settings.Watercolour_Seed (Session);
      begin
         Testing.Click_On (Window, "New picture");
         Check
           ("settings-name-reopened-reseed",
            "TRUE",
            Image
              (Settings.Watercolour_Seed (Session) /= Before
               and then Settings.Background_Choice (Session) = Preferences.Watercolour));
      end;
      Testing.Press (Window, Events.Key_Escape);
      Check ("settings-name-escaped", "FALSE", Image (Settings.Is_Settings_Open (Session)));
   end By_Name;

   procedure Browser_Filter is
      Session : aliased View.Session;
      Ears    : aliased View_Driver.Driver (Session'Access);
      Window  : Testing.Session;
      Drawn   : Images.Image;

      procedure Type_Site (Text : String) is
      begin
         Testing.Click_On (Window, "Site", Pomarine.Semantics.Text_Input);
         Testing.Press (Window, Events.Key_A, Command => True);
         Testing.Type_Text (Window, Text);
      end Type_Site;
   begin
      --  Tall enough that the whole of the form shows.
      View.Open (Session, "", 1000, 2000);
      Testing.Attach (Window, View.Widget_Tree (Session).all, Ears'Access);
      Testing.Click_On (Window, "Settings");

      Check
        ("settings-browser-off",
         "TRUE FALSE",
         Image (Testing.Shows (Window, "radio button 'Off' ON")) & " " & Image (Testing.Exists (Window, "Add")));

      Testing.Click_On (Window, "Block the sites listed");
      Check
        ("settings-browser-blocking",
         "TRUE TRUE TRUE",
         Image
           (Testing.Shows (Window, "radio button 'Block the sites listed' ON")
            and then Testing.Exists (Window, "Site")
            and then Testing.Exists (Window, "Sites"))
         & " "
         & Image (Testing.Is_Disabled (Window, "Add"))
         & " "
         & Image (Testing.Is_Disabled (Window, "Remove")));

      --  An address is cut down to its base.
      Type_Site ("Example.com/some/page?x=1");
      Check ("settings-browser-can-add", "FALSE", Image (Testing.Is_Disabled (Window, "Add")));
      Testing.Click_On (Window, "Add");
      Type_Site ("https://news.example.org");
      Testing.Click_On (Window, "Add");
      Check
        ("settings-browser-added",
         "TRUE TRUE",
         Image (Testing.Shows (Window, "https://example.com"))
         & " "
         & Image (Testing.Shows (Window, "https://news.example.org")));

      Type_Site ("two words");
      Check
        ("settings-browser-refused",
         "TRUE TRUE",
         Image (Testing.Shows (Window, "That is not a web address."))
         & " "
         & Image (Testing.Is_Disabled (Window, "Add")));
      Testing.Press (Window, Events.Key_A, Command => True);
      Testing.Press (Window, Events.Key_Backspace);

      --  The other mode has a list of its own.
      Testing.Click_On (Window, "Allow only the sites listed");
      Check
        ("settings-browser-allowing",
         "TRUE FALSE",
         Image (Testing.Shows (Window, "radio button 'Allow only the sites listed' ON"))
         & " "
         & Image (Testing.Shows (Window, "https://example.com")));
      Testing.Click_On (Window, "Block the sites listed");

      --  Choose one, change it, remove it.
      Testing.Click_On (Window, "https://news.example.org");
      Check
        ("settings-browser-chosen",
         "https://news.example.org",
         Testing.Value_Of (Window, "Site", Pomarine.Semantics.Text_Input));
      Type_Site ("blog.example.org");
      Testing.Click_On (Window, "Change");
      Check
        ("settings-browser-changed",
         "TRUE FALSE",
         Image (Testing.Shows (Window, "https://blog.example.org"))
         & " "
         & Image (Testing.Shows (Window, "https://news.example.org")));
      Testing.Click_On (Window, "Remove");
      Check ("settings-browser-removed", "FALSE", Image (Testing.Shows (Window, "https://blog.example.org")));
      Type_Site ("blog.example.org");
      Testing.Click_On (Window, "Add");

      View.Render (Session, Drawn);
      Goldens.Check ("settings-browser", Drawn);
   end Browser_Filter;

end Settings_Tests;
