--  What the user has chosen, kept in a file beside the projects
--  (`<config>/bonxie/settings`, a line of `name=value` to each choice), and
--  where the models those choices need are kept.
package Preferences is

   type Speech_Models is (MacOS, Parakeet);
   --  What turns speech into text: the system's, or Parakeet, which needs
   --  its model fetched first (see Speech.Models).

   type Theme_Choices is (Light, Dark, System);
   --  The appearance of the windows: light, dark, or the system's, which
   --  follows its light or dark appearance as it changes.

   type Background_Modes is
     (Fixed, Watercolour, Paper, Ink_Wash, Mist, Grain, Marbling, Risograph, Contours, Bauhaus);
   --  What the windows are drawn on: Fixed, the theme's own colours on a plain background; or
   --  one of the procedural pictures (see Backgrounds.Styles), with colours worked out from it
   --  (adapted to it), light or dark as the theme is.

   subtype Pictures is Background_Modes range Watercolour .. Bauhaus;
   --  The ones that are painted, and take a seed.

   function Config_Directory (Store_Path : String) return String
     with Post => Config_Directory'Result /= "";
   --  The folder the projects database at Store_Path is in:
   --  `$XDG_CONFIG_HOME/bonxie` (`~/.config/bonxie`) as the program runs. For
   --  a store that is not kept (Projects.Memory), one in the system's
   --  temporary folder.

   function Speech_Model_Directory (Config : String) return String
     with Post => Speech_Model_Directory'Result /= "";
   --  Where the model for Parakeet is kept: the folder
   --  `speech/parakeet-tdt-0.6b-v3` in Config.

   function Load_Speech_Model (Config : String) return Speech_Models;
   --  The one chosen, MacOS if none was or it cannot be read.

   procedure Save_Speech_Model (Config : String; To : Speech_Models);
   --  Keep the choice, making Config if need be.

   function Load_Theme (Config : String) return Theme_Choices;
   --  The one chosen, System if none was or it cannot be read.

   procedure Save_Theme (Config : String; To : Theme_Choices);
   --  Keep the choice, making Config if need be.

   function Load_Background (Config : String) return Background_Modes;
   --  The one chosen, Watercolour if none was or it cannot be read.

   procedure Save_Background (Config : String; To : Background_Modes);
   --  Keep the choice, making Config if need be.

   Seed_Limit : constant := 2 ** 24;

   function Has_Seed (Config : String) return Boolean;
   --  Whether a watercolour's seed has been kept.

   function Load_Seed (Config : String) return Natural
     with Pre => Has_Seed (Config), Post => Load_Seed'Result < Seed_Limit;
   --  The seed of the watercolour the windows were last painted with, so that it is the same
   --  picture on every run.

   procedure Save_Seed (Config : String; To : Natural)
     with Pre => To < Seed_Limit;
   --  Keep it, making Config if need be.

   function Load_AI_Enabled (Config : String) return Boolean;
   --  Whether the local language model is switched on: False if none was
   --  chosen or it cannot be read.

   procedure Save_AI_Enabled (Config : String; To : Boolean);
   --  Keep the choice, making Config if need be.

   function Load_AI_Model (Config : String) return String;
   --  The language model chosen, as "provider/name" of the Hugging Face
   --  cache; "" if none was or it cannot be read.

   procedure Save_AI_Model (Config : String; To : String);
   --  Keep the choice ("" for none), making Config if need be.

   function Load_Sidebar_Width (Config : String) return Natural;
   --  How wide the writing view's list of documents was left, in points;
   --  0 if it was not, or it cannot be read.

   procedure Save_Sidebar_Width (Config : String; To : Natural);
   --  Keep the width, making Config if need be.

   function Load_Generate_Notes (Config : String) return Boolean;
   --  Whether the outline's Generate button was last used to make the
   --  sections with notes; False if it was not, or it cannot be read.

   procedure Save_Generate_Notes (Config : String; To : Boolean);
   --  Keep the choice, making Config if need be.

end Preferences;
