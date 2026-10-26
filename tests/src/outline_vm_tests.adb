with Ada.Assertions;
with Goldens;
with Items.Schema;
with Outline_VM;
with Outline_VM.Stored;
with Outline_VM_Fakes;
with Pomarine.View_Models;
with Projects;
with Projects.Sections;

package body Outline_VM_Tests is

   package Parts renames Pomarine.View_Models;
   package Sections renames Projects.Sections;
   package Fakes renames Outline_VM_Fakes;

   use type Parts.Version_Number;
   use all type Outline_VM.Command;

   procedure Check (Name : String; Expected, Actual : String) renames Goldens.Check_Text;

   function Image (Value : Boolean) return String is (Value'Image);

   function Number (Value : Integer) return String is (Value'Image (2 .. Value'Image'Last));

   --  The titles of the view-model, in order.
   function Titles (Model : Outline_VM.View_Model) return String is
      Said : String (1 .. 400);
      Used : Natural := 0;
   begin
      for Each in 1 .. Outline_VM.Count (Model) loop
         declare
            Title : constant String := Outline_VM.Title (Model, Each);
         begin
            if Used > 0 then
               Said (Used + 1) := ',';
               Used := Used + 1;
            end if;
            Said (Used + 1 .. Used + Title'Length) := Title;
            Used := Used + Title'Length;
         end;
      end loop;
      return Said (1 .. Used);
   end Titles;

   procedure Entering is
      Kept  : aliased Fakes.Kept;
      Model : Outline_VM.View_Model;
   begin
      Fakes.Put (Kept, "Opening");
      Fakes.Put (Kept, "Middle", Notes => "Some notes");
      Fakes.Put (Kept, "End");
      Fakes.Link (Kept, 10, 2);
      Fakes.Link (Kept, 11, 2);
      Fakes.Link (Kept, 12, 3);
      Outline_VM.Initialize (Model, Kept'Access);
      Check ("outline-vm-before", "FALSE 0 FALSE", Image (Outline_VM.Is_Entered (Model)) & " "
             & Number (Outline_VM.Count (Model)) & " " & Image (Outline_VM.Can_Execute (Model, Add_Section)));

      Outline_VM.Enter (Model, 1);
      Check ("outline-vm-entered", "TRUE Opening,Middle,End Great skua|A bird",
             Image (Outline_VM.Is_Entered (Model)) & " " & Titles (Model) & " " & Outline_VM.Project_Title (Model)
             & "|" & Outline_VM.Project_Description (Model));
      Check ("outline-vm-open", "FALSE TRUE FALSE",
             Image (Outline_VM.Is_Open (Model, 1)) & " " & Image (Outline_VM.Is_Open (Model, 2)) & " "
             & Image (Outline_VM.Is_Open (Model, 3)));
      Check ("outline-vm-counts", "0 2 1", Number (Outline_VM.Documents_In (Model, 1)) & " "
             & Number (Outline_VM.Documents_In (Model, 2)) & " " & Number (Outline_VM.Documents_In (Model, 3)));
      Check ("outline-vm-of-item", "2 3 0", Number (Outline_VM.Section_Of_Item (Model, 11)) & " "
             & Number (Outline_VM.Section_Of_Item (Model, 12)) & " " & Number (Outline_VM.Section_Of_Item (Model, 99)));
      Check ("outline-vm-of-key", "3 0",
             Number (Outline_VM.Index_Of_Key (Model, Outline_VM.Section_At (Model, 3).Key)) & " "
             & Number (Outline_VM.Index_Of_Key (Model, 99)));
      Check ("outline-vm-notes", "Some notes <Some notes>", Outline_VM.Notes (Model, 2) & " "
             & Outline_VM.Stored_Notes (Model, 2));
      Check ("outline-vm-can", "TRUE TRUE TRUE TRUE TRUE",
             Image (Outline_VM.Can_Execute (Model, Add_Section)) & " " & Image (Outline_VM.Can_Execute (Model, Move_Up))
             & " " & Image (Outline_VM.Can_Execute (Model, Move_Down)) & " "
             & Image (Outline_VM.Can_Execute (Model, Remove_Section)) & " "
             & Image (Outline_VM.Can_Execute (Model, Toggle_Notes)));

      --  Left, nothing is held.
      Outline_VM.Leave (Model);
      Check ("outline-vm-left", "FALSE 0 FALSE FALSE", Image (Outline_VM.Is_Entered (Model)) & " "
             & Number (Outline_VM.Count (Model)) & " " & Image (Outline_VM.Can_Execute (Model, Add_Section)) & " "
             & Image (Outline_VM.Can_Execute (Model, Move_Up)));
   end Entering;

   procedure Changing is
      Kept  : aliased Fakes.Kept;
      Model : Outline_VM.View_Model;
      Seen  : Parts.Version_Number;
   begin
      Fakes.Put (Kept, "One");
      Fakes.Put (Kept, "Two");
      Fakes.Put (Kept, "Three");
      Fakes.Link (Kept, 10, 3);
      Outline_VM.Initialize (Model, Kept'Access);
      Outline_VM.Enter (Model, 1);

      --  Adding puts one last, and it is kept.
      Seen := Outline_VM.Version (Model);
      Outline_VM.Execute (Model, Add_Section);
      Check ("outline-vm-added", "One,Two,Three,Untitled section TRUE",
             Titles (Model) & " " & Image (Outline_VM.Version (Model) /= Seen));
      Check ("outline-vm-added-kept", "One,Two,Three,Untitled section", Fakes.Titles (Kept));
      Check ("outline-vm-added-closed", "FALSE", Image (Outline_VM.Is_Open (Model, 4)));

      --  Moving: the first has no up, the last no down.
      Check ("outline-vm-can-move", "FALSE TRUE|TRUE FALSE",
             Image (Outline_VM.Can_Move_Up (Model, 1)) & " " & Image (Outline_VM.Can_Move_Up (Model, 2)) & "|"
             & Image (Outline_VM.Can_Move_Down (Model, 1)) & " " & Image (Outline_VM.Can_Move_Down (Model, 4)));
      Outline_VM.Execute (Model, Move_Down, 1);
      Check ("outline-vm-down", "Two,One,Three,Untitled section", Titles (Model));
      Check ("outline-vm-down-kept", "Two,One,Three,Untitled section", Fakes.Titles (Kept));
      Outline_VM.Execute (Model, Move_Up, 3);
      Check ("outline-vm-up", "Two,Three,One,Untitled section", Titles (Model));
      Check ("outline-vm-up-first", "FALSE TRUE|FALSE TRUE",
             Image (Outline_VM.Can_Execute (Model, Move_Up, 1)) & " "
             & Image (Outline_VM.Can_Execute (Model, Move_Up, 2)) & "|"
             & Image (Outline_VM.Can_Execute (Model, Move_Down, 4)) & " "
             & Image (Outline_VM.Can_Execute (Model, Move_Down, 3)));
      begin
         Outline_VM.Execute (Model, Move_Up, 1);
         Check ("outline-vm-up-first-pre", "raised", "not raised");
      exception
         when Ada.Assertions.Assertion_Error =>
            Check ("outline-vm-up-first-pre", "raised", "raised");
      end;
      Check ("outline-vm-up-first-same", "Two,Three,One,Untitled section", Fakes.Titles (Kept));

      --  The colour box and the title field are the view's: the commands change nothing of the model.
      Seen := Outline_VM.Version (Model);
      Check ("outline-vm-colour-rules", "FALSE TRUE FALSE|TRUE TRUE TRUE|FALSE",
             Image (Outline_VM.Can_Execute (Model, Choose_Colour, 0)) & " "
             & Image (Outline_VM.Can_Execute (Model, Choose_Colour, 4)) & " "
             & Image (Outline_VM.Can_Execute (Model, Choose_Colour, 5)) & "|"
             & Image (Outline_VM.Can_Execute (Model, Accept_Colour)) & " "
             & Image (Outline_VM.Can_Execute (Model, Cancel_Colour)) & " "
             & Image (Outline_VM.Can_Execute (Model, End_Title)) & "|"
             & Image (Outline_VM.Can_Execute (Model, End_Title, 1)));
      Outline_VM.Execute (Model, Choose_Colour, 2);
      Outline_VM.Execute (Model, Accept_Colour);
      Outline_VM.Execute (Model, Cancel_Colour);
      Outline_VM.Execute (Model, End_Title);
      Check ("outline-vm-colour-no-change", "TRUE Two,Three,One,Untitled section",
             Image (Outline_VM.Version (Model) = Seen) & " " & Titles (Model));

      --  A drag comes to Move, to any place.
      Outline_VM.Move (Model, 4, 1);
      Check ("outline-vm-move-first", "Untitled section,Two,Three,One", Titles (Model));
      Check ("outline-vm-move-first-kept", "Untitled section,Two,Three,One", Fakes.Titles (Kept));
      Outline_VM.Move (Model, 1, 3);
      Check ("outline-vm-move-down", "Two,Three,Untitled section,One", Titles (Model));
      Outline_VM.Move (Model, 2, 2);
      Check ("outline-vm-move-same", "Two,Three,Untitled section,One", Titles (Model));

      --  The items go with their sections.
      Check ("outline-vm-moved-links", "2", Number (Outline_VM.Section_Of_Item (Model, 10)));

      --  Notes open and shut, and nothing is kept for it.
      declare
         Writes : constant Natural := Kept.Writes;
      begin
         Outline_VM.Execute (Model, Toggle_Notes, 2);
         Check ("outline-vm-notes-open", "TRUE", Image (Outline_VM.Is_Open (Model, 2)));
         Outline_VM.Reload (Model);
         Check ("outline-vm-reload-keeps-open", "TRUE", Image (Outline_VM.Is_Open (Model, 2)));
         Outline_VM.Execute (Model, Toggle_Notes, 2);
         Check ("outline-vm-notes-shut", "FALSE", Image (Outline_VM.Is_Open (Model, 2)));
         Check ("outline-vm-notes-nothing-kept", "0", Number (Kept.Writes - Writes));
      end;

      --  Removing takes the section and its links.
      Outline_VM.Execute (Model, Remove_Section, 2);
      Check ("outline-vm-removed", "Two,Untitled section,One", Titles (Model));
      Check ("outline-vm-removed-kept", "Two,Untitled section,One", Fakes.Titles (Kept));
      Check ("outline-vm-removed-links", "0", Number (Outline_VM.Section_Of_Item (Model, 10)));
      Outline_VM.Execute (Model, Remove_Section, 1);
      Outline_VM.Execute (Model, Remove_Section, 1);
      Outline_VM.Execute (Model, Remove_Section, 1);
      Check ("outline-vm-removed-all", "0 FALSE FALSE", Number (Outline_VM.Count (Model)) & " "
             & Image (Outline_VM.Can_Execute (Model, Remove_Section)) & " "
             & Image (Outline_VM.Can_Execute (Model, Move_Up)));
      Check ("outline-vm-add-again", "TRUE", Image (Outline_VM.Can_Execute (Model, Add_Section)));

      --  A row that is none is refused, and nothing changes.
      Outline_VM.Execute (Model, Add_Section);
      Seen := Outline_VM.Version (Model);
      begin
         Outline_VM.Execute (Model, Remove_Section, 2);
         Check ("outline-vm-remove-range", "raised", "not raised");
      exception
         when Ada.Assertions.Assertion_Error =>
            Check ("outline-vm-remove-range", "raised", "raised");
      end;
      begin
         Outline_VM.Execute (Model, Toggle_Notes, 2);
         Check ("outline-vm-notes-range", "raised", "not raised");
      exception
         when Ada.Assertions.Assertion_Error =>
            Check ("outline-vm-notes-range", "raised", "raised");
      end;
      Check ("outline-vm-range-same", "FALSE 1", Image (Outline_VM.Version (Model) /= Seen) & " "
             & Number (Outline_VM.Count (Model)));

      --  Doing what cannot be done is the caller's mistake.
      Outline_VM.Execute (Model, Remove_Section, 1);
      begin
         Outline_VM.Execute (Model, Remove_Section, 1);
         Check ("outline-vm-remove-pre", "raised", "not raised");
      exception
         when Ada.Assertions.Assertion_Error =>
            Check ("outline-vm-remove-pre", "raised", "raised");
      end;
   end Changing;

   procedure Typing is
      Kept  : aliased Fakes.Kept;
      Model : Outline_VM.View_Model;
      Done  : Boolean;
   begin
      Fakes.Put (Kept, "One");
      Fakes.Put (Kept, "Two");
      Outline_VM.Initialize (Model, Kept'Access);
      Outline_VM.Enter (Model, 1);

      --  A project is not left without a name, and is not named by the spaces about it.
      Outline_VM.Set_Project_Title (Model, "  Bonxie  ", Done);
      Check ("outline-vm-named", "TRUE Bonxie|Bonxie", Image (Done) & " " & Outline_VM.Project_Title (Model) & "|"
             & Projects.Titles.To_String (Kept.Title));
      declare
         Writes : constant Natural := Kept.Writes;
      begin
         Outline_VM.Set_Project_Title (Model, "   ", Done);
         Check ("outline-vm-not-named", "FALSE Bonxie 0", Image (Done) & " " & Outline_VM.Project_Title (Model) & " "
               & Number (Kept.Writes - Writes));
         Outline_VM.Set_Project_Title (Model, "", Done);
         Check ("outline-vm-not-named-empty", "FALSE", Image (Done));
      end;
      Outline_VM.Set_Project_Description (Model, "<p>Seabirds</p>");
      Check ("outline-vm-described", "<p>Seabirds</p>", Projects.Titles.To_String (Kept.Words));

      --  The project elsewhere renamed is read again.
      Kept.Title := Projects.Titles.To_Text ("Arctic skua");
      Outline_VM.Reload_Project (Model);
      Check ("outline-vm-reload-project", "Arctic skua", Outline_VM.Project_Title (Model));

      --  A section's title and notes are kept as typed, spaces and all.
      Outline_VM.Set_Title (Model, 2, "  Second ");
      Check ("outline-vm-title", "One,  Second ", Titles (Model));
      Check ("outline-vm-title-kept", "One,  Second ", Fakes.Titles (Kept));
      Outline_VM.Set_Notes (Model, 1, "Plain", "<p>Plain</p>");
      Check ("outline-vm-notes-typed", "Plain|<p>Plain</p>", Outline_VM.Notes (Model, 1) & "|"
             & Sections.Note_Texts.To_String (Kept.Table (1).Notes));
      Outline_VM.Set_Colour (Model, 1, 7);
      Check ("outline-vm-colour", "7 7", Number (Outline_VM.Section_At (Model, 1).Colour) & " "
             & Number (Kept.Table (1).Colour));
   end Typing;

   procedure Stored is
      Store : aliased Projects.Store;
      Kept  : aliased Outline_VM.Stored.Sections_Kept;
      Model : Outline_VM.View_Model;
      Again : Outline_VM.View_Model;
      Owner : Projects.Id;
      Done  : Boolean;
   begin
      Projects.Open (Store, Projects.Memory);
      Items.Schema.Prepare (Store);
      Outline_VM.Stored.Open (Kept, Store'Access);
      Owner := Projects.Create (Store, "Great skua");
      Outline_VM.Initialize (Model, Kept'Access);
      Outline_VM.Enter (Model, Owner);
      Check ("outline-vm-stored-none", "0 Great skua", Number (Outline_VM.Count (Model)) & " "
             & Outline_VM.Project_Title (Model));
      Outline_VM.Execute (Model, Add_Section);
      Outline_VM.Execute (Model, Add_Section);
      Outline_VM.Execute (Model, Add_Section);
      Outline_VM.Set_Title (Model, 1, "Opening");
      Outline_VM.Set_Title (Model, 2, "Middle");
      Outline_VM.Set_Title (Model, 3, "End");
      Outline_VM.Set_Notes (Model, 2, "Plain", "<p>Plain</p>");
      Outline_VM.Execute (Model, Move_Down, 1);
      Outline_VM.Move (Model, 3, 1);
      Outline_VM.Set_Project_Title (Model, " Bonxie ", Done);
      Outline_VM.Execute (Model, Remove_Section, 2);

      --  What was done is what another reading finds.
      Outline_VM.Initialize (Again, Kept'Access);
      Outline_VM.Enter (Again, Owner);
      Check ("outline-vm-stored-kept", "End,Opening 2 Bonxie",
             Titles (Again) & " " & Number (Outline_VM.Count (Again)) & " " & Outline_VM.Project_Title (Again));
   end Stored;

end Outline_VM_Tests;
