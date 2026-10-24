with Ada.Assertions;
with Goldens;
with Grammar_VM;
with Grammar_VM.Stored;
with Grammar_VM_Fakes;
with Items.Schema;
with Long_Texts;
with Pomarine.View_Models;
with Projects;

package body Grammar_VM_Tests is

   package Parts renames Pomarine.View_Models;
   package Fakes renames Grammar_VM_Fakes;

   use type Parts.Version_Number;
   use all type Grammar_VM.Command;

   procedure Check (Name : String; Expected, Actual : String) renames Goldens.Check_Text;

   function Image (Value : Boolean) return String is (Value'Image);

   function Number (Value : Integer) return String is (Value'Image (2 .. Value'Image'Last));

   function Long_Texts_Image (Text : Long_Texts.Text) return String renames Long_Texts.To_String;

   procedure Rule_List is
      Kept  : aliased Fakes.Kept;
      Model : Grammar_VM.View_Model;
      Seen  : Parts.Version_Number;
      Done  : Boolean;
   begin
      Grammar_VM.Initialize (Model, Kept'Access);
      Check ("grammar-vm-first", "0 0 0", Number (Grammar_VM.Count (Model)) & " "
             & Number (Integer (Grammar_VM.Owner_Of (Model))) & " " & Number (Kept.Reads));

      --  A project's rules are read once, for as long as it is the one.
      Grammar_VM.Open (Model, 7);
      Grammar_VM.Open (Model, 7);
      Check ("grammar-vm-opened", "7 1", Number (Integer (Grammar_VM.Owner_Of (Model))) & " " & Number (Kept.Reads));
      Grammar_VM.Open (Model, 8);
      Check ("grammar-vm-other", "8 2", Number (Integer (Grammar_VM.Owner_Of (Model))) & " " & Number (Kept.Reads));
      Grammar_VM.Forget (Model);
      Grammar_VM.Open (Model, 8);
      Check ("grammar-vm-forgotten", "3", Number (Kept.Reads));

      --  Ignoring a text is a rule, and is a change of the rules.
      Seen := Grammar_VM.Rules_Version (Model);
      Grammar_VM.Ignore (Model, 4, "speling");
      Check ("grammar-vm-ignored", "1 TRUE IGNORE 4 speling",
             Number (Grammar_VM.Count (Model)) & " " & Image (Grammar_VM.Rules_Version (Model) /= Seen) & " "
             & Grammar_VM.Current (Model).all (1).Action'Image & Grammar_VM.Current (Model).all (1).Kind'Image & " "
             & Long_Texts_Image (Grammar_VM.Current (Model).all (1).Pattern));
      Check ("grammar-vm-ignore-not-correction", "FALSE", Image (Grammar_VM.Corrects (Model, "speling")));

      --  A text corrected is a rule that corrects it, which can be taken away, once.
      Grammar_VM.Begin_Entry (Model, "teh", 0, "the");
      Grammar_VM.Execute (Model, Accept_Entry);
      Check ("grammar-vm-corrects", "2 TRUE", Number (Grammar_VM.Count (Model)) & " "
             & Image (Grammar_VM.Corrects (Model, "teh")));
      Seen := Grammar_VM.Rules_Version (Model);
      Grammar_VM.Remove_Correction (Model, "speling", Done);
      Check ("grammar-vm-remove-ignore", "FALSE 2 FALSE", Image (Done) & " " & Number (Grammar_VM.Count (Model)) & " "
             & Image (Grammar_VM.Rules_Version (Model) /= Seen));
      Grammar_VM.Remove_Correction (Model, "teh", Done);
      Check ("grammar-vm-removed", "TRUE 1 FALSE TRUE", Image (Done) & " " & Number (Grammar_VM.Count (Model)) & " "
             & Image (Grammar_VM.Corrects (Model, "teh")) & " " & Image (Grammar_VM.Rules_Version (Model) /= Seen));
      Grammar_VM.Remove_Correction (Model, "teh", Done);
      Check ("grammar-vm-removed-again", "FALSE", Image (Done));
   end Rule_List;

   procedure Entry_Form is
      Kept  : aliased Fakes.Kept;
      Model : Grammar_VM.View_Model;
      Seen  : Parts.Version_Number;
   begin
      Grammar_VM.Initialize (Model, Kept'Access);
      Grammar_VM.Open (Model, 1);
      Check ("grammar-vm-entry-off", "FALSE FALSE FALSE", Image (Grammar_VM.Is_Entering (Model)) & " "
             & Image (Grammar_VM.Can_Execute (Model, Accept_Entry)) & " "
             & Image (Grammar_VM.Can_Execute (Model, Cancel_Entry)));

      Grammar_VM.Begin_Entry (Model, "speling", 3, "spelling");
      Check ("grammar-vm-entry", "TRUE speling spelling Always correct ""speling"" to:",
             Image (Grammar_VM.Is_Entering (Model)) & " " & Grammar_VM.Entry_Text (Model) & " "
             & Grammar_VM.Correction (Model) & " " & Grammar_VM.Prompt (Model));
      Check ("grammar-vm-entry-can", "TRUE TRUE", Image (Grammar_VM.Can_Execute (Model, Accept_Entry)) & " "
             & Image (Grammar_VM.Can_Execute (Model, Cancel_Entry)));

      --  A correction that changes nothing is no rule.
      Seen := Grammar_VM.Version (Model);
      Grammar_VM.Set_Correction (Model, "speling");
      Check ("grammar-vm-entry-same", "TRUE FALSE TRUE", Image (Grammar_VM.Version (Model) /= Seen) & " "
             & Image (Grammar_VM.Can_Execute (Model, Accept_Entry)) & " "
             & Image (Grammar_VM.Can_Execute (Model, Cancel_Entry)));
      Grammar_VM.Set_Correction (Model, "");
      Check ("grammar-vm-entry-empty", "TRUE", Image (Grammar_VM.Can_Execute (Model, Accept_Entry)));

      --  Nor one longer than a suggestion can be, and one that is as long is.
      Grammar_VM.Set_Correction (Model, [1 .. Grammar_VM.Longest_Correction => 'x']);
      Check ("grammar-vm-entry-longest", "TRUE", Image (Grammar_VM.Can_Execute (Model, Accept_Entry)));
      Grammar_VM.Set_Correction (Model, [1 .. Grammar_VM.Longest_Correction + 1 => 'x']);
      Check ("grammar-vm-entry-too-long", "FALSE", Image (Grammar_VM.Can_Execute (Model, Accept_Entry)));
      begin
         Grammar_VM.Execute (Model, Accept_Entry);
         Check ("grammar-vm-entry-pre", "raised", "not raised");
      exception
         when Ada.Assertions.Assertion_Error =>
            Check ("grammar-vm-entry-pre", "raised", "raised");
      end;
      Check ("grammar-vm-entry-nothing-written", "0", Number (Kept.Writes));

      --  Accepted: the rule is the text's, of the kind of the diagnostic, and the form is put away.
      Grammar_VM.Set_Correction (Model, "spelling!");
      Grammar_VM.Execute (Model, Accept_Entry);
      Check ("grammar-vm-entry-made", "FALSE 1 CORRECT 3 speling spelling!",
             Image (Grammar_VM.Is_Entering (Model)) & " " & Number (Grammar_VM.Count (Model)) & " "
             & Kept.Table (1).Action'Image & Kept.Table (1).Kind'Image & " "
             & Long_Texts_Image (Kept.Table (1).Pattern) & " " & Long_Texts_Image (Kept.Table (1).Replacement));

      --  Cancelled: nothing is made.
      Grammar_VM.Begin_Entry (Model, "teh", 0, "the");
      Grammar_VM.Execute (Model, Cancel_Entry);
      Check ("grammar-vm-entry-cancelled", "FALSE 1 1", Image (Grammar_VM.Is_Entering (Model)) & " "
             & Number (Grammar_VM.Count (Model)) & " " & Number (Kept.Writes));

      --  Another project's rules put it away.
      Grammar_VM.Begin_Entry (Model, "teh", 0, "the");
      Grammar_VM.Open (Model, 2);
      Check ("grammar-vm-entry-other-project", "FALSE", Image (Grammar_VM.Is_Entering (Model)));
   end Entry_Form;

   procedure Stored is
      Store : aliased Projects.Store;
      Kept  : aliased Grammar_VM.Stored.Rules_Kept;
      Model : Grammar_VM.View_Model;
      Again : Grammar_VM.View_Model;
      Mine  : Projects.Id;
      Yours : Projects.Id;
   begin
      Projects.Open (Store, Projects.Memory);
      Items.Schema.Prepare (Store);
      Grammar_VM.Stored.Open (Kept, Store'Access);
      Mine := Projects.Create (Store, "Mine");
      Yours := Projects.Create (Store, "Yours");
      Grammar_VM.Initialize (Model, Kept'Access);
      Grammar_VM.Open (Model, Mine);
      Grammar_VM.Ignore (Model, 2, "the the");
      Grammar_VM.Begin_Entry (Model, "speling", 3, "spelling");
      Grammar_VM.Execute (Model, Accept_Entry);

      --  What was made is the project's, and found by another reading.
      Grammar_VM.Initialize (Again, Kept'Access);
      Grammar_VM.Open (Again, Mine);
      Check ("grammar-vm-stored-kept", "2 TRUE", Number (Grammar_VM.Count (Again)) & " "
             & Image (Grammar_VM.Corrects (Again, "speling")));
      Grammar_VM.Open (Again, Yours);
      Check ("grammar-vm-stored-others", "0 FALSE", Number (Grammar_VM.Count (Again)) & " "
             & Image (Grammar_VM.Corrects (Again, "speling")));
      Grammar_VM.Open (Model, Mine);
      Grammar_VM.Open (Again, Mine);
      declare
         Done : Boolean;
      begin
         Grammar_VM.Remove_Correction (Again, "speling", Done);
         Check ("grammar-vm-stored-removed", "TRUE 1", Image (Done) & " " & Number (Grammar_VM.Count (Again)));
      end;
   end Stored;

end Grammar_VM_Tests;
