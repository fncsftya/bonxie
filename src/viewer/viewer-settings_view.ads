with Preferences;
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

   procedure Choose_VSync (Item : in out Session; To : Boolean)
     with Post => Item.Prefs.VSync_Chosen = To;
   --  Choose whether presenting waits for the display, and keep the choice. It applies now,
   --  in a window.

   procedure Choose_Background
     (Item : in out Session; To : Preferences.Background_Modes)
     with Post => Preferences."=" (Item.Prefs.Background_Chosen, To);
   --  Choose whether the windows have a painted background, with colours that go with it
   --  (Watercolour), or the theme's own on a plain one (Fixed), and keep the choice. It is
   --  drawn so now (see Apply_Theme).

   procedure Reseed (Item : in out Session);
   --  Paint another watercolour, and keep which it is. It is drawn so now if it is the background.

   procedure Apply_Theme (Item : in out Session);
   --  Draw in the theme the choices make now: the system's, for System,
   --  which may have changed; with the painted background, if Watercolour is
   --  chosen and there is one. Whatever is drawn is drawn again if the
   --  theme has changed.

   procedure Download (Item : in out Session)
     with Pre => Item.Prefs.Showing_Settings;
   --  Fetch the speech model's files, if they are not there.

   procedure Ask_To_Delete (Item : in out Session)
     with Pre => Item.Prefs.Showing_Settings;
   --  Ask before the speech model's files are deleted, if they are there.

   procedure Delete_Files (Item : in out Session);
   --  The answer to that: delete them.
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
