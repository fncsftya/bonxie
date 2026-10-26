with Ada.Strings.Unbounded;
with Pomarine.View_Models;
with Preferences;
with Speech.Models;

--  The view-model of the settings: what they mean, and nothing of how they
--  look. The choices (theme, background, speech model, VSync), when each
--  command is possible, how the speech model's download stands and what is
--  said of it, and where the choices are kept. It names no widget, tree or
--  window, so the tests run it without one (see Settings_VM_Tests).
--
--  Applying a choice to the world (the window's VSync, the colours the windows
--  are drawn in, the painted background) is the view's, as a reaction to
--  Version: see View.Settings_View.
package Settings_VM is

   package Parts renames Pomarine.View_Models;

   type Command is
     (Open,
      --  Show the settings.
      Close,
      Choose_Theme,
      --  Index: the Theme_Choices'Pos of the one chosen.
      Choose_Background,
      --  Index: the Background_Modes'Pos.
      Choose_Speech_Model,
      --  Index: the Speech_Models'Pos.
      Toggle_VSync,
      Reseed,
      --  Index: the number of the picture now painted (below Preferences.Seed_Limit), which is kept.
      Download_Model,
      --  Fetch the speech model's files.
      Delete_Model,
      --  Remove them.
      Confirm_Delete);
      --  Ask whether to remove them (Effects.Ask_To_Delete); Delete_Model is the answer.

   package Commands is new Parts.Command_Models (Command);

   --  Where the choices are kept. A save that fails does not take the choice
   --  back: it holds for now, and Keep_Failed says so.

   type Store is limited interface;

   procedure Save_Speech_Model (Self : in out Store; To : Preferences.Speech_Models) is abstract;

   procedure Save_Theme (Self : in out Store; To : Preferences.Theme_Choices) is abstract;

   procedure Save_Background (Self : in out Store; To : Preferences.Background_Modes) is abstract;

   procedure Save_VSync (Self : in out Store; To : Boolean) is abstract;

   procedure Save_Seed (Self : in out Store; To : Natural) is abstract;

   --  The speech model and what the program has fetched of it.

   type Model_Source is limited interface;

   function State (Self : Model_Source) return Speech.Models.States is abstract;

   function Fraction (Self : Model_Source) return Float is abstract;

   function Preparing (Self : Model_Source) return Boolean is abstract;

   function Total_Bytes (Self : Model_Source) return Long_Long_Integer is abstract;

   function Message (Self : Model_Source) return String is abstract;

   function Present (Self : Model_Source) return Boolean is abstract;
   --  Whether all of the files are there.

   function On_Disk (Self : Model_Source) return Long_Long_Integer is abstract;

   procedure Start (Self : in out Model_Source) is abstract;
   --  Begin to fetch it.

   procedure Delete (Self : in out Model_Source) is abstract;
   --  Remove the files, and forget how the last fetch ended.

   --  What the world is told, after a command is done, for what is the view's to do about it: the colours
   --  the windows are drawn in, the display's VSync, a question to ask before files are deleted.

   type Effects is limited interface;

   procedure Done (Self : in out Effects; What : Command) is abstract;
   --  After What was executed (not Open and Close, which are the navigation's).

   procedure Ask_To_Delete (Self : in out Effects; Size : String) is abstract;
   --  Confirm_Delete was executed: ask before the files, which take Size, are deleted.

   type View_Model is limited new Commands.Model with private;

   procedure Initialize
     (Self       : in out View_Model;
      Source     : not null access Model_Source'Class;
      Kept_In    : access Store'Class;
      Config_Dir      : String;
      Kept_Speech     : Preferences.Speech_Models := Preferences.MacOS;
      Kept_Theme      : Preferences.Theme_Choices := Preferences.System;
      Kept_Background : Preferences.Background_Modes := Preferences.Watercolour;
      Kept_VSync      : Boolean := False;
      Reactions       : access Effects'Class := null);
   --  With the choices as they were kept. Source and Kept_In must be there as
   --  long as the view-model is. Without a Kept_In, nothing is kept. The
   --  download is looked at (Poll).

   function Config_Directory (Self : View_Model) return String;
   --  Where the settings, and the files they need, are kept.

   function Persists (Self : View_Model) return Boolean;
   --  Whether the choices are kept: it has a Store.

   overriding function Version (Self : View_Model) return Parts.Version_Number;

   overriding function Can_Execute (Self : View_Model; What : Command; Index : Natural := 0) return Boolean;
   --  Open: the settings are not shown. Close: they are. Download_Model: the
   --  files are not there and not on their way. Delete_Model and Confirm_Delete: they are there and
   --  not being replaced. The choices, Toggle_VSync and Reseed: always.

   overriding procedure Execute (Self : in out View_Model; What : Command; Index : Natural := 0)
     with Post => (case What is
                      when Open => Is_Showing (Self),
                      when Close => not Is_Showing (Self),
                      when Choose_Theme => Preferences.Theme_Choices'Pos (Theme (Self)) = Index,
                      when Choose_Background => Preferences.Background_Modes'Pos (Background (Self)) = Index,
                      when Choose_Speech_Model => Preferences.Speech_Models'Pos (Speech_Model (Self)) = Index,
                      when others => True);
   --  A choice out of range raises Constraint_Error, and changes nothing.

   --  What is chosen

   function Is_Showing (Self : View_Model) return Boolean;

   function Theme (Self : View_Model) return Preferences.Theme_Choices;

   function Background (Self : View_Model) return Preferences.Background_Modes;

   function Speech_Model (Self : View_Model) return Preferences.Speech_Models;

   function VSync (Self : View_Model) return Boolean;

   function Seed (Self : View_Model) return Natural
     with Post => Seed'Result < Preferences.Seed_Limit;
   --  Of the picture last painted (Reseed).

   function Keep_Failed (Self : View_Model) return Boolean;
   --  Whether the last save failed.

   --  How the download stands: polled, for it is changed by another task.

   procedure Poll (Self : in out View_Model);
   --  Look at the model's source, and take what it says. Cheap while nothing
   --  is going on; the files are looked at when the state has changed.

   function Download_State (Self : View_Model) return Speech.Models.States;

   function Download_Row_Shown (Self : View_Model) return Boolean;
   --  The download's controls are for Parakeet, whose files come to be fetched.

   function Download_Button_Shown (Self : View_Model) return Boolean;
   --  While the files are not there.

   function Delete_Button_Shown (Self : View_Model) return Boolean;
   --  While they are, and none are coming.

   function Download_Bar_Shown (Self : View_Model) return Boolean;
   --  For Parakeet, while they come.

   function Download_Fraction (Self : View_Model) return Float
     with Post => Download_Fraction'Result in 0.0 .. 1.0;

   function Download_Status (Self : View_Model) return String;
   --  What is said by the button: "Model not downloaded", "Downloading 12.3 MB of
   --  483.0 MB (2%)", "Download failed: ...", "Model available, 483.0 MB on disk".

   function Size_On_Disk_Text (Self : View_Model) return String;
   --  As people say it: "483.0 MB".

   function Size_Text (Bytes : Long_Long_Integer) return String
     with Post => Size_Text'Result /= "";
   --  "12 KB", "483.0 MB", or "1.20 GB" from a thousand megabytes.

private

   package Theme_Properties is new Parts.Properties (Preferences.Theme_Choices, Preferences."=");
   package Background_Properties is new Parts.Properties (Preferences.Background_Modes, Preferences."=");
   package Speech_Properties is new Parts.Properties (Preferences.Speech_Models, Preferences."=");
   package Flag_Properties is new Parts.Properties (Boolean);

   type Source_Access is access all Model_Source'Class;

   type Store_Access is access all Store'Class;

   type Effects_Access is access all Effects'Class;

   type Snapshot is record
      State     : Speech.Models.States := Speech.Models.Idle;
      Fraction  : Float := 0.0;
      Preparing : Boolean := False;
      Total     : Long_Long_Integer := 0;
      Present   : Boolean := False;
      On_Disk   : Long_Long_Integer := 0;
      Message   : Ada.Strings.Unbounded.Unbounded_String;
   end record;
   --  What the source said when last asked.

   type View_Model is limited new Commands.Model with record
      Source   : Source_Access;
      Store    : Store_Access;
      Reactions : Effects_Access;
      Config   : Ada.Strings.Unbounded.Unbounded_String;
      Showing  : Flag_Properties.Property;
      Themes   : Theme_Properties.Property;
      Pictures : Background_Properties.Property;
      Voice    : Speech_Properties.Property;
      Ticked   : Flag_Properties.Property;
      --  VSync.
      Number   : Natural range 0 .. Preferences.Seed_Limit - 1 := 0;
      Download : Snapshot;
      Changes  : Parts.Change_Counter;
      --  Of what is not a property: the download, the seed, a save that failed.
      Failed   : Boolean := False;
   end record;

end Settings_VM;
