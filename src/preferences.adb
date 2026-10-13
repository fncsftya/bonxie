with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Files;
with Projects;

package body Preferences is

   Key : constant String := "speech_model=";

   function Config_Directory (Store_Path : String) return String is
   begin
      if Store_Path = Projects.Memory then
         return
           (if Ada.Environment_Variables.Exists ("TMPDIR")
              and then Ada.Environment_Variables.Value ("TMPDIR") /= ""
            then Ada.Strings.Fixed.Trim
                   (Ada.Environment_Variables.Value ("TMPDIR"),
                    Ada.Strings.Right)
            else "/tmp")
           & "/bonxie-memory";
      else
         return Ada.Directories.Containing_Directory (Store_Path);
      end if;
   end Config_Directory;

   function Speech_Model_File (Config : String) return String is
     (Config & "/speech/model.gguf");

   function Settings_File (Config : String) return String is
     (Config & "/settings");

   function Load_Speech_Model (Config : String) return Speech_Models is
   begin
      --  Read in the body: a missing file raises, which the handler below
      --  would not see from a declaration.
      declare
         Saved : constant String :=
           Ada.Characters.Handling.To_Lower
             (Files.Read (Settings_File (Config)));
      begin
         return
           (if Ada.Strings.Fixed.Index (Saved, Key & "parakeet") > 0
            then Parakeet else MacOS);
      end;
   exception
      when others =>
         return MacOS;  --  none kept, or unreadable
   end Load_Speech_Model;

   procedure Save_Speech_Model (Config : String; To : Speech_Models) is
   begin
      Ada.Directories.Create_Path (Config);
      Files.Write
        (Settings_File (Config),
         Key & Ada.Characters.Handling.To_Lower (Speech_Models'Image (To))
         & Character'Val (10));
   end Save_Speech_Model;

end Preferences;
