with Updater;

package body Update_VM_Fakes is

   use type Update_VM.Fetch_States;

   overriding
   function Now (Self : Pretend) return Long_Long_Integer
   is (Self.Time);
   overriding
   function Automatic (Self : Pretend) return Boolean
   is (Self.Auto);

   overriding
   procedure Set_Automatic (Self : in out Pretend; To : Boolean) is
   begin
      Self.Auto := To;
   end Set_Automatic;

   overriding
   function Skipped (Self : Pretend) return String
   is (To_String (Self.Kept_Skip));

   overriding
   procedure Set_Skipped (Self : in out Pretend; Text : String) is
   begin
      Self.Kept_Skip := To_Unbounded_String (Text);
   end Set_Skipped;

   overriding
   function Last_Checked (Self : Pretend) return Long_Long_Integer
   is (Self.Checked);

   overriding
   procedure Set_Last_Checked (Self : in out Pretend; At_Time : Long_Long_Integer) is
   begin
      Self.Checked := At_Time;
   end Set_Last_Checked;

   overriding
   function Placement (Self : Pretend) return Updater.Locations.Placements
   is (Self.Where);

   overriding
   procedure Begin_Fetch (Self : in out Pretend; URL, File : String) is
   begin
      pragma Assert (Self.Fetch /= Update_VM.Fetch_Running, "one fetch at a time");
      Append (Self.Asked, File & " " & URL & ";");
      Self.Fetch := Update_VM.Fetch_Running;
   end Begin_Fetch;

   overriding
   function Fetch_State (Self : Pretend) return Update_VM.Fetch_States
   is (Self.Fetch);
   overriding
   function Fetch_Fraction (Self : Pretend) return Float
   is (Self.Progress);
   overriding
   function Fetch_Message (Self : Pretend) return String
   is (To_String (Self.Why_Not));

   overriding
   procedure Cancel_Fetch (Self : in out Pretend) is
   begin
      Self.Cancelled := Self.Cancelled + 1;
   end Cancel_Fetch;

   overriding
   procedure Reset_Fetch (Self : in out Pretend) is
   begin
      if Self.Fetch /= Update_VM.Fetch_Running then
         Self.Fetch := Update_VM.Fetch_Idle;
      end if;
   end Reset_Fetch;

   overriding
   function Text_Of (Self : Pretend; File : String) return String
   is (if File = Update_VM.Release_File then To_String (Self.Release) else "");

   overriding
   procedure Begin_Staging (Self : in out Pretend; Expected : Updater.Versions.Version) is
   begin
      Self.Staged_For := To_Unbounded_String (Updater.Versions.Image (Expected));
      Self.Stage := Update_VM.Stage_Running;
   end Begin_Staging;

   overriding
   function Stage_State (Self : Pretend) return Update_VM.Stage_States
   is (Self.Stage);
   overriding
   function Stage_Message (Self : Pretend) return String
   is (To_String (Self.Stage_Why));

   overriding
   procedure Reset_Stage (Self : in out Pretend) is
   begin
      Self.Stage := Update_VM.Stage_Idle;
   end Reset_Stage;

   overriding
   procedure Hand_Over (Self : in out Pretend; Started : out Boolean) is
   begin
      Self.Handed := Self.Handed + 1;
      Started := Self.Hand_Start;
   end Hand_Over;

   overriding
   function Previous_Failure (Self : Pretend) return String
   is (To_String (Self.Failure));

   overriding
   procedure Forget_Previous_Failure (Self : in out Pretend) is
   begin
      Self.Failure := Null_Unbounded_String;
      Self.Forgotten := Self.Forgotten + 1;
   end Forget_Previous_Failure;

   function Release_Of (Tag : String; Prerelease : Boolean := False) return String is
      Base : constant String := "https://github.com/" & Updater.Repository & "/releases/download/" & Tag & "/";
   begin
      return
        "{""tag_name"":"""
        & Tag
        & """,""draft"":false,""prerelease"":"
        & (if Prerelease then "true" else "false")
        & ",""body"":""## "
        & Tag
        & "\n\n- Add an embedded browser\n- Add a thesaurus"",""assets"":["
        & "{""name"":""Bonxie.dmg"",""browser_download_url"":"""
        & Base
        & "Bonxie.dmg""},"
        & "{""name"":""Bonxie.dmg.manifest"",""browser_download_url"":"""
        & Base
        & "Bonxie.dmg.manifest""},"
        & "{""name"":""Bonxie.dmg.manifest.sig"",""browser_download_url"":"""
        & Base
        & "Bonxie.dmg.manifest.sig""}]}";
   end Release_Of;

end Update_VM_Fakes;
