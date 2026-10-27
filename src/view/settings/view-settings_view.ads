with Preferences;
with Settings_VM;

--  The settings, shown in the home screen's place: the widgets of the form set from
--  Settings_VM, what the person does there asked of it, and what it comes to
--  applied to the window and the colours it is drawn in.

private package View.Settings_View is

   procedure Open (Item : in out Session)
   with
     Pre  => Screen (Item) = Home and then not Settings_VM.Is_Showing (Item.Choices.Model),
     Post => Settings_VM.Is_Showing (Item.Choices.Model);
   --  Show the form.

   procedure Close (Item : in out Session)
   with Pre => Settings_VM.Is_Showing (Item.Choices.Model), Post => not Settings_VM.Is_Showing (Item.Choices.Model);
   --  Show the home screen again.

   procedure Show_Form (Item : in out Session);
   --  The form in the home screen's place: the reaction to Nav_VM putting the settings up (see View.Navigation).

   procedure Hide_Form (Item : in out Session);
   --  The home screen in its place.

   procedure Choose (Item : in out Session; To : Preferences.Speech_Models)
   with Post => Preferences."=" (Settings_VM.Speech_Model (Item.Choices.Model), To);
   --  Choose what turns speech into text, and keep the choice.

   procedure Choose_Appearance (Item : in out Session; To : Preferences.Theme_Choices)
   with Post => Preferences."=" (Settings_VM.Theme (Item.Choices.Model), To);
   --  Choose the appearance of the windows, and keep the choice. The
   --  windows are drawn in it now (see Apply_Theme).

   procedure Choose_VSync (Item : in out Session; To : Boolean)
   with Post => Settings_VM.VSync (Item.Choices.Model) = To;
   --  Choose whether presenting waits for the display, and keep the choice. It applies now,
   --  in a window.

   procedure Choose_Background (Item : in out Session; To : Preferences.Background_Modes)
   with Post => Preferences."=" (Settings_VM.Background (Item.Choices.Model), To);
   --  Choose whether the windows have a painted background, with colours that go with it
   --  (Watercolour), or the theme's own on a plain one (Fixed), and keep the choice. It is
   --  drawn so now (see Apply_Theme).

   function New_Picture_Seed (Item : in out Session) return Natural;
   --  Generate a seed for a new picture. Settings_VM owns choosing its style and keeping the seed.

   procedure Done (Item : in out Session; What : Settings_VM.Command);
   --  What the world does after the view-model has done What, as a click in the form made it do: draw in the
   --  theme, set the display's VSync, show the download's controls (see Settings_VM.Effects).

   procedure Confirm_Delete (Item : in out Session; Size : String);
   --  Ask before the speech model's files, which take Size, are deleted.

   procedure Apply_Theme (Item : in out Session);
   --  Draw in the theme the choices make now: the system's, for System,
   --  which may have changed; with the painted background, if Watercolour is
   --  chosen and there is one. Whatever is drawn is drawn again if the
   --  theme has changed.

   procedure Download (Item : in out Session)
   with Pre => Settings_VM.Is_Showing (Item.Choices.Model);
   --  Fetch the speech model's files, if they are not there.

   procedure Ask_To_Delete (Item : in out Session)
   with Pre => Settings_VM.Is_Showing (Item.Choices.Model);
   --  Ask before the speech model's files are deleted, if they are there.

   procedure Delete_Files (Item : in out Session);
   --  The answer to that: delete them.
   --  Act on what has been clicked in the form, or in the dialog that asks
   --  before the speech model's files are deleted.

   procedure Update (Item : in out Session)
   with Pre => Settings_VM.Is_Showing (Item.Choices.Model);
   --  Show how far the download is, and what else the view-model has changed.

   procedure Fit (Item : in out Session)
   with Pre => Settings_VM.Is_Showing (Item.Choices.Model);
   --  Make the form as wide as a page, or as the window leaves room for.

   function Downloading (Item : Session) return Boolean;
   --  Whether the form needs to be looked at again soon, for the
   --  download's progress.

   procedure Refresh (Item : in out Session);
   --  Show what the view-model says: the choices, and the download's controls and words.

end View.Settings_View;
