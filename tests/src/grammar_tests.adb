with Ada.Real_Time;
with Goldens;
with Grammar_Rules;
with Harper;
with Items.Schema;
with Long_Texts;
with Projects.Rules;
with SDL3.Events;
with Viewer;
with Viewer.Canvas_Windows;
with Viewer.Documents;
with Viewer.Home_Screen;
with Viewer.Project_Screen;
with Viewer.Outline_Screen;

package body Grammar_Tests is
   package Events renames SDL3.Events;
   package Docs renames Viewer.Documents;
   package Windows renames Viewer.Canvas_Windows;
   package Proj renames Viewer.Project_Screen;
   use type Ada.Real_Time.Time;
   use type Events.Milliseconds;

   procedure Click (Item : in out Viewer.Session; X, Y : Float) is
   begin
      Viewer.Handle (Item, (Kind => Events.Mouse_Move, Mouse_X => X, Mouse_Y => Y, others => <>));
      Viewer.Handle (Item, (Kind => Events.Mouse_Down, Button => 1, Clicks => 1,
                           Mouse_X => X, Mouse_Y => Y, others => <>));
      Viewer.Handle (Item, (Kind => Events.Mouse_Up, Button => 1, Clicks => 1,
                           Mouse_X => X, Mouse_Y => Y, others => <>));
   end Click;

   procedure Check (Name : String; Value : Boolean) is
   begin
      Goldens.Check_Text (Name, "TRUE", Boolean'Image (Value));
   end Check;

   procedure Await (Item : in out Viewer.Session; Now : Events.Milliseconds) is
      Deadline : constant Ada.Real_Time.Time := Ada.Real_Time.Clock + Ada.Real_Time.Seconds (60);
   begin
      loop
         Viewer.Tick (Item, Now);
         exit when not Docs.Grammar_Pending (Item);
         pragma Assert (Ada.Real_Time.Clock < Deadline, "grammar checking timed out");
         delay 0.002;
      end loop;
   end Await;

   procedure Snap (Item : in out Viewer.Session; Name : String) is
      Image : Goldens.Images.Image;
   begin
      Viewer.Render (Item, Image);
      Goldens.Check (Name, Image);
   end Snap;

   procedure Checking is
      Item : Viewer.Session;
      Now  : Events.Milliseconds := 10_000;
      Image : Goldens.Images.Image;
   begin
      Viewer.Open (Item, "", 720, 480, 2.0);
      Viewer.Home_Screen.New_Project (Item);
      Proj.Set_Mode (Item, Viewer.Canvas);
      Windows.Add_Item (Item, "First document");
      Viewer.Handle (Item, Events.Text_Event
        ("This is a speling mistake. This is the the sentence. This is an test."));
      Windows.Add_Item (Item, "Second document");
      Viewer.Handle (Item, Events.Text_Event ("This is a speling mistake."));
      Proj.Set_Mode (Item, Viewer.Write);
      Check ("grammar-default-on", Docs.Grammar_Suggestions_Shown (Item));
      Viewer.Tick (Item, Now);
      Check ("grammar-parallel", Docs.Grammar_Running (Item) >= 2);
      Await (Item, Now);
      Check ("grammar-first-checked", Docs.Grammar_Highlights (Item, 1) > 0);
      Check ("grammar-second-checked", Docs.Grammar_Highlights (Item, 2) > 0);
      Snap (Item, "write-grammar-highlights");

      --  Turning off clears all documents, including those below the viewport.
      Click (Item, 28.0, 95.0);
      Viewer.Tick (Item, Now);
      Check ("grammar-off", not Docs.Grammar_Suggestions_Shown (Item));
      Check ("grammar-cleared", Docs.Grammar_Highlights (Item, 1) = 0
             and then Docs.Grammar_Highlights (Item, 2) = 0);
      Snap (Item, "write-grammar-off");
      Click (Item, 28.0, 95.0);
      Await (Item, Now);
      Check ("grammar-back-on", Docs.Grammar_Highlights (Item, 1) > 0);

      --  Edits expire marks immediately; checks wait until 500 ms idle.
      Click (Item, 400.0, 140.0);
      Viewer.Handle (Item, (Kind => Events.Key_Down, Key => Events.Key_A, Command => True, others => <>));
      Viewer.Handle (Item, Events.Text_Event ("This is a correct sentence."));
      Goldens.Check_Text ("grammar-edited-text", "This is a correct sentence.", Windows.Item_Text (Item, 1));
      Goldens.Check_Text ("grammar-other-text", "This is a speling mistake.", Windows.Item_Text (Item, 2));
      Viewer.Tick (Item, Now);
      Check ("grammar-edit-clears", Docs.Grammar_Highlights (Item, 1) = 0);
      Check ("grammar-other-counted", Docs.Grammar_Count (Item) /= "0");
      Now := Now + 499;
      Viewer.Tick (Item, Now);
      Check ("grammar-idle-waits", Docs.Grammar_Running (Item) = 0 and then Docs.Grammar_Pending (Item));
      Now := Now + 1;
      Await (Item, Now);
      Check ("grammar-corrected", Docs.Grammar_Highlights (Item, 1) = 0);
      Check ("grammar-other-still-counted", Docs.Grammar_Count (Item) = "1");

      --  A newer edit wins even if the old document is still being checked.
      Viewer.Handle (Item, (Kind => Events.Key_Down, Key => Events.Key_A, Command => True, others => <>));
      Viewer.Handle (Item, Events.Text_Event ("This is a speling mistake."));
      Viewer.Tick (Item, Now);
      Now := Now + 500;
      Viewer.Tick (Item, Now);
      Viewer.Handle (Item, (Kind => Events.Key_Down, Key => Events.Key_A, Command => True, others => <>));
      Viewer.Handle (Item, Events.Text_Event ("This is a correct sentence."));
      Viewer.Tick (Item, Now);
      Now := Now + 500;
      Await (Item, Now);
      Check ("grammar-stale-result", Docs.Grammar_Highlights (Item, 1) = 0);

      --  Diagnostics span all documents: editing a clean one keeps the others' marks, count and menu.
      Click (Item, 400.0, 140.0);
      Viewer.Handle (Item, (Kind => Events.Key_Down, Key => Events.Key_A, Command => True, others => <>));
      Viewer.Handle (Item, Events.Text_Event ("This is a speling mistake."));
      Viewer.Tick (Item, Now);
      Now := Now + 500;
      Await (Item, Now);
      Check ("grammar-span-first", Docs.Grammar_Highlights (Item, 1) > 0 and then Docs.Grammar_Count (Item) = "2");
      Click (Item, 100.0, 251.0);
      Viewer.Tick (Item, Now + 1000);
      Viewer.Render (Item, Image);
      Click (Item, 400.0, 460.0);
      Viewer.Handle (Item, (Kind => Events.Key_Down, Key => Events.Key_A, Command => True, others => <>));
      for C of String'("Fine and dandy. It is good.") loop
         Viewer.Handle (Item, Events.Text_Event ([C]));
         Now := Now + 60;
         Viewer.Tick (Item, Now);
         Check ("grammar-span-typing-count", Docs.Grammar_Count (Item) = "1");
      end loop;
      Goldens.Check_Text ("grammar-span-edited", "This is a speling mistake.|Fine and dandy. It is good.",
                          Windows.Item_Text (Item, 1) & "|" & Windows.Item_Text (Item, 2));
      Now := Now + 500;
      Await (Item, Now);
      Check ("grammar-span-kept-marks", Docs.Grammar_Highlights (Item, 1) > 0);
      Check ("grammar-span-kept-count", Docs.Grammar_Count (Item) = "1");

      Proj.Set_Mode (Item, Viewer.Canvas);
      Viewer.Tick (Item, Now);
      Proj.Set_Mode (Item, Viewer.Write);
      Viewer.Tick (Item, Now);
      Check ("grammar-tab-return", Docs.Grammar_Count (Item) = "1" and then Docs.Grammar_Highlights (Item, 1) > 0);
      Click (Item, 181.0, 140.0);
      Viewer.Tick (Item, Now + 1000);
      Check ("grammar-added-count", Docs.Document_Count (Item) = 3);
      Viewer.Handle (Item, Events.Text_Event ("Brand new."));
      for I in 1 .. 4 loop
         Now := Now + 300;
         Viewer.Tick (Item, Now);
         Check ("grammar-added-typing-count", Docs.Grammar_Count (Item) = "1");
      end loop;
      Docs.Move_Document (Item, 2, 1);
      Viewer.Tick (Item, Now);
      Await (Item, Now);
      Check ("grammar-reordered", Docs.Grammar_Highlights (Item, 1) = 0
             and then Docs.Grammar_Highlights (Item, 2) > 0);

      --  Notes alone never create document checker jobs.
      Proj.Close_Project (Item);
      Viewer.Home_Screen.New_Project (Item);
      Viewer.Outline_Screen.Add_Section (Item);
      Viewer.Outline_Screen.Toggle_Notes (Item, 1);
      Viewer.Handle (Item, Events.Text_Event ("speling misteak"));
      Proj.Set_Mode (Item, Viewer.Write);
      Viewer.Tick (Item, Now);
      Check ("grammar-notes-excluded", not Docs.Grammar_Pending (Item) and then Docs.Grammar_Running (Item) = 0);

      --  A paragraph larger than one Harper request is checked in chunks.
      Proj.Set_Mode (Item, Viewer.Canvas);
      Windows.Add_Item (Item, "Long document");
      Windows.Dictate_Into (Item, 1, String'(1 .. 65_540 => ' ') & "This is a speling mistake.");
      Proj.Set_Mode (Item, Viewer.Write);
      Await (Item, Now);
      Check ("grammar-long-document", Docs.Grammar_Highlights (Item, 1) > 0);
   end Checking;

   procedure Rules is
      use type Harper.Span;
      use type Harper.Lint_Kind;
      package PR renames Projects.Rules;

      Text : constant String := "This is a speling mistake. ADA is here. ADAM is not. ADA.";
      --  speling is bytes 10 .. 17, the first ADA 27 .. 30, ADAM 40 .. 44, the last ADA 53 .. 56.

      Rule_List : PR.Rule_List;
      Result : Harper.Check_Result;

      procedure Rule_For (Action : PR.Actions; Kind : PR.Kind_Code; Pattern, Replacement : String) is
      begin
         Rule_List.Append
           ((Key => PR.Rule_Id (Rule_List.Count + 1), Action => Action, Kind => Kind,
             Pattern => Long_Texts.To_Text (Pattern), Replacement => Long_Texts.To_Text (Replacement)));
      end Rule_For;

      procedure Lint (First, Last : Natural; Kind : Harper.Lint_Kind; Fix : String) is
      begin
         Result.Count := Result.Count + 1;
         Result.Lints (Result.Count) :=
           (Location => (First, Last), Kind => Kind, Suggestion_Count => 1, Priority => 31,
            Suggestions => [1 => ((First, Last), Harper.Replacements.To_Bounded_String (Fix)),
                            others => <>],
            others => <>);
      end Lint;
   begin
      --  Nothing ruled: nothing changes.
      Lint (10, 17, Harper.Spelling, "spelling");
      Lint (27, 30, Harper.Capitalization, "Ada");
      Grammar_Rules.Apply (Rule_List, Text, Result);
      Check ("rules-none-kept", Result.Count = 2 and then not Result.Lints (1).Custom);

      --  An ignored text is dropped only as the kind it was ignored as.
      Rule_For (PR.Ignore, Grammar_Rules.Kind_Code (Harper.Typo), "speling", "");
      Grammar_Rules.Apply (Rule_List, Text, Result);
      Check ("rules-ignore-other-kind", Result.Count = 2);
      Rule_For (PR.Ignore, Grammar_Rules.Kind_Code (Harper.Spelling), "speling", "");
      Grammar_Rules.Apply (Rule_List, Text, Result);
      Check ("rules-ignore", Result.Count = 1 and then Result.Lints (1).Location = (27, 30));

      --  A correction goes first at a diagnostic on its text, and is not offered twice.
      Rule_For (PR.Correct, 0, "ADA", "Ada");
      Grammar_Rules.Apply (Rule_List, Text, Result);
      Check ("rules-correct-upgrades", Result.Lints (1).Custom and then Result.Lints (1).Suggestion_Count = 1
             and then Harper.Replacements.To_String (Result.Lints (1).Suggestions (1).Text) = "Ada");
      Check ("rules-correct-message", Harper.Messages.To_String (Result.Lints (1).Message)
             = "Your rule: replace ""ADA"" with ""Ada"".");

      --  And makes its own where Harper found nothing: at whole words only, in the order of the places.
      Check ("rules-correct-adds", Result.Count = 2 and then Result.Lints (2).Location = (53, 56)
             and then Result.Lints (2).Custom and then Result.Lints (2).Kind = Harper.Spelling);

      --  Harper's own order is kept, and a rule is no one's diagnostic twice.
      Grammar_Rules.Apply (Rule_List, Text, Result);
      Check ("rules-idempotent", Result.Count = 2);
      Check ("rules-adam-left", (for all Index in 1 .. Result.Count => Result.Lints (Index).Location /= (40, 44)));

      --  Text of other places and cases is not touched.
      Result := (others => <>);
      Grammar_Rules.Apply (Rule_List, "Ada and ada and ADAM", Result);
      Check ("rules-case", Result.Count = 0);

      --  A correction too long for a suggestion is left out, not cut.
      Result := (others => <>);
      Rule_List.Clear;
      Rule_For (PR.Correct, 0, "ADA", String'[1 .. Harper.Max_Replacement + 1 => 'x']);
      Grammar_Rules.Apply (Rule_List, Text, Result);
      Check ("rules-too-long", Result.Count = 0);

      --  Many places: the result stays within its room.
      Result := (others => <>);
      Rule_List.Clear;
      Rule_For (PR.Correct, 0, "ADA", "Ada");
      declare
         Words : String (1 .. 5 * 200);
      begin
         for Index in 0 .. 199 loop
            Words (Index * 5 + 1 .. Index * 5 + 5) := "ADA, ";
         end loop;
         Grammar_Rules.Apply (Rule_List, Words, Result);
         Check ("rules-capacity", Result.Count = Harper.Max_Lints and then Result.Truncated);
      end;
   end Rules;

   procedure Rule_Cards is
      use type Projects.Rules.Rule_Id;
      Item : Viewer.Session;
      Now  : Events.Milliseconds := 10_000;
      Store : Projects.Store;
   begin
      Viewer.Open (Item, "", 720, 480, 2.0);
      Viewer.Home_Screen.New_Project (Item);
      Proj.Set_Mode (Item, Viewer.Canvas);
      Windows.Add_Item (Item, "Notes");
      Viewer.Handle (Item, Events.Text_Event ("This is a speling mistake. Another speling here, and a the the."));
      Proj.Set_Mode (Item, Viewer.Write);
      Await (Item, Now);
      Check ("rule-cards-marked", Docs.Grammar_Marking (Item, "speling") = 2);
      Check ("rule-cards-none-made", Docs.Grammar_Made_By_Rule (Item, "speling") = 0);
      Check ("rule-cards-no-rules", Docs.Grammar_Rule_Count (Item) = 0);

      --  Correcting a text makes a rule, offered first at every place of the text, and listed first.
      Docs.Grammar_Show (Item);
      Viewer.Tick (Item, Now);
      Docs.Grammar_Expand (Item, "speling");
      Snap (Item, "write-grammar-rule-card");
      Docs.Grammar_Begin_Rule (Item, "speling");
      Snap (Item, "write-grammar-rule-entry");
      Docs.Grammar_Correct (Item, "speling", "Speling!");
      Check ("rule-cards-corrected", Docs.Grammar_Rule_Count (Item) = 1);
      Now := Now + 1;
      Await (Item, Now);
      Check ("rule-cards-made", Docs.Grammar_Made_By_Rule (Item, "speling") = 2);
      Goldens.Check_Text ("rule-cards-first-fix", "Speling!", Docs.Grammar_First_Suggestion (Item, "speling"));
      Docs.Grammar_Show (Item);
      Viewer.Tick (Item, Now);
      Check ("rule-cards-first", Docs.Grammar_First_Card_Made_By_Rule (Item));
      Docs.Grammar_Expand (Item, "speling");
      Snap (Item, "write-grammar-rule-made");

      --  Taking the rule away puts Harper's own diagnostics back.
      Docs.Grammar_Remove_Rule (Item, "speling");
      Check ("rule-cards-removed", Docs.Grammar_Rule_Count (Item) = 0);
      Now := Now + 1;
      Await (Item, Now);
      Check ("rule-cards-unmade", Docs.Grammar_Made_By_Rule (Item, "speling") = 0
             and then Docs.Grammar_Marking (Item, "speling") = 2);

      --  Ignoring a text drops the diagnostics on it, and no others.
      Docs.Grammar_Ignore (Item, "speling");
      Check ("rule-cards-ignored", Docs.Grammar_Rule_Count (Item) = 1);
      Now := Now + 1;
      Await (Item, Now);
      Check ("rule-cards-gone", Docs.Grammar_Marking (Item, "speling") = 0);
      Check ("rule-cards-others-stay", Docs.Grammar_Marking (Item, "the the") > 0);

      --  The rules are the project's own, and are kept.
      Projects.Open (Store, Projects.Memory);
      Items.Schema.Prepare (Store);
      declare
         Mine  : constant Projects.Id := Projects.Create (Store, "Mine");
         Yours : constant Projects.Id := Projects.Create (Store, "Yours");
         Made  : Projects.Rules.Rule_List;

         procedure Put (Owner : Projects.Id; Action : Projects.Rules.Actions; Kind : Projects.Rules.Kind_Code;
                        Pattern : String; Replacement : String := "")
         is
            Key : constant Projects.Rules.Rule_Id :=
              Projects.Rules.Add (Store, Owner, Action, Kind, Pattern, Replacement);
         begin
            Check ("rule-store-key", Key > 0);
         end Put;
      begin
         Put (Mine, Projects.Rules.Correct, 15, "ADA", "Ada");
         Put (Mine, Projects.Rules.Correct, 15, "ADA", "Ada!");
         Put (Mine, Projects.Rules.Ignore, 15, "ADA");
         Put (Mine, Projects.Rules.Ignore, 3, "ADA");
         Put (Yours, Projects.Rules.Ignore, 15, "ADA");
         Projects.Rules.Load (Store, Mine, Made);
         Check ("rule-store-count", Made.Count = 3);
         Goldens.Check_Text ("rule-store-replaced", "Ada!", Long_Texts.To_String (Made (1).Replacement));
         Projects.Rules.Remove (Store, Made (2).Key);
         Projects.Rules.Load (Store, Mine, Made);
         Check ("rule-store-removed", Made.Count = 2);
         Projects.Rules.Load (Store, Yours, Made);
         Check ("rule-store-apart", Made.Count = 1);
      end;
   end Rule_Cards;
end Grammar_Tests;
