with Ada.Assertions;
with Pomarine.Events;
with Pomarine.Semantics;
with Pomarine.Testing;
with View;
with View.Canvas_Windows;
with View.Project_Screen;
with View_Driver;
with Canvas_VM;
with Canvas_VM_Fakes;
with Goldens;
with Item_List_VM;
with Items.Models.Tables;
with Pomarine.View_Models;

package body Item_List_VM_Tests is
   use type Pomarine.View_Models.Version_Number;
   procedure Check (Name : String; Expected, Actual : String) renames Goldens.Check_Text;
   function Image (Value : Boolean) return String is (Value'Image);

   type Surface is limited new Item_List_VM.Surface with record
      Canvas : access Canvas_VM.View_Model;
   end record;
   overriding procedure Apply (Self : in out Surface; What : Canvas_VM.Command; Slot : Items.Slot);
   overriding procedure Apply (Self : in out Surface; What : Canvas_VM.Command; Slot : Items.Slot) is
   begin
      Canvas_VM.Execute (Self.Canvas.all, What, Slot);
   end Apply;

   procedure Rows_And_Actions is
      Kept : aliased Canvas_VM_Fakes.Few;
      Slots : aliased Items.Models.Tables.Table;
      Room : aliased Canvas_VM_Fakes.Room;
      Canvas : aliased Canvas_VM.View_Model;
      Pane : aliased Surface;
      Model : Item_List_VM.View_Model;
      Seen : Pomarine.View_Models.Version_Number;
      Slot : Items.Slot;
      Rejected : Boolean := False;
      Long_Title : constant String (1 .. 700) := [others => 'x'];
   begin
      Room.Models := Slots'Unchecked_Access;
      Canvas_VM.Initialize (Canvas, Kept'Unchecked_Access, Room'Unchecked_Access, Slots'Unchecked_Access);
      Pane.Canvas := Canvas'Unchecked_Access;
      Item_List_VM.Initialize (Model, Canvas'Unchecked_Access, Slots'Unchecked_Access, Pane'Unchecked_Access);
      Canvas_VM.Enter (Canvas);
      Item_List_VM.Refresh (Model);
      Check ("item-list-vm-empty", "TRUE FALSE FALSE", Image (Item_List_VM.Count (Model) = 0) & " "
             & Image (Item_List_VM.Can_Execute (Model, Item_List_VM.Reveal)) & " "
             & Image (Item_List_VM.Can_Execute (Model, Item_List_VM.Remove, 1)));
      Canvas_VM.Add (Canvas, "", Items.Note, Slot);
      Canvas_VM.Add (Canvas, Long_Title, Items.Source, Slot);
      Item_List_VM.Refresh (Model);
      Check ("item-list-vm-rows", "TRUE (untitled) TRUE TRUE", Image (Item_List_VM.Count (Model) = 2) & " "
             & Item_List_VM.Title (Model, 1) & " " & Image (Item_List_VM.Title (Model, 2) = Long_Title) & " "
             & Image (Item_List_VM.Slot_Of (Model, 2) = Slot));
      Seen := Item_List_VM.Version (Model);
      Item_List_VM.Refresh (Model);
      Check ("item-list-vm-no-change", "TRUE", Image (Item_List_VM.Version (Model) = Seen));
      Items.Models.Set_Title_Text (Slots (1), "Renamed");
      Item_List_VM.Refresh (Model);
      Check ("item-list-vm-title", "Renamed TRUE", Item_List_VM.Title (Model, 1) & " "
             & Image (Item_List_VM.Version (Model) /= Seen));
      Item_List_VM.Execute (Model, Item_List_VM.Toggle_Shown, 1);
      Check ("item-list-vm-hidden", "TRUE CLOSED", Image (Item_List_VM.Is_Closed (Model, 1)) & " "
             & Canvas_VM_Fakes.State_Of (Kept, Items.Models.Details (Slots (1)).Key)'Image);
      Item_List_VM.Execute (Model, Item_List_VM.Toggle_Shown, 1);
      Check ("item-list-vm-shown", "FALSE OPEN", Image (Item_List_VM.Is_Closed (Model, 1)) & " "
             & Canvas_VM_Fakes.State_Of (Kept, Items.Models.Details (Slots (1)).Key)'Image);
      Canvas_VM.Execute (Canvas, Canvas_VM.Minimize_Item, 1);
      Item_List_VM.Execute (Model, Item_List_VM.Toggle_Shown, 1);
      Check ("item-list-vm-minimized-hidden", "TRUE", Image (Item_List_VM.Is_Closed (Model, 1)));
      Item_List_VM.Execute (Model, Item_List_VM.Reveal, 1);
      Check ("item-list-vm-revealed", "FALSE TRUE", Image (Item_List_VM.Is_Closed (Model, 1)) & " "
             & Image (Canvas_VM.Raised (Canvas) = 1));
      begin
         Item_List_VM.Execute (Model, Item_List_VM.Remove, 3);
      exception
         when Ada.Assertions.Assertion_Error => Rejected := True;
      end;
      Check ("item-list-vm-contract", "TRUE", Image (Rejected));
      Canvas_VM.Execute (Canvas, Canvas_VM.Remove_Item, 1);
      Check ("item-list-vm-stale", "FALSE", Image (Item_List_VM.Can_Execute (Model, Item_List_VM.Remove, 1)));
      Canvas_VM.Add (Canvas, "Replacement", Items.Note, Slot);
      Check ("item-list-vm-reused-slot", "TRUE FALSE", Image (Slot = 1) & " "
             & Image (Item_List_VM.Can_Execute (Model, Item_List_VM.Remove, 1)));
      Item_List_VM.Refresh (Model);
      Item_List_VM.Execute (Model, Item_List_VM.Remove, 1);
      Check ("item-list-vm-removed", "TRUE Replacement TRUE", Image (Item_List_VM.Count (Model) = 1) & " "
             & Item_List_VM.Title (Model, 1) & " " & Image (Item_List_VM.Slot_Of (Model, 1) = 1));
      Item_List_VM.Execute (Model, Item_List_VM.Remove);
      Check ("item-list-vm-last-removed", "TRUE FALSE", Image (Item_List_VM.Count (Model) = 0) & " "
             & Image (Item_List_VM.Can_Execute (Model, Item_List_VM.Remove)));
   end Rows_And_Actions;
   procedure Window_Controls_By_Name is
      Session : aliased View.Session;
      Ears : aliased View_Driver.Driver (Session'Access);
      Window : Pomarine.Testing.Session;
      package Testing renames Pomarine.Testing;
      package Windows renames View.Canvas_Windows;
   begin
      View.Open (Session, "", 1000, 800);
      Testing.Attach (Window, View.Widget_Tree (Session).all, Ears'Access);
      Testing.Click_On (Window, "New project");
      Testing.Click_On (Window, "Canvas");
      Windows.Add_Unchosen_Source (Session, "Toolbar source");
      Testing.Click_On (Window, "From URL");
      Testing.Click_On (Window, "Mark");
      Check ("item-controls-marker", "TRUE", Image (Testing.Shows (Window, "button 'Mark' selected")));
      Testing.Click_On (Window, "Rub");
      Check ("item-controls-eraser", "TRUE FALSE", Image (Testing.Shows (Window, "button 'Rub' selected"))
             & " " & Image (Testing.Shows (Window, "button 'Mark' selected")));
      Testing.Click_On (Window, "100%");
      Testing.Click_On (Window, "150%");
      Check ("item-controls-preset", "TRUE", Image (Windows.Item_Zoom (Session, 1) = 1.5));
   end Window_Controls_By_Name;

   procedure By_Name is
      Session : aliased View.Session;
      Ears : aliased View_Driver.Driver (Session'Access);
      Window : Pomarine.Testing.Session;
      package Testing renames Pomarine.Testing;
      package Windows renames View.Canvas_Windows;
   begin
      View.Open (Session, "", 1000, 800);
      Testing.Attach (Window, View.Widget_Tree (Session).all, Ears'Access);
      Testing.Click_On (Window, "New project");
      Testing.Click_On (Window, "Canvas");
      Windows.Add_Item (Session, "First");
      Windows.Add_Item (Session, "Second");
      Testing.Click_On (Window, "Items");
      Check ("item-list-name-rows", "TRUE TRUE", Image (Testing.Exists (Window, "First")) & " "
             & Image (Testing.Exists (Window, "Second")));
      Testing.Click_On (Window, "Hide", Nth => 1);
      Check ("item-list-name-hidden", "CLOSED TRUE", Windows.Item_State (Session, 1)'Image & " "
             & Image (Testing.Exists (Window, "Show")));
      Testing.Click_On (Window, "Show");
      Check ("item-list-name-shown", "OPEN", Windows.Item_State (Session, 1)'Image);
      Testing.Click_On (Window, "Remove", Nth => 1);
      Check ("item-list-name-removed", "TRUE Second", Image (Windows.Item_Count (Session) = 1) & " "
             & Windows.Item_Title (Session, 1));
      Testing.Click_On (Window, "Second", Role => Pomarine.Semantics.List_Item);
      Testing.Press (Window, Pomarine.Events.Key_Return);
      Check ("item-list-name-revealed", "FALSE OPEN", Image (View.Project_Screen.Is_Listing (Session)) & " "
             & Windows.Item_State (Session, 1)'Image);
      Testing.Click_On (Window, "Items");
      Testing.Click_On (Window, "Remove");
      Check ("item-list-name-empty", "TRUE", Image (Windows.Item_Count (Session) = 0));
      Testing.Press (Window, Pomarine.Events.Key_Escape);
   end By_Name;
end Item_List_VM_Tests;
