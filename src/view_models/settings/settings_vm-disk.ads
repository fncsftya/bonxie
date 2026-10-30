with Ada.Strings.Unbounded;

--  The settings' choices kept in a file, and the speech model kept in a
--  folder: what the program uses (a test uses its own).

package Settings_VM.Disk is

   type File_Store is limited new Store with private;

   procedure Open (Self : in out File_Store; Config_Dir : String);

   overriding
   procedure Save_Speech_Model (Self : in out File_Store; To : Preferences.Speech_Models);

   overriding
   procedure Save_Theme (Self : in out File_Store; To : Preferences.Theme_Choices);

   overriding
   procedure Save_Background (Self : in out File_Store; To : Preferences.Background_Modes);

   overriding
   procedure Save_VSync (Self : in out File_Store; To : Boolean);

   overriding
   procedure Save_Seed (Self : in out File_Store; To : Natural);

   type Speech_Files is limited new Model_Source with private;

   procedure Open (Self : in out Speech_Files; Config_Dir : String);
   --  The models whose files are in Config_Dir (see Preferences.Speech_Model_Directory), as Speech.Models
   --  fetches them. They are read as they are, from the task that fetches: as Speech.Models gives them.
   --  Parakeet's are the ones that are read until another is chosen.

   function Kind_Of (Which : Preferences.Speech_Models) return Speech.Model_Kinds
   with Pre => Preferences."/=" (Which, Preferences.MacOS);
   --  The model that this choice runs.

   overriding
   procedure Choose (Self : in out Speech_Files; To : Preferences.Speech_Models);

   overriding
   function State (Self : Speech_Files) return Speech.Models.States;

   overriding
   function Fraction (Self : Speech_Files) return Float;

   overriding
   function Preparing (Self : Speech_Files) return Boolean;

   overriding
   function Total_Bytes (Self : Speech_Files) return Long_Long_Integer;

   overriding
   function Message (Self : Speech_Files) return String;

   overriding
   function Present (Self : Speech_Files) return Boolean;

   overriding
   function On_Disk (Self : Speech_Files) return Long_Long_Integer;

   overriding
   procedure Start (Self : in out Speech_Files);

   overriding
   procedure Delete (Self : in out Speech_Files);

private

   type File_Store is limited new Store with record
      Config : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   type Speech_Files is limited new Model_Source with record
      Config : Ada.Strings.Unbounded.Unbounded_String;
      Chosen : Preferences.Speech_Models := Preferences.Parakeet;
      --  Never MacOS, which has no files.
   end record;

end Settings_VM.Disk;
