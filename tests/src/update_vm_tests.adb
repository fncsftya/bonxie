with Ada.Strings.Unbounded;
with Goldens;
with Update_VM;
with Update_VM_Fakes;
with Updater.Locations;

package body Update_VM_Tests is

   package Fakes renames Update_VM_Fakes;
   package Unbounded renames Ada.Strings.Unbounded;

   use all type Update_VM.Command;
   use type Update_VM.Fetch_States;

   procedure Check (Name : String; Expected, Actual : String) renames Goldens.Check_Text;

   function Image (Value : Boolean) return String
   is (Value'Image);

   function Can (Model : Update_VM.View_Model; What : Update_VM.Command) return String
   is (Image (Update_VM.Can_Execute (Model, What)));

   Latest_Asked : constant String := "release.json https://api.github.com/repos/fncsftya/bonxie/releases/latest;";

   Ellipsis : constant String := [Character'Val (16#E2#), Character'Val (16#80#), Character'Val (16#A6#)];

   function Now_Is (Model : Update_VM.View_Model) return String
   is (Update_VM.State (Model)'Image & " " & Update_VM.Attention (Model)'Image);
   --  What it is and what it wants shown.

   function Rules (Model : Update_VM.View_Model) return String
   is (Can (Model, Check_Now)
       & " "
       & Can (Model, Install)
       & " "
       & Can (Model, Skip)
       & " "
       & Can (Model, Later)
       & " "
       & Can (Model, Cancel));
   --  Check_Now Install Skip Later Cancel.

   --  A fetch of the release that has come.
   procedure Release_Comes (Fake : in out Fakes.Pretend; Model : in out Update_VM.View_Model; Text : String);

   procedure Release_Comes (Fake : in out Fakes.Pretend; Model : in out Update_VM.View_Model; Text : String) is
   begin
      Fake.Release := Unbounded.To_Unbounded_String (Text);
      Fake.Fetch := Update_VM.Fetch_Done;
      Update_VM.Poll (Model);
   end Release_Comes;

   --  The fake has been asked for something: it is fetched, as far as the fake goes.
   procedure Fetched (Fake : in out Fakes.Pretend; Model : in out Update_VM.View_Model);

   procedure Fetched (Fake : in out Fakes.Pretend; Model : in out Update_VM.View_Model) is
   begin
      Fake.Fetch := Update_VM.Fetch_Done;
      Update_VM.Poll (Model);
   end Fetched;

   function Asked (Fake : Fakes.Pretend) return String
   is (Unbounded.To_String (Fake.Asked));

   procedure Not_Newer (Fake : in out Fakes.Pretend; Model : in out Update_VM.View_Model; Tag : String) is
   begin
      Update_VM.Execute (Model, Check_Now);
      Release_Comes (Fake, Model, Fakes.Release_Of (Tag));
      Check ("update-not-newer-" & Tag, "UP_TO_DATE NOTHING", Now_Is (Model));
      Check ("update-not-newer-status-" & Tag, "Bonxie is up to date.", Update_VM.Status (Model));
   end Not_Newer;

   Base : constant String := "https://github.com/fncsftya/bonxie/releases/download/v0.3.0/";

   procedure Checking is
      Fake  : aliased Fakes.Pretend;
      Model : Update_VM.View_Model;
   begin
      Update_VM.Initialize (Model, Fake'Access, "0.2.0");
      Check
        ("update-first",
         "IDLE NOTHING TRUE FALSE TRUE FALSE",
         Now_Is (Model)
         & " "
         & Image (Update_VM.Automatic (Model))
         & " "
         & Can (Model, Install)
         & " "
         & Can (Model, Check_Now)
         & " "
         & Can (Model, Cancel));
      Check ("update-version-line", "Bonxie 0.2.0", Update_VM.Version_Line (Model));

      --  Nothing is asked of GitHub until a check is.
      Check ("update-nothing-asked", "", Asked (Fake));
      Update_VM.Execute (Model, Check_Now);
      Check ("update-checking", "CHECKING NOTHING", Now_Is (Model));
      Check
        ("update-asks-github",
         "release.json https://api.github.com/repos/fncsftya/bonxie/releases/latest;",
         Asked (Fake));
      Check ("update-checking-rules", "FALSE FALSE FALSE FALSE FALSE", Rules (Model));
      Check ("update-checking-status", "Checking" & Ellipsis, Update_VM.Status (Model));
      Update_VM.Poll (Model);
      Check ("update-still-checking", "CHECKING", Update_VM.State (Model)'Image);

      --  A newer release.
      Release_Comes (Fake, Model, Fakes.Release_Of ("v0.3.0"));
      Check ("update-newer", "AVAILABLE OFFERING 0.3.0", Now_Is (Model) & " " & Update_VM.Newest (Model));
      Check ("update-newer-rules", "TRUE TRUE TRUE TRUE FALSE", Rules (Model));
      Check ("update-checked-kept", "1000000", Fake.Checked'Image (2 .. Fake.Checked'Image'Last));
      Check ("update-offer-words", "Bonxie 0.3.0 is available. You have 0.2.0.", Update_VM.Offer_Message (Model));
      Check ("update-offer-note", "New: v0.3.0", Update_VM.Offer_Note (Model));
      Check ("update-available-status", "Version 0.3.0 is available.", Update_VM.Status (Model));
      Check ("update-nothing-fetched", Latest_Asked, Asked (Fake));

      --  The same version, an older one and a prerelease are not newer.
      Not_Newer (Fake, Model, "v0.2.0");
      Not_Newer (Fake, Model, "v0.1.0-alpha");
      Update_VM.Execute (Model, Check_Now);
      Release_Comes (Fake, Model, Fakes.Release_Of ("v0.3.0", Prerelease => True));
      Check ("update-prerelease", "FAILED PROBLEM", Now_Is (Model));
      Check ("update-prerelease-words", "GitHub did not answer with a release", Update_VM.Problem_Message (Model));
      Update_VM.Execute (Model, Later);
      Check ("update-failure-put-away", "IDLE NOTHING", Now_Is (Model));

      --  Something that is not a release, and a fetch that fails.
      Update_VM.Execute (Model, Check_Now);
      Release_Comes (Fake, Model, "<html>rate limited</html>");
      Check ("update-not-json", "FAILED", Update_VM.State (Model)'Image);
      Update_VM.Execute (Model, Later);
      Update_VM.Execute (Model, Check_Now);
      Fake.Why_Not := Unbounded.To_Unbounded_String ("the transfer failed (curl exit 22)");
      Fake.Fetch := Update_VM.Fetch_Failed;
      Update_VM.Poll (Model);
      Check
        ("update-fetch-failed",
         "Could not look for updates (the transfer failed (curl exit 22))",
         Update_VM.Status (Model));
      Check ("update-nothing-kept-on-failure", "1000000", Fake.Checked'Image (2 .. Fake.Checked'Image'Last));

      --  A check is announced when the menu asks for it.
      Update_VM.Execute (Model, Later);
      Update_VM.Execute (Model, Check_Now, Update_VM.Announcing);
      Release_Comes (Fake, Model, Fakes.Release_Of ("v0.2.0"));
      Check ("update-announced", "UP_TO_DATE PROBLEM", Now_Is (Model));
      Check ("update-announced-words", "Bonxie 0.2.0 is up to date.", Update_VM.Problem_Message (Model));
      Update_VM.Execute (Model, Later);
      Check ("update-announced-put-away", "IDLE NOTHING", Now_Is (Model));

      --  The setting.
      Update_VM.Execute (Model, Toggle_Automatic);
      Check ("update-toggled", "FALSE", Image (Fake.Auto));
      Update_VM.Execute (Model, Toggle_Automatic);
      Check ("update-toggled-back", "TRUE", Image (Fake.Auto));
   end Checking;

   procedure Offering is
      Fake  : aliased Fakes.Pretend;
      Model : Update_VM.View_Model;
   begin
      Update_VM.Initialize (Model, Fake'Access, "0.2.0");

      --  Later puts the offer away, and the version stays known.
      Update_VM.Execute (Model, Check_Now);
      Release_Comes (Fake, Model, Fakes.Release_Of ("v0.3.0"));
      Update_VM.Execute (Model, Later);
      Check ("offer-later", "AVAILABLE NOTHING", Now_Is (Model));
      Check ("offer-later-status", "Version 0.3.0 is available.", Update_VM.Status (Model));
      Check ("offer-later-nothing-fetched", Latest_Asked, Asked (Fake));
      --  Asking again brings it back.
      Update_VM.Execute (Model, Check_Now);
      Release_Comes (Fake, Model, Fakes.Release_Of ("v0.3.0"));
      Check ("offer-again", "AVAILABLE OFFERING", Now_Is (Model));

      --  Skip keeps it from a check that was not asked for, not from one that was.
      Update_VM.Execute (Model, Skip);
      Check ("offer-skip", "IDLE NOTHING 0.3.0", Now_Is (Model) & " " & Unbounded.To_String (Fake.Kept_Skip));
      Fake.Checked := 0;
      Update_VM.Start (Model);
      Check ("offer-skip-quiet", "CHECKING", Update_VM.State (Model)'Image);
      Release_Comes (Fake, Model, Fakes.Release_Of ("v0.3.0"));
      Check ("offer-skipped-not-offered", "IDLE NOTHING", Now_Is (Model));
      Update_VM.Execute (Model, Check_Now);
      Release_Comes (Fake, Model, Fakes.Release_Of ("v0.3.0"));
      Check ("offer-skipped-asked-for", "AVAILABLE OFFERING", Now_Is (Model));
      --  A version after it is offered.
      Fake.Checked := 0;
      Update_VM.Execute (Model, Later);
      Fake.Kept_Skip := Unbounded.To_Unbounded_String ("0.3.0");
      Update_VM.Execute (Model, Later);
      Update_VM.Start (Model);
      Release_Comes (Fake, Model, Fakes.Release_Of ("v0.3.1"));
      Check ("offer-next-version", "AVAILABLE OFFERING 0.3.1", Now_Is (Model) & " " & Update_VM.Newest (Model));
   end Offering;

   procedure Installing is
      Fake  : aliased Fakes.Pretend;
      Model : Update_VM.View_Model;

      procedure Offered is
      begin
         Update_VM.Execute (Model, Check_Now);
         Release_Comes (Fake, Model, Fakes.Release_Of ("v0.3.0"));
      end Offered;
   begin
      Update_VM.Initialize (Model, Fake'Access, "0.2.0");
      Offered;

      --  The whole way.
      Fake.Asked := Unbounded.Null_Unbounded_String;
      Update_VM.Execute (Model, Install);
      Check ("install-first-file", "DOWNLOADING WORKING", Now_Is (Model));
      Check ("install-asks-manifest", "Bonxie.dmg.manifest " & Base & "Bonxie.dmg.manifest;", Asked (Fake));
      Check ("install-rules", "FALSE FALSE FALSE FALSE TRUE", Rules (Model));
      Fetched (Fake, Model);
      Check
        ("install-asks-signature",
         "Bonxie.dmg.manifest "
         & Base
         & "Bonxie.dmg.manifest;"
         & "Bonxie.dmg.manifest.sig "
         & Base
         & "Bonxie.dmg.manifest.sig;",
         Asked (Fake));
      Fetched (Fake, Model);
      Check
        ("install-asks-image",
         "Bonxie.dmg.manifest "
         & Base
         & "Bonxie.dmg.manifest;"
         & "Bonxie.dmg.manifest.sig "
         & Base
         & "Bonxie.dmg.manifest.sig;"
         & "Bonxie.dmg "
         & Base
         & "Bonxie.dmg;",
         Asked (Fake));
      Fake.Progress := 0.42;
      Update_VM.Poll (Model);
      Check ("install-progress", "Downloading Bonxie 0.3.0 42%", Update_VM.Working_Message (Model));
      Check ("install-fraction", "42", Natural'Image (Natural (Update_VM.Fraction (Model) * 100.0)) (2 .. 3));
      Check ("install-not-staged-yet", "", Unbounded.To_String (Fake.Staged_For));
      Fetched (Fake, Model);
      Check
        ("install-verifying", "VERIFYING WORKING 0.3.0", Now_Is (Model) & " " & Unbounded.To_String (Fake.Staged_For));
      Check ("install-verifying-rules", "FALSE FALSE FALSE FALSE FALSE", Rules (Model));
      Update_VM.Poll (Model);
      Check ("install-waits-for-staging", "VERIFYING 0", Update_VM.State (Model)'Image & Fake.Handed'Image);
      Fake.Stage := Update_VM.Stage_Done;
      Update_VM.Poll (Model);
      Check ("install-hands-over", "HANDING_OVER LEAVING 1", Now_Is (Model) & Fake.Handed'Image);

      --  A download that fails.
      Fake.Fetch := Update_VM.Fetch_Idle;
      Fake.Stage := Update_VM.Stage_Idle;
      Fake.Handed := 0;
      Update_VM.Initialize (Model, Fake'Access, "0.2.0");
      Offered;
      Update_VM.Execute (Model, Install);
      Fetched (Fake, Model);
      Fake.Why_Not := Unbounded.To_Unbounded_String ("the transfer did not finish");
      Fake.Fetch := Update_VM.Fetch_Failed;
      Update_VM.Poll (Model);
      Check
        ("install-download-failed",
         "FAILED PROBLEM The update could not be downloaded (the transfer did not finish)",
         Now_Is (Model) & " " & Update_VM.Problem_Message (Model));
      Check ("install-failed-nothing-handed", "0", Fake.Handed'Image (2 .. 2));

      --  A download that is not what was signed.
      Update_VM.Execute (Model, Later);
      Fake.Fetch := Update_VM.Fetch_Idle;
      Offered;
      Update_VM.Execute (Model, Install);
      Fetched (Fake, Model);
      Fetched (Fake, Model);
      Fetched (Fake, Model);
      Fake.Stage := Update_VM.Stage_Failed;
      Fake.Stage_Why := Unbounded.To_Unbounded_String ("the update is not signed by its author");
      Update_VM.Poll (Model);
      Check
        ("install-not-signed",
         "FAILED The update was not installed: the update is not signed by its author",
         Update_VM.State (Model)'Image & " " & Update_VM.Status (Model));
      Check ("install-not-signed-nothing-handed", "0", Fake.Handed'Image (2 .. 2));
      Check ("install-not-signed-stage-reset", "STAGE_IDLE", Fake.Stage'Image);

      --  The script cannot be started.
      Update_VM.Execute (Model, Later);
      Fake.Fetch := Update_VM.Fetch_Idle;
      Fake.Hand_Start := False;
      Offered;
      Update_VM.Execute (Model, Install);
      Fetched (Fake, Model);
      Fetched (Fake, Model);
      Fetched (Fake, Model);
      Fake.Stage := Update_VM.Stage_Done;
      Update_VM.Poll (Model);
      Check
        ("install-no-script",
         "FAILED The update could not be started",
         Update_VM.State (Model)'Image & " " & Update_VM.Status (Model));
      Fake.Hand_Start := True;

      --  Cancelled while the image comes: it stops, waits for the transfer to end, and is not offered again at once.
      Update_VM.Execute (Model, Later);
      Fake.Fetch := Update_VM.Fetch_Idle;
      Offered;
      Update_VM.Execute (Model, Install);
      Fetched (Fake, Model);
      Fetched (Fake, Model);
      Update_VM.Execute (Model, Cancel);
      Check ("install-cancel", "STOPPING WORKING 1", Now_Is (Model) & Fake.Cancelled'Image);
      Update_VM.Poll (Model);
      Check ("install-cancel-waits", "STOPPING", Update_VM.State (Model)'Image);
      Fake.Fetch := Update_VM.Fetch_Failed;
      Update_VM.Poll (Model);
      Check ("install-cancelled", "AVAILABLE NOTHING", Now_Is (Model));

      --  Where it cannot be replaced.
      for Where in Updater.Locations.Not_Bundled .. Updater.Locations.Read_Only loop
         Fake.Where := Where;
         Fake.Fetch := Update_VM.Fetch_Idle;
         Fake.Asked := Unbounded.Null_Unbounded_String;
         Update_VM.Initialize (Model, Fake'Access, "0.2.0");
         Offered;
         Fake.Asked := Unbounded.Null_Unbounded_String;
         Update_VM.Execute (Model, Install);
         Check ("install-not-here-" & Where'Image, "FAILED PROBLEM ", Now_Is (Model) & " ");
         Check ("install-not-here-fetches-nothing-" & Where'Image, "", Asked (Fake));
      end loop;
      Fake.Where := Updater.Locations.Running_From_Image;
      Check
        ("install-not-here-words",
         "Drag Bonxie to the Applications folder, open it there, and try again.",
         Update_VM.Problem_Note (Model));
   end Installing;

   procedure Starting is
      Fake  : aliased Fakes.Pretend;
      Model : Update_VM.View_Model;
      Day   : constant := 86_400;

      procedure Fresh is
      begin
         Fake.Fetch := Update_VM.Fetch_Idle;
         Fake.Asked := Unbounded.Null_Unbounded_String;
         Update_VM.Initialize (Model, Fake'Access, "0.2.0");
      end Fresh;
   begin
      --  Due, wanted and possible: it looks, quietly.
      Fake.Time := 10 * Day;
      Fake.Checked := 5 * Day;
      Fresh;
      Update_VM.Start (Model);
      Check ("start-looks", "CHECKING NOTHING", Now_Is (Model));
      --  A quiet look that fails says nothing.
      Fake.Fetch := Update_VM.Fetch_Failed;
      Update_VM.Poll (Model);
      Check ("start-failure-is-quiet", "IDLE NOTHING", Now_Is (Model));
      Check ("start-failure-keeps-no-time", "432000", Fake.Checked'Image (2 .. Fake.Checked'Image'Last));
      --  One that finds a newer release offers it.
      Fresh;
      Update_VM.Start (Model);
      Release_Comes (Fake, Model, Fakes.Release_Of ("v0.3.0"));
      Check ("start-offers", "AVAILABLE OFFERING", Now_Is (Model));
      --  One that finds nothing says nothing.
      Fresh;
      Update_VM.Start (Model);
      Release_Comes (Fake, Model, Fakes.Release_Of ("v0.2.0"));
      Check ("start-nothing-new-is-quiet", "IDLE NOTHING", Now_Is (Model));
      Check ("start-time-kept", "864000", Fake.Checked'Image (2 .. Fake.Checked'Image'Last));

      --  Not due, off, or not where it can be replaced: it does not look.
      Fake.Checked := 10 * Day - 100;
      Fresh;
      Update_VM.Start (Model);
      Check ("start-not-due", "IDLE", Update_VM.State (Model)'Image);
      Fake.Checked := 100 * Day;
      Fresh;
      Update_VM.Start (Model);
      Check ("start-clock-went-back", "CHECKING", Update_VM.State (Model)'Image);
      Fake.Checked := 0;
      Fake.Auto := False;
      Fresh;
      Update_VM.Start (Model);
      Check ("start-turned-off", "IDLE", Update_VM.State (Model)'Image);
      Check ("start-turned-off-asks-nothing", "", Asked (Fake));
      Fake.Auto := True;
      Fake.Where := Updater.Locations.Not_Bundled;
      Fresh;
      Update_VM.Start (Model);
      Check ("start-not-bundled", "IDLE", Update_VM.State (Model)'Image);
      Fake.Where := Updater.Locations.Read_Only;
      Fresh;
      Update_VM.Start (Model);
      Check ("start-read-only", "IDLE", Update_VM.State (Model)'Image);
      Fake.Where := Updater.Locations.Replaceable;

      --  An update that did not take is told, once.
      Fake.Failure := Unbounded.To_Unbounded_String ("the new version could not be written beside the old");
      Fresh;
      Update_VM.Start (Model);
      Check
        ("start-previous-failure",
         "FAILED PROBLEM The last update did not install: the new version could not be written beside the old",
         Now_Is (Model) & " " & Update_VM.Problem_Message (Model));
      Check ("start-previous-failure-forgotten", "1", Fake.Forgotten'Image (2 .. 2));
      Update_VM.Execute (Model, Later);
      Fresh;
      Update_VM.Start (Model);
      Check ("start-not-told-twice", "CHECKING", Update_VM.State (Model)'Image);
   end Starting;

end Update_VM_Tests;
