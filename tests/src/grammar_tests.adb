with Ada.Real_Time;
with Goldens;
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
end Grammar_Tests;
