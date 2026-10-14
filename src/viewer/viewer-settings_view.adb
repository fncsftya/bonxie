with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Downloads;
with UI.Widgets;
with UI.Widgets.Buttons;
with UI.Widgets.Checks;
with UI.Widgets.Labels;
with UI.Widgets.Progress_Bars;
with SDL3.Events;
with Viewer.Style;
with Yoga.Nodes;

package body Viewer.Settings_View is

   package Widgets renames UI.Widgets;
   package Buttons renames UI.Widgets.Buttons;
   package Checks renames UI.Widgets.Checks;
   package Labels renames UI.Widgets.Labels;
   package Progress_Bars renames UI.Widgets.Progress_Bars;

   use type Downloads.States;
   use type Preferences.Speech_Models;
   use type Preferences.Theme_Choices;

   function Config (Item : Session) return String is
     (Ada.Strings.Unbounded.To_String (Item.Prefs.Config_Dir));

   function Model_File (Item : Session) return String is
     (Preferences.Speech_Model_File (Config (Item)));

   function Model_Present (Item : Session) return Boolean is
     (Ada.Directories.Exists (Model_File (Item)));

   function Downloading (Item : Session) return Boolean is
     (Item.Prefs.Showing_Settings
    and then Downloads.State = Downloads.Running);

   function Percent return String;
   --  How much of the file has come, as "42%"; "" while its length is not
   --  known.

   function Percent return String is
      Done : constant Natural := Natural (Downloads.Fraction * 100.0);
   begin
      return (if Done = 0 then ""
              else Ada.Strings.Fixed.Trim (Done'Image, Ada.Strings.Left)
                   & "%");
   end Percent;

   function Fits (Words : String) return String is
     (Words (Words'First ..
             Words'First - 1
             + Natural'Min (Words'Length, Labels.Text_Capacity)));
   --  As much of Words as a label holds.

   function Status (Item : Session) return String;
   --  What the label by the Download button says.

   function Status (Item : Session) return String is
   begin
      if Model_Present (Item) then
         return "Model available";
      end if;
      case Downloads.State is
         when Downloads.Running =>
            return Fits ("Downloading " & Percent);
         when Downloads.Failed =>
            return Fits ("Download failed: " & Downloads.Message);
         when Downloads.Idle | Downloads.Done =>
            return "Model not downloaded";
      end case;
   end Status;

   procedure Refresh (Item : in out Session) is
      Parakeet : constant Boolean := Item.Prefs.Speech_Choice
         = Preferences.Parakeet;
      Running  : constant Boolean := Downloads.State = Downloads.Running;
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
      Buttons.Set_Enabled
        (Item.Prefs.Download_Button, not Model_Present (Item)
       and then not Running);
      Labels.Set_Text (Item.Prefs.Download_State, Status (Item));
      if Running then
         Progress_Bars.Set_Value (Item.Prefs.Download_Bar, Downloads.Fraction);
      end if;
      Item.Prefs.Download_Seen := Downloads.State;
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

   procedure Take (Item : in out Session) is
      Clicked : Boolean;
   begin
      Buttons.Take_Click (Item.Prefs.Settings_Close, Clicked);
      if Clicked then
         Close (Item);
         return;
      end if;
      Checks.Take_Change (Item.Prefs.Theme_Light, Clicked);
      if Clicked then
         Choose_Appearance (Item, Preferences.Light);
         return;
      end if;
      Checks.Take_Change (Item.Prefs.Theme_Dark, Clicked);
      if Clicked then
         Choose_Appearance (Item, Preferences.Dark);
         return;
      end if;
      Checks.Take_Change (Item.Prefs.Theme_System, Clicked);
      if Clicked then
         Choose_Appearance (Item, Preferences.System);
         return;
      end if;
      Checks.Take_Change (Item.Prefs.Model_Native, Clicked);
      if Clicked then
         Choose (Item, Preferences.MacOS);
         return;
      end if;
      Checks.Take_Change (Item.Prefs.Model_Parakeet, Clicked);
      if Clicked then
         Choose (Item, Preferences.Parakeet);
         return;
      end if;
      Buttons.Take_Click (Item.Prefs.Download_Button, Clicked);
      if Clicked
        and then Downloads.State /= Downloads.Running
        and then not Model_Present (Item)
      then
         Downloads.Start (Preferences.Parakeet_URL, Model_File (Item));
         Refresh (Item);
         Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      end if;
   end Take;

   procedure Update (Item : in out Session) is
      Now : constant Downloads.States := Downloads.State;
   begin
      if Now = Downloads.Running then
         Refresh (Item);
      elsif Now /= Item.Prefs.Download_Seen then
         --  It has ended: the button and the bar change.
         Refresh (Item);
         Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      end if;
   end Update;

   procedure Fit (Item : in out Session) is
      use Yoga.Nodes;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Room   : constant Float :=
        Widgets.Width_Of (Item.Prefs.Settings_Content) / Pixels
        - 2.0 * Style.Page_Margin;
      Wide   : constant Float :=
        Float'Max (Style.Page_Min_Width, Float'Min (Style.Page_Width, Room));
   begin
      if Wide /= Item.Prefs.Form_Wide then
         Item.Prefs.Form_Wide := Wide;
         Set_Width (Widgets.Node (Item.Prefs.Settings_Form), Wide * Pixels);
         Widgets.Request_Layout (Item.Prefs.Settings_Form);
      end if;
   end Fit;

end Viewer.Settings_View;
