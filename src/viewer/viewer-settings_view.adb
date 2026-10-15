with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with MLX;
with MLX.Hub;
with Pomarine.Themes;
with Pomarine.Widgets;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Checks;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Menus;
with Pomarine.Widgets.Progress_Bars;
with Pomarine.Widgets.Selects;
with Pomarine.Widgets.Switches;
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
   package Menus renames Pomarine.Widgets.Menus;
   package Progress_Bars renames Pomarine.Widgets.Progress_Bars;
   package Selects renames Pomarine.Widgets.Selects;
   package Switches renames Pomarine.Widgets.Switches;
   package Themes renames Pomarine.Themes;
   package Layouts renames Pomarine.Widgets.Layouts;

   use type MLX.States;
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
    and then (Speech.Models.State = Speech.Models.Running
              or else MLX.State = MLX.Running));

   --  AI

   function AI_Model (Item : Session) return String is
     (Ada.Strings.Unbounded.To_String (Item.Prefs.AI_Model));

   function AI_Problem (Item : Session) return String is
     (Ada.Strings.Unbounded.To_String (Item.Prefs.AI_Problem));

   function AI_Menu_Open (Item : Session) return Boolean is (Item.Prefs.AI_Menu_Open);

   function Shown (Name : String) return String;
   --  A model's name as far as a field or a row holds: from its two ends
   --  if it is too long, with an ellipsis between.

   function Shown (Name : String) return String is
      Ellipsis : constant String := [Character'Val (16#E2#), Character'Val (16#80#), Character'Val (16#A6#)];
      Room     : constant := Labels.Text_Capacity;
      Head     : constant := (Room - Ellipsis'Length) / 2 + 1;
      Tail     : constant := Room - Ellipsis'Length - Head;
   begin
      return (if Name'Length <= Room then Name
              else Name (Name'First .. Name'First + Head - 1) & Ellipsis
                   & Name (Name'Last - Tail + 1 .. Name'Last));
   end Shown;

   procedure Save_AI (Item : in out Session);
   --  Keep whether it is on, and the model chosen.

   procedure Judge (Item : in out Session);
   --  Find out whether the model chosen will run, and keep why not.

   procedure Judge (Item : in out Session) is
      Name : constant String := AI_Model (Item);
      Said : Ada.Strings.Unbounded.Unbounded_String;
   begin
      if Name /= "" then
         declare
            Folder : constant String := MLX.Hub.Snapshot (Name);
         begin
            Said :=
              Ada.Strings.Unbounded.To_Unbounded_String
                (if Folder = "" then "This model is not in the Hugging Face cache"
                 elsif Folder'Length > MLX.Max_Path then "The model's folder is too deep to use"
                 else MLX.Problem (Folder));
         end;
      end if;
      Item.Prefs.AI_Problem := Said;
   end Judge;

   procedure Say (Item : in out Session; Words : String; Ink : Themes.Slot);
   --  Show Words in the lines under the model, broken between words, as
   --  many as fit (the last then ends in an ellipsis); none if Words is "".

   procedure Say (Item : in out Session; Words : String; Ink : Themes.Slot) is
      Capacity : constant := Labels.Text_Capacity;
      Ellipsis : constant String := [Character'Val (16#E2#), Character'Val (16#80#), Character'Val (16#A6#)];
      Start    : Positive := Words'First;

      function Blank (At_Place : Positive) return Boolean is
        (Words (At_Place) in ' ' | ASCII.LF | ASCII.CR | ASCII.HT);
   begin
      for Number in Item.Prefs.AI_Notes'Range loop
         while Start <= Words'Last and then Blank (Start) loop
            Start := Start + 1;
         end loop;
         if Start > Words'Last then
            Widgets.Set_Visible (Item.Prefs.AI_Notes (Number), False);
         else
            declare
               Last_Line : constant Boolean := Number = Item.Prefs.AI_Notes'Last;
               Fits      : constant Boolean := Words'Last - Start + 1 <= Capacity;
               Room      : constant Positive := (if Last_Line and then not Fits then Capacity - Ellipsis'Length
                                                 else Capacity);
               Stop      : Natural := Natural'Min (Words'Last, Start + Room - 1);
            begin
               if Stop < Words'Last and then not Blank (Stop + 1) then
                  --  Break at the last space; or, in a word too long for
                  --  the line, between characters.
                  declare
                     Space : Natural := 0;
                  begin
                     for Place in reverse Start + 1 .. Stop loop
                        if Blank (Place) then
                           Space := Place;
                           exit;
                        end if;
                     end loop;
                     if Space /= 0 then
                        Stop := Space - 1;
                     else
                        while Stop > Start and then Character'Pos (Words (Stop + 1)) in 16#80# .. 16#BF# loop
                           Stop := Stop - 1;
                        end loop;
                     end if;
                  end;
               end if;
               declare
                  Line : constant String :=
                    [for Place in Start .. Stop => (if Blank (Place) then ' ' else Words (Place))];
               begin
                  Labels.Set_Text
                    (Item.Prefs.AI_Notes (Number),
                     (if Last_Line and then Stop < Words'Last then Line & Ellipsis else Line));
               end;
               Labels.Set_Ink (Item.Prefs.AI_Notes (Number), Ink);
               Widgets.Set_Visible (Item.Prefs.AI_Notes (Number), True);
               Start := Stop + 1;
            end;
         end if;
      end loop;
   end Say;

   procedure Fill_AI_Menu (Item : in out Session);
   --  Make the rows of the menu: None Selected, and each model found.

   procedure Fill_AI_Menu (Item : in out Session) is
      Chosen : constant String := AI_Model (Item);
      Found  : MLX.Hub.Models renames Item.Prefs.AI_Found;
   begin
      Menus.Clear (Item.Prefs.AI_Menu);
      Menus.Add (Item.Prefs.AI_Menu, Menus.Check, Style.None_Selected, Checked => Chosen = "");
      for Which in 1 .. MLX.Hub.Count (Found) loop
         Menus.Add
           (Item.Prefs.AI_Menu, Menus.Check, Shown (MLX.Hub.Model_At (Found, Which)),
            Checked => MLX.Hub.Model_At (Found, Which) = Chosen);
      end loop;
      if MLX.Hub.Left_Out (Found) then
         Menus.Add (Item.Prefs.AI_Menu, Menus.Note, "More models are not shown");
      end if;
   end Fill_AI_Menu;

   procedure Place_AI_Menu (Item : in out Session);
   --  Put the menu under the Model field, its width, as the form is
   --  scrolled.

   procedure Place_AI_Menu (Item : in out Session) is
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Left   : constant Float :=
        (Widgets.Left_Of (Item.Prefs.AI_Select) - Widgets.Left_Of (Item.Prefs.Settings_Panel)) / Pixels;
      Top    : constant Float :=
        (Widgets.Top_Of (Item.Prefs.AI_Select) + Widgets.Height_Of (Item.Prefs.AI_Select)
         - Widgets.Top_Of (Item.Prefs.Settings_Panel)) / Pixels + Style.Menu_Gap;
   begin
      if Left /= Item.Prefs.AI_Menu_Left or else Top /= Item.Prefs.AI_Menu_Top then
         Item.Prefs.AI_Menu_Left := Left;
         Item.Prefs.AI_Menu_Top := Top;
         Layouts.Set_Layout
           (Item.Prefs.AI_Menu,
            Position => (Left => Float'Rounding (Left * Pixels), Top => Float'Rounding (Top * Pixels),
                         others => <>),
            Unit => Layouts.Device_Pixels);
         Layouts.Set_Layout (Item.Prefs.AI_Menu, Width => Widgets.Width_Of (Item.Prefs.AI_Select) / Pixels);
         Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      end if;
   end Place_AI_Menu;

   procedure Refresh_AI (Item : in out Session);
   --  Show the AI settings as they are.

   procedure Refresh_AI (Item : in out Session) is
      On       : constant Boolean := Item.Prefs.AI_On;
      Name     : constant String := AI_Model (Item);
      Any      : constant Boolean := MLX.Hub.Count (Item.Prefs.AI_Found) > 0;
      Chosen   : constant Boolean := Any and then Name /= "";
      Problem  : constant String := AI_Problem (Item);
      Running  : constant Boolean := MLX.State = MLX.Running;
      --  What the test says is of this model only, and not of one that
      --  was chosen since.
      Tested   : constant Boolean :=
        Chosen and then Problem = ""
        and then Ada.Strings.Unbounded.To_String (Item.Prefs.AI_Tested) = Name;
      Done     : constant Boolean := Tested and then MLX.State = MLX.Done;
      Failed   : constant Boolean := Tested and then MLX.State = MLX.Failed;
   begin
      Switches.Set_On (Item.Prefs.AI_Enable, On);
      Widgets.Set_Visible (Item.Prefs.AI_Model_Name, On);
      Widgets.Set_Visible (Item.Prefs.AI_Hub_Note, On and then not Any);
      Widgets.Set_Visible (Item.Prefs.AI_Select, On and then Any);
      Widgets.Set_Visible (Item.Prefs.AI_Test_Row, On and then Chosen);
      if not (On and then Any) and then Item.Prefs.AI_Menu_Open then
         Close_AI_Menu (Item);
      end if;
      Selects.Set_Value (Item.Prefs.AI_Select, (if Name = "" then Style.None_Selected else Shown (Name)));
      Selects.Set_Open (Item.Prefs.AI_Select, Item.Prefs.AI_Menu_Open);
      Buttons.Set_Enabled (Item.Prefs.AI_Test_Button, Problem = "" and then not Running);
      Labels.Set_Text
        (Item.Prefs.AI_Test_State,
         (if Running then "Running the test, this can take a while"
          elsif Done then "The test passed"
          elsif Failed then "The test failed"
          else ""));
      Labels.Set_Ink
        (Item.Prefs.AI_Test_State, (if Failed then Themes.Danger_Ink else Style.Quiet_Ink));
      if On and then Chosen and then Problem /= "" then
         Say (Item, Problem, Themes.Danger_Ink);
      elsif On and then Done then
         Say (Item, MLX.Text, Themes.Foreground);
      elsif On and then Failed then
         Say (Item, MLX.Text, Themes.Danger_Ink);
      else
         Say (Item, "", Themes.Foreground);
      end if;
      Item.Prefs.AI_Test_Seen := MLX.State;
   end Refresh_AI;

   procedure Scan_AI (Item : in out Session);
   --  Look in the Hugging Face cache again, and find out about the model
   --  chosen.

   procedure Scan_AI (Item : in out Session) is
   begin
      MLX.Hub.Scan (Item.Prefs.AI_Found);
      Judge (Item);
      Fill_AI_Menu (Item);
   end Scan_AI;

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
      Refresh_AI (Item);
   end Refresh;

   procedure Open (Item : in out Session) is
   begin
      Item.Prefs.Showing_Settings := True;
      Widgets.Clear_Focus (Item.Root.Widgets);
      Widgets.Set_Visible (Item.Home_View.Home_Panel, False);
      Widgets.Set_Visible (Item.Prefs.Settings_Panel, True);
      Scan_AI (Item);
      Refresh (Item);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Open;

   procedure Close (Item : in out Session) is
   begin
      Item.Prefs.Showing_Settings := False;
      Close_AI_Menu (Item);
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

   procedure Download (Item : in out Session) is
   begin
      if Speech.Models.State /= Speech.Models.Running
        and then not Model_Present (Item)
      then
         Speech.Models.Start (Model_Directory (Item));
         Refresh (Item);
         Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      end if;
   end Download;

   procedure Ask_To_Delete (Item : in out Session) is
   begin
      if Speech.Models.State /= Speech.Models.Running and then Model_Present (Item) then
         Deletion.Confirm_Model
           (Item, "Its " & Size_Text (On_Disk (Item)) & " of files go; they can be downloaded again.");
      end if;
   end Ask_To_Delete;

   procedure Delete_Files (Item : in out Session) is
   begin
      Deletion.Close (Item);
      if Speech.Models.State /= Speech.Models.Running then
         Speech.Models.Delete (Model_Directory (Item));
         Speech.Models.Reset;
      end if;
      Refresh (Item);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Delete_Files;

   procedure Update (Item : in out Session) is
      Now : constant Speech.Models.States := Speech.Models.State;
   begin
      if Item.Prefs.AI_Menu_Open then
         Place_AI_Menu (Item);
      end if;
      if Now = Speech.Models.Running then
         Refresh (Item);
      elsif Now /= Item.Prefs.Download_Seen or else MLX.State /= Item.Prefs.AI_Test_Seen then
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
         Close_AI_Menu (Item);
         Pomarine.Widgets.Layouts.Set_Layout (Item.Prefs.Settings_Form, Width => Wide);
      end if;
   end Fit;

   procedure Save_AI (Item : in out Session) is
   begin
      if Item.Prefs.Persist then
         begin
            Preferences.Save_AI_Enabled (Config (Item), Item.Prefs.AI_On);
            Preferences.Save_AI_Model (Config (Item), AI_Model (Item));
         exception
            when others =>
               null;  --  the choice holds for now; it is not worth a crash
         end;
      end if;
   end Save_AI;

   procedure Close_AI_Menu (Item : in out Session) is
   begin
      if Item.Prefs.AI_Menu_Open then
         Item.Prefs.AI_Menu_Open := False;
         Widgets.Set_Visible (Item.Prefs.AI_Menu, False);
         Selects.Set_Open (Item.Prefs.AI_Select, False);
      end if;
   end Close_AI_Menu;

   procedure Enable_AI (Item : in out Session; To : Boolean) is
   begin
      Item.Prefs.AI_On := To;
      Save_AI (Item);
      if To then
         Scan_AI (Item);
      else
         Close_AI_Menu (Item);
      end if;
      Refresh (Item);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Enable_AI;

   procedure Toggle_AI_Menu (Item : in out Session) is
   begin
      if Item.Prefs.AI_Menu_Open then
         Close_AI_Menu (Item);
      elsif Item.Prefs.AI_On and then MLX.Hub.Count (Item.Prefs.AI_Found) > 0 then
         --  What is in the cache may have changed since it was looked at.
         Scan_AI (Item);
         Item.Prefs.AI_Menu_Open := True;
         Item.Prefs.AI_Menu_Left := -1.0E9;
         Widgets.Set_Visible (Item.Prefs.AI_Menu, True);
         Widgets.Raise_To_Front (Item.Prefs.AI_Menu);
         Place_AI_Menu (Item);
      end if;
      Refresh (Item);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Toggle_AI_Menu;

   procedure Choose_AI_Model (Item : in out Session; Row : Natural) is
      Found : MLX.Hub.Models renames Item.Prefs.AI_Found;
   begin
      if Row = 1 or else Row in 2 .. MLX.Hub.Count (Found) + 1 then
         Item.Prefs.AI_Model :=
           Ada.Strings.Unbounded.To_Unbounded_String
             (if Row = 1 then "" else MLX.Hub.Model_At (Found, Row - 1));
         Save_AI (Item);
         Judge (Item);
         Close_AI_Menu (Item);
         Fill_AI_Menu (Item);
         Refresh (Item);
         Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      end if;
   end Choose_AI_Model;

   procedure Test_AI (Item : in out Session) is
      Name   : constant String := AI_Model (Item);
      Folder : constant String := (if Name = "" then "" else MLX.Hub.Snapshot (Name));
   begin
      Judge (Item);
      if Item.Prefs.AI_On and then Name /= "" and then AI_Problem (Item) = ""
        and then MLX.State /= MLX.Running and then Folder /= ""
      then
         Item.Prefs.AI_Tested := Item.Prefs.AI_Model;
         MLX.Start_Test (Folder);
      end if;
      Refresh (Item);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Test_AI;

   procedure Pressed (Item : in out Session; X, Y : Float) is
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
   begin
      --  The field's own click puts the menu away, if it is pressed.
      if Item.Prefs.AI_Menu_Open
        and then not Widgets.Contains (Item.Prefs.AI_Menu, X * Pixels, Y * Pixels)
        and then not Widgets.Contains (Item.Prefs.AI_Select, X * Pixels, Y * Pixels)
      then
         Close_AI_Menu (Item);
         Refresh (Item);
      end if;
   end Pressed;

end Viewer.Settings_View;
