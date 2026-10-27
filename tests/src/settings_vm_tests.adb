with Ada.Directories;
with Ada.Assertions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Goldens;
with Pomarine.View_Models;
with Preferences;
with Settings_VM.Disk;
with Settings_VM_Fakes;
with Speech.Models;

package body Settings_VM_Tests is

   package Parts renames Pomarine.View_Models;
   package Fakes renames Settings_VM_Fakes;

   use type Parts.Version_Number;
   use type Preferences.Background_Modes;
   use type Preferences.Speech_Models;
   use type Preferences.Theme_Choices;
   use type Speech.Models.States;
   use all type Settings_VM.Command;

   procedure Check (Name : String; Expected, Actual : String) renames Goldens.Check_Text;

   function Image (Value : Boolean) return String
   is (Value'Image);

   procedure Command_Rules is
      Voice : aliased Fakes.Pretend;
      Saved : aliased Fakes.Notes;
      Model : Settings_VM.View_Model;
      Seen  : Parts.Version_Number;
   begin
      Settings_VM.Initialize (Model, Voice'Access, Saved'Access, "/nowhere");
      Check
        ("settings-vm-first",
         "FALSE FALSE SYSTEM WATERCOLOUR MACOS",
         Image (Settings_VM.Is_Showing (Model))
         & " "
         & Image (Settings_VM.VSync (Model))
         & " "
         & Settings_VM.Theme (Model)'Image
         & " "
         & Settings_VM.Background (Model)'Image
         & " "
         & Settings_VM.Speech_Model (Model)'Image);

      --  What can be done when.
      Check
        ("settings-vm-can-closed",
         "TRUE FALSE",
         Image (Settings_VM.Can_Execute (Model, Open)) & " " & Image (Settings_VM.Can_Execute (Model, Close)));
      Settings_VM.Execute (Model, Open);
      Check
        ("settings-vm-can-open",
         "FALSE TRUE TRUE",
         Image (Settings_VM.Can_Execute (Model, Open))
         & " "
         & Image (Settings_VM.Can_Execute (Model, Close))
         & " "
         & Image (Settings_VM.Is_Showing (Model)));
      Check
        ("settings-vm-can-choices",
         "TRUE TRUE TRUE TRUE TRUE",
         Image (Settings_VM.Can_Execute (Model, Choose_Theme))
         & " "
         & Image (Settings_VM.Can_Execute (Model, Choose_Background))
         & " "
         & Image (Settings_VM.Can_Execute (Model, Choose_Speech_Model))
         & " "
         & Image (Settings_VM.Can_Execute (Model, Toggle_VSync))
         & " "
         & Image (Settings_VM.Can_Execute (Model, Reseed)));
      Settings_VM.Execute (Model, Close);
      Check ("settings-vm-closed", "FALSE", Image (Settings_VM.Is_Showing (Model)));

      --  A choice is a change, and the same again is not.
      Seen := Settings_VM.Version (Model);
      Settings_VM.Execute (Model, Choose_Theme, Preferences.Theme_Choices'Pos (Preferences.Dark));
      Check
        ("settings-vm-theme",
         "DARK TRUE",
         Settings_VM.Theme (Model)'Image & " " & Image (Settings_VM.Version (Model) /= Seen));
      Seen := Settings_VM.Version (Model);
      Settings_VM.Execute (Model, Choose_Theme, Preferences.Theme_Choices'Pos (Preferences.Dark));
      Check ("settings-vm-theme-same", "FALSE", Image (Settings_VM.Version (Model) /= Seen));

      Settings_VM.Execute (Model, Choose_Background, Preferences.Background_Modes'Pos (Preferences.Mist));
      Settings_VM.Execute (Model, Choose_Speech_Model, Preferences.Speech_Models'Pos (Preferences.Parakeet));
      Check
        ("settings-vm-choices",
         "MIST PARAKEET",
         Settings_VM.Background (Model)'Image & " " & Settings_VM.Speech_Model (Model)'Image);
      Settings_VM.Execute (Model, Toggle_VSync);
      Check ("settings-vm-vsync", "TRUE", Image (Settings_VM.VSync (Model)));
      Settings_VM.Execute (Model, Toggle_VSync);
      Check ("settings-vm-vsync-again", "FALSE", Image (Settings_VM.VSync (Model)));

      --  A choice that is not one is refused, and changes nothing.
      Seen := Settings_VM.Version (Model);
      begin
         Settings_VM.Execute (Model, Choose_Theme, 3);
         Check ("settings-vm-theme-range", "raised", "not raised");
      exception
         when Constraint_Error =>
            Check ("settings-vm-theme-range", "raised", "raised");
      end;
      begin
         Settings_VM.Execute (Model, Choose_Speech_Model, 2);
         Check ("settings-vm-speech-range", "raised", "not raised");
      exception
         when Constraint_Error =>
            Check ("settings-vm-speech-range", "raised", "raised");
      end;
      Check
        ("settings-vm-range-unchanged",
         "DARK FALSE",
         Settings_VM.Theme (Model)'Image & " " & Image (Settings_VM.Version (Model) /= Seen));
   end Command_Rules;

   procedure New_Pictures is
      Voice                  : aliased Fakes.Pretend;
      Saved                  : aliased Fakes.Notes;
      Pictures               : aliased Fakes.Reactions;
      Model, Without_Effects : Settings_VM.View_Model;
      Seen                   : Parts.Version_Number;
      Choice                 : constant Natural := Preferences.Background_Modes'Pos (Preferences.Mist);
      Rejected               : Boolean := False;
   begin
      Settings_VM.Initialize (Without_Effects, Voice'Access, null, "/nowhere");
      Settings_VM.Execute (Without_Effects, Open);
      Check
        ("settings-picture-no-effects",
         "FALSE",
         Image (Settings_VM.Can_Execute (Without_Effects, New_Picture, Choice)));
      Settings_VM.Initialize (Model, Voice'Access, Saved'Access, "/nowhere", Reactions => Pictures'Access);
      Check ("settings-picture-closed", "FALSE", Image (Settings_VM.Can_Execute (Model, New_Picture, Choice)));
      Settings_VM.Execute (Model, Open);
      Check
        ("settings-picture-range",
         "TRUE",
         Image
           (Settings_VM.Can_Execute (Model, New_Picture, Choice)
            and then not Settings_VM.Can_Execute
                           (Model, New_Picture, Preferences.Background_Modes'Pos (Preferences.Fixed))
            and then not Settings_VM.Can_Execute (Model, New_Picture, Natural'Last)));
      Seen := Settings_VM.Version (Model);
      begin
         Settings_VM.Execute (Model, New_Picture, Natural'Last);
      exception
         when Ada.Assertions.Assertion_Error =>
            Rejected := True;
      end;
      Check
        ("settings-picture-invalid-contract",
         "TRUE",
         Image
           (Rejected
            and then Pictures.Requests = 0
            and then Fakes.Told (Saved) = ""
            and then Settings_VM.Version (Model) = Seen));
      Settings_VM.Execute (Model, New_Picture, Choice);
      Check ("settings-picture-kept", "background=MIST;seed=1234;", Fakes.Told (Saved));
      Check
        ("settings-picture-changed",
         "TRUE",
         Image
           (Settings_VM.Background (Model) = Preferences.Mist
            and then Settings_VM.Seed (Model) = 1234
            and then Pictures.Requests = 1
            and then Pictures.Notices = 1
            and then Pictures.Last = New_Picture
            and then Settings_VM.Version (Model) /= Seen));
      Seen := Settings_VM.Version (Model);
      Settings_VM.Execute (Model, New_Picture, Choice);
      Check ("settings-picture-same-version", "TRUE", Image (Settings_VM.Version (Model) = Seen));
      Saved.Background_Failing := True;
      Seen := Settings_VM.Version (Model);
      Settings_VM.Execute (Model, New_Picture, Choice);
      Check
        ("settings-picture-partial-failure",
         "TRUE",
         Image (Settings_VM.Keep_Failed (Model) and then Settings_VM.Version (Model) /= Seen));
      Saved.Background_Failing := False;
      Settings_VM.Execute (Model, New_Picture, Choice);
      Check ("settings-picture-save-recovered", "FALSE", Image (Settings_VM.Keep_Failed (Model)));
      Saved.Failing := True;
      Pictures.Seed := Preferences.Seed_Limit - 1;
      Settings_VM.Execute (Model, New_Picture, Preferences.Background_Modes'Pos (Preferences.Grain));
      Check
        ("settings-picture-save-failed",
         "TRUE",
         Image
           (Settings_VM.Background (Model) = Preferences.Grain
            and then Settings_VM.Seed (Model) = Pictures.Seed
            and then Settings_VM.Keep_Failed (Model)));
   end New_Pictures;

   procedure Keeping is
      Voice : aliased Fakes.Pretend;
      Saved : aliased Fakes.Notes;
      Model : Settings_VM.View_Model;
      None  : Settings_VM.View_Model;
   begin
      Settings_VM.Initialize (Model, Voice'Access, Saved'Access, "/nowhere");
      Check ("settings-vm-persists", "TRUE", Image (Settings_VM.Persists (Model)));
      Settings_VM.Execute (Model, Choose_Theme, Preferences.Theme_Choices'Pos (Preferences.Light));
      Settings_VM.Execute (Model, Choose_Background, Preferences.Background_Modes'Pos (Preferences.Fixed));
      Settings_VM.Execute (Model, Choose_Speech_Model, Preferences.Speech_Models'Pos (Preferences.Parakeet));
      Settings_VM.Execute (Model, Toggle_VSync);
      Settings_VM.Execute (Model, Reseed, 4242);
      Check
        ("settings-vm-kept", "theme=LIGHT;background=FIXED;speech=PARAKEET;vsync=TRUE;seed=4242;", Fakes.Told (Saved));
      Check ("settings-vm-seed", "4242", Settings_VM.Seed (Model)'Image (2 .. 5));

      begin
         Settings_VM.Execute (Model, Reseed, Preferences.Seed_Limit);
         Check ("settings-vm-seed-range", "raised", "not raised");
      exception
         when Constraint_Error =>
            Check ("settings-vm-seed-range", "raised", "raised");
      end;

      --  A save that fails keeps the choice and does not raise.
      Saved.Failing := True;
      Settings_VM.Execute (Model, Choose_Theme, Preferences.Theme_Choices'Pos (Preferences.Dark));
      Check
        ("settings-vm-save-failed",
         "DARK TRUE",
         Settings_VM.Theme (Model)'Image & " " & Image (Settings_VM.Keep_Failed (Model)));
      Settings_VM.Execute (Model, Toggle_VSync);
      Settings_VM.Execute (Model, Reseed, 7);
      Check
        ("settings-vm-save-failed-all",
         "FALSE 7",
         Image (Settings_VM.VSync (Model)) & " " & Settings_VM.Seed (Model)'Image (2 .. 2));
      Saved.Failing := False;
      Settings_VM.Execute (Model, Choose_Theme, Preferences.Theme_Choices'Pos (Preferences.System));
      Check
        ("settings-vm-save-recovered",
         "SYSTEM FALSE",
         Settings_VM.Theme (Model)'Image & " " & Image (Settings_VM.Keep_Failed (Model)));

      --  With nowhere to keep them, nothing is.
      Settings_VM.Initialize (None, Voice'Access, null, "/nowhere");
      Settings_VM.Execute (None, Choose_Theme, Preferences.Theme_Choices'Pos (Preferences.Dark));
      Check
        ("settings-vm-no-store",
         "FALSE DARK FALSE",
         Image (Settings_VM.Persists (None))
         & " "
         & Settings_VM.Theme (None)'Image
         & " "
         & Image (Settings_VM.Keep_Failed (None)));

      --  The file: what is chosen is read back as the program reads it at start.
      declare
         Folder : constant String := "/tmp/bonxie-settings-vm-test";
         File   : aliased Settings_VM.Disk.File_Store;
         Filed  : Settings_VM.View_Model;
      begin
         if Ada.Directories.Exists (Folder) then
            Ada.Directories.Delete_Tree (Folder);
         end if;
         Settings_VM.Disk.Open (File, Folder);
         Settings_VM.Initialize (Filed, Voice'Access, File'Access, Folder);
         Settings_VM.Execute (Filed, Choose_Theme, Preferences.Theme_Choices'Pos (Preferences.Dark));
         Settings_VM.Execute (Filed, Choose_Background, Preferences.Background_Modes'Pos (Preferences.Grain));
         Settings_VM.Execute (Filed, Choose_Speech_Model, Preferences.Speech_Models'Pos (Preferences.Parakeet));
         Settings_VM.Execute (Filed, Toggle_VSync);
         Settings_VM.Execute (Filed, Reseed, 31337);
         Check
           ("settings-vm-file",
            "DARK GRAIN PARAKEET TRUE 31337",
            Preferences.Load_Theme (Folder)'Image
            & " "
            & Preferences.Load_Background (Folder)'Image
            & " "
            & Preferences.Load_Speech_Model (Folder)'Image
            & " "
            & Image (Preferences.Load_VSync (Folder))
            & Preferences.Load_Seed (Folder)'Image);
         Ada.Directories.Delete_Tree (Folder);
      end;
   end Keeping;

   procedure Downloading is
      Voice : aliased Fakes.Pretend;
      Model : Settings_VM.View_Model;
      Seen  : Parts.Version_Number;

      function Controls return String
      is (Image (Settings_VM.Download_Row_Shown (Model))
          & " "
          & Image (Settings_VM.Download_Button_Shown (Model))
          & " "
          & Image (Settings_VM.Delete_Button_Shown (Model))
          & " "
          & Image (Settings_VM.Download_Bar_Shown (Model))
          & " "
          & Image (Settings_VM.Can_Execute (Model, Download_Model))
          & " "
          & Image (Settings_VM.Can_Execute (Model, Delete_Model)));
      --  Row, Download, Delete, Bar shown; Download, Delete possible.
   begin
      Settings_VM.Initialize (Model, Voice'Access, null, "/nowhere");

      --  MacOS has nothing to fetch.
      Check ("settings-vm-macos-row", "FALSE", Image (Settings_VM.Download_Row_Shown (Model)));
      Settings_VM.Execute (Model, Choose_Speech_Model, Preferences.Speech_Models'Pos (Preferences.Parakeet));

      --  Idle, no files.
      Check ("settings-vm-idle", "TRUE TRUE FALSE FALSE TRUE FALSE", Controls);
      Check ("settings-vm-idle-says", "Model not downloaded", Settings_VM.Download_Status (Model));

      --  Started: it is Running, and the files are not there yet.
      Settings_VM.Execute (Model, Download_Model);
      Check ("settings-vm-started", "TRUE TRUE FALSE TRUE FALSE FALSE", Controls);

      Voice.Bytes := 483_000_000;
      Voice.Part := 0.42;
      Seen := Settings_VM.Version (Model);
      Settings_VM.Poll (Model);
      Check ("settings-vm-progress-changed", "TRUE", Image (Settings_VM.Version (Model) /= Seen));
      Check ("settings-vm-progress", "Downloading 202.9 MB of 483.0 MB (42%)", Settings_VM.Download_Status (Model));
      Seen := Settings_VM.Version (Model);
      Settings_VM.Poll (Model);
      Check ("settings-vm-progress-same", "FALSE", Image (Settings_VM.Version (Model) /= Seen));

      Voice.Bytes := 0;
      Check ("settings-vm-progress-unknown-total", "TRUE", Image (Settings_VM.Download_Status (Model)'Length > 0));
      Settings_VM.Poll (Model);
      Check ("settings-vm-progress-percent", "Downloading 42%", Settings_VM.Download_Status (Model));

      Voice.Working := True;
      Settings_VM.Poll (Model);
      Check ("settings-vm-preparing", "Preparing the model, once only", Settings_VM.Download_Status (Model));
      Voice.Working := False;

      --  Failed.
      Voice.Now := Speech.Models.Failed;
      Ada.Strings.Unbounded.Set_Unbounded_String (Voice.Said, "no network");
      Settings_VM.Poll (Model);
      Check ("settings-vm-failed", "Download failed: no network", Settings_VM.Download_Status (Model));
      Check ("settings-vm-failed-controls", "TRUE TRUE FALSE FALSE TRUE FALSE", Controls);

      --  Done: the files are there.
      Voice.Now := Speech.Models.Done;
      Voice.Files := True;
      Voice.Size := 483_000_000;
      Settings_VM.Poll (Model);
      Check ("settings-vm-done", "Model available, 483.0 MB on disk", Settings_VM.Download_Status (Model));
      Check ("settings-vm-done-controls", "TRUE FALSE TRUE FALSE FALSE TRUE", Controls);

      --  Deleted: back to where it began.
      Settings_VM.Execute (Model, Delete_Model);
      Check ("settings-vm-deleted", "TRUE TRUE FALSE FALSE TRUE FALSE", Controls);
      Check ("settings-vm-deleted-says", "Model not downloaded", Settings_VM.Download_Status (Model));

      --  The row goes with the choice.
      Settings_VM.Execute (Model, Choose_Speech_Model, Preferences.Speech_Models'Pos (Preferences.MacOS));
      Check ("settings-vm-back-to-macos", "FALSE", Image (Settings_VM.Download_Row_Shown (Model)));
   end Downloading;

   procedure Sizes is
      function Size_Text (Bytes : Long_Long_Integer) return String renames Settings_VM.Size_Text;
   begin
      Check
        ("settings-vm-size-small",
         "0 KB 1 KB 100 KB",
         Size_Text (0) & " " & Size_Text (500) & " " & Size_Text (99_999));
      Check ("settings-vm-size-megabytes", "0.1 MB 483.0 MB", Size_Text (100_000) & " " & Size_Text (483_000_000));
      Check
        ("settings-vm-size-gigabytes", "1.20 GB 2.05 GB", Size_Text (1_200_000_000) & " " & Size_Text (2_049_999_999));
   end Sizes;

   --  Whether the text of a file has Part.
   function Mentions (Path : String; Part : String) return Boolean is
      File  : Ada.Text_IO.File_Type;
      Found : Boolean := False;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         if Ada.Strings.Fixed.Index (Ada.Text_IO.Get_Line (File), Part) > 0 then
            Found := True;
         end if;
      end loop;
      Ada.Text_IO.Close (File);
      return Found;
   end Mentions;

   procedure No_Widgets is
      Seen  : Natural := 0;
      Clean : Boolean := True;

      --  Every Ada file under Folder, in its subdirectories too.
      procedure Scan (Folder : String) is
         Search      : Ada.Directories.Search_Type;
         Entry_Found : Ada.Directories.Directory_Entry_Type;
      begin
         Ada.Directories.Start_Search
           (Search, Folder, "", [Ada.Directories.Directory | Ada.Directories.Ordinary_File => True, others => False]);
         while Ada.Directories.More_Entries (Search) loop
            Ada.Directories.Get_Next_Entry (Search, Entry_Found);
            declare
               Path : constant String := Ada.Directories.Full_Name (Entry_Found);
               Name : constant String := Ada.Directories.Simple_Name (Entry_Found);
            begin
               if Ada.Directories.Kind (Entry_Found) in Ada.Directories.Directory then
                  if Name /= "." and then Name /= ".." then
                     Scan (Path);
                  end if;
               elsif Ada.Directories.Extension (Name) in "ads" | "adb" then
                  Seen := Seen + 1;
                  if Mentions (Path, "Pomarine.Widgets") or else Mentions (Path, "SDL3") then
                     Ada.Text_IO.Put_Line ("a view-model names a widget or SDL: " & Path);
                     Clean := False;
                  end if;
               end if;
            end;
         end loop;
         Ada.Directories.End_Search (Search);
      end Scan;
   begin
      Scan ("../src/view_models");
      Check ("view-models-no-widgets", "TRUE", Image (Clean and then Seen > 0));
   end No_Widgets;

end Settings_VM_Tests;
