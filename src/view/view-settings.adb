with Backgrounds;
with Settings_VM;
with View.Settings_View;

package body View.Settings is

   function Is_Settings_Open (Item : Session) return Boolean is
     (Settings_VM.Is_Showing (Item.Choices.Model));

   procedure Open_Settings (Item : in out Session)
     renames Settings_View.Open;

   procedure Close_Settings (Item : in out Session)
     renames Settings_View.Close;

   function Speech_Model (Item : Session) return Preferences.Speech_Models is
     (Settings_VM.Speech_Model (Item.Choices.Model));

   procedure Choose_Speech_Model
     (Item : in out Session; To : Preferences.Speech_Models)
     renames Settings_View.Choose;

   function Theme_Choice (Item : Session) return Preferences.Theme_Choices is
     (Settings_VM.Theme (Item.Choices.Model));

   procedure Choose_Theme
     (Item : in out Session; To : Preferences.Theme_Choices)
     renames Settings_View.Choose_Appearance;

   function Background_Choice (Item : Session) return Preferences.Background_Modes is
     (Settings_VM.Background (Item.Choices.Model));

   procedure Choose_Background
     (Item : in out Session; To : Preferences.Background_Modes)
     renames Settings_View.Choose_Background;

   function Watercolour_Seed (Item : Session) return Natural is
     (Backgrounds.Seed_Number (Item.Host.Background));

   procedure Reseed_Background (Item : in out Session; Mode : Preferences.Pictures) is
   begin
      Settings_View.Choose_Background (Item, Mode);
      Settings_View.Reseed (Item);
   end Reseed_Background;

   function VSync_Choice (Item : Session) return Boolean is (Settings_VM.VSync (Item.Choices.Model));

   procedure Choose_VSync (Item : in out Session; To : Boolean)
     renames Settings_View.Choose_VSync;

   function Is_Adaptive (Item : Session) return Boolean is (Item.Choices.Adaptive_Shown);

   function Is_Dark (Item : Session) return Boolean is (Item.Choices.Dark_Shown);

end View.Settings;
