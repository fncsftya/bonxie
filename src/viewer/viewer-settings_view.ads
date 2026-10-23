with Ada.Strings.Unbounded;
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

   procedure Locate_AI_Model
     (Item    : Session;
      Folder  : out Ada.Strings.Unbounded.Unbounded_String;
      Problem : out Ada.Strings.Unbounded.Unbounded_String)
     with Post => (Ada.Strings.Unbounded.Length (Problem) = 0)
                  = (Ada.Strings.Unbounded.Length (Folder) > 0);
   --  Where the language model chosen is kept, to ask it for something. If
   --  it cannot be asked (none was chosen, it is not in the cache, its
   --  folder is too deep, or the binding finds it wanting) Folder is empty
   --  and Problem says why, in few words.

   procedure Enable_AI (Item : in out Session; To : Boolean)
     with Pre => Item.Prefs.Showing_Settings;
   --  Switch the language model on or off, and keep the choice.

   function Premium_Chosen (Item : Session) return Boolean;
   --  Whether the AI is on and premium, the hosted backend, does its work: it is on offer (see
   --  Premium.Available) and was chosen. No language model is used, or needed, then.

   procedure Choose_AI_Backend (Item : in out Session; To : Preferences.AI_Backends)
     with Pre => Item.Prefs.Showing_Settings;
   --  Choose what does the AI's work, as the radios of Backend do, and keep the choice.

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
