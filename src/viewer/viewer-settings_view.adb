with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Pomarine.Widgets;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Checks;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Progress_Bars;
with SDL3.Events;
with Speech.Models;
with Viewer.Deletion;
with Viewer.Style;
with Pomarine.Widgets.Layouts;

package body Viewer.Settings_View is

   package Widgets renames Pomarine.Widgets;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Checks renames Pomarine.Widgets.Checks;
   package Labels renames Pomarine.Widgets.Labels;
   package Progress_Bars renames Pomarine.Widgets.Progress_Bars;

   use type Speech.Models.States;
   use type Preferences.Speech_Models;
   use type Preferences.Theme_Choices;

   function Config (Item : Session) return String is
     (Ada.Strings.Unbounded.To_String (Item.Prefs.Config_Dir));

   function Model_Directory (Item : Session) return String is
     (Preferences.Speech_Model_Directory (Config (Item)));

   function Model_Present (Item : Session) return Boolean is
     (Speech.Models.Present (Model_Directory (Item)));

   function On_Disk (Item : Session) return Long_Long_Integer is
     (Speech.Models.Size_On_Disk (Model_Directory (Item)));

   function Downloading (Item : Session) return Boolean is
     (Item.Prefs.Showing_Settings
    and then Speech.Models.State = Speech.Models.Running);

   function Percent return String;
   --  How much of the model has come, as "42%".

   function Percent return String is
      Done : constant Natural := Natural (Speech.Models.Fraction * 100.0);
   begin
      return Ada.Strings.Fixed.Trim (Done'Image, Ada.Strings.Left) & "%";
   end Percent;

   function Size_Text (Bytes : Long_Long_Integer) return String;
   --  A size as people say it: "483.0 MB", or "1.20 GB" from a thousand.

   function Size_Text (Bytes : Long_Long_Integer) return String is
      function Trimmed (Value : Long_Long_Integer) return String is
        (Ada.Strings.Fixed.Trim (Value'Image, Ada.Strings.Left));
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

   function Fits (Words : String) return String is
     (Words (Words'First ..
             Words'First - 1
             + Natural'Min (Words'Length, Labels.Text_Capacity)));
   --  As much of Words as a label holds.

   function Progress_Text return String;
   --  "123.4 MB of 483.0 MB (25%)", or just the percentage while the
   --  total is not known.

   function Progress_Text return String is
      Total : constant Long_Long_Integer := Speech.Models.Total_Bytes;
      Got   : constant Long_Long_Integer :=
        Long_Long_Integer (Float (Total) * Speech.Models.Fraction);
   begin
      return (if Total = 0 then Percent
              else Size_Text (Got) & " of " & Size_Text (Total) & " (" & Percent & ")");
   end Progress_Text;

   function Status (Item : Session) return String;
   --  What the label by the Download button says.

   function Status (Item : Session) return String is
   begin
      if Model_Present (Item) and then Speech.Models.State /= Speech.Models.Running then
         return Fits ("Model available, " & Size_Text (On_Disk (Item)) & " on disk");
      end if;
      case Speech.Models.State is
         when Speech.Models.Running =>
            return (if Speech.Models.Preparing
                    then Fits ("Preparing the model, once only")
                    else Fits ("Downloading " & Progress_Text));
         when Speech.Models.Failed =>
            return Fits ("Download failed: " & Speech.Models.Message);
         when Speech.Models.Idle | Speech.Models.Done =>
            return "Model not downloaded";
      end case;
   end Status;

   procedure Refresh (Item : in out Session) is
      Parakeet : constant Boolean := Item.Prefs.Speech_Choice
         = Preferences.Parakeet;
      Running  : constant Boolean := Speech.Models.State = Speech.Models.Running;
      Present  : constant Boolean := Model_Present (Item);
   begin
      Checks.Set_Checked (Item.Prefs.Model_Native, not Parakeet);
      Checks.Set_Checked (Item.Prefs.Model_Parakeet, Parakeet);
      Checks.Set_Checked
        (Item.Prefs.Theme_Light, Item.Prefs.Theme_Chosen = Preferences.Light);
      Checks.Set_Checked
        (Item.Prefs.Theme_Dark, Item.Prefs.Theme_Chosen = Preferences.Dark);
      Checks.Set_Checked
        (Item.Prefs.Theme_System,
         Item.Prefs.Theme_Chosen = Preferences.System);
      Widgets.Set_Visible (Item.Prefs.Download_Row, Parakeet);
      Widgets.Set_Visible (Item.Prefs.Download_Bar, Parakeet and then Running);
      Widgets.Set_Visible (Item.Prefs.Download_Button, not Present);
      Widgets.Set_Visible (Item.Prefs.Delete_Button, Present and then not Running);
      Buttons.Set_Enabled (Item.Prefs.Download_Button, not Present and then not Running);
      Labels.Set_Text (Item.Prefs.Download_State, Status (Item));
      if Running then
         Progress_Bars.Set_Value (Item.Prefs.Download_Bar, Speech.Models.Fraction);
      end if;
      Item.Prefs.Download_Seen := Speech.Models.State;
   end Refresh;

   procedure Open (Item : in out Session) is
   begin
      Item.Prefs.Showing_Settings := True;
      Widgets.Clear_Focus (Item.Root.Widgets);
      Widgets.Set_Visible (Item.Home_View.Home_Panel, False);
      Widgets.Set_Visible (Item.Prefs.Settings_Panel, True);
      Refresh (Item);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Open;

   procedure Close (Item : in out Session) is
   begin
      Item.Prefs.Showing_Settings := False;
      Widgets.Clear_Focus (Item.Root.Widgets);
      Widgets.Set_Visible (Item.Prefs.Settings_Panel, False);
      Widgets.Set_Visible (Item.Home_View.Home_Panel, True);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Close;

   procedure Choose
     (Item : in out Session; To : Preferences.Speech_Models) is
   begin
      Item.Prefs.Speech_Choice := To;
      if Item.Prefs.Persist then
         begin
            Preferences.Save_Speech_Model (Config (Item), To);
         exception
            when others =>
               null;  --  the choice holds for now; it is not worth a crash
         end;
      end if;
      if Item.Prefs.Showing_Settings then
         Refresh (Item);
         Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      end if;
   end Choose;

   procedure Choose_Appearance
     (Item : in out Session; To : Preferences.Theme_Choices) is
   begin
      Item.Prefs.Theme_Chosen := To;
      if Item.Prefs.Persist then
         begin
            Preferences.Save_Theme (Config (Item), To);
         exception
            when others =>
               null;  --  the choice holds for now; it is not worth a crash
         end;
      end if;
      Apply_Theme (Item);
      if Item.Prefs.Showing_Settings then
         Refresh (Item);
      end if;
   end Choose_Appearance;

   procedure Apply_Theme (Item : in out Session) is
      Dark : constant Boolean :=
        (case Item.Prefs.Theme_Chosen is
            when Preferences.Light  => False,
            when Preferences.Dark   => True,
            when Preferences.System => SDL3.Events.System_Is_Dark);
   begin
      Viewer.Style.Use_Dark (Dark);
      if Dark /= Item.Prefs.Dark_Shown then
         Item.Prefs.Dark_Shown := Dark;
         Widgets.Invalidate_All (Item.Root.Widgets);
      end if;
   end Apply_Theme;

   procedure Respond (Item : in out Session; What : Command) is
   begin
      if Item.Confirm.Deleting_Model then
         --  The dialog is all that takes clicks.
         case What is
            when Confirm_Deletion =>
               Deletion.Close (Item);
               if Speech.Models.State /= Speech.Models.Running then
                  Speech.Models.Delete (Model_Directory (Item));
                  Speech.Models.Reset;
               end if;
               Refresh (Item);
               Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
            when Cancel_Deletion =>
               Deletion.Close (Item);
            when others =>
               null;
         end case;
         return;
      end if;
      case What is
         when Close_Settings =>
            Close (Item);
         when Choose_Light =>
            Choose_Appearance (Item, Preferences.Light);
         when Choose_Dark =>
            Choose_Appearance (Item, Preferences.Dark);
         when Choose_System =>
            Choose_Appearance (Item, Preferences.System);
         when Choose_MacOS =>
            Choose (Item, Preferences.MacOS);
         when Choose_Parakeet =>
            Choose (Item, Preferences.Parakeet);
         when Download_Model =>
            if Speech.Models.State /= Speech.Models.Running
              and then not Model_Present (Item)
            then
               Speech.Models.Start (Model_Directory (Item));
               Refresh (Item);
               Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
            end if;
         when Delete_Model =>
            if Speech.Models.State /= Speech.Models.Running and then Model_Present (Item) then
               Deletion.Confirm_Model
                 (Item, "Its " & Size_Text (On_Disk (Item)) & " of files go; they can be downloaded again.");
            end if;
         when others =>
            null;
      end case;
   end Respond;

   procedure Update (Item : in out Session) is
      Now : constant Speech.Models.States := Speech.Models.State;
   begin
      if Now = Speech.Models.Running then
         Refresh (Item);
      elsif Now /= Item.Prefs.Download_Seen then
         --  It has ended: the button and the bar change.
         Refresh (Item);
         Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      end if;
   end Update;

   procedure Fit (Item : in out Session) is
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Room   : constant Float :=
        Widgets.Width_Of (Item.Prefs.Settings_Content) / Pixels
        - 2.0 * Style.Page_Margin;
      Wide   : constant Float :=
        Float'Max (Style.Page_Min_Width, Float'Min (Style.Page_Width, Room));
   begin
      if Wide /= Item.Prefs.Form_Wide then
         Item.Prefs.Form_Wide := Wide;
         Pomarine.Widgets.Layouts.Set_Layout (Item.Prefs.Settings_Form, Width => Wide);
      end if;
   end Fit;

end Viewer.Settings_View;
