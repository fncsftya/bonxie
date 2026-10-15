--  The settings, shown in the home screen's place.
private package Viewer.Settings_View is

   procedure Open (Item : in out Session)
     with Pre  => Item.Nav.Shown = Home
      and then not Item.Prefs.Showing_Settings,
          Post => Item.Prefs.Showing_Settings;
   --  Show the form.

   procedure Close (Item : in out Session)
     with Pre  => Item.Prefs.Showing_Settings,
          Post => not Item.Prefs.Showing_Settings;
   --  Show the home screen again.

   procedure Choose
     (Item : in out Session; To : Preferences.Speech_Models)
     with Post => Preferences."=" (Item.Prefs.Speech_Choice, To);
   --  Choose what turns speech into text, and keep the choice.

   procedure Choose_Appearance
     (Item : in out Session; To : Preferences.Theme_Choices)
     with Post => Preferences."=" (Item.Prefs.Theme_Chosen, To);
   --  Choose the appearance of the windows, and keep the choice. The
   --  windows are drawn in it now (see Apply_Theme).

   procedure Apply_Theme (Item : in out Session);
   --  Draw in the theme the choice makes now: the system's, for System,
   --  which may have changed. Whatever is drawn is drawn again if the
   --  theme has changed.

   procedure Respond (Item : in out Session; What : Command)
     with Pre => Item.Prefs.Showing_Settings;
   --  Act on what has been clicked in the form, or in the dialog that asks
   --  before the speech model's files are deleted.

   procedure Update (Item : in out Session)
     with Pre => Item.Prefs.Showing_Settings;
   --  Show how far the download is.

   procedure Fit (Item : in out Session)
     with Pre => Item.Prefs.Showing_Settings;
   --  Make the form as wide as a page, or as the window leaves room for.

   function Downloading (Item : Session) return Boolean;
   --  Whether the form needs to be looked at again soon, for the
   --  download's progress.

   procedure Refresh (Item : in out Session);
   --  Show the choice, and whether the file for it is there.

end Viewer.Settings_View;
