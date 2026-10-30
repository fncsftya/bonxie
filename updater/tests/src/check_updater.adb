with Ada.Command_Line;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Ada.Streams.Stream_IO;
with Updater;
with Updater.Keys;
with Updater.Locations;
with Updater.Manifests;
with Updater.Releases;
with Updater.Signing;
with Updater.Versions;

--  Checks of the updater's pieces that need no network and no release:
--
--     bin/check_updater <public-key> <signature-file> <message-file> <message-digest>
--
--  The last arguments, when given, are a signature made by tools/update-key.swift, the file it is of and the digest
--  `shasum -a 256` gives for that file; they check the native half (Ed25519 and SHA-256) against another maker.

procedure Check_Updater is

   package V renames Updater.Versions;

   Failures : Natural := 0;

   function Slurp (File_Name : String) return String is
      File : Ada.Streams.Stream_IO.File_Type;
   begin
      Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, File_Name);
      declare
         Text : String (1 .. Natural (Ada.Streams.Stream_IO.Size (File)));
      begin
         String'Read (Ada.Streams.Stream_IO.Stream (File), Text);
         Ada.Streams.Stream_IO.Close (File);
         return Text;
      end;
   end Slurp;

   procedure Check (Name : String; Ok : Boolean) is
   begin
      if not Ok then
         Failures := Failures + 1;
         Ada.Text_IO.Put_Line ("FAIL " & Name);
      end if;
   end Check;

   function Version (Text : String) return V.Version is
      Item : V.Version;
   begin
      pragma Assert (V.Parse (Text, Item), Text);
      return Item;
   end Version;

   function Newer (Candidate, Current : String) return Boolean
   is (V.Is_Newer (Version (Candidate), Version (Current)));

   function Order (Index : Positive) return String
   is (case Index is
         when 1      => "1.0.0-alpha",
         when 2      => "1.0.0-alpha.1",
         when 3      => "1.0.0-alpha.beta",
         when 4      => "1.0.0-beta",
         when 5      => "1.0.0-beta.2",
         when 6      => "1.0.0-beta.11",
         when 7      => "1.0.0-rc.1",
         when others => "1.0.0");
   --  Semantic versioning's own example of the order.

   procedure Reject (Text : String) is
      Item : V.Version;
   begin
      Check ("reject '" & Text & "'", not V.Parse (Text, Item));
   end Reject;

   procedure Versions is
      Item : V.Version;
   begin
      Check ("parse plain", V.Parse ("0.2.0", Item) and then V.Image (Item) = "0.2.0");
      Check ("parse tag", V.Parse ("v0.1.0-alpha", Item) and then V.Image (Item) = "0.1.0-alpha");
      Check ("metadata ignored", V.Parse ("1.2.3+build.5", Item) and then V.Image (Item) = "1.2.3");
      Check
        ("prerelease flag", V.Is_Prerelease (Version ("1.0.0-rc.1")) and then not V.Is_Prerelease (Version ("1.0.0")));
      Reject ("");
      Reject ("v");
      Reject ("1");
      Reject ("1.2");
      Reject ("1.2.3.4");
      Reject ("a.b.c");
      Reject ("1.2.x");
      Reject ("1..3");
      Reject ("-1.2.3");
      Reject ("1.2.3-");
      Reject ("1.2.3-a b");
      Reject ("1234567890.0.0");
      Reject ("1.2.3-0123456789012345678901234567890123456789x");

      Check ("0.2.0 over 0.1.0-alpha", Newer ("0.2.0", "0.1.0-alpha"));
      Check ("not conversely", not Newer ("0.1.0-alpha", "0.2.0"));
      Check ("not itself", not Newer ("0.2.0", "0.2.0"));
      Check ("minor", Newer ("0.10.0", "0.9.9"));
      Check ("major", Newer ("2.0.0", "1.99.99"));
      Check ("patch", Newer ("1.0.1", "1.0.0"));
      Check ("release over its prerelease", Newer ("1.0.0", "1.0.0-rc.1"));
      Check ("prerelease under its release", not Newer ("1.0.0-rc.1", "1.0.0"));
      --  Semantic versioning's own example of the order.
      for Low in 1 .. 7 loop
         for High in Low + 1 .. 8 loop
            Check
              (Order (Low) & " < " & Order (High),
               Newer (Order (High), Order (Low)) and then not Newer (Order (Low), Order (High)));
         end loop;
      end loop;
      Check ("equal", V.Compare (Version ("v1.2.3"), Version ("1.2.3")) = 0);
   end Versions;

   Digest : constant String := [1 .. 64 => 'a'];

   procedure Manifests is
      Item  : Updater.Manifests.Manifest;
      Again : Updater.Manifests.Manifest;
      Good  : constant String :=
        "bonxie-update 1"
        & ASCII.LF
        & "version 0.2.0"
        & ASCII.LF
        & "file Bonxie.dmg"
        & ASCII.LF
        & "size 1234"
        & ASCII.LF
        & "sha256 "
        & Digest
        & ASCII.LF;
   begin
      Check ("manifest parses", Updater.Manifests.Parse (Good, Item));
      Check
        ("manifest fields", Item.Size = 1234 and then Item.Digest = Digest and then V.Image (Item.Version) = "0.2.0");
      Check ("manifest image", Updater.Manifests.Image (Item) = Good);
      Check ("manifest round trip", Updater.Manifests.Parse (Updater.Manifests.Image (Item), Again));
      Check ("no final line feed", not Updater.Manifests.Parse (Good (Good'First .. Good'Last - 1), Item));
      Check ("trailing text", not Updater.Manifests.Parse (Good & "more" & ASCII.LF, Item));
      Check
        ("other file",
         not Updater.Manifests.Parse
               ("bonxie-update 1"
                & ASCII.LF
                & "version 0.2.0"
                & ASCII.LF
                & "file Evil.dmg"
                & ASCII.LF
                & "size 1234"
                & ASCII.LF
                & "sha256 "
                & Digest
                & ASCII.LF,
                Item));
      Check
        ("upper-case digest",
         not Updater.Manifests.Parse
               ("bonxie-update 1"
                & ASCII.LF
                & "version 0.2.0"
                & ASCII.LF
                & "file Bonxie.dmg"
                & ASCII.LF
                & "size 1234"
                & ASCII.LF
                & "sha256 "
                & [1 .. 64 => 'A']
                & ASCII.LF,
                Item));
      Check
        ("short digest",
         not Updater.Manifests.Parse
               ("bonxie-update 1"
                & ASCII.LF
                & "version 0.2.0"
                & ASCII.LF
                & "file Bonxie.dmg"
                & ASCII.LF
                & "size 1234"
                & ASCII.LF
                & "sha256 abc"
                & ASCII.LF,
                Item));
      Check
        ("signed size",
         not Updater.Manifests.Parse
               ("bonxie-update 1"
                & ASCII.LF
                & "version 0.2.0"
                & ASCII.LF
                & "file Bonxie.dmg"
                & ASCII.LF
                & "size -5"
                & ASCII.LF
                & "sha256 "
                & Digest
                & ASCII.LF,
                Item));
      Check ("empty", not Updater.Manifests.Parse ("", Item));
   end Manifests;

   Base : constant String := "https://github.com/" & Updater.Repository & "/releases/download/v0.2.0/";

   function Release_JSON
     (Draft      : String := "false";
      Prerelease : String := "false";
      Tag        : String := "v0.2.0";
      Image_URL  : String := Base & "Bonxie.dmg") return String
   is ("{""tag_name"":"""
       & Tag
       & """,""draft"":"
       & Draft
       & ",""prerelease"":"
       & Prerelease
       & ",""html_url"":""https://github.com/fncsftya/bonxie/releases/tag/v0.2.0"","
       & """body"":""## 0.2.0\n\n- Add an embedded browser\n- Add a thesaurus"","
       & """author"":{""login"":""x"",""id"":1},""assets"":["
       & "{""name"":""Bonxie.dmg"",""size"":5,""browser_download_url"":"""
       & Image_URL
       & """,""uploader"":{""id"":1}},"
       & "{""name"":""Bonxie.dmg.manifest"",""browser_download_url"":"""
       & Base
       & "Bonxie.dmg.manifest""},"
       & "{""name"":""Bonxie.dmg.manifest.sig"",""browser_download_url"":"""
       & Base
       & "Bonxie.dmg.manifest.sig""}]}");

   procedure Releases is
      Item : Updater.Releases.Release;
      use Ada.Strings.Unbounded;
   begin
      Check ("release parses", Updater.Releases.Parse (Release_JSON, Item));
      Check ("release version", V.Image (Item.Version) = "0.2.0");
      Check
        ("release urls",
         To_String (Item.Disk_Image_URL) = Base & "Bonxie.dmg"
         and then To_String (Item.Manifest_URL) = Base & "Bonxie.dmg.manifest"
         and then To_String (Item.Signature_URL) = Base & "Bonxie.dmg.manifest.sig");
      Check ("release notes", Index (Item.Notes, "- Add a thesaurus") > 0);
      Check ("draft", not Updater.Releases.Parse (Release_JSON (Draft => "true"), Item));
      Check ("prerelease", not Updater.Releases.Parse (Release_JSON (Prerelease => "true"), Item));
      Check ("bad tag", not Updater.Releases.Parse (Release_JSON (Tag => "nightly"), Item));
      Check
        ("foreign url",
         not Updater.Releases.Parse
               (Release_JSON (Image_URL => "https://evil.example/releases/download/v0.2.0/Bonxie.dmg"), Item));
      Check
        ("other repository",
         not Updater.Releases.Parse
               (Release_JSON (Image_URL => "https://github.com/evil/bonxie/releases/download/v0.2.0/Bonxie.dmg"),
                Item));
      Check
        ("http url",
         not Updater.Releases.Parse
               (Release_JSON (Image_URL => "http://github.com/fncsftya/bonxie/releases/download/v0.2.0/Bonxie.dmg"),
                Item));
      Check ("not json", not Updater.Releases.Parse ("<html>", Item));
      Check ("empty", not Updater.Releases.Parse ("", Item));
      Check ("rate limit message", not Updater.Releases.Parse ("{""message"":""API rate limit exceeded""}", Item));
      Check
        ("no assets",
         not Updater.Releases.Parse
               ("{""tag_name"":""v0.2.0"",""draft"":false,""prerelease"":false,""assets"":[]}", Item));
      Check ("first line", Updater.Releases.First_Line ("## 0.2.0" & ASCII.LF & ASCII.LF & "- one", 50) = "0.2.0");
      Check ("first line of a list", Updater.Releases.First_Line ("- Add a thesaurus", 50) = "Add a thesaurus");
      Check ("first line cut", Updater.Releases.First_Line ("abcdef", 3) = "abc");
      Check ("first line of nothing", Updater.Releases.First_Line ("" & ASCII.LF & "#" & ASCII.LF, 50) = "");
   end Releases;

   procedure Locations is
      use Updater.Locations;
   begin
      Check ("not bundled", Placement ("") = Not_Bundled);
      Check ("from an image", Placement ("/Volumes/Bonxie/Bonxie.app") = Running_From_Image);
      Check
        ("translocated", Placement ("/private/var/folders/x/AppTranslocation/ABC/d/Bonxie.app") = Running_From_Image);
      Check ("own process runs", Is_Running (Process_Number));
      Check ("no process 0", not Is_Running (0));
   end Locations;

   procedure Native is
   begin
      Check
        ("sha256 of nothing known",
         Updater.Signing.SHA_256 ("/dev/null") = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");
      Check ("sha256 of nothing there", Updater.Signing.SHA_256 ("/nonexistent/file") = "");
      Check ("junk key", not Updater.Signing.Verify ("junk", "message", "junk"));
      Check ("junk signature", not Updater.Signing.Verify (Updater.Keys.Public_Key, "message", "junk"));
   end Native;

begin
   Versions;
   Manifests;
   Releases;
   Locations;
   Native;
   if Ada.Command_Line.Argument_Count = 4 then
      declare
         Key       : constant String := Ada.Command_Line.Argument (1);
         Signature : constant String := Ada.Command_Line.Argument (2);
         Message   : constant String := Ada.Command_Line.Argument (3);
         Expected  : constant String := Ada.Command_Line.Argument (4);
      begin
         Check ("sha256 agrees with shasum", Updater.Signing.SHA_256 (Message) = Expected);
         --  Verify wants the bytes, not a name: read them as the program does.
         Check ("outside signature verifies", Updater.Signing.Verify (Key, Slurp (Message), Slurp (Signature)));
         Check ("changed message fails", not Updater.Signing.Verify (Key, Slurp (Message) & " ", Slurp (Signature)));
      end;
   end if;
   if Failures = 0 then
      Ada.Text_IO.Put_Line ("updater: all checks passed");
   else
      Ada.Text_IO.Put_Line ("updater:" & Failures'Image & " checks failed");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Check_Updater;
