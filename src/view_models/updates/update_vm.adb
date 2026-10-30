with Ada.Strings.Fixed;
with Updater;

package body Update_VM is

   package Unbounded renames Ada.Strings.Unbounded;
   use type Updater.Locations.Placements;

   Day : constant := 24 * 60 * 60;

   Ellipsis : constant String := [Character'Val (16#E2#), Character'Val (16#80#), Character'Val (16#A6#)];
   --  In UTF-8.

   function Image (Item : Natural) return String
   is (Ada.Strings.Fixed.Trim (Item'Image, Ada.Strings.Left));

   procedure Set_State (Self : in out View_Model; To : States);
   procedure Set_State (Self : in out View_Model; To : States) is
   begin
      Self.Now := To;
      Parts.Bump (Self.Changes);
   end Set_State;

   procedure Fail (Self : in out View_Model; Why : String);
   --  Report it, unless the look was quiet: then nothing is said and nothing is kept.

   procedure Fail (Self : in out View_Model; Why : String) is
   begin
      if Self.Quiet and then Self.Now = Checking then
         Self.Source.Reset_Fetch;
         Set_State (Self, Idle);
      else
         Self.Why := Unbounded.To_Unbounded_String (Why);
         Set_State (Self, Failed);
      end if;
   end Fail;

   procedure Initialize (Self : in out View_Model; Source : not null access Services'Class; Running : String) is
   begin
      Self.Source := Source.all'Unrestricted_Access;
      Self.Running := Unbounded.To_Unbounded_String (Running);
      Self.Now := Idle;
      Self.Quiet := False;
      Self.Declined := False;
      Self.Told := False;
      Self.Step := 0;
      Self.Why := Unbounded.Null_Unbounded_String;
      Self.Last_Done := 0.0;
      Parts.Bump (Self.Changes);
   end Initialize;

   procedure Begin_Check (Self : in out View_Model; Quiet, Told : Boolean);
   procedure Begin_Check (Self : in out View_Model; Quiet, Told : Boolean) is
   begin
      Self.Quiet := Quiet;
      Self.Declined := False;
      Self.Told := Told;
      Self.Source.Reset_Fetch;
      Self.Source.Begin_Fetch (Updater.Latest_URL, Release_File);
      Set_State (Self, Checking);
   end Begin_Check;

   procedure Start (Self : in out View_Model) is
      Failure : constant String := Self.Source.Previous_Failure;
      Last    : constant Long_Long_Integer := Self.Source.Last_Checked;
      Time    : constant Long_Long_Integer := Self.Source.Now;
   begin
      if Failure /= "" then
         Self.Source.Forget_Previous_Failure;
         Self.Why := Unbounded.To_Unbounded_String ("The last update did not install: " & Failure);
         Set_State (Self, Failed);
      elsif Self.Source.Automatic
        and then Self.Source.Placement = Updater.Locations.Replaceable
        and then (Last > Time or else Time - Last >= Day)
      then
         Begin_Check (Self, Quiet => True, Told => False);
      end if;
   end Start;

   procedure Finish_Check (Self : in out View_Model);
   --  The newest release has come: see whether it is one to offer.

   procedure Finish_Check (Self : in out View_Model) is
      Text  : constant String := Self.Source.Text_Of (Release_File);
      Found : Updater.Releases.Release;
      Mine  : Updater.Versions.Version;
   begin
      Self.Source.Reset_Fetch;
      if not Updater.Releases.Parse (Text, Found)
        or else not Updater.Versions.Parse (Unbounded.To_String (Self.Running), Mine)
      then
         Fail (Self, "GitHub did not answer with a release");
         return;
      end if;
      Self.Source.Set_Last_Checked (Self.Source.Now);
      if not Updater.Versions.Is_Newer (Found.Version, Mine) then
         Set_State (Self, (if Self.Quiet then Idle else Up_To_Date));
      elsif Self.Quiet and then Self.Source.Skipped = Updater.Versions.Image (Found.Version) then
         Set_State (Self, Idle);
      else
         Self.Found := Found;
         Set_State (Self, Available);
      end if;
   end Finish_Check;

   procedure Fetch_Next (Self : in out View_Model);
   --  Begin the file of the install that comes next.

   procedure Fetch_Next (Self : in out View_Model) is
   begin
      Self.Source.Reset_Fetch;
      Self.Step := Self.Step + 1;
      case Self.Step is
         when 1      =>
            Self.Source.Begin_Fetch (Unbounded.To_String (Self.Found.Manifest_URL), Updater.Manifest_Name);

         when 2      =>
            Self.Source.Begin_Fetch (Unbounded.To_String (Self.Found.Signature_URL), Updater.Signature_Name);

         when others =>
            Self.Source.Begin_Fetch (Unbounded.To_String (Self.Found.Disk_Image_URL), Updater.Disk_Image_Name);
      end case;
      Parts.Bump (Self.Changes);
   end Fetch_Next;

   procedure Poll (Self : in out View_Model) is
   begin
      case Self.Now is
         when Checking    =>
            case Self.Source.Fetch_State is
               when Fetch_Done   =>
                  Finish_Check (Self);

               when Fetch_Failed =>
                  declare
                     Why : constant String := Self.Source.Fetch_Message;
                  begin
                     Fail (Self, "Could not look for updates (" & Why & ")");
                  end;

               when others       =>
                  null;
            end case;

         when Downloading =>
            case Self.Source.Fetch_State is
               when Fetch_Done    =>
                  if Self.Step < 3 then
                     Fetch_Next (Self);
                  else
                     Self.Source.Reset_Fetch;
                     Self.Source.Begin_Staging (Self.Found.Version);
                     Set_State (Self, Verifying);
                  end if;

               when Fetch_Failed  =>
                  declare
                     Why : constant String := Self.Source.Fetch_Message;
                  begin
                     Fail (Self, "The update could not be downloaded (" & Why & ")");
                  end;

               when Fetch_Running =>
                  --  The picture of how far on it is moves with the percent, not each tick.
                  if Self.Step = 3 and then abs (Self.Source.Fetch_Fraction - Self.Last_Done) >= 0.01 then
                     Self.Last_Done := Self.Source.Fetch_Fraction;
                     Parts.Bump (Self.Changes);
                  end if;

               when Fetch_Idle    =>
                  null;
            end case;

         when Verifying   =>
            case Self.Source.Stage_State is
               when Stage_Done   =>
                  declare
                     Started : Boolean;
                  begin
                     Self.Source.Hand_Over (Started);
                     if Started then
                        Set_State (Self, Handing_Over);
                     else
                        Fail (Self, "The update could not be started");
                     end if;
                  end;

               when Stage_Failed =>
                  declare
                     Why : constant String := Self.Source.Stage_Message;
                  begin
                     Self.Source.Reset_Stage;
                     Fail (Self, "The update was not installed: " & Why);
                  end;

               when others       =>
                  null;
            end case;

         when Stopping    =>
            if Self.Source.Fetch_State /= Fetch_Running then
               Self.Source.Reset_Fetch;
               Set_State (Self, Available);
            end if;

         when others      =>
            null;
      end case;
   end Poll;

   function State (Self : View_Model) return States
   is (Self.Now);

   function Attention (Self : View_Model) return Attentions
   is (case Self.Now is
         when Available                          => (if Self.Declined then Nothing else Offering),
         when Downloading | Verifying | Stopping => Working,
         when Failed                             => Problem,
         when Up_To_Date                         => (if Self.Told then Problem else Nothing),
         when Handing_Over                       => Leaving,
         when Idle | Checking                    => Nothing);

   function Current (Self : View_Model) return String
   is (Unbounded.To_String (Self.Running));

   function Newest (Self : View_Model) return String
   is (Updater.Versions.Image (Self.Found.Version));

   function Automatic (Self : View_Model) return Boolean
   is (Self.Source.Automatic);

   function Fraction (Self : View_Model) return Float
   is (case Self.Now is
         when Downloading              =>
           (if Self.Step < 3 then 0.0 else Float'Min (1.0, Float'Max (0.0, Self.Source.Fetch_Fraction))),
         when Verifying | Handing_Over => 1.0,
         when others                   => 0.0);

   function Version_Line (Self : View_Model) return String
   is ("Bonxie " & Unbounded.To_String (Self.Running));

   function Percent (Self : View_Model) return String
   is (Image (Natural (Fraction (Self) * 100.0)) & "%");

   function Status (Self : View_Model) return String
   is (case Self.Now is
         when Idle         => "",
         when Checking     => "Checking" & Ellipsis,
         when Up_To_Date   => "Bonxie is up to date.",
         when Available    => "Version " & Newest (Self) & " is available.",
         when Downloading  => "Downloading " & Newest (Self) & " " & Percent (Self),
         when Verifying    => "Checking the download" & Ellipsis,
         when Stopping     => "Cancelling" & Ellipsis,
         when Handing_Over => "Restarting" & Ellipsis,
         when Failed       => Unbounded.To_String (Self.Why));

   function Offer_Message (Self : View_Model) return String
   is ("Bonxie " & Newest (Self) & " is available. You have " & Current (Self) & ".");

   function Offer_Note (Self : View_Model) return String is
      Line : constant String := Updater.Releases.First_Line (Unbounded.To_String (Self.Found.Notes), 100);
   begin
      return (if Line = "" then "Updating restarts Bonxie; your work is saved first." else "New: " & Line);
   end Offer_Note;

   function Working_Message (Self : View_Model) return String
   is (case Self.Now is
         when Downloading => "Downloading Bonxie " & Newest (Self) & " " & Percent (Self),
         when Stopping    => "Cancelling" & Ellipsis,
         when others      => "Checking and preparing Bonxie " & Newest (Self) & Ellipsis);

   function Working_Note (Self : View_Model) return String
   is ("Bonxie restarts when it is ready.");

   function Problem_Message (Self : View_Model) return String
   is (if Self.Now = Up_To_Date
       then "Bonxie " & Current (Self) & " is up to date."
       else Unbounded.To_String (Self.Why));

   function Problem_Note (Self : View_Model) return String is
   begin
      if Self.Now = Up_To_Date then
         return "It is the newest version.";
      end if;
      case Self.Source.Placement is
         when Updater.Locations.Running_From_Image =>
            return "Drag Bonxie to the Applications folder, open it there, and try again.";

         when Updater.Locations.Read_Only          =>
            return "Bonxie's folder is not yours to change. Download the new version from GitHub.";

         when others                               =>
            return "Nothing was changed. You can try again from the settings.";
      end case;
   end Problem_Note;

   function Can_Cancel (Self : View_Model) return Boolean
   is (Self.Now = Downloading);

   overriding
   function Version (Self : View_Model) return Parts.Version_Number
   is (Parts.Value (Self.Changes));

   overriding
   function Can_Execute (Self : View_Model; What : Command; Index : Natural := 0) return Boolean is
      pragma Unreferenced (Index);
   begin
      return
        (case What is
           when Check_Now        => Self.Now in Idle | Up_To_Date | Available | Failed,
           when Toggle_Automatic => True,
           when Install | Skip   => Self.Now = Available,
           when Later            => Self.Now in Available | Failed | Up_To_Date,
           when Cancel           => Self.Now = Downloading);
   end Can_Execute;

   procedure Begin_Install (Self : in out View_Model);
   procedure Begin_Install (Self : in out View_Model) is
   begin
      case Self.Source.Placement is
         when Updater.Locations.Replaceable        =>
            Self.Step := 0;
            Self.Last_Done := 0.0;
            Self.Quiet := False;
            Self.Source.Reset_Stage;
            Set_State (Self, Downloading);
            Fetch_Next (Self);

         when Updater.Locations.Not_Bundled        =>
            Self.Why :=
              Unbounded.To_Unbounded_String
                ("This copy of Bonxie is not an installed application, so it cannot update itself.");
            Set_State (Self, Failed);

         when Updater.Locations.Running_From_Image =>
            Self.Why :=
              Unbounded.To_Unbounded_String
                ("Bonxie " & Newest (Self) & " is available, but this copy is running from a disk image.");
            Set_State (Self, Failed);

         when Updater.Locations.Read_Only          =>
            Self.Why :=
              Unbounded.To_Unbounded_String
                ("Bonxie " & Newest (Self) & " is available, but this copy cannot be replaced.");
            Set_State (Self, Failed);
      end case;
   end Begin_Install;

   overriding
   procedure Execute (Self : in out View_Model; What : Command; Index : Natural := 0) is
   begin
      case What is
         when Check_Now        =>
            Begin_Check (Self, Quiet => False, Told => Index = Announcing);

         when Toggle_Automatic =>
            Self.Source.Set_Automatic (not Self.Source.Automatic);
            Parts.Bump (Self.Changes);

         when Install          =>
            Begin_Install (Self);

         when Skip             =>
            Self.Source.Set_Skipped (Newest (Self));
            Set_State (Self, Idle);

         when Later            =>
            if Self.Now in Failed | Up_To_Date then
               Set_State (Self, Idle);
            else
               Self.Declined := True;
               Parts.Bump (Self.Changes);
            end if;

         when Cancel           =>
            Self.Source.Cancel_Fetch;
            Self.Declined := True;  --  It is not to be offered again at once.
            Set_State (Self, Stopping);
      end case;
   end Execute;

end Update_VM;
