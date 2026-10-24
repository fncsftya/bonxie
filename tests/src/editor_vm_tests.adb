with Ada.Assertions;
with Editor_VM;
with Goldens;
with Items.Models;
with Pomarine.View_Models;
with Pomarine.Events;
with Pomarine.Semantics;
with Pomarine.Testing;
with View;
with View.Canvas_Windows;
with View_Driver;
with Texts;
with Texts.Documents;

package body Editor_VM_Tests is
   package Docs renames Texts.Documents;
   use type Pomarine.View_Models.Version_Number;
   use type Docs.Version;
   use type Texts.Position;
   use type Items.Models.Dictations;
   procedure Check (Name : String; Expected, Actual : String) renames Goldens.Check_Text;
   function Image (Value : Boolean) return String is (Value'Image);

   type Editor is limited new Editor_VM.Editor with record
      Doc : Docs.Document_Access;
      Has_Focus : Boolean := False;
      At_Caret, At_Mark : Texts.Position;
      Seen : Docs.Version := 0;
      Faint : Boolean := False;
      Faint_From, Faint_To : Texts.Position;
      Clears : Natural := 0;
   end record;
   overriding function Focused (Self : Editor) return Boolean;
   overriding function Caret (Self : Editor) return Texts.Position;
   overriding function Mark (Self : Editor) return Texts.Position;
   overriding procedure Select_Range (Self : in out Editor; From, To : Texts.Position);
   overriding procedure Insert (Self : in out Editor; Text : String);
   overriding procedure Set_Faint (Self : in out Editor; From, To : Texts.Position);
   overriding procedure Clear_Faint (Self : in out Editor);

   function Updated (Self : Editor; Where : Texts.Position) return Texts.Position is
      Result : Texts.Position := Where;
   begin
      for Seen in Self.Seen .. Docs.Current (Self.Doc.all) - 1 loop
         Result := Docs.Map (Docs.Change_After (Self.Doc.all, Seen), Result);
      end loop;
      return Result;
   end Updated;
   overriding function Focused (Self : Editor) return Boolean is (Self.Has_Focus);
   overriding function Caret (Self : Editor) return Texts.Position is (Updated (Self, Self.At_Caret));
   overriding function Mark (Self : Editor) return Texts.Position is (Updated (Self, Self.At_Mark));
   overriding procedure Select_Range (Self : in out Editor; From, To : Texts.Position) is
   begin
      pragma Assert (Docs.Is_Position (Self.Doc.all, From) and then Docs.Is_Position (Self.Doc.all, To));
      Self.At_Mark := From;
      Self.At_Caret := To;
      Self.Seen := Docs.Current (Self.Doc.all);
      Docs.Seal (Self.Doc.all);
   end Select_Range;
   overriding procedure Insert (Self : in out Editor; Text : String) is
      From : constant Texts.Position := Caret (Self);
   begin
      pragma Assert (From = Mark (Self));
      Docs.Begin_Step (Self.Doc.all);
      Docs.Replace (Self.Doc.all, From, From, Text);
      Docs.End_Step (Self.Doc.all);
      Select_Range (Self, Texts.End_After (From, Text), Texts.End_After (From, Text));
   end Insert;
   overriding procedure Set_Faint (Self : in out Editor; From, To : Texts.Position) is
   begin
      pragma Assert (Docs.Is_Position (Self.Doc.all, From) and then Docs.Is_Position (Self.Doc.all, To));
      Self.Faint := True;
      Self.Faint_From := From;
      Self.Faint_To := To;
   end Set_Faint;
   overriding procedure Clear_Faint (Self : in out Editor) is
   begin
      Self.Faint := False;
      Self.Clears := Self.Clears + 1;
   end Clear_Faint;

   type Fixture is limited record
      Doc : aliased Docs.Document;
      Model : Editor_VM.View_Model;
      View : Editor;
   end record;
   procedure Prepare (Self : in out Fixture; Text : String; With_Focus : Boolean := False) is
   begin
      Docs.Load (Self.Doc, Text);
      Editor_VM.Initialize (Self.Model, Self.Doc'Unchecked_Access);
      Self.View.Doc := Self.Doc'Unchecked_Access;
      Self.View.Has_Focus := With_Focus;
      Self.View.At_Caret := (1, 1);
      Self.View.At_Mark := (1, 1);
      Self.View.Seen := Docs.Current (Self.Doc);
      Self.View.Faint := False;
      Self.View.Clears := 0;
      Editor_VM.Show_Live (Self.Model, Self.View, "");
   end Prepare;

   procedure Placement is
      Test : Fixture;
      From, To : Texts.Position;
   begin
      Prepare (Test, "ac", With_Focus => True);
      Select_Range (Test.View, (1, 1), (1, 2));
      Editor_VM.Append_Said (Test.Model, Test.View, "b");
      Check ("editor-vm-selection-kept", "abc", Docs.Whole (Test.Doc));
      Check ("editor-vm-caret", "TRUE", Image (Caret (Test.View) = Texts.Position'(1, 3)));
      Docs.Undo (Test.Doc, From, To);
      Check ("editor-vm-caret-undo", "ac", Docs.Whole (Test.Doc));
      Prepare (Test, "abc");
      Editor_VM.Append_Said (Test.Model, Test.View, "next");
      Check ("editor-vm-new-paragraph", "abc" & ASCII.LF & "next", Docs.Whole (Test.Doc));
      Docs.Undo (Test.Doc, From, To);
      Check ("editor-vm-paragraph-undo", "abc", Docs.Whole (Test.Doc));
      Prepare (Test, "abc" & ASCII.LF);
      Editor_VM.Append_Said (Test.Model, Test.View, "next");
      Check ("editor-vm-empty-paragraph", "abc" & ASCII.LF & "next", Docs.Whole (Test.Doc));
      Prepare (Test, "");
      Editor_VM.Append_Said (Test.Model, Test.View, "first");
      Editor_VM.Append_Said (Test.Model, Test.View, "");
      Check ("editor-vm-empty-note", "first", Docs.Whole (Test.Doc));
   end Placement;

   procedure Live_Text is
      Test : Fixture;
      Seen : Docs.Version;
      Model_Seen : Pomarine.View_Models.Version_Number;
      From, To : Texts.Position;
   begin
      Prepare (Test, "abc");
      Editor_VM.Show_Live (Test.Model, Test.View, "hel");
      Check ("editor-vm-live", "abc" & ASCII.LF & "hel", Docs.Whole (Test.Doc));
      Check ("editor-vm-provisional", "TRUE TRUE FALSE", Image (Editor_VM.Has_Live (Test.Model)) & " "
             & Image (Test.View.Faint) & " " & Image (Docs.Can_Undo (Test.Doc)));
      Editor_VM.Show_Live (Test.Model, Test.View, "hello world", Settled => 5);
      Check ("editor-vm-grown", "abc" & ASCII.LF & "hello world", Docs.Whole (Test.Doc));
      Check ("editor-vm-faint-suffix", "TRUE TRUE", Image (Test.View.Faint_From = Texts.Position'(2, 6)) & " "
             & Image (Test.View.Faint_To = Texts.Position'(2, 12)));
      Seen := Docs.Current (Test.Doc);
      Model_Seen := Editor_VM.Version (Test.Model);
      Editor_VM.Show_Live (Test.Model, Test.View, "hello world", Settled => 20);
      Check ("editor-vm-settled-no-edit", "TRUE FALSE", Image (Docs.Current (Test.Doc) = Seen) & " "
             & Image (Test.View.Faint));
      Check ("editor-vm-no-op-version", "TRUE", Image (Editor_VM.Version (Test.Model) = Model_Seen));
      Editor_VM.Append_Said (Test.Model, Test.View, "Hello, world.");
      Check ("editor-vm-final", "abc" & ASCII.LF & "Hello, world.", Docs.Whole (Test.Doc));
      Check ("editor-vm-final-clears", "FALSE FALSE", Image (Editor_VM.Has_Live (Test.Model)) & " "
             & Image (Test.View.Faint));
      Docs.Undo (Test.Doc, From, To);
      Check ("editor-vm-final-undo", "abc", Docs.Whole (Test.Doc));
      Docs.Redo (Test.Doc, From, To);
      Check ("editor-vm-final-redo", "abc" & ASCII.LF & "Hello, world.", Docs.Whole (Test.Doc));
      Prepare (Test, "abc");
      Editor_VM.Show_Live (Test.Model, Test.View, "temporary");
      Editor_VM.Take_Back_Live (Test.Model, Test.View);
      Check ("editor-vm-cancel", "abc FALSE FALSE", Docs.Whole (Test.Doc) & " "
             & Image (Editor_VM.Has_Live (Test.Model)) & " " & Image (Test.View.Faint));
   end Live_Text;

   procedure Interrupted is
      Test : Fixture;
   begin
      Prepare (Test, "abc", With_Focus => True);
      Select_Range (Test.View, (1, 4), (1, 4));
      Editor_VM.Show_Live (Test.Model, Test.View, " and");
      Insert (Test.View, "!");
      Editor_VM.Show_Live (Test.Model, Test.View, " and more");
      Check ("editor-vm-typing-waits", "abc and!", Docs.Whole (Test.Doc));
      Editor_VM.Show_Live (Test.Model, Test.View, " and more");
      Check ("editor-vm-typing-resumes", "abc and! more", Docs.Whole (Test.Doc));
      Test.View.Has_Focus := False;
      Editor_VM.Append_Said (Test.Model, Test.View, " and more.");
      Check ("editor-vm-typing-final", "abc and! more.", Docs.Whole (Test.Doc));
      Prepare (Test, "abc", With_Focus => True);
      Select_Range (Test.View, (1, 4), (1, 4));
      Editor_VM.Show_Live (Test.Model, Test.View, " and");
      Insert (Test.View, "!");
      Editor_VM.Take_Back_Live (Test.Model, Test.View);
      Check ("editor-vm-cancel-edited", "abc and! FALSE FALSE", Docs.Whole (Test.Doc) & " "
             & Image (Editor_VM.Has_Live (Test.Model)) & " " & Image (Test.View.Faint));
      Editor_VM.Append_Said (Test.Model, Test.View, " an");
      Check ("editor-vm-shorter-final", "abc and!", Docs.Whole (Test.Doc));
   end Interrupted;

   procedure Boundaries is
      Test : Fixture;
      UTF8_Speech : constant String :=
        [Character'Val (16#C3#), Character'Val (16#A9#),
         Character'Val (16#F0#), Character'Val (16#9F#), Character'Val (16#AA#), Character'Val (16#B6#), 'x'];
      Long_Text : constant String (1 .. 70_000) := [others => 'x'];
      Item : Items.Models.Item;
      Info : Items.Info;
      Rejected : Boolean := False;
      Uninitialized : Editor_VM.View_Model;
   begin
      begin
         Editor_VM.Show_Live (Uninitialized, Test.View, "not bound");
      exception
         when Ada.Assertions.Assertion_Error => Rejected := True;
      end;
      Check ("editor-vm-initialize-contract", "TRUE", Image (Rejected));
      Rejected := False;
      Prepare (Test, "");
      Editor_VM.Show_Live (Test.Model, Test.View, UTF8_Speech, Settled => 3);
      Check ("editor-vm-utf8-edge", "TRUE", Image (Test.View.Faint_From = Texts.Position'(1, 7)));
      Editor_VM.Take_Back_Live (Test.Model, Test.View);
      Editor_VM.Append_Said (Test.Model, Test.View, "a" & ASCII.CR & ASCII.LF & "b");
      Check ("editor-vm-line-feeds", "a " & ASCII.LF & "b", Docs.Whole (Test.Doc));
      Prepare (Test, "");
      Editor_VM.Show_Live (Test.Model, Test.View, Long_Text);
      Check ("editor-vm-long-live", "TRUE", Image (Docs.Whole (Test.Doc) = Long_Text));
      Editor_VM.Append_Said (Test.Model, Test.View, Long_Text);
      Check ("editor-vm-long-final", "TRUE", Image (Docs.Whole (Test.Doc) = Long_Text));
      Info.Kind := Items.Note;
      Items.Models.Assign (Item, Info, "");
      Test.View.Doc := Items.Models.Content_Document (Item);
      Test.View.At_Caret := (1, 1);
      Test.View.At_Mark := (1, 1);
      Test.View.Seen := Docs.Current (Test.View.Doc.all);
      Editor_VM.Show_Live (Items.Models.Editor (Item).all, Test.View, "");
      Editor_VM.Show_Live (Items.Models.Editor (Item).all, Test.View, "old");
      Items.Models.Change_Dictation (Item, Test.View, Items.Models.Failed, "microphone failed");
      Check ("editor-vm-job-failed", "TRUE TRUE FALSE", Image (Items.Models.Dictation (Item) = Items.Models.Failed)
             & " " & Image (Items.Models.Text (Item) = "") & " " & Image (Test.View.Faint));
      Editor_VM.Show_Live (Items.Models.Editor (Item).all, Test.View, "old");
      Editor_VM.Show_Live (Items.Models.Editor (Item).all, Test.View, "old");
      Check ("editor-vm-item-live", "TRUE", Image (Editor_VM.Has_Live (Items.Models.Editor (Item).all)));
      Items.Models.Release (Item);
      Items.Models.Assign (Item, Info, "new");
      Check ("editor-vm-item-reused", "new FALSE", Items.Models.Text (Item) & " "
             & Image (Editor_VM.Has_Live (Items.Models.Editor (Item).all)));
      Items.Models.Release (Item);
      Info.Kind := Items.Source;
      Items.Models.Assign (Item, Info, "");
      begin
         Editor_VM.Reset (Items.Models.Editor (Item).all);
      exception
         when Ada.Assertions.Assertion_Error => Rejected := True;
      end;
      Check ("editor-vm-source-contract", "TRUE", Image (Rejected));
   end Boundaries;
   procedure By_Name is
      App : aliased View.Session;
      Ears : aliased View_Driver.Driver (App'Access);
      Window : Pomarine.Testing.Session;
      package Testing renames Pomarine.Testing;
      package Windows renames View.Canvas_Windows;
   begin
      View.Open (App, "", 1000, 800);
      Testing.Attach (Window, View.Widget_Tree (App).all, Ears'Access);
      Testing.Click_On (Window, "New project");
      Testing.Click_On (Window, "Canvas");
      Windows.Add_Item (App, "Dictation");
      Testing.Type_Text (Window, "ac");
      Testing.Press (Window, Pomarine.Events.Key_Left_Arrow);
      Windows.Dictate_Into (App, 1, "b");
      Check ("editor-name-canvas-caret", "abc", Windows.Item_Text (App, 1));
      Testing.Press (Window, Pomarine.Events.Key_Z, Command => True);
      Check ("editor-name-canvas-undo", "ac", Windows.Item_Text (App, 1));
      Testing.Click_On (Window, "Write");
      Testing.Click_On (Window, "Text of Dictation", Role => Pomarine.Semantics.Multiline_Text_Input);
      Testing.Press (Window, Pomarine.Events.Key_A, Command => True);
      Testing.Type_Text (Window, "ac");
      Testing.Press (Window, Pomarine.Events.Key_Left_Arrow);
      Windows.Dictate_Into (App, 1, "b");
      Check ("editor-name-writing-caret", "abc", Windows.Item_Text (App, 1));
      Testing.Press (Window, Pomarine.Events.Key_Right_Arrow);
      Windows.Dictate_Live (App, 1, " and");
      Windows.Dictate_Live (App, 1, " and");
      Check ("editor-name-writing-live", "abc and", Windows.Item_Text (App, 1));
      Windows.Dictate_Into (App, 1, " and more.");
      Check ("editor-name-writing-final", "abc and more.", Windows.Item_Text (App, 1));
      Testing.Press (Window, Pomarine.Events.Key_Z, Command => True);
      Check ("editor-name-writing-undo", "abc", Windows.Item_Text (App, 1));
      Testing.Click_On (Window, "Canvas");
      Check ("editor-name-shared-document", "abc", Windows.Item_Text (App, 1));
   end By_Name;
end Editor_VM_Tests;
