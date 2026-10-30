with Updater.Versions;

--  Making a download ready, in the background, one at a time: the manifest's signature is checked, the disk
--  image is the one it describes, the application inside is taken out of it and is the version that was
--  promised and is signed (as macOS reckons: ad hoc, intact). The caller polls (State) and does not wait.
--
--  Nothing here changes the installed program. Hand_Over starts the script that does, once this program is gone.

package Updater.Staging is

   type States is (Idle, Running, Done, Failed);

   Max_Message : constant := 160;

   procedure Start (Directory, Disk_Image, Manifest, Signature, Public_Key : String; Expected : Versions.Version)
   with Pre => State /= Running and then Directory /= "", Post => State = Running;
   --  Check the files (the disk image, the manifest and its signature, fetched into Directory by the caller) against
   --  the key, as the version that was promised, and take Bonxie.app out of the image into Directory.

   function State return States;

   function Message return String
   with Pre => State = Failed, Post => Message'Result'Length <= Max_Message;
   --  Why it failed.

   function Application return String
   with Pre => State = Done;
   --  Where the staged application is.

   procedure Reset
   with Pre => State /= Running, Post => State = Idle;

   procedure Hand_Over (Script, Staged, Target, Directory : String; Process : Natural; Started : out Boolean)
   with Pre => State = Done;
   --  Start the script (`sh Script`) on its own, to wait for the process to end and then put Staged in the place
   --  of Target, with its progress and any failure noted in Directory. Started is False if it could not be started;
   --  the caller then quits only if it is True. The script is copied into Directory first, as Target holds it.

   function Last_Failure (Directory : String) return String;
   --  What the script said of the last update that did not take, "" if it never did. It is kept until Forget.

   procedure Forget_Failure (Directory : String);

end Updater.Staging;
