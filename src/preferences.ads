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

end Preferences;
