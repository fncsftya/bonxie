with Ada.Assertions;
with Ada.Strings.Fixed;
with Publish_VM;
with Goldens;
with Items.Directories;
with Pomarine.View_Models;
with Writing_VM;
with Writing_VM.Trees;
with Items;
with Pomarine.Events;
with Pomarine.Testing;
with View;
with View.Canvas_Windows;
with View.Documents;
with View.Outline_Screen;
with View_Driver;

package body Writing_VM_Tests is
   use type Pomarine.View_Models.Version_Number;
   procedure Check (Name : String; Value : Boolean) is
   begin
      Goldens.Check_Text (Name, "TRUE", Value'Image);
   end Check;

   package Trees renames Writing_VM.Trees;
   use type Trees.Tree_Entry;
   use type Items.Id;

   type Positions is array (1 .. 3) of Natural;
   type Keys is array (1 .. 3) of Items.Id;
   type Library is limited new Trees.Library with record
      Writes, Touches     : Natural := 0;
      Pages, Folders      : Positions := [others => 0];
      Membership, Parents : Keys := [others => 0];
   end record;
   overriding
   function Key_Of (Self : Library; Doc : Items.Slot) return Items.Id;
   overriding
   procedure Keep_Position (Self : in out Library; Key : Items.Id; Position : Positive; Directory : Boolean);
   overriding
   procedure Keep_Membership (Self : in out Library; Key, Directory : Items.Id);
   overriding
   procedure Keep_Parent (Self : in out Library; Key, Parent : Items.Id);
   overriding
   procedure Touch (Self : in out Library);

   overriding
   function Key_Of (Self : Library; Doc : Items.Slot) return Items.Id is
      pragma Unreferenced (Self);
   begin
      return 100 + Items.Id (Doc);
   end Key_Of;
   overriding
   procedure Keep_Position (Self : in out Library; Key : Items.Id; Position : Positive; Directory : Boolean) is
   begin
      Self.Writes := Self.Writes + 1;
      if Directory then
         Self.Folders (Positive (Key / 10)) := Position;
      else
         Self.Pages (Positive (Key - 100)) := Position;
      end if;
   end Keep_Position;
   overriding
   procedure Keep_Membership (Self : in out Library; Key, Directory : Items.Id) is
   begin
      Self.Writes := Self.Writes + 1;
      Self.Membership (Positive (Key - 100)) := Directory;
   end Keep_Membership;
   overriding
   procedure Keep_Parent (Self : in out Library; Key, Parent : Items.Id) is
   begin
      Self.Writes := Self.Writes + 1;
      Self.Parents (Positive (Key / 10)) := Parent;
   end Keep_Parent;
   overriding
   procedure Touch (Self : in out Library) is
   begin
      Self.Touches := Self.Touches + 1;
   end Touch;

   procedure Ordering is
      Dirs     : Writing_VM.Directories;
      Docs     : Trees.Documents;
      Model    : Trees.Tree_Model;
      Store    : Library;
      Seen     : Pomarine.View_Models.Version_Number;
      Writes   : Natural;
      Rejected : Boolean := False;
   begin
      Trees.Arrange (Model, Dirs, Docs);
      Check
        ("writing-tree-overview",
         Trees.Count (Model) = 1 and then Trees.Element (Model, 1) = Trees.Tree_Entry'(others => <>));
      Dirs.Append ((Key => 10, Position => 2, others => <>));
      Dirs.Append ((Key => 20, Position => 3, Parent => 10, others => <>));
      Dirs.Append ((Key => 30, Position => 5, Section => 7, others => <>));
      Docs.Append ((Slot => 1, Dir => 1, Position => 4));
      Docs.Append ((Slot => 2, Dir => 2, Position => 6));
      Docs.Append ((Slot => 3, Dir => 0, Position => 7));
      Trees.Arrange (Model, Dirs, Docs);
      Check
        ("writing-tree-arrange",
         Trees.Count (Model) = 7
         and then Trees.Dir_Row (Model, 1) = 2
         and then Trees.Dir_Row (Model, 2) = 3
         and then Trees.Leaf_Row (Model, 2) = 4
         and then Trees.Leaf_Row (Model, 1) = 5
         and then Trees.Dir_Row (Model, 3) = 6
         and then Trees.Leaf_Row (Model, 3) = 7);
      Check
        ("writing-tree-page-index",
         Trees.Page_Count (Model) = 3
         and then Trees.Page_At (Model, 1) = 2
         and then Trees.Page_At (Model, 2) = 1
         and then Trees.Rank_Of (Model, 3) = 3
         and then Trees.Directory_Of (Model, 2) = 2
         and then Trees.Directory_Of (Model, 4) = 0);
      Check
        ("writing-tree-blocks",
         Trees.Block_End (Model, Dirs, 2) = 5
         and then Trees.Block_End (Model, Dirs, 3) = 4
         and then Trees.Last_Of (Model, Dirs, 0) = 8
         and then Trees.Last_Of (Model, Dirs, 3) = 7);
      Seen := Trees.Version (Model);
      Trees.Arrange (Model, Dirs, Docs);
      Check ("writing-tree-load-no-change", Trees.Version (Model) = Seen);
      Check
        ("writing-tree-rules",
         not Trees.Can_Execute (Model, Dirs, 1, 2, 0)
         and then not Trees.Can_Execute (Model, Dirs, 6, 2, 0)
         and then not Trees.Can_Execute (Model, Dirs, 2, 8, 2)
         and then not Trees.Can_Execute (Model, Dirs, 3, 4, 0)
         and then not Trees.Can_Execute (Model, Dirs, 3, 9, 0)
         and then not Trees.Can_Execute (Model, Dirs, 5, 8, 4)
         and then not Trees.Can_Execute (Model, Dirs, 7, 4, 0)
         and then not Trees.Can_Execute (Model, Dirs, 7, 8, 1));
      begin
         Trees.Relocate (Model, Dirs, Store, 2, 8, 2);
      exception
         when Ada.Assertions.Assertion_Error =>
            Rejected := True;
      end;
      Check ("writing-tree-move-contract", Rejected and then Store.Writes = 0 and then Trees.Version (Model) = Seen);
      Trees.Relocate (Model, Dirs, Store, 3, 7, 3);
      Check
        ("writing-tree-move-subtree-down",
         Trees.Dir_Row (Model, 2) = 5
         and then Trees.Leaf_Row (Model, 2) = 6
         and then Trees.Leaf_Row (Model, 1) = 3
         and then Dirs (2).Parent = 30
         and then Store.Parents (2) = 30);
      Check
        ("writing-tree-keep-positions",
         Store.Folders = Positions'[2, 5, 4]
         and then Store.Pages = Positions'[3, 6, 7]
         and then Store.Touches = 1
         and then Store.Writes = 7
         and then Trees.Version (Model) /= Seen);
      Trees.Relocate (Model, Dirs, Store, 3, 7, 2);
      Check
        ("writing-tree-move-document",
         Trees.Leaf_Row (Model, 1) = 6 and then Trees.Element (Model, 6).Dir = 2 and then Store.Membership (1) = 20);
      Trees.Relocate (Model, Dirs, Store, 4, 2, 0);
      Check
        ("writing-tree-page-index-moved",
         Trees.Page_At (Model, 1) = 2 and then Trees.Page_At (Model, 2) = 1 and then Trees.Directory_Of (Model, 1) = 2);
      Check
        ("writing-tree-move-subtree-up",
         Trees.Dir_Row (Model, 2) = 2
         and then Trees.Leaf_Row (Model, 2) = 3
         and then Trees.Leaf_Row (Model, 1) = 4
         and then Dirs (2).Parent = 0
         and then Store.Parents (2) = 0
         and then Trees.Block_End (Model, Dirs, 2) = 4);
      Seen := Trees.Version (Model);
      Writes := Store.Writes;
      Trees.Relocate (Model, Dirs, Store, 2, 5, 0);
      Check ("writing-tree-move-no-change", Trees.Version (Model) = Seen and then Store.Writes = Writes);
      Trees.Relocate (Model, Dirs, Store, 7, 7, 3);
      Check
        ("writing-tree-membership-only",
         Trees.Leaf_Row (Model, 3) = 7 and then Trees.Element (Model, 7).Dir = 3 and then Store.Membership (3) = 30);
      Trees.Delete (Model, 7);
      Check
        ("writing-tree-delete",
         Trees.Leaf_Row (Model, 3) = 0
         and then Trees.Count (Model) = 6
         and then Trees.Page_Count (Model) = 2
         and then Trees.Directory_Of (Model, 3) = 0);
      Trees.Insert (Model, 3, (Kind => Trees.Document_Leaf, Doc => 3, Dir => 2));
      Check ("writing-tree-insert", Trees.Leaf_Row (Model, 3) = 3 and then Trees.Leaf_Row (Model, 2) = 4);
      for Doc in 4 .. 2_048 loop
         Trees.Insert (Model, Trees.Count (Model) + 1, (Kind => Trees.Document_Leaf, Doc => Doc, Dir => 0));
      end loop;
      Check ("writing-tree-growing", Trees.Count (Model) = 2_052 and then Trees.Leaf_Row (Model, 2_048) = 2_052);
      Trees.Reset (Model);
      Seen := Trees.Version (Model);
      Trees.Reset (Model);
      Check
        ("writing-tree-reset",
         Trees.Count (Model) = 0
         and then Trees.Version (Model) = Seen
         and then Trees.Page_Count (Model) = 0
         and then Trees.Directory_Of (Model, 1) = 0);
      Dirs.Clear;
      Docs.Clear;
      Dirs.Append ((Key => 10, others => <>));
      Docs.Append ((Slot => 1, Dir => 0, Position => 0));
      Trees.Arrange (Model, Dirs, Docs);
      Check ("writing-tree-unplaced-ties", Trees.Dir_Row (Model, 1) = 2 and then Trees.Leaf_Row (Model, 1) = 3);
   end Ordering;

   procedure Navigation is
      Dirs     : Writing_VM.Directories;
      Model    : Writing_VM.View_Model;
      Seen     : Pomarine.View_Models.Version_Number;
      Rejected : Boolean := False;
      Saved    : Items.Directories.Directory;
   begin
      Check ("writing-empty", Writing_VM.Shown (Model, Dirs) = 0 and then Writing_VM.In_View (Model, Dirs, 0));
      Dirs.Append ((Key => 10, others => <>));
      Dirs.Append ((Key => 20, Parent => 10, Section => 7, others => <>));
      Dirs.Append ((Key => 30, Parent => 20, others => <>));
      Dirs.Append ((Key => 40, others => <>));
      Check
        ("writing-ancestry",
         Writing_VM.Parent_Of (Dirs, 3) = 2
         and then Writing_VM.Depth (Dirs, 3) = 2
         and then Writing_VM.Section_Directory (Dirs, 3) = 2
         and then Writing_VM.Section_Directory (Dirs, 1) = 0);
      Check
        ("writing-subtrees",
         Writing_VM.Within (Dirs, 3, 1)
         and then Writing_VM.Within (Dirs, 3, 3)
         and then Writing_VM.Within (Dirs, 4, 0)
         and then not Writing_VM.Within (Dirs, 0, 1)
         and then not Writing_VM.Within (Dirs, 4, 1));
      Seen := Writing_VM.Version (Model);
      Writing_VM.Show (Model, Dirs, 2);
      Check
        ("writing-select",
         Writing_VM.Version (Model) /= Seen
         and then Writing_VM.Shown (Model, Dirs) = 2
         and then Writing_VM.In_View (Model, Dirs, 3)
         and then not Writing_VM.In_View (Model, Dirs, 1));
      Seen := Writing_VM.Version (Model);
      Writing_VM.Show (Model, Dirs, 2);
      Writing_VM.Reconcile (Model, Dirs);
      Check ("writing-no-change", Writing_VM.Version (Model) = Seen);
      Saved := Dirs (2);
      Dirs (2) := Dirs (4);
      Dirs (4) := Saved;
      Writing_VM.Reconcile (Model, Dirs);
      Check
        ("writing-key-reorder",
         Writing_VM.Shown (Model, Dirs) = 4
         and then Writing_VM.Version (Model) = Seen
         and then Writing_VM.Parent_Of (Dirs, 3) = 4);
      Dirs (4).Key := 50;
      Writing_VM.Reconcile (Model, Dirs);
      Check
        ("writing-deleted-replaced", Writing_VM.Shown (Model, Dirs) = 0 and then Writing_VM.Version (Model) /= Seen);
      Seen := Writing_VM.Version (Model);
      Writing_VM.Reset (Model);
      Check ("writing-reset-no-change", Writing_VM.Version (Model) = Seen);
      Check ("writing-command-availability", not Writing_VM.Can_Execute (Dirs, Dirs.Count + 1));
      begin
         Writing_VM.Show (Model, Dirs, Dirs.Count + 1);
      exception
         when Ada.Assertions.Assertion_Error =>
            Rejected := True;
      end;
      Check ("writing-select-contract", Rejected);
      Writing_VM.Show (Model, Dirs, 1);
      Writing_VM.Reset (Model);
      Check ("writing-leave", Writing_VM.Shown (Model, Dirs) = 0);
   end Navigation;
   procedure By_Name is
      App    : aliased View.Session;
      Ears   : aliased View_Driver.Driver (App'Access);
      Window : Pomarine.Testing.Session;
      package Testing renames Pomarine.Testing;
      package Docs renames View.Documents;
   begin
      View.Open (App, "", 1000, 800);
      Testing.Attach (Window, View.Widget_Tree (App).all, Ears'Access);
      Testing.Click_On (Window, "New project");
      Testing.Click_On (Window, "Canvas");
      View.Canvas_Windows.Add_Item (App, "Alpha");
      View.Canvas_Windows.Add_Item (App, "Beta");
      Testing.Click_On (Window, "Write");
      Testing.Click_On (Window, "Sources", Nth => 1);
      Check ("writing-name-page-sources", Testing.Exists (Window, "No linked sources"));
      Testing.Click_On (Window, "Sources", Nth => 1);
      Check ("writing-name-page-sources-closed", not Testing.Exists (Window, "No linked sources"));
      Testing.Click_On (Window, "New folder");
      Testing.Type_Text (Window, "Part");
      Testing.Press (Window, Pomarine.Events.Key_Return);
      Check
        ("writing-name-directory-created",
         Docs.Directory_Count (App) = 1 and then Testing.Exists (Window, "Directory Part"));
      Docs.Move_Document_To (App, 1, 1);
      Testing.Click_On (Window, "Directory Part");
      Check
        ("writing-name-filter",
         Docs.Shown_Directory (App) = 1
         and then Testing.Exists (Window, "Text of Alpha")
         and then not Testing.Exists (Window, "Text of Beta"));
      Testing.Click_On (Window, "Add document");
      Check
        ("writing-name-add-in-directory",
         Docs.Document_Count (App) = 3
         and then Docs.Document_Directory (App, 3) = 1
         and then Docs.Document_Title (App, 3) = "Untitled document");
      Testing.Click_On (Window, "Canvas");
      Testing.Click_On (Window, "Write");
      Check
        ("writing-name-rebuild",
         Docs.Shown_Directory (App) = 1
         and then Docs.Document_Directory (App, 3) = 1
         and then not Testing.Exists (Window, "Text of Beta"));
      Testing.Click_On (Window, "Overview");
      Check ("writing-name-overview", Docs.Shown_Directory (App) = 0 and then Testing.Exists (Window, "Text of Beta"));
      Testing.Click_On (Window, "Directory Part");
      Testing.Click_On (Window, "New folder");
      Testing.Type_Text (Window, "Child");
      Testing.Press (Window, Pomarine.Events.Key_Return);
      Check
        ("writing-name-nested-created",
         Docs.Directory_Count (App) = 2
         and then Docs.Directory_Title (App, 2) = "Child"
         and then Docs.Directory_Parent (App, 2) = 1);
      Testing.Click_On (Window, "Projects");
      Testing.Click_On (Window, "Open Untitled project");
      Check
        ("writing-name-creation-reopened",
         Docs.Document_Count (App) = 3
         and then Docs.Document_Title (App, 3) = "Untitled document"
         and then Docs.Document_Directory (App, 3) = 1
         and then Docs.Directory_Count (App) = 2
         and then Docs.Directory_Title (App, 2) = "Child"
         and then Docs.Directory_Parent (App, 2) = 1);
   end By_Name;
   procedure Sidebar_By_Name is
      App    : aliased View.Session;
      Ears   : aliased View_Driver.Driver (App'Access);
      Window : Pomarine.Testing.Session;
      package Testing renames Pomarine.Testing;
   begin
      View.Open (App, "", 1000, 800);
      Testing.Attach (Window, View.Widget_Tree (App).all, Ears'Access);
      Testing.Click_On (Window, "New project");
      Testing.Click_On (Window, "Write");
      Check
        ("sidebar-name-initial",
         Testing.Exists (Window, "Show Grammar Suggestions")
         and then Testing.Exists (Window, "Overview")
         and then Testing.Exists (Window, "No sources yet"));
      Testing.Click_On (Window, "Fold or unfold EDIT");
      Check
        ("sidebar-name-edit",
         not Testing.Exists (Window, "Show Grammar Suggestions") and then Testing.Exists (Window, "Add document"));
      Testing.Click_On (Window, "Fold or unfold DOCUMENTS");
      Check
        ("sidebar-name-documents",
         not Testing.Exists (Window, "Overview")
         and then not Testing.Exists (Window, "Add document")
         and then not Testing.Exists (Window, "New folder"));
      Testing.Click_On (Window, "Fold or unfold SOURCES");
      Check ("sidebar-name-sources", not Testing.Exists (Window, "No sources yet"));
      Testing.Click_On (Window, "Canvas");
      Testing.Click_On (Window, "Write");
      Check
        ("sidebar-name-return",
         not Testing.Exists (Window, "Overview") and then not Testing.Exists (Window, "Show Grammar Suggestions"));
      Testing.Click_On (Window, "Fold or unfold DOCUMENTS");
      Testing.Click_On (Window, "Fold or unfold SOURCES");
      Testing.Click_On (Window, "Fold or unfold EDIT");
      Check
        ("sidebar-name-unfolded",
         Testing.Exists (Window, "Overview")
         and then Testing.Exists (Window, "Add document")
         and then Testing.Exists (Window, "New folder")
         and then Testing.Exists (Window, "Show Grammar Suggestions")
         and then Testing.Exists (Window, "No sources yet"));
      Testing.Click_On (Window, "Add document");
      Check ("sidebar-name-create-after-unfold", View.Documents.Document_Count (App) = 1);
   end Sidebar_By_Name;

   procedure Publishing_By_Name is
      App    : aliased View.Session;
      Ears   : aliased View_Driver.Driver (App'Access);
      Window : Pomarine.Testing.Session;
      package Testing renames Pomarine.Testing;
      LF     : constant Character := ASCII.LF;

      procedure Copy_And_Check (Name, Expected : String) is
      begin
         Testing.Click_On
           (Window, (if Testing.Exists (Window, "Copy to Clipboard") then "Copy to Clipboard" else "Copied"));
         Goldens.Check_Text (Name, Expected, View.Clipboard_Text (App));
         Check (Name & "-confirmed", Testing.Exists (Window, "Copied"));
      end Copy_And_Check;
   begin
      View.Open (App, "", 1000, 800);
      Testing.Attach (Window, View.Widget_Tree (App).all, Ears'Access);
      Testing.Click_On (Window, "New project");
      Testing.Click_On (Window, "Add Section");
      Testing.Type_Text (Window, "Chapter");
      Testing.Click_On (Window, "Write");
      Testing.Click_On (Window, "Add document", Nth => 2);
      Testing.Type_Text (Window, "Body");
      Testing.Click_On (Window, "Publish");
      Check
        ("publish-name-initial",
         Testing.Is_Disabled (Window, "Export") and then Testing.Is_Disabled (Window, "Copy to Clipboard"));
      Testing.Click_On (Window, "Publish format");
      Check ("publish-name-menu", Testing.Exists (Window, "Markdown"));
      Testing.Click_On (Window, "Publish format");
      Check ("publish-name-select-dismiss", not Testing.Exists (Window, "Markdown"));
      Testing.Click_On (Window, "Publish format");
      Testing.Click_On (Window, "Markdown");
      Check
        ("publish-name-chosen",
         not Testing.Exists (Window, "Markdown")
         and then Testing.Value_Of (Window, "Publish format") = "Markdown"
         and then not Testing.Is_Disabled (Window, "Copy to Clipboard"));
      Check ("publish-name-export-needs-window", Testing.Is_Disabled (Window, "Export"));
      Copy_And_Check ("publish-name-plain", "Body" & LF);
      Testing.Click_On (Window, "Include section headings");
      Copy_And_Check ("publish-name-sections", "## Chapter" & LF & LF & "Body" & LF);
      Testing.Click_On (Window, "Include document headings");
      Copy_And_Check ("publish-name-documents", "## Chapter" & LF & LF & "### Chapter" & LF & LF & "Body" & LF);
      Testing.Click_On (Window, "Publish format");
      Testing.Click_On (Window, "Publish");
      Check ("publish-name-outside-dismiss", not Testing.Exists (Window, "Markdown"));
      Testing.Click_On (Window, "Include section headings");
      Copy_And_Check ("publish-name-sections-off", "### Chapter" & LF & LF & "Body" & LF);
      Testing.Click_On (Window, "Publish format");
      Testing.Click_On (Window, "Write");
      Testing.Click_On (Window, "Publish");
      Check
        ("publish-name-return",
         not Testing.Exists (Window, "Markdown") and then Testing.Value_Of (Window, "Publish format") = "Markdown");
      Copy_And_Check ("publish-name-kept-options", "### Chapter" & LF & LF & "Body" & LF);
      declare
         Book : constant String := View.Published_As (App, Publish_VM.EPUB);
      begin
         --  The section is a chapter, whether or not its heading is published.
         Check
           ("publish-name-epub-chapter",
            Ada.Strings.Fixed.Index (Book, "<a href=""chapter-1.xhtml"">Chapter</a>") > 0
            and then Ada.Strings.Fixed.Index (Book, "chapter-2.xhtml") = 0);
      end;
   end Publishing_By_Name;

   procedure Sections_By_Name is
      App    : aliased View.Session;
      Ears   : aliased View_Driver.Driver (App'Access);
      Window : Pomarine.Testing.Session;
      package Testing renames Pomarine.Testing;
      package Outline renames View.Outline_Screen;
      package Docs renames View.Documents;
   begin
      View.Open (App, "", 1000, 2200);
      Testing.Attach (Window, View.Widget_Tree (App).all, Ears'Access);
      Testing.Click_On (Window, "New project");
      Testing.Click_On (Window, "Add Section");
      Testing.Type_Text (Window, "First");
      Testing.Click_On (Window, "Add Section");
      Testing.Type_Text (Window, "Second");
      Testing.Click_On (Window, "Write");
      Testing.Click_On (Window, "Notes", Nth => 1);
      Testing.Type_Text (Window, "Shared section notes");
      Testing.Click_On (Window, "Notes", Nth => 1);
      Check
        ("writing-section-notes-focused",
         Outline.Section_Notes (App, 1) = "Shared section notes" and then not Outline.Notes_Shown (App, 1));
      Testing.Click_On (Window, "Notes", Nth => 1);
      Check ("writing-section-notes-reopened", Outline.Notes_Shown (App, 1));
      Testing.Click_On (Window, "Notes", Nth => 1);
      --  The empty section button targets the second section, alongside the sidebar's Add document.
      Testing.Click_On (Window, "Add document", Nth => 3);
      Check
        ("writing-section-empty-add",
         Docs.Document_Count (App) = 1
         and then Outline.Section_Item (App, 1) = ""
         and then Outline.Section_Item (App, 2) = "Second,");
      --  Header bindings follow current row positions after a reorder.
      Outline.Move_Section (App, 2, 1);
      Testing.Settle (Window);
      Testing.Click_On (Window, "Add document to this section", Nth => 1);
      Check
        ("writing-section-header-add",
         Docs.Document_Count (App) = 2
         and then Outline.Section_Item (App, 1) = "Second,Second,"
         and then Outline.Section_Item (App, 2) = "");
      Testing.Click_On (Window, "Outline");
      Testing.Click_On (Window, "Add Section");
      Testing.Type_Text (Window, "Late");
      Testing.Click_On (Window, "Write");
      Testing.Click_On (Window, "Add document", Nth => 3);
      Check
        ("writing-section-late-add", Docs.Document_Count (App) = 3 and then Outline.Section_Item (App, 3) = "Late,");
   end Sections_By_Name;

end Writing_VM_Tests;
