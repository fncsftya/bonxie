with System;
with Ada.Directories;
with Download_Jobs;
with Files;
with Preferences;
with Updater.Keys;
with Updater.Staging;

package body Update_VM.Disk is

   use Ada.Strings.Unbounded;

   package Fetches is new Download_Jobs;
   --  The one transfer there is at a time; the transport for the release and then its files.

   use type Fetches.States;
   use type Updater.Staging.States;

   Folder : constant String := "/updates";

   function Config_Of (Self : Disk_Services) return String
   is (To_String (Self.Config));

   function Directory (Self : Disk_Services) return String
   is (Config_Of (Self) & Folder);

   procedure Open (Self : in out Disk_Services; Config_Dir, Helper_Script : String) is
   begin
      Self.Config := To_Unbounded_String (Config_Dir);
      Self.Script := To_Unbounded_String (Helper_Script);
   end Open;

   function Unix_Time (Where : System.Address) return Long_Long_Integer
   with Import, Convention => C, External_Name => "time";
   --  time(3), with no place to put it too.

   overriding
   function Now (Self : Disk_Services) return Long_Long_Integer
   is (Unix_Time (System.Null_Address));

   overriding
   function Automatic (Self : Disk_Services) return Boolean
   is (Preferences.Load_Update_Checks (Config_Of (Self)));

   overriding
   procedure Set_Automatic (Self : in out Disk_Services; To : Boolean) is
   begin
      Preferences.Save_Update_Checks (Config_Of (Self), To);
   end Set_Automatic;

   overriding
   function Skipped (Self : Disk_Services) return String
   is (Preferences.Load_Skipped_Version (Config_Of (Self)));

   overriding
   procedure Set_Skipped (Self : in out Disk_Services; Text : String) is
   begin
      Preferences.Save_Skipped_Version (Config_Of (Self), Text);
   end Set_Skipped;

   overriding
   function Last_Checked (Self : Disk_Services) return Long_Long_Integer
   is (Preferences.Load_Last_Update_Check (Config_Of (Self)));

   overriding
   procedure Set_Last_Checked (Self : in out Disk_Services; At_Time : Long_Long_Integer) is
   begin
      Preferences.Save_Last_Update_Check (Config_Of (Self), Long_Long_Integer'Max (0, At_Time));
   end Set_Last_Checked;

   overriding
   function Placement (Self : Disk_Services) return Updater.Locations.Placements
   is (Updater.Locations.Placement (Updater.Locations.Bundle));

   overriding
   procedure Begin_Fetch (Self : in out Disk_Services; URL, File : String) is
   begin
      Fetches.Start (URL, Directory (Self) & "/" & File);
   end Begin_Fetch;

   overriding
   function Fetch_State (Self : Disk_Services) return Fetch_States
   is (case Fetches.State is
         when Fetches.Idle    => Fetch_Idle,
         when Fetches.Running => Fetch_Running,
         when Fetches.Done    => Fetch_Done,
         when Fetches.Failed  => Fetch_Failed);

   overriding
   function Fetch_Fraction (Self : Disk_Services) return Float
   is (Fetches.Fraction);

   overriding
   function Fetch_Message (Self : Disk_Services) return String
   is (if Fetches.State = Fetches.Failed then Fetches.Message else "");

   overriding
   procedure Cancel_Fetch (Self : in out Disk_Services) is
   begin
      Fetches.Cancel;
   end Cancel_Fetch;

   overriding
   procedure Reset_Fetch (Self : in out Disk_Services) is
   begin
      if Fetches.State /= Fetches.Running then
         Fetches.Reset;
      end if;
   end Reset_Fetch;

   overriding
   function Text_Of (Self : Disk_Services; File : String) return String is
   begin
      return Files.Read (Directory (Self) & "/" & File);
   exception
      when others =>
         return "";
   end Text_Of;

   overriding
   procedure Begin_Staging (Self : in out Disk_Services; Expected : Updater.Versions.Version) is
      Where : constant String := Directory (Self);
   begin
      Updater.Staging.Start
        (Directory  => Where,
         Disk_Image => Where & "/" & Updater.Disk_Image_Name,
         Manifest   => Where & "/" & Updater.Manifest_Name,
         Signature  => Where & "/" & Updater.Signature_Name,
         Public_Key => Updater.Keys.Public_Key,
         Expected   => Expected);
   end Begin_Staging;

   overriding
   function Stage_State (Self : Disk_Services) return Stage_States
   is (case Updater.Staging.State is
         when Updater.Staging.Idle    => Stage_Idle,
         when Updater.Staging.Running => Stage_Running,
         when Updater.Staging.Done    => Stage_Done,
         when Updater.Staging.Failed  => Stage_Failed);

   overriding
   function Stage_Message (Self : Disk_Services) return String
   is (if Updater.Staging.State = Updater.Staging.Failed then Updater.Staging.Message else "");

   overriding
   procedure Reset_Stage (Self : in out Disk_Services) is
   begin
      if Updater.Staging.State /= Updater.Staging.Running then
         Updater.Staging.Reset;
      end if;
   end Reset_Stage;

   overriding
   procedure Hand_Over (Self : in out Disk_Services; Started : out Boolean) is
   begin
      Started := False;
      if Self.Script = Null_Unbounded_String or else not Ada.Directories.Exists (To_String (Self.Script)) then
         return;
      end if;
      Updater.Staging.Hand_Over
        (Script    => To_String (Self.Script),
         Staged    => Updater.Staging.Application,
         Target    => Updater.Locations.Bundle,
         Directory => Directory (Self),
         Process   => Updater.Locations.Process_Number,
         Started   => Started);
   end Hand_Over;

   overriding
   function Previous_Failure (Self : Disk_Services) return String
   is (Updater.Staging.Last_Failure (Directory (Self)));

   overriding
   procedure Forget_Previous_Failure (Self : in out Disk_Services) is
   begin
      Updater.Staging.Forget_Failure (Directory (Self));
   end Forget_Previous_Failure;

end Update_VM.Disk;
