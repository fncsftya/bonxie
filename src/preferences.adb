with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Files;
with Projects;

package body Preferences is

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

   function Speech_Model_Directory (Config : String) return String is
     (Config & "/speech/parakeet-tdt-0.6b-v3");

   function Settings_File (Config : String) return String is
     (Config & "/settings");

   function Settings_Text (Config : String) return String is
   begin
      return Files.Read (Settings_File (Config));
   exception
      when others =>
         return "";  --  none kept, or unreadable
   end Settings_Text;

   function Setting (Config, Name : String) return String;
   --  The value kept for Name in the settings, "" if there is none.

   function Setting (Config, Name : String) return String is
      Text  : constant String := Settings_Text (Config);
      Start : Natural := Text'First;
   begin
      while Start <= Text'Last loop
         declare
            Stop : constant Natural :=
              (if Ada.Strings.Fixed.Index (Text (Start .. Text'Last),
                                           [ASCII.LF]) = 0
               then Text'Last + 1
               else Ada.Strings.Fixed.Index (Text (Start .. Text'Last),
                                             [ASCII.LF]));
            Line  : constant String := Text (Start .. Stop - 1);
         begin
            if Line'Length > Name'Length
              and then Line (Line'First .. Line'First + Name'Length - 1)
                       = Name
              and then Line (Line'First + Name'Length) = '='
            then
               return Line (Line'First + Name'Length + 1 .. Line'Last);
            end if;
            Start := Stop + 1;
         end;
      end loop;
      return "";
   end Setting;

   procedure Put_Setting (Config, Name, Value : String);
   --  Keep Value for Name, and the other settings as they were.

   procedure Put_Setting (Config, Name, Value : String) is
      Text  : constant String := Settings_Text (Config);
      Kept  : Ada.Strings.Unbounded.Unbounded_String;
      Start : Natural := Text'First;
   begin
      while Start <= Text'Last loop
         declare
            Stop : constant Natural :=
              (if Ada.Strings.Fixed.Index (Text (Start .. Text'Last),
                                           [ASCII.LF]) = 0
               then Text'Last + 1
               else Ada.Strings.Fixed.Index (Text (Start .. Text'Last),
                                             [ASCII.LF]));
            Line  : constant String := Text (Start .. Stop - 1);
         begin
            if Line'Length > 0
              and then not (Line'Length > Name'Length
                            and then Line (Line'First ..
                                           Line'First + Name'Length - 1)
                                     = Name
                            and then Line (Line'First + Name'Length) = '=')
            then
               Ada.Strings.Unbounded.Append (Kept, Line & ASCII.LF);
            end if;
            Start := Stop + 1;
         end;
      end loop;
      Ada.Directories.Create_Path (Config);
      Files.Write
        (Settings_File (Config),
         Ada.Strings.Unbounded.To_String (Kept)
         & Name & "=" & Value & ASCII.LF);
   end Put_Setting;

   function Load_Speech_Model (Config : String) return Speech_Models is
     (if Ada.Characters.Handling.To_Lower (Setting (Config, "speech_model"))
         = "parakeet"
      then Parakeet else MacOS);

   procedure Save_Speech_Model (Config : String; To : Speech_Models) is
   begin
      Put_Setting
        (Config, "speech_model",
         Ada.Characters.Handling.To_Lower (Speech_Models'Image (To)));
   end Save_Speech_Model;

   function Load_Theme (Config : String) return Theme_Choices is
      Saved : constant String :=
        Ada.Characters.Handling.To_Lower (Setting (Config, "theme"));
   begin
      if Saved = "light" then
         return Light;
      elsif Saved = "dark" then
         return Dark;
      else
         return System;  --  none kept, or not one of these
      end if;
   end Load_Theme;

   procedure Save_Theme (Config : String; To : Theme_Choices) is
   begin
      Put_Setting
        (Config, "theme",
         Ada.Characters.Handling.To_Lower (Theme_Choices'Image (To)));
   end Save_Theme;

end Preferences;
