package body Settings_VM.Disk is

   function Where (Self : File_Store) return String
   is (Ada.Strings.Unbounded.To_String (Self.Config));

   function Kind_Of (Which : Preferences.Speech_Models) return Speech.Model_Kinds
   is (case Which is
         when Preferences.Granite => Speech.Granite_5,
         when others              => Speech.Parakeet_V3);

   function Folder (Self : Speech_Files) return String
   is (Preferences.Speech_Model_Directory (Ada.Strings.Unbounded.To_String (Self.Config), Self.Chosen));

   procedure Open (Self : in out File_Store; Config_Dir : String) is
   begin
      Self.Config := Ada.Strings.Unbounded.To_Unbounded_String (Config_Dir);
   end Open;

   overriding
   procedure Save_Speech_Model (Self : in out File_Store; To : Preferences.Speech_Models) is
   begin
      Preferences.Save_Speech_Model (Where (Self), To);
   end Save_Speech_Model;

   overriding
   procedure Save_Theme (Self : in out File_Store; To : Preferences.Theme_Choices) is
   begin
      Preferences.Save_Theme (Where (Self), To);
   end Save_Theme;

   overriding
   procedure Save_Background (Self : in out File_Store; To : Preferences.Background_Modes) is
   begin
      Preferences.Save_Background (Where (Self), To);
   end Save_Background;

   overriding
   procedure Save_VSync (Self : in out File_Store; To : Boolean) is
   begin
      Preferences.Save_VSync (Where (Self), To);
   end Save_VSync;

   overriding
   procedure Save_Seed (Self : in out File_Store; To : Natural) is
   begin
      Preferences.Save_Seed (Where (Self), To);
   end Save_Seed;

   procedure Open (Self : in out Speech_Files; Config_Dir : String) is
   begin
      Self.Config := Ada.Strings.Unbounded.To_Unbounded_String (Config_Dir);
   end Open;

   use type Speech.Models.States;
   use type Preferences.Speech_Models;

   overriding
   procedure Choose (Self : in out Speech_Files; To : Preferences.Speech_Models) is
   begin
      if To /= Preferences.MacOS and then Speech.Models.State /= Speech.Models.Running then
         Self.Chosen := To;
         Speech.Models.Focus (Kind_Of (To));
      end if;
   end Choose;

   overriding
   function State (Self : Speech_Files) return Speech.Models.States is
      pragma Unreferenced (Self);
   begin
      return Speech.Models.State;
   end State;

   overriding
   function Fraction (Self : Speech_Files) return Float is
      pragma Unreferenced (Self);
   begin
      return Speech.Models.Fraction;
   end Fraction;

   overriding
   function Preparing (Self : Speech_Files) return Boolean is
      pragma Unreferenced (Self);
   begin
      return Speech.Models.Preparing;
   end Preparing;

   overriding
   function Total_Bytes (Self : Speech_Files) return Long_Long_Integer is
      pragma Unreferenced (Self);
   begin
      return Speech.Models.Total_Bytes;
   end Total_Bytes;

   overriding
   function Message (Self : Speech_Files) return String is
      pragma Unreferenced (Self);
   begin
      return Speech.Models.Message;
   end Message;

   overriding
   function Present (Self : Speech_Files) return Boolean
   is (Speech.Models.Present (Kind_Of (Self.Chosen), Folder (Self)));

   overriding
   function On_Disk (Self : Speech_Files) return Long_Long_Integer
   is (Speech.Models.Size_On_Disk (Folder (Self)));

   --  Not while a fetch goes on: the view-model does not ask, but the state may have changed since.

   overriding
   procedure Start (Self : in out Speech_Files) is
   begin
      if Speech.Models.State /= Speech.Models.Running then
         Speech.Models.Start (Kind_Of (Self.Chosen), Folder (Self));
      end if;
   end Start;

   overriding
   procedure Delete (Self : in out Speech_Files) is
   begin
      if Speech.Models.State /= Speech.Models.Running then
         Speech.Models.Delete (Kind_Of (Self.Chosen), Folder (Self));
         Speech.Models.Reset;
      end if;
   end Delete;

end Settings_VM.Disk;
