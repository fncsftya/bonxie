with Ada.Assertions;
with Goldens;
with Items;
with Long_Texts;
with Pomarine.Events;
with Pomarine.Testing;
with Pomarine.View_Models;
with Search_VM;
with View;
with View.Canvas_Windows;
with View_Driver;

package body Search_VM_Tests is
   use type Items.Id;
   use type Search_VM.Context;
   use type Pomarine.View_Models.Version_Number;
   procedure Check (Name : String; Expected, Actual : String) renames Goldens.Check_Text;
   function Image (Value : Boolean) return String
   is (Value'Image);

   type Finder is limited new Search_VM.Finder with record
      Available            : Boolean := True;
      Key                  : Items.Id := 7;
      Matches              : Search_VM.Result;
      Typed                : Long_Texts.Text;
      Where                : Search_VM.Context;
      Polls, Clears, Steps : Natural := 0;
   end record;
   overriding
   function Valid (Self : Finder; Where : Search_VM.Context) return Boolean;
   overriding
   procedure Refresh (Self : in out Finder; Where : Search_VM.Context; Term : String; Found : out Search_VM.Result);
   overriding
   procedure Advance (Self : in out Finder; Where : Search_VM.Context; Backwards : Boolean);
   overriding
   procedure Clear (Self : in out Finder; Where : Search_VM.Context);

   overriding
   function Valid (Self : Finder; Where : Search_VM.Context) return Boolean
   is (Self.Available and then Where.Key = Self.Key);
   overriding
   procedure Refresh (Self : in out Finder; Where : Search_VM.Context; Term : String; Found : out Search_VM.Result) is
   begin
      Self.Where := Where;
      Self.Typed := Long_Texts.To_Text (Term);
      Self.Polls := Self.Polls + 1;
      Found := Self.Matches;
   end Refresh;
   overriding
   procedure Advance (Self : in out Finder; Where : Search_VM.Context; Backwards : Boolean) is
   begin
      pragma Assert (Valid (Self, Where));
      Self.Steps := Self.Steps + 1;
      Self.Matches.Current :=
        (if Backwards
         then (if Self.Matches.Current <= 1 then Self.Matches.Total else Self.Matches.Current - 1)
         else (if Self.Matches.Current >= Self.Matches.Total then 1 else Self.Matches.Current + 1));
   end Advance;
   overriding
   procedure Clear (Self : in out Finder; Where : Search_VM.Context) is
   begin
      Self.Where := Where;
      Self.Clears := Self.Clears + 1;
   end Clear;

   procedure Lifecycle is
      Engine    : aliased Finder;
      Model     : Search_VM.View_Model;
      Seen      : Pomarine.View_Models.Version_Number;
      Rejected  : Boolean := False;
      Long_Term : constant String (1 .. 700) := [others => 'x'];
      Target    : constant Search_VM.Context := (Search_VM.Canvas_Item, 4, 7);
   begin
      Search_VM.Initialize (Model, Engine'Unchecked_Access);
      Check
        ("search-vm-closed",
         "FALSE FALSE FALSE 0 / 0",
         Image (Search_VM.Is_Showing (Model))
         & " "
         & Image (Search_VM.Can_Execute (Model, Search_VM.Close))
         & " "
         & Image (Search_VM.Can_Execute (Model, Search_VM.Next))
         & " "
         & Search_VM.Summary (Model));
      Search_VM.Poll (Model);
      Check ("search-vm-hidden-no-poll", "TRUE", Image (Engine.Polls = 0));
      Search_VM.Set_Term (Model, Long_Term);
      Seen := Search_VM.Version (Model);
      Search_VM.Set_Term (Model, Long_Term);
      Check ("search-vm-term-no-change", "TRUE", Image (Search_VM.Version (Model) = Seen));
      Search_VM.Open (Model, Target);
      Check
        ("search-vm-open",
         "TRUE TRUE TRUE TRUE FALSE",
         Image (Search_VM.Is_Showing (Model))
         & " "
         & Image (Search_VM.Location (Model) = Target)
         & " "
         & Image (Long_Texts.To_String (Engine.Typed) = Long_Term)
         & " "
         & Image (Search_VM.Can_Execute (Model, Search_VM.Close))
         & " "
         & Image (Search_VM.Can_Execute (Model, Search_VM.Previous)));
      begin
         Search_VM.Execute (Model, Search_VM.Next);
      exception
         when Ada.Assertions.Assertion_Error =>
            Rejected := True;
      end;
      Check ("search-vm-next-contract", "TRUE", Image (Rejected));
      Seen := Search_VM.Version (Model);
      Search_VM.Poll (Model);
      Check ("search-vm-poll-no-change", "TRUE", Image (Search_VM.Version (Model) = Seen));
      Engine.Matches := (1, 700, True);
      Search_VM.Poll (Model);
      Check
        ("search-vm-background",
         "1 / 700 ... TRUE TRUE",
         Search_VM.Summary (Model)
         & " "
         & Image (Search_VM.Version (Model) /= Seen)
         & " "
         & Image (Search_VM.Can_Execute (Model, Search_VM.Next)));
      Search_VM.Execute (Model, Search_VM.Previous);
      Check ("search-vm-back-wrap", "700 / 700 ...", Search_VM.Summary (Model));
      Search_VM.Execute (Model, Search_VM.Next);
      Check ("search-vm-forward-wrap", "1 / 700 ...", Search_VM.Summary (Model));
      Engine.Matches.Busy := False;
      Search_VM.Poll (Model);
      Check ("search-vm-done", "1 / 700", Search_VM.Summary (Model));
      Search_VM.Set_Term (Model, "changed query");
      Search_VM.Poll (Model);
      Check ("search-vm-query-edited", "changed query", Long_Texts.To_String (Engine.Typed));
      Search_VM.Set_Term (Model, Long_Term);
      Search_VM.Open (Model, (Search_VM.Writing, 1, 7));
      Check
        ("search-vm-switch",
         "TRUE TRUE TRUE",
         Image (Engine.Clears = 1)
         & " "
         & Image (Search_VM.Term (Model) = Long_Term)
         & " "
         & Image (Engine.Where = Search_VM.Context'(Search_VM.Writing, 1, 7)));
      Engine.Key := 8;
      Search_VM.Execute (Model, Search_VM.Next);
      Check
        ("search-vm-stale",
         "FALSE TRUE TRUE 0 / 0",
         Image (Search_VM.Is_Showing (Model))
         & " "
         & Image (Engine.Steps = 2)
         & " "
         & Image (Engine.Clears = 2)
         & " "
         & Search_VM.Summary (Model));
      Search_VM.Open (Model, Target);
      Check ("search-vm-invalid-open", "FALSE", Image (Search_VM.Is_Showing (Model)));
      Engine.Key := 7;
      Search_VM.Open (Model, Target);
      Engine.Available := False;
      Search_VM.Poll (Model);
      Check
        ("search-vm-left-view", "FALSE TRUE", Image (Search_VM.Is_Showing (Model)) & " " & Image (Engine.Clears = 3));
   end Lifecycle;

   procedure By_Name is
      App    : aliased View.Session;
      Ears   : aliased View_Driver.Driver (App'Access);
      Window : Pomarine.Testing.Session;
      package Testing renames Pomarine.Testing;
   begin
      View.Open (App, "", 1000, 800);
      Testing.Attach (Window, View.Widget_Tree (App).all, Ears'Access);
      Testing.Click_On (Window, "New project");
      Testing.Click_On (Window, "Canvas");
      View.Canvas_Windows.Add_Item (App, "Searchable");
      Testing.Type_Text (Window, "bonxie bonxie");
      Testing.Press (Window, Pomarine.Events.Key_F, Command => True);
      Testing.Type_Text (Window, "bonxie");
      Check
        ("search-name-open",
         "TRUE TRUE FALSE",
         Image (Testing.Exists (Window, "Find in item"))
         & " "
         & Image (Testing.Shows (Window, "1 / 2"))
         & " "
         & Image (Testing.Is_Disabled (Window, "Next")));
      Testing.Click_On (Window, "Next");
      Check ("search-name-next", "TRUE", Image (Testing.Shows (Window, "2 / 2")));
      Testing.Click_On (Window, "Previous");
      Check ("search-name-previous", "TRUE", Image (Testing.Shows (Window, "1 / 2")));
      Testing.Click_On (Window, "Find in item");
      Testing.Press (Window, Pomarine.Events.Key_A, Command => True);
      Testing.Type_Text (Window, "absent");
      Check
        ("search-name-none",
         "TRUE TRUE TRUE",
         Image (Testing.Shows (Window, "0 / 0"))
         & " "
         & Image (Testing.Is_Disabled (Window, "Next"))
         & " "
         & Image (Testing.Is_Disabled (Window, "Previous")));
      Testing.Click_On (Window, "Close", Nth => 2);
      Check ("search-name-close", "FALSE", Image (View.Canvas_Windows.Search_Is_Open (App)));
      --  Reuse the same bar and bindings after closing and changing its parent.
      Testing.Press (Window, Pomarine.Events.Key_F, Command => True);
      Check
        ("search-name-reopen",
         "TRUE TRUE",
         Image (Testing.Exists (Window, "Find in item")) & " " & Image (Testing.Shows (Window, "0 / 0")));
      Testing.Click_On (Window, "Find in item");
      Testing.Press (Window, Pomarine.Events.Key_A, Command => True);
      Testing.Type_Text (Window, "bonxie");
      Testing.Click_On (Window, "Next");
      Check ("search-name-reused-next", "TRUE", Image (Testing.Shows (Window, "2 / 2")));
      Testing.Click_On (Window, "Write");
      Testing.Press (Window, Pomarine.Events.Key_F, Command => True);
      Check ("search-name-writing", "TRUE", Image (Testing.Exists (Window, "Find in all documents")));
      Testing.Click_On (Window, "Close");
      Check ("search-name-writing-close", "FALSE", Image (Testing.Exists (Window, "Find in all documents")));

   end By_Name;
end Search_VM_Tests;
