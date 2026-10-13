with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Downloads;
with UI.Widgets;
with UI.Widgets.Buttons;
with UI.Widgets.Checks;
with UI.Widgets.Labels;
with UI.Widgets.Progress_Bars;
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

   function Config (Item : Session) return String is
     (Ada.Strings.Unbounded.To_String (Item.Config_Dir));

   function Model_File (Item : Session) return String is
     (Preferences.Speech_Model_File (Config (Item)));

   function Model_Present (Item : Session) return Boolean is
     (Ada.Directories.Exists (Model_File (Item)));

   function Downloading (Item : Session) return Boolean is
     (Item.Showing_Settings and then Downloads.State = Downloads.Running);

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
      Parakeet : constant Boolean := Item.Speech_Choice = Preferences.Parakeet;
      Running  : constant Boolean := Downloads.State = Downloads.Running;
   begin
      Checks.Set_Checked (Item.Model_Native, not Parakeet);
      Checks.Set_Checked (Item.Model_Parakeet, Parakeet);
      Widgets.Set_Visible (Item.Download_Row, Parakeet);
      Widgets.Set_Visible (Item.Download_Bar, Parakeet and then Running);
      Buttons.Set_Enabled
        (Item.Download_Button, not Model_Present (Item) and then not Running);
      Labels.Set_Text (Item.Download_State, Status (Item));
      if Running then
         Progress_Bars.Set_Value (Item.Download_Bar, Downloads.Fraction);
      end if;
      Item.Download_Seen := Downloads.State;
   end Refresh;

   procedure Open (Item : in out Session) is
   begin
      Item.Showing_Settings := True;
      Widgets.Clear_Focus (Item.Widgets);
      Widgets.Set_Visible (Item.Home_Panel, False);
      Widgets.Set_Visible (Item.Settings_Panel, True);
      Refresh (Item);
      Widgets.Layout (Item.Widgets, Item.Target);
   end Open;

   procedure Close (Item : in out Session) is
   begin
      Item.Showing_Settings := False;
      Widgets.Clear_Focus (Item.Widgets);
      Widgets.Set_Visible (Item.Settings_Panel, False);
      Widgets.Set_Visible (Item.Home_Panel, True);
      Widgets.Layout (Item.Widgets, Item.Target);
   end Close;

   procedure Choose
     (Item : in out Session; To : Preferences.Speech_Models) is
   begin
      Item.Speech_Choice := To;
      if Item.Persist then
         begin
            Preferences.Save_Speech_Model (Config (Item), To);
         exception
            when others =>
               null;  --  the choice holds for now; it is not worth a crash
         end;
      end if;
      if Item.Showing_Settings then
         Refresh (Item);
         Widgets.Layout (Item.Widgets, Item.Target);
      end if;
   end Choose;

   procedure Take (Item : in out Session) is
      Clicked : Boolean;
   begin
      Buttons.Take_Click (Item.Settings_Close, Clicked);
      if Clicked then
         Close (Item);
         return;
      end if;
      Checks.Take_Change (Item.Model_Native, Clicked);
      if Clicked then
         Choose (Item, Preferences.MacOS);
         return;
      end if;
      Checks.Take_Change (Item.Model_Parakeet, Clicked);
      if Clicked then
         Choose (Item, Preferences.Parakeet);
         return;
      end if;
      Buttons.Take_Click (Item.Download_Button, Clicked);
      if Clicked
        and then Downloads.State /= Downloads.Running
        and then not Model_Present (Item)
      then
         Downloads.Start (Preferences.Parakeet_URL, Model_File (Item));
         Refresh (Item);
         Widgets.Layout (Item.Widgets, Item.Target);
      end if;
   end Take;

   procedure Update (Item : in out Session) is
      Now : constant Downloads.States := Downloads.State;
   begin
      if Now = Downloads.Running then
         Refresh (Item);
      elsif Now /= Item.Download_Seen then
         --  It has ended: the button and the bar change.
         Refresh (Item);
         Widgets.Layout (Item.Widgets, Item.Target);
      end if;
   end Update;

   procedure Fit (Item : in out Session) is
      use Yoga.Nodes;
      Pixels : constant Float := Widgets.Density (Item.Widgets);
      Room   : constant Float :=
        Widgets.Width_Of (Item.Settings_Content) / Pixels
        - 2.0 * Style.Page_Margin;
      Wide   : constant Float :=
        Float'Max (Style.Page_Min_Width, Float'Min (Style.Page_Width, Room));
   begin
      if Wide /= Item.Form_Wide then
         Item.Form_Wide := Wide;
         Set_Width (Widgets.Node (Item.Settings_Form), Wide * Pixels);
         Widgets.Request_Layout (Item.Settings_Form);
      end if;
   end Fit;

end Viewer.Settings_View;
