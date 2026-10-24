with Ada.Strings.Fixed;

package body Settings_VM is

   use type Parts.Version_Number;
   use type Preferences.Speech_Models;
   use type Speech.Models.States;

   overriding function Version (Self : View_Model) return Parts.Version_Number is
     (Parts.Value (Self.Changes) + Flag_Properties.Version (Self.Showing) + Theme_Properties.Version (Self.Themes)
      + Background_Properties.Version (Self.Pictures) + Speech_Properties.Version (Self.Voice)
      + Flag_Properties.Version (Self.Ticked));

   function Config_Directory (Self : View_Model) return String is
     (Ada.Strings.Unbounded.To_String (Self.Config));

   function Persists (Self : View_Model) return Boolean is (Self.Store /= null);

   function Is_Showing (Self : View_Model) return Boolean is (Flag_Properties.Get (Self.Showing));

   function Theme (Self : View_Model) return Preferences.Theme_Choices is (Theme_Properties.Get (Self.Themes));

   function Background (Self : View_Model) return Preferences.Background_Modes is
     (Background_Properties.Get (Self.Pictures));

   function Speech_Model (Self : View_Model) return Preferences.Speech_Models is
     (Speech_Properties.Get (Self.Voice));

   function VSync (Self : View_Model) return Boolean is (Flag_Properties.Get (Self.Ticked));

   function Seed (Self : View_Model) return Natural is (Self.Number);

   function Keep_Failed (Self : View_Model) return Boolean is (Self.Failed);

   --  How the download stands

   function Download_State (Self : View_Model) return Speech.Models.States is (Self.Download.State);

   function Running (Self : View_Model) return Boolean is (Self.Download.State = Speech.Models.Running);

   function Download_Row_Shown (Self : View_Model) return Boolean is (Speech_Model (Self) = Preferences.Parakeet);

   function Download_Button_Shown (Self : View_Model) return Boolean is (not Self.Download.Present);

   function Delete_Button_Shown (Self : View_Model) return Boolean is
     (Self.Download.Present and then not Running (Self));

   function Download_Bar_Shown (Self : View_Model) return Boolean is
     (Download_Row_Shown (Self) and then Running (Self));

   function Download_Fraction (Self : View_Model) return Float is (Self.Download.Fraction);

   function Trimmed (Value : Long_Long_Integer) return String is
     (Ada.Strings.Fixed.Trim (Value'Image, Ada.Strings.Left));

   function Size_Text (Bytes : Long_Long_Integer) return String is
      function Digits_Of (Value : Long_Long_Integer; Width : Positive) return String is
         Number : constant String := Trimmed (Value);
      begin
         return [1 .. Integer'Max (0, Width - Number'Length) => '0'] & Number;
      end Digits_Of;
   begin
      if Bytes >= 1_000_000_000 then
         declare
            Hundredths : constant Long_Long_Integer := (Bytes + 5_000_000) / 10_000_000;
         begin
            return Trimmed (Hundredths / 100) & "." & Digits_Of (Hundredths mod 100, 2) & " GB";
         end;
      elsif Bytes >= 100_000 then
         declare
            Tenths : constant Long_Long_Integer := (Bytes + 50_000) / 100_000;
         begin
            return Trimmed (Tenths / 10) & "." & Trimmed (Tenths mod 10) & " MB";
         end;
      else
         return Trimmed ((Bytes + 500) / 1_000) & " KB";
      end if;
   end Size_Text;

   function Size_On_Disk_Text (Self : View_Model) return String is (Size_Text (Self.Download.On_Disk));

   function Percent (Self : View_Model) return String is
     (Trimmed (Long_Long_Integer (Natural (Self.Download.Fraction * 100.0))) & "%");

   --  "123.4 MB of 483.0 MB (25%)", or just the percentage while the total is not known.
   function Progress_Text (Self : View_Model) return String is
     (if Self.Download.Total = 0 then Percent (Self)
      else Size_Text (Long_Long_Integer (Float (Self.Download.Total) * Self.Download.Fraction))
           & " of " & Size_Text (Self.Download.Total) & " (" & Percent (Self) & ")");

   function Download_Status (Self : View_Model) return String is
   begin
      if Self.Download.Present and then not Running (Self) then
         return "Model available, " & Size_On_Disk_Text (Self) & " on disk";
      end if;
      case Self.Download.State is
         when Speech.Models.Running =>
            return (if Self.Download.Preparing
                    then "Preparing the model, once only"
                    else "Downloading " & Progress_Text (Self));
         when Speech.Models.Failed =>
            return "Download failed: " & Ada.Strings.Unbounded.To_String (Self.Download.Message);
         when Speech.Models.Idle | Speech.Models.Done =>
            return "Model not downloaded";
      end case;
   end Download_Status;

   --  Take what the source says, and say whether it differs from what was taken. The files are looked at
   --  when the state has changed, or when asked: they are a walk of a folder.
   procedure Look (Self : in out View_Model; Files : Boolean) is
      Now   : Snapshot;
      Asked : Model_Source'Class renames Self.Source.all;
   begin
      Now.State := State (Asked);
      Now.Fraction := Fraction (Asked);
      Now.Preparing := Preparing (Asked);
      Now.Total := Total_Bytes (Asked);
      if Now.State = Speech.Models.Failed then
         Now.Message := Ada.Strings.Unbounded.To_Unbounded_String (Message (Asked));
      end if;
      if Files or else Now.State /= Self.Download.State then
         Now.Present := Present (Asked);
         Now.On_Disk := (if Now.Present then On_Disk (Asked) else 0);
      else
         Now.Present := Self.Download.Present;
         Now.On_Disk := Self.Download.On_Disk;
      end if;
      if Now /= Self.Download then
         Self.Download := Now;
         Parts.Bump (Self.Changes);
      end if;
   end Look;

   procedure Poll (Self : in out View_Model) is
   begin
      Look (Self, Files => False);
   end Poll;

   procedure Initialize
     (Self            : in out View_Model;
      Source          : not null access Model_Source'Class;
      Kept_In         : access Store'Class;
      Config_Dir      : String;
      Kept_Speech     : Preferences.Speech_Models := Preferences.MacOS;
      Kept_Theme      : Preferences.Theme_Choices := Preferences.System;
      Kept_Background : Preferences.Background_Modes := Preferences.Watercolour;
      Kept_VSync      : Boolean := False) is
   begin
      Self.Source := Source.all'Unrestricted_Access;
      Self.Store := (if Kept_In = null then null else Kept_In.all'Unrestricted_Access);
      Self.Config := Ada.Strings.Unbounded.To_Unbounded_String (Config_Dir);
      Flag_Properties.Initialize (Self.Showing, False);
      Theme_Properties.Initialize (Self.Themes, Kept_Theme);
      Background_Properties.Initialize (Self.Pictures, Kept_Background);
      Speech_Properties.Initialize (Self.Voice, Kept_Speech);
      Flag_Properties.Initialize (Self.Ticked, Kept_VSync);
      Look (Self, Files => True);
   end Initialize;

   overriding function Can_Execute (Self : View_Model; What : Command) return Boolean is
     (case What is
         when Open           => not Is_Showing (Self),
         when Close          => Is_Showing (Self),
         when Download_Model => not Self.Download.Present and then not Running (Self),
         when Delete_Model   => Self.Download.Present and then not Running (Self),
         when Choose_Theme | Choose_Background | Choose_Speech_Model | Toggle_VSync | Reseed => True);

   --  Keep a choice, if there is anywhere to. A save that fails is not a reason to take the choice back,
   --  nor to stop: it holds for now.
   generic
      type Choice is private;
      with procedure Save (Where : in out Store'Class; To : Choice);
   procedure Keep (Self : in out View_Model; To : Choice);

   procedure Keep (Self : in out View_Model; To : Choice) is
   begin
      if Self.Store /= null then
         begin
            Save (Self.Store.all, To);
            Self.Failed := False;
         exception
            when others =>
               Self.Failed := True;
         end;
      end if;
   end Keep;

   procedure Save_Speech (Where : in out Store'Class; To : Preferences.Speech_Models);
   procedure Save_Speech (Where : in out Store'Class; To : Preferences.Speech_Models) is
   begin
      Save_Speech_Model (Where, To);
   end Save_Speech;

   procedure Save_Appearance (Where : in out Store'Class; To : Preferences.Theme_Choices);
   procedure Save_Appearance (Where : in out Store'Class; To : Preferences.Theme_Choices) is
   begin
      Save_Theme (Where, To);
   end Save_Appearance;

   procedure Save_Picture (Where : in out Store'Class; To : Preferences.Background_Modes);
   procedure Save_Picture (Where : in out Store'Class; To : Preferences.Background_Modes) is
   begin
      Save_Background (Where, To);
   end Save_Picture;

   procedure Save_Wait (Where : in out Store'Class; To : Boolean);
   procedure Save_Wait (Where : in out Store'Class; To : Boolean) is
   begin
      Save_VSync (Where, To);
   end Save_Wait;

   procedure Save_Number (Where : in out Store'Class; To : Natural);
   procedure Save_Number (Where : in out Store'Class; To : Natural) is
   begin
      Save_Seed (Where, To);
   end Save_Number;

   procedure Keep_Speech is new Keep (Preferences.Speech_Models, Save_Speech);
   procedure Keep_Theme is new Keep (Preferences.Theme_Choices, Save_Appearance);
   procedure Keep_Background is new Keep (Preferences.Background_Modes, Save_Picture);
   procedure Keep_VSync is new Keep (Boolean, Save_Wait);
   procedure Keep_Seed is new Keep (Natural, Save_Number);

   overriding procedure Execute (Self : in out View_Model; What : Command; Index : Natural := 0) is
   begin
      case What is
         when Open =>
            Flag_Properties.Set (Self.Showing, True);
            Look (Self, Files => True);
         when Close =>
            Flag_Properties.Set (Self.Showing, False);
         when Choose_Theme =>
            declare
               To : constant Preferences.Theme_Choices := Preferences.Theme_Choices'Val (Index);
            begin
               Theme_Properties.Set (Self.Themes, To);
               Keep_Theme (Self, To);
            end;
         when Choose_Background =>
            declare
               To : constant Preferences.Background_Modes := Preferences.Background_Modes'Val (Index);
            begin
               Background_Properties.Set (Self.Pictures, To);
               Keep_Background (Self, To);
            end;
         when Choose_Speech_Model =>
            declare
               To : constant Preferences.Speech_Models := Preferences.Speech_Models'Val (Index);
            begin
               Speech_Properties.Set (Self.Voice, To);
               Keep_Speech (Self, To);
            end;
         when Toggle_VSync =>
            Flag_Properties.Set (Self.Ticked, not VSync (Self));
            Keep_VSync (Self, VSync (Self));
         when Reseed =>
            if Index >= Preferences.Seed_Limit then
               raise Constraint_Error with "a seed is below" & Preferences.Seed_Limit'Image;
            end if;
            Self.Number := Index;
            Parts.Bump (Self.Changes);
            Keep_Seed (Self, Index);
         when Download_Model =>
            Start (Self.Source.all);
            Look (Self, Files => True);
         when Delete_Model =>
            Delete (Self.Source.all);
            Look (Self, Files => True);
      end case;
   end Execute;

end Settings_VM;
