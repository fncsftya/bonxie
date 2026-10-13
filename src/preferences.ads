--  What the user has chosen, kept in a file beside the projects
--  (`<config>/bonxie/settings`), and where the files those choices need
--  are kept.
package Preferences is

   type Speech_Models is (MacOS, Parakeet);
   --  What turns speech into text: the system's, or Parakeet, which needs a
   --  file fetched first.

   Parakeet_URL : constant String :=
     "https://huggingface.co/handy-computer/parakeet-unified-en-0.6b-gguf"
     & "/resolve/main/parakeet-unified-en-0.6b-Q5_K_M.gguf";
   --  Where the file for Parakeet is fetched from.

   function Config_Directory (Store_Path : String) return String
     with Post => Config_Directory'Result /= "";
   --  The folder the projects database at Store_Path is in:
   --  `$XDG_CONFIG_HOME/bonxie` (`~/.config/bonxie`) as the program runs. For
   --  a store that is not kept (Projects.Memory), one in the system's
   --  temporary folder.

   function Speech_Model_File (Config : String) return String
     with Post => Speech_Model_File'Result /= "";
   --  Where the file for Parakeet is kept: `speech/model.gguf` in Config.

   function Load_Speech_Model (Config : String) return Speech_Models;
   --  The one chosen, MacOS if none was or it cannot be read.

   procedure Save_Speech_Model (Config : String; To : Speech_Models);
   --  Keep the choice, making Config if need be.

end Preferences;
