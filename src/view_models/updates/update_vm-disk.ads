with Ada.Strings.Unbounded;

--  What updating uses in the program: the preferences in their file, GitHub by curl (Downloads, one file at a
--  time), the files in a folder of their own beside the projects, and the staging and the script of the updater.

package Update_VM.Disk is

   type Disk_Services is limited new Services with private;

   procedure Open (Self : in out Disk_Services; Config_Dir, Helper_Script : String);
   --  Config_Dir is where the preferences are (the updates are fetched into `updates` in it); Helper_Script is
   --  share/bonxie/update-helper.sh as found beside the program, "" if it was not.

   function Directory (Self : Disk_Services) return String;
   --  Where the files are fetched and staged.

   overriding
   function Now (Self : Disk_Services) return Long_Long_Integer;

   overriding
   function Automatic (Self : Disk_Services) return Boolean;

   overriding
   procedure Set_Automatic (Self : in out Disk_Services; To : Boolean);

   overriding
   function Skipped (Self : Disk_Services) return String;

   overriding
   procedure Set_Skipped (Self : in out Disk_Services; Text : String);

   overriding
   function Last_Checked (Self : Disk_Services) return Long_Long_Integer;

   overriding
   procedure Set_Last_Checked (Self : in out Disk_Services; At_Time : Long_Long_Integer);

   overriding
   function Placement (Self : Disk_Services) return Updater.Locations.Placements;

   overriding
   procedure Begin_Fetch (Self : in out Disk_Services; URL, File : String);

   overriding
   function Fetch_State (Self : Disk_Services) return Fetch_States;

   overriding
   function Fetch_Fraction (Self : Disk_Services) return Float;

   overriding
   function Fetch_Message (Self : Disk_Services) return String;

   overriding
   procedure Cancel_Fetch (Self : in out Disk_Services);

   overriding
   procedure Reset_Fetch (Self : in out Disk_Services);

   overriding
   function Text_Of (Self : Disk_Services; File : String) return String;

   overriding
   procedure Begin_Staging (Self : in out Disk_Services; Expected : Updater.Versions.Version);

   overriding
   function Stage_State (Self : Disk_Services) return Stage_States;

   overriding
   function Stage_Message (Self : Disk_Services) return String;

   overriding
   procedure Reset_Stage (Self : in out Disk_Services);

   overriding
   procedure Hand_Over (Self : in out Disk_Services; Started : out Boolean);

   overriding
   function Previous_Failure (Self : Disk_Services) return String;

   overriding
   procedure Forget_Previous_Failure (Self : in out Disk_Services);

private

   type Disk_Services is limited new Services with record
      Config : Ada.Strings.Unbounded.Unbounded_String;
      Script : Ada.Strings.Unbounded.Unbounded_String;
   end record;

end Update_VM.Disk;
