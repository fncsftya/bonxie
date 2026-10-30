with Ada.Strings.Unbounded;
with Pomarine.View_Models;
with Updater.Locations;
with Updater.Releases;
with Updater.Versions;

--  The view-model of updating the program: looking for a newer release on GitHub, offering it, and, only when the
--  person chooses, fetching it, checking it and handing over to the script that swaps it for this one. It names
--  no widget, so the tests run it without a window or a network, with fake Services.
--
--  Nothing here is done without the person's say: a check is a request for a small file from GitHub (by itself at
--  most once a day, and not if they turned that off), and an update is not fetched until Install. Skip keeps one
--  version from being offered again by a check that was not asked for.
--
--  The view polls (Poll, on each tick), shows what Attention says is wanted of it, and acts on a state that asks
--  for the program to end (Leaving).

package Update_VM is

   package Parts renames Pomarine.View_Models;

   type States is
     (Idle,
      --  Nothing is known, or the person put it away.
      Checking,
      --  Asking GitHub for the newest release.
      Up_To_Date,
      Available,
      --  A newer release was found. Later puts the offer away; it stays known.
      Downloading,
      Verifying,
      --  Checking what came, and taking the application out of it.
      Stopping,
      --  Cancelled; waiting for the transfer to end.
      Handing_Over,
      --  The script is started: the program is to quit.
      Failed);

   type Command is
     (Check_Now,
      Toggle_Automatic,
      Install,
      --  Fetch, check and install the release that is Available.
      Skip,
      --  Do not offer this version again, unless asked.
      Later,
      --  Put the offer, or the report of what went wrong, away.
      Cancel);
   --  Stop fetching.

   package Commands is new Parts.Command_Models (Command);

   Announcing : constant := 1;
   --  The Index of a Check_Now that is to be told of whatever it finds, as the menu's is: that the program is up
   --  to date (the settings' button shows it where it is).

   type Fetch_States is (Fetch_Idle, Fetch_Running, Fetch_Done, Fetch_Failed);
   type Stage_States is (Stage_Idle, Stage_Running, Stage_Done, Stage_Failed);

   Release_File : constant String := "release.json";
   --  What the fetch of Updater.Latest_URL is called to Services; the others are Updater's asset names.

   --  What the world does for it. Files are named as above and are kept by Services, in a folder of its own.
   type Services is limited interface;

   function Now (Self : Services) return Long_Long_Integer is abstract;
   --  Seconds since 1970.

   function Automatic (Self : Services) return Boolean is abstract;
   procedure Set_Automatic (Self : in out Services; To : Boolean) is abstract;

   function Skipped (Self : Services) return String is abstract;
   procedure Set_Skipped (Self : in out Services; Text : String) is abstract;

   function Last_Checked (Self : Services) return Long_Long_Integer is abstract;
   procedure Set_Last_Checked (Self : in out Services; At_Time : Long_Long_Integer) is abstract;

   function Placement (Self : Services) return Updater.Locations.Placements is abstract;

   procedure Begin_Fetch (Self : in out Services; URL, File : String) is abstract;
   function Fetch_State (Self : Services) return Fetch_States is abstract;
   function Fetch_Fraction (Self : Services) return Float is abstract;
   function Fetch_Message (Self : Services) return String is abstract;
   procedure Cancel_Fetch (Self : in out Services) is abstract;
   procedure Reset_Fetch (Self : in out Services) is abstract;
   function Text_Of (Self : Services; File : String) return String is abstract;

   procedure Begin_Staging (Self : in out Services; Expected : Updater.Versions.Version) is abstract;
   function Stage_State (Self : Services) return Stage_States is abstract;
   function Stage_Message (Self : Services) return String is abstract;
   procedure Reset_Stage (Self : in out Services) is abstract;

   procedure Hand_Over (Self : in out Services; Started : out Boolean) is abstract;
   --  Start the script that swaps the staged application for the running one, once this process has ended.

   function Previous_Failure (Self : Services) return String is abstract;
   --  What the script said of an update that did not take, "" if none.
   procedure Forget_Previous_Failure (Self : in out Services) is abstract;

   type View_Model is limited new Commands.Model with private;

   procedure Initialize (Self : in out View_Model; Source : not null access Services'Class; Running : String)
   with Pre => Running /= "";
   --  Source must outlive the model. Running is the version that is running (`0.2.0`).

   procedure Start (Self : in out View_Model);
   --  The program has started: report an update that did not take; else, if checks are on, it is replaceable
   --  where it is and it has been a day since the last, look quietly.

   procedure Poll (Self : in out View_Model);
   --  Move on as far as the fetches and the checking have got. Cheap when nothing is going on.

   function State (Self : View_Model) return States;

   type Attentions is (Nothing, Offering, Working, Problem, Leaving);

   function Attention (Self : View_Model) return Attentions;
   --  What the view should be showing: Offering, an offer to install, skip or put off; Working, how far an install
   --  has got, which can be cancelled while it is fetching; Problem, what went wrong, or that a check that was to
   --  be announced found nothing newer; Leaving, the program is to quit now (the script waits for it).

   function Current (Self : View_Model) return String;
   --  The running version.

   function Newest (Self : View_Model) return String
   with Pre => State (Self) in Available | Downloading | Verifying | Stopping | Handing_Over;
   --  The version found.

   function Automatic (Self : View_Model) return Boolean;

   function Fraction (Self : View_Model) return Float
   with Post => Fraction'Result in 0.0 .. 1.0;
   --  How far the disk image has come; 0.0 before it, 1.0 after.

   --  What is said

   function Version_Line (Self : View_Model) return String;
   --  "Bonxie 0.2.0".

   function Status (Self : View_Model) return String;
   --  For the settings: "", "Checking…", "Bonxie is up to date.", "Version 0.3.0 is available." ...

   function Offer_Message (Self : View_Model) return String;
   function Offer_Note (Self : View_Model) return String;
   function Working_Message (Self : View_Model) return String;
   function Working_Note (Self : View_Model) return String;
   function Problem_Message (Self : View_Model) return String;
   function Problem_Note (Self : View_Model) return String;
   --  The dialog's words, in the three kinds of its Attention.

   function Can_Cancel (Self : View_Model) return Boolean;

   overriding
   function Version (Self : View_Model) return Parts.Version_Number;

   overriding
   function Can_Execute (Self : View_Model; What : Command; Index : Natural := 0) return Boolean;
   --  Check_Now unless one is going on or an install is; Toggle_Automatic always; Install while Available;
   --  Skip while Available; Later while Available, and after a failure or an announced finding; Cancel while
   --  Downloading.

   overriding
   procedure Execute (Self : in out View_Model; What : Command; Index : Natural := 0);

private

   type Services_Access is access all Services'Class;

   type View_Model is limited new Commands.Model with record
      Source    : Services_Access;
      Running   : Ada.Strings.Unbounded.Unbounded_String;
      Now       : States := Idle;
      Quiet     : Boolean := False;
      --  Looking by itself: a failure is not reported, and a skipped version is not offered.
      Declined  : Boolean := False;
      --  The offer was put away (Later).
      Told      : Boolean := False;
      --  What an announced check found is for the person to be told.
      Found     : Updater.Releases.Release;
      Step      : Natural range 0 .. 3 := 0;
      --  Of an install, the file being fetched: the manifest, its signature, the disk image.
      Why       : Ada.Strings.Unbounded.Unbounded_String;
      Last_Done : Float := 0.0;
      Changes   : Parts.Change_Counter;
   end record;

end Update_VM;
