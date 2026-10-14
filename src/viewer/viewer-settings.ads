with Preferences;

--  The settings, shown in place of the home screen, and what they choose.
package Viewer.Settings is

   function Is_Settings_Open (Item : Session) return Boolean
     with Pre => Is_Open (Item);
   --  Whether the settings are shown, in place of the home screen.

   procedure Open_Settings (Item : in out Session)
     with Pre  => Is_Open (Item) and then Screen (Item) = Home
                  and then not Is_Settings_Open (Item),
          Post => Is_Settings_Open (Item);
   --  Show the settings, as the Settings button does.

   procedure Close_Settings (Item : in out Session)
     with Pre  => Is_Open (Item) and then Is_Settings_Open (Item),
          Post => not Is_Settings_Open (Item);
   --  Go back to the home screen, as the settings' Close button does.

   function Speech_Model (Item : Session) return Preferences.Speech_Models
     with Pre => Is_Open (Item);
   --  What is chosen to turn speech into text.

   procedure Choose_Speech_Model
     (Item : in out Session; To : Preferences.Speech_Models)
     with Pre  => Is_Open (Item) and then Is_Settings_Open (Item),
          Post => Preferences."=" (Speech_Model (Item), To);
   --  Choose it, as its radio does.

   function Theme_Choice (Item : Session) return Preferences.Theme_Choices
     with Pre => Is_Open (Item);
   --  What is chosen for the appearance of the windows.

   procedure Choose_Theme
     (Item : in out Session; To : Preferences.Theme_Choices)
     with Pre  => Is_Open (Item),
          Post => Preferences."=" (Theme_Choice (Item), To);
   --  Choose it, as its radio does.

   function Is_Dark (Item : Session) return Boolean
     with Pre => Is_Open (Item);
   --  Whether the windows are drawn in the dark theme now: as the choice
   --  says, or, for System, as the system's appearance is.

end Viewer.Settings;
