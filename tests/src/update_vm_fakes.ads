with Ada.Strings.Unbounded;
with Update_VM;
with Updater.Locations;
with Updater.Versions;

--  What Update_VM is run on in the tests: no network, no disk, no script. A test says how each fetch and the
--  staging go, and reads what was asked.

package Update_VM_Fakes is

   use Ada.Strings.Unbounded;

   type Pretend is limited new Update_VM.Services with record
      Time       : Long_Long_Integer := 1_000_000;
      Auto       : Boolean := True;
      Kept_Skip  : Unbounded_String;
      Checked    : Long_Long_Integer := 0;
      Where      : Updater.Locations.Placements := Updater.Locations.Replaceable;
      --  The preferences and the place.
      Fetch      : Update_VM.Fetch_States := Update_VM.Fetch_Idle;
      Progress   : Float := 0.0;
      Why_Not    : Unbounded_String;
      Release    : Unbounded_String;
      --  What the fetch of the release gives (as text), and how fetches stand.
      Asked      : Unbounded_String;
      --  Every fetch begun, as `file url;`.
      Cancelled  : Natural := 0;
      Stage      : Update_VM.Stage_States := Update_VM.Stage_Idle;
      Stage_Why  : Unbounded_String;
      Staged_For : Unbounded_String;
      Hand_Start : Boolean := True;
      Handed     : Natural := 0;
      Failure    : Unbounded_String;
      Forgotten  : Natural := 0;
   end record;

   overriding
   function Now (Self : Pretend) return Long_Long_Integer;
   overriding
   function Automatic (Self : Pretend) return Boolean;
   overriding
   procedure Set_Automatic (Self : in out Pretend; To : Boolean);
   overriding
   function Skipped (Self : Pretend) return String;
   overriding
   procedure Set_Skipped (Self : in out Pretend; Text : String);
   overriding
   function Last_Checked (Self : Pretend) return Long_Long_Integer;
   overriding
   procedure Set_Last_Checked (Self : in out Pretend; At_Time : Long_Long_Integer);
   overriding
   function Placement (Self : Pretend) return Updater.Locations.Placements;
   overriding
   procedure Begin_Fetch (Self : in out Pretend; URL, File : String);
   overriding
   function Fetch_State (Self : Pretend) return Update_VM.Fetch_States;
   overriding
   function Fetch_Fraction (Self : Pretend) return Float;
   overriding
   function Fetch_Message (Self : Pretend) return String;
   overriding
   procedure Cancel_Fetch (Self : in out Pretend);
   overriding
   procedure Reset_Fetch (Self : in out Pretend);
   overriding
   function Text_Of (Self : Pretend; File : String) return String;
   overriding
   procedure Begin_Staging (Self : in out Pretend; Expected : Updater.Versions.Version);
   overriding
   function Stage_State (Self : Pretend) return Update_VM.Stage_States;
   overriding
   function Stage_Message (Self : Pretend) return String;
   overriding
   procedure Reset_Stage (Self : in out Pretend);
   overriding
   procedure Hand_Over (Self : in out Pretend; Started : out Boolean);
   overriding
   function Previous_Failure (Self : Pretend) return String;
   overriding
   procedure Forget_Previous_Failure (Self : in out Pretend);

   function Release_Of (Tag : String; Prerelease : Boolean := False) return String;
   --  What GitHub would say of a release of that tag, with the three assets.

end Update_VM_Fakes;
