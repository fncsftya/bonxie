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

   procedure Apply_Theme (Item : in out Session);
   --  Draw in the theme the choice makes now: the system's, for System,
   --  which may have changed. Whatever is drawn is drawn again if the
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

   procedure Enable_AI (Item : in out Session; To : Boolean)
     with Pre => Item.Prefs.Showing_Settings;
   --  Switch the language model on or off, and keep the choice.

   procedure Toggle_AI_Menu (Item : in out Session)
     with Pre => Item.Prefs.Showing_Settings;
   --  Show the menu of the models in the Hugging Face cache under the
   --  Model field, or put it away if it is shown.

   procedure Choose_AI_Model (Item : in out Session; Row : Natural)
     with Pre => Item.Prefs.Showing_Settings;
   --  A row of that menu was chosen (the first is None Selected, the rest
   --  the models, in order): keep the choice, and put the menu away.

   procedure Test_AI (Item : in out Session)
     with Pre => Item.Prefs.Showing_Settings;
   --  Run the test prompt through the model chosen, in the background.

   function AI_Menu_Open (Item : Session) return Boolean;
   --  Whether the menu of models is shown.

   procedure Close_AI_Menu (Item : in out Session)
     with Post => not AI_Menu_Open (Item);

   procedure Pressed (Item : in out Session; X, Y : Float)
     with Pre => Item.Prefs.Showing_Settings;
   --  The pointer was pressed at X, Y, in points of the window: put the
   --  menu of models away if that was outside it (and its field, whose
   --  click does that).

   function Downloading (Item : Session) return Boolean;
   --  Whether the form needs to be looked at again soon, for the
   --  download's progress, or for the language model's test to end.

   procedure Refresh (Item : in out Session);
   --  Show the choice, and whether the file for it is there.

end Viewer.Settings_View;
