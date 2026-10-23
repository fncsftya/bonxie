with Backgrounds;
with Ada.Strings.Unbounded;
with Viewer.Settings_View;

package body Viewer.Settings is

   function Is_Settings_Open (Item : Session) return Boolean is
     (Item.Prefs.Showing_Settings);

   procedure Open_Settings (Item : in out Session)
     renames Settings_View.Open;

   procedure Close_Settings (Item : in out Session)
     renames Settings_View.Close;

   function Speech_Model (Item : Session) return Preferences.Speech_Models is
     (Item.Prefs.Speech_Choice);

   procedure Choose_Speech_Model
     (Item : in out Session; To : Preferences.Speech_Models)
     renames Settings_View.Choose;

   function Theme_Choice (Item : Session) return Preferences.Theme_Choices is
     (Item.Prefs.Theme_Chosen);

   procedure Choose_Theme
     (Item : in out Session; To : Preferences.Theme_Choices)
     renames Settings_View.Choose_Appearance;

   function Background_Choice (Item : Session) return Preferences.Background_Modes is
     (Item.Prefs.Background_Chosen);

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

   function Is_Adaptive (Item : Session) return Boolean is (Item.Prefs.Adaptive_Shown);

   procedure Choose_AI_Enabled (Item : in out Session; To : Boolean)
     renames Settings_View.Enable_AI;

   procedure Choose_AI_Backend (Item : in out Session; To : Preferences.AI_Backends)
     renames Settings_View.Choose_AI_Backend;

   function AI_Backend (Item : Session) return Preferences.AI_Backends is (Item.Prefs.AI_Backend);

   function AI_Enabled (Item : Session) return Boolean is (Item.Prefs.AI_On);

   function AI_Model (Item : Session) return String is
     (Ada.Strings.Unbounded.To_String (Item.Prefs.AI_Model));

   function Is_Dark (Item : Session) return Boolean is (Item.Prefs.Dark_Shown);

end Viewer.Settings;
