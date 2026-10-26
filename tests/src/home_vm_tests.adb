with Ada.Assertions;
with Confirm_VM;
with Goldens;
with Home_VM;
with Home_VM.Stored;
with Home_VM_Fakes;
with Items.Schema;
with Pomarine.View_Models;
with Projects;

package body Home_VM_Tests is

   package Parts renames Pomarine.View_Models;

   use type Parts.Version_Number;
   use type Projects.Id;
   use all type Home_VM.Command;

   procedure Check (Name : String; Expected, Actual : String) renames Goldens.Check_Text;

   function Image (Value : Boolean) return String is (Value'Image);

   function Number (Value : Integer) return String is (Value'Image (2 .. Value'Image'Last));

   Dot : constant String := [Character'Val (16#C2#), Character'Val (16#B7#)];

   procedure Listing is
      Kept  : aliased Home_VM_Fakes.Few;
      Model : Home_VM.View_Model;
      Seen  : Parts.Version_Number;
   begin
      Home_VM.Initialize (Model, Kept'Access);
      Check ("home-vm-none", "0 FALSE FALSE FALSE TRUE",
             Number (Home_VM.Count (Model)) & " " & Image (Home_VM.Can_Execute (Model, Begin_Rename)) & " "
             & Image (Home_VM.Can_Execute (Model, Ask_Delete)) & " "
             & Image (Home_VM.Can_Execute (Model, Cancel_Rename)) & " "
             & Image (Home_VM.Can_Execute (Model, Refresh)));

      Home_VM_Fakes.Add (Kept, "Episode 1", Documents => 1, Sources => 0);
      Home_VM_Fakes.Add (Kept, "Episode 2", Documents => 3, Sources => 1);
      Check ("home-vm-not-yet", "0", Number (Home_VM.Count (Model)));
      Seen := Home_VM.Listed_Version (Model);
      Home_VM.Execute (Model, Refresh);
      Check ("home-vm-listed", "2 Episode 2 Episode 1 TRUE",
             Number (Home_VM.Count (Model)) & " " & Home_VM.Title (Model, 1) & " " & Home_VM.Title (Model, 2) & " "
             & Image (Home_VM.Listed_Version (Model) /= Seen));
      Check ("home-vm-meta", "3 documents " & Dot & " 1 source|1 document " & Dot & " 0 sources",
             Home_VM.Meta (Model, 1) & "|" & Home_VM.Meta (Model, 2));
      Check ("home-vm-keys", "TRUE", Image (Home_VM.Key_Of (Model, 1) /= Home_VM.Key_Of (Model, 2)));

      --  Only the latest five.
      for Each in 3 .. 7 loop
         Home_VM_Fakes.Add (Kept, "Episode" & Each'Image);
      end loop;
      Home_VM.Execute (Model, Refresh);
      Check ("home-vm-five", "5 Episode 7 Episode 3",
             Number (Home_VM.Count (Model)) & " " & Home_VM.Title (Model, 1) & " " & Home_VM.Title (Model, 5));
   end Listing;

   procedure Renaming is
      Kept  : aliased Home_VM_Fakes.Few;
      Model : Home_VM.View_Model;
      Seen  : Parts.Version_Number;
      Lists : Parts.Version_Number;
   begin
      Home_VM_Fakes.Add (Kept, "Episode 1");
      Home_VM_Fakes.Add (Kept, "Episode 2");
      Home_VM_Fakes.Add (Kept, "Episode 3");
      Home_VM.Initialize (Model, Kept'Access);

      Check ("home-vm-rename-off", "FALSE FALSE 0",
             Image (Home_VM.Can_Execute (Model, Accept_Rename)) & " "
             & Image (Home_VM.Can_Execute (Model, Cancel_Rename)) & " " & Number (Home_VM.Editing (Model)));
      Home_VM.Execute (Model, Begin_Rename, 2);
      Check ("home-vm-rename-begun", "2 Episode 2 TRUE TRUE",
             Number (Home_VM.Editing (Model)) & " " & Home_VM.Draft (Model) & " "
             & Image (Home_VM.Can_Execute (Model, Accept_Rename)) & " "
             & Image (Home_VM.Can_Execute (Model, Cancel_Rename)));

      --  Typing is a change of the draft, not of the list.
      Seen := Home_VM.Version (Model);
      Lists := Home_VM.Listed_Version (Model);
      Home_VM.Set_Draft (Model, "   ");
      Check ("home-vm-rename-typing", "TRUE FALSE",
             Image (Home_VM.Version (Model) /= Seen) & " " & Image (Home_VM.Listed_Version (Model) /= Lists));
      Check ("home-vm-rename-spaces", "FALSE", Image (Home_VM.Can_Execute (Model, Accept_Rename)));
      Home_VM.Set_Draft (Model, "");
      Check ("home-vm-rename-nothing", "FALSE", Image (Home_VM.Can_Execute (Model, Accept_Rename)));

      --  Accepted: not the spaces about it, and it is the latest.
      Home_VM.Set_Draft (Model, "  Pilot  ");
      Home_VM.Execute (Model, Accept_Rename);
      Check ("home-vm-rename-done", "Pilot,Episode 3,Episode 1 0 Pilot",
             Home_VM_Fakes.Titles (Kept) & " " & Number (Home_VM.Editing (Model)) & " " & Home_VM.Title (Model, 1));

      --  Stopped.
      Home_VM.Execute (Model, Begin_Rename, 3);
      Home_VM.Set_Draft (Model, "Not this");
      Home_VM.Execute (Model, Cancel_Rename);
      Check ("home-vm-rename-cancelled", "Pilot,Episode 3,Episode 1 0",
             Home_VM_Fakes.Titles (Kept) & " " & Number (Home_VM.Editing (Model)));

      --  Listing again stops it, as a project made or deleted does.
      Home_VM.Execute (Model, Begin_Rename, 1);
      Home_VM.Execute (Model, Refresh);
      Check ("home-vm-rename-refresh", "0 FALSE", Number (Home_VM.Editing (Model)) & " "
             & Image (Home_VM.Can_Execute (Model, Cancel_Rename)));

      --  A row that is not one is refused, and cannot be asked of.
      Check ("home-vm-rename-rows", "TRUE TRUE FALSE",
             Image (Home_VM.Can_Execute (Model, Begin_Rename, 1)) & " "
             & Image (Home_VM.Can_Execute (Model, Begin_Rename, 3)) & " "
             & Image (Home_VM.Can_Execute (Model, Begin_Rename, 4)));
      Seen := Home_VM.Version (Model);
      begin
         Home_VM.Execute (Model, Begin_Rename, 4);
         Check ("home-vm-rename-range", "raised", "not raised");
      exception
         when Ada.Assertions.Assertion_Error =>
            Check ("home-vm-rename-range", "raised", "raised");
      end;
      Check ("home-vm-rename-range-same", "0 FALSE", Number (Home_VM.Editing (Model)) & " "
             & Image (Home_VM.Version (Model) /= Seen));

      --  Accepting what cannot be is refused by the precondition.
      begin
         Home_VM.Execute (Model, Accept_Rename);
         Check ("home-vm-rename-accept-pre", "raised", "not raised");
      exception
         when Ada.Assertions.Assertion_Error =>
            Check ("home-vm-rename-accept-pre", "raised", "raised");
      end;
   end Renaming;

   procedure Deleting is
      Kept  : aliased Home_VM_Fakes.Few;
      Model : Home_VM.View_Model;
      Dialog : aliased Confirm_VM.View_Model;
   begin
      Home_VM_Fakes.Add (Kept, "Episode 1");
      Home_VM_Fakes.Add (Kept, "Episode 2");
      Home_VM_Fakes.Add (Kept, "Episode 3");
      Home_VM.Initialize (Model, Kept'Access);
      Check ("home-vm-delete-no-dialog", "FALSE", Image (Home_VM.Can_Execute (Model, Ask_Delete, 2)));
      Home_VM.Initialize (Model, Kept'Access, Dialog'Access);
      Check ("home-vm-delete-rows", "FALSE TRUE FALSE",
             Image (Home_VM.Can_Execute (Model, Ask_Delete, 0)) & " "
             & Image (Home_VM.Can_Execute (Model, Ask_Delete, 2)) & " "
             & Image (Home_VM.Can_Execute (Model, Ask_Delete, 4)));
      Home_VM.Execute (Model, Begin_Rename, 1);
      Home_VM.Execute (Model, Ask_Delete, 2);
      Check ("home-vm-delete-asked", "0 TRUE FALSE Episode 3,Episode 2,Episode 1",
             Number (Home_VM.Editing (Model)) & " " & Image (Confirm_VM.Is_Asking (Dialog)) & " "
             & Image (Home_VM.Can_Execute (Model, Ask_Delete, 1)) & " " & Home_VM_Fakes.Titles (Kept));
      Confirm_VM.Execute (Dialog, Confirm_VM.Cancel);
      Check ("home-vm-delete-cancelled", "0 Episode 3,Episode 2,Episode 1",
             Number (Integer (Confirm_VM.Last_Answer (Dialog).Project_Key)) & " " & Home_VM_Fakes.Titles (Kept));
      Home_VM.Execute (Model, Ask_Delete, 2);
      --  Changing the recent list while confirmation is open must not change its target.
      Home_VM_Fakes.Add (Kept, "Episode 4");
      Home_VM.Execute (Model, Refresh);
      Confirm_VM.Execute (Dialog, Confirm_VM.Confirm);
      Home_VM.Delete_Confirmed (Model, Confirm_VM.Last_Answer (Dialog).Project_Key);
      Home_VM.Delete_Confirmed (Model, Home_VM.Key_Of (Model, 1));
      Check ("home-vm-deleted", "Episode 3,Episode 1 2 Episode 3 Episode 1",
             Home_VM_Fakes.Titles (Kept) & " " & Number (Home_VM.Count (Model)) & " " & Home_VM.Title (Model, 1)
             & " " & Home_VM.Title (Model, 2));
      begin
         Home_VM.Execute (Model, Ask_Delete, 3);
         Check ("home-vm-delete-range", "raised", "not raised");
      exception
         when Ada.Assertions.Assertion_Error =>
            Check ("home-vm-delete-range", "raised", "raised");
      end;
      Home_VM.Delete_Confirmed (Model, Home_VM.Key_Of (Model, 1));
      Home_VM.Delete_Confirmed (Model, Home_VM.Key_Of (Model, 1));
      Check ("home-vm-delete-all", "0 FALSE", Number (Home_VM.Count (Model)) & " "
             & Image (Home_VM.Can_Execute (Model, Ask_Delete)));
   end Deleting;

   procedure Stored is
      Store : aliased Projects.Store;
      Kept  : aliased Home_VM.Stored.Projects_Kept;
      Model : Home_VM.View_Model;
      First : Projects.Id;
   begin
      Projects.Open (Store, Projects.Memory);
      Items.Schema.Prepare (Store);
      Home_VM.Stored.Open (Kept, Store'Access);
      First := Projects.Create (Store, "Great skua", Time => 100);
      declare
         Second : constant Projects.Id := Projects.Create (Store, "Bonxie", Time => 200);
         pragma Unreferenced (Second);
      begin
         Home_VM.Initialize (Model, Kept'Access);
      end;
      Check ("home-vm-stored-listed", "2 Bonxie Great skua", Number (Home_VM.Count (Model)) & " "
             & Home_VM.Title (Model, 1) & " " & Home_VM.Title (Model, 2));
      Check ("home-vm-stored-meta", "0 documents " & Dot & " 0 sources", Home_VM.Meta (Model, 1));
      Home_VM.Execute (Model, Begin_Rename, 2);
      Home_VM.Set_Draft (Model, "Arctic skua");
      Home_VM.Execute (Model, Accept_Rename);
      Check ("home-vm-stored-renamed", "Arctic skua Bonxie", Home_VM.Title (Model, 1) & " " & Home_VM.Title (Model, 2));
      Check ("home-vm-stored-same-key", "TRUE", Image (Home_VM.Key_Of (Model, 1) = First));
      Home_VM.Delete_Confirmed (Model, Home_VM.Key_Of (Model, 1));
      Check ("home-vm-stored-deleted", "1 Bonxie", Number (Home_VM.Count (Model)) & " " & Home_VM.Title (Model, 1));
   end Stored;

   procedure Asking is
      use all type Confirm_VM.Subjects;
      use all type Confirm_VM.Command;
      Dialog : Confirm_VM.View_Model;
      Open   : constant String := [Character'Val (16#E2#), Character'Val (16#80#), Character'Val (16#9C#)];
      Close  : constant String := [Character'Val (16#E2#), Character'Val (16#80#), Character'Val (16#9D#)];
   begin
      Check ("confirm-vm-first", "NOTHING FALSE FALSE FALSE",
             Confirm_VM.Subject (Dialog)'Image & " " & Image (Confirm_VM.Is_Asking (Dialog)) & " "
             & Image (Confirm_VM.Can_Execute (Dialog, Confirm)) & " "
             & Image (Confirm_VM.Can_Execute (Dialog, Cancel)));

      --  A project.
      Confirm_VM.Ask_Project (Dialog, 3, "Episode 3");
      Check ("confirm-vm-project",
             "Delete project|Delete " & Open & "Episode 3" & Close & "?|This cannot be undone.|FALSE",
             Confirm_VM.Title (Dialog) & "|" & Confirm_VM.Message (Dialog) & "|" & Confirm_VM.Note (Dialog) & "|"
             & Image (Confirm_VM.Offers_Documents (Dialog)));
      Check ("confirm-vm-up", "TRUE FALSE TRUE TRUE",
             Image (Confirm_VM.Is_Asking (Dialog)) & " " & Image (Confirm_VM.Is_About_Node (Dialog)) & " "
             & Image (Confirm_VM.Can_Execute (Dialog, Confirm)) & " "
             & Image (Confirm_VM.Can_Execute (Dialog, Cancel)));
      Confirm_VM.Execute (Dialog, Confirm);
      declare
         Said : constant Confirm_VM.Answer := Confirm_VM.Last_Answer (Dialog);
      begin
         Check ("confirm-vm-project-answer", "PROJECT 3 FALSE",
                Said.Subject'Image & Said.Project_Key'Image & " " & Image (Confirm_VM.Is_Asking (Dialog)));
      end;

      --  Cancelled: nothing is answered.
      Confirm_VM.Ask_Project (Dialog, 1, "Episode 1");
      Confirm_VM.Execute (Dialog, Cancel);
      Check ("confirm-vm-cancelled", "NOTHING FALSE", Confirm_VM.Last_Answer (Dialog).Subject'Image & " "
             & Image (Confirm_VM.Is_Asking (Dialog)));

      --  A folder asks of its documents too, and a document does not.
      Confirm_VM.Ask_Node (Dialog, Folder, Dir => 2, Doc => 0, Name => "Notes");
      Check ("confirm-vm-folder", "Delete folder|This also deletes all subfolders.|TRUE TRUE",
             Confirm_VM.Title (Dialog) & "|" & Confirm_VM.Note (Dialog) & "|"
             & Image (Confirm_VM.Offers_Documents (Dialog)) & " " & Image (Confirm_VM.Is_About_Node (Dialog)));
      Confirm_VM.Set_Delete_Documents (Dialog, True);
      Confirm_VM.Execute (Dialog, Confirm);
      declare
         Said : constant Confirm_VM.Answer := Confirm_VM.Last_Answer (Dialog);
      begin
         Check ("confirm-vm-folder-answer", "FOLDER 2 0 TRUE",
                Said.Subject'Image & Said.Dir'Image & Said.Doc'Image & " " & Image (Said.Delete_Documents));
      end;

      --  Asking again forgets that.
      Confirm_VM.Ask_Node (Dialog, Document, Dir => 2, Doc => 5, Name => "Draft");
      Check ("confirm-vm-document", "Delete document|FALSE FALSE", Confirm_VM.Title (Dialog) & "|"
             & Image (Confirm_VM.Offers_Documents (Dialog)) & " " & Image (Confirm_VM.Delete_Documents (Dialog)));
      Confirm_VM.Ask_Node (Dialog, Source, Dir => 0, Doc => 6, Name => "Page");
      Check ("confirm-vm-source", "Delete source", Confirm_VM.Title (Dialog));
      Confirm_VM.Execute (Dialog, Cancel);

      --  The speech model's files.
      Confirm_VM.Ask_Model (Dialog, "Its 483.0 MB of files go.");
      Check ("confirm-vm-model", "Delete model|Delete the Parakeet model?|Its 483.0 MB of files go.|FALSE",
             Confirm_VM.Title (Dialog) & "|" & Confirm_VM.Message (Dialog) & "|" & Confirm_VM.Note (Dialog) & "|"
             & Image (Confirm_VM.Is_About_Node (Dialog)));

      --  Answering what is not asked is refused by the precondition.
      Confirm_VM.Execute (Dialog, Confirm);
      begin
         Confirm_VM.Execute (Dialog, Confirm);
         Check ("confirm-vm-not-asked", "raised", "not raised");
      exception
         when Ada.Assertions.Assertion_Error =>
            Check ("confirm-vm-not-asked", "raised", "raised");
      end;
   end Asking;

end Home_VM_Tests;
