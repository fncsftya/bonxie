with Canvas_VM;
with Canvas_VM.Stored;
with Canvas_VM_Fakes;
with Goldens;
with Items.Links;
with Items.Models.Tables;
with Items.Records;
with Items.Schema;
with Pomarine.View_Models;
with Projects;

package body Canvas_VM_Tests is

   package Parts renames Pomarine.View_Models;
   package Models renames Items.Models;

   use type Parts.Version_Number;
   use type Items.Origins;
   use all type Canvas_VM.Command;

   procedure Check (Name : String; Expected, Actual : String) renames Goldens.Check_Text;

   function Image (Value : Boolean) return String
   is (Value'Image);

   function Number (Value : Integer) return String
   is (Value'Image (2 .. Value'Image'Last));

   function Where_Is (Where : Items.Frame) return String
   is (Number (Integer (Where.Left)) & "," & Number (Integer (Where.Top)));

   --  A canvas of two items, as the project had them, entered, in a window 800 by 600 points looking at the origin.
   type Setting is limited record
      Kept  : aliased Canvas_VM_Fakes.Few;
      Slots : aliased Items.Models.Tables.Table;
      Room  : aliased Canvas_VM_Fakes.Room;
      Model : aliased Canvas_VM.View_Model;
   end record;

   procedure Prepare (Where : aliased in out Setting; Enter : Boolean := True);

   procedure Prepare (Where : aliased in out Setting; Enter : Boolean := True) is
   begin
      Canvas_VM_Fakes.Add (Where.Kept, "First", Items.Note, (Left => 0.0, Top => 0.0, Width => 280.0, Height => 200.0));
      Canvas_VM_Fakes.Add
        (Where.Kept, "Second", Items.Source, (Left => 400.0, Top => 100.0, Width => 360.0, Height => 200.0));
      Where.Room.Models := Where.Slots'Unchecked_Access;
      Canvas_VM.Initialize (Where.Model, Where.Kept'Access, Where.Room'Access, Where.Slots'Access);
      Canvas_VM.Set_Viewport (Where.Model, 800.0, 600.0);
      if Enter then
         Canvas_VM.Enter (Where.Model);
      end if;
   end Prepare;

   procedure Entering is
      Where : aliased Setting;
      Model : Canvas_VM.View_Model renames Where.Model;
      Order : Canvas_VM.Slot_Lists.List;
   begin
      Prepare (Where, Enter => False);
      Check
        ("canvas-vm-first", "FALSE 0", Image (Canvas_VM.Is_Entered (Model)) & " " & Number (Canvas_VM.Count (Model)));
      Check
        ("canvas-vm-not-entered",
         "FALSE FALSE",
         Image (Canvas_VM.Can_Execute (Model, Add_Note)) & " " & Image (Canvas_VM.Can_Execute (Model, Show_Item)));
      Canvas_VM.Enter (Model);
      Check
        ("canvas-vm-entered",
         "TRUE 2 1",
         Image (Canvas_VM.Is_Entered (Model))
         & " "
         & Number (Canvas_VM.Count (Model))
         & " "
         & Number (Where.Room.Made));
      Check
        ("canvas-vm-item",
         "First 280x200 text of 1",
         Projects.Titles.To_String (Models.Details (Where.Slots (1)).Title)
         & " 280x200 "
         & Models.Text (Where.Slots (1)));
      Check
        ("canvas-vm-items",
         "TRUE TRUE FALSE",
         Image (Canvas_VM.Is_Item (Model, 1))
         & " "
         & Image (Canvas_VM.Is_Item (Model, 2))
         & " "
         & Image (Canvas_VM.Is_Item (Model, 3)));
      Check
        ("canvas-vm-source-rank",
         "0 1",
         Number (Canvas_VM.Source_Rank (Model, 1)) & " " & Number (Canvas_VM.Source_Rank (Model, 2)));
      Canvas_VM.Order (Model, Order);
      Check ("canvas-vm-order", "2 1,2", Number (Order.Count) & " " & Number (Order (1)) & "," & Number (Order (2)));
      Check ("canvas-vm-none-made", "0", Number (Canvas_VM.Made (Model)));
      Canvas_VM.Leave (Model);
      Check
        ("canvas-vm-left",
         "FALSE 0 FALSE",
         Image (Canvas_VM.Is_Entered (Model))
         & " "
         & Number (Canvas_VM.Count (Model))
         & " "
         & Image (Canvas_VM.Is_Item (Model, 1)));
   end Entering;

   procedure Adding is
      Where : aliased Setting;
      Model : Canvas_VM.View_Model renames Where.Model;
      Slot  : Items.Slot;
      Seen  : Parts.Version_Number;
   begin
      Prepare (Where);
      --  Zoomed to twice, with the origin at -100, -50: the middle of 800 x 600 is canvas 250, 175.
      Canvas_VM.Set_Camera (Model, (Zoom => 2.0, Origin_X => -100.0, Origin_Y => -50.0));
      Check
        ("canvas-vm-middle",
         "250 175",
         Number (Integer (Canvas_VM.Middle (Model, True))) & " " & Number (Integer (Canvas_VM.Middle (Model, False))));
      Seen := Canvas_VM.Items_Version (Model);
      Canvas_VM.Add (Model, "Third", Items.Note, Slot);
      --  A step on from the middle, for the two there are.
      Check
        ("canvas-vm-added",
         "3 3 TRUE 3 158,123 TRUE",
         Number (Slot)
         & " "
         & Number (Canvas_VM.Made (Model))
         & " "
         & Image (Canvas_VM.Is_Item (Model, 3))
         & " "
         & Number (Canvas_VM.Count (Model))
         & " "
         & Where_Is (Models.Details (Where.Slots (3)).Where)
         & " "
         & Image (Canvas_VM.Items_Version (Model) /= Seen));
      Check ("canvas-vm-added-kept", "3 3", Number (Where.Kept.Last) & " " & Number (Where.Kept.Touched + 2));
      Check ("canvas-vm-added-room", "2", Number (Where.Room.Made));
      Check
        ("canvas-vm-added-state",
         "OPEN TRUE",
         Models.Details (Where.Slots (3)).State'Image
         & " "
         & Image (Models.Details (Where.Slots (3)).Origin = Items.Remote));
      Canvas_VM.Add (Model, "Fourth", Items.Source, Slot);
      Check
        ("canvas-vm-added-source",
         "4 UNCHOSEN 360",
         Number (Slot)
         & " "
         & Models.Details (Where.Slots (4)).Origin'Image
         & " "
         & Number (Integer (Models.Details (Where.Slots (4)).Where.Width)));

      --  The cascade goes round, one step to a place.
      for Each in 5 .. 9 loop
         Canvas_VM.Add (Model, "More", Items.Note, Slot);
      end loop;
      Check
        ("canvas-vm-cascade",
         "9 TRUE TRUE",
         Number (Canvas_VM.Count (Model))
         & " "
         & Image (Models.Details (Where.Slots (4)).Where.Left /= Models.Details (Where.Slots (3)).Where.Left)
         & " "
         & Image (Models.Details (Where.Slots (9)).Where.Left = Models.Details (Where.Slots (3)).Where.Left));

      --  A place free is used before one is made.
      Canvas_VM.Execute (Model, Remove_Item, 3);
      Check
        ("canvas-vm-gone", "8 FALSE", Number (Canvas_VM.Count (Model)) & " " & Image (Canvas_VM.Is_Item (Model, 3)));
      Canvas_VM.Add (Model, "Again", Items.Note, Slot);
      Check ("canvas-vm-free-place", "3", Number (Slot));
   end Adding;

   procedure Showing is
      Where : aliased Setting;
      Model : Canvas_VM.View_Model renames Where.Model;
      Seen  : Parts.Version_Number;
   begin
      Prepare (Where);
      Check
        ("canvas-vm-show-commands",
         "FALSE TRUE TRUE TRUE TRUE",
         Image (Canvas_VM.Can_Execute (Model, Open_Item, 1))
         & " "
         & Image (Canvas_VM.Can_Execute (Model, Minimize_Item, 1))
         & " "
         & Image (Canvas_VM.Can_Execute (Model, Close_Item, 1))
         & " "
         & Image (Canvas_VM.Can_Execute (Model, Show_Item, 1))
         & " "
         & Image (Canvas_VM.Can_Execute (Model, Add_Note)));
      Check
        ("canvas-vm-show-none",
         "FALSE FALSE",
         Image (Canvas_VM.Can_Execute (Model, Minimize_Item, 3))
         & " "
         & Image (Canvas_VM.Can_Execute (Model, Remove_Item, 3)));
      Seen := Canvas_VM.Items_Version (Model);
      Canvas_VM.Execute (Model, Minimize_Item, 1);
      Check
        ("canvas-vm-minimized",
         "MINIMIZED MINIMIZED TRUE",
         Models.Details (Where.Slots (1)).State'Image
         & " "
         & Where.Kept.State_Of (1)'Image
         & " "
         & Image (Canvas_VM.Items_Version (Model) /= Seen));
      Check
        ("canvas-vm-minimized-commands",
         "TRUE FALSE",
         Image (Canvas_VM.Can_Execute (Model, Open_Item, 1))
         & " "
         & Image (Canvas_VM.Can_Execute (Model, Minimize_Item, 1)));
      Canvas_VM.Choose_Origin (Model, 2, Items.Local);
      Check
        ("canvas-vm-origin",
         "LOCAL LOCAL TRUE",
         Models.Details (Where.Slots (2)).Origin'Image
         & " "
         & Where.Kept.Table (2).Info.Origin'Image
         & " "
         & Image (Where.Kept.Touched > 0));
      Canvas_VM.Execute (Model, Close_Item, 1);
      Check
        ("canvas-vm-closed",
         "CLOSED CLOSED FALSE",
         Models.Details (Where.Slots (1)).State'Image
         & " "
         & Where.Kept.State_Of (1)'Image
         & " "
         & Image (Canvas_VM.Can_Execute (Model, Close_Item, 1)));

      --  Shown: opened, asked to be centred on, and brought up.
      Seen := Canvas_VM.Steering_Version (Model);
      Canvas_VM.Execute (Model, Show_Item, 1);
      Check
        ("canvas-vm-revealed",
         "OPEN OPEN TRUE 140,100 1",
         Models.Details (Where.Slots (1)).State'Image
         & " "
         & Where.Kept.State_Of (1)'Image
         & " "
         & Image (Canvas_VM.Steering_Version (Model) /= Seen)
         & " "
         & Number (Integer (Canvas_VM.Steering (Model).Centre_X))
         & ","
         & Number (Integer (Canvas_VM.Steering (Model).Centre_Y))
         & " "
         & Number (Canvas_VM.Raised (Model)));
      Check ("canvas-vm-revealed-same-zoom", "0", Number (Integer (Canvas_VM.Steering (Model).Zoom)));

      --  Taken away for good.
      Canvas_VM.Execute (Model, Remove_Item, 1);
      Check
        ("canvas-vm-removed",
         "1 1 FALSE 2",
         Number (Canvas_VM.Count (Model))
         & " "
         & Number (Where.Kept.Last)
         & " "
         & Image (Canvas_VM.Is_Item (Model, 1))
         & " "
         & Where.Kept.Keys);
   end Showing;

   procedure Camera is
      Where : aliased Setting;
      Model : Canvas_VM.View_Model renames Where.Model;
      Seen  : Parts.Version_Number;
      Found : Boolean;
   begin
      Prepare (Where);
      Check
        ("canvas-vm-camera-first",
         "1 0",
         Number (Integer (Canvas_VM.Camera (Model).Zoom)) & " " & Number (Integer (Canvas_VM.Camera (Model).Origin_X)));
      Seen := Canvas_VM.Camera_Version (Model);
      Canvas_VM.Set_Camera (Model, (Zoom => 2.0, Origin_X => 10.0, Origin_Y => 20.0));
      Check
        ("canvas-vm-camera-set",
         "2 10 20 TRUE",
         Number (Integer (Canvas_VM.Camera (Model).Zoom))
         & " "
         & Number (Integer (Canvas_VM.Camera (Model).Origin_X))
         & " "
         & Number (Integer (Canvas_VM.Camera (Model).Origin_Y))
         & " "
         & Image (Canvas_VM.Camera_Version (Model) /= Seen));
      --  What windows are put by is the camera, as it changes.
      Check ("canvas-vm-camera-shown", "2", Number (Integer (Canvas_VM.Shown_Camera (Model).Zoom)));
      Seen := Canvas_VM.Camera_Version (Model);
      Canvas_VM.Set_Camera (Model, (Zoom => 2.0, Origin_X => 10.0, Origin_Y => 20.0));
      Check ("canvas-vm-camera-same", "FALSE", Image (Canvas_VM.Camera_Version (Model) /= Seen));

      --  Asked to look at the middle of the windows that are shown.
      Canvas_VM.Execute (Model, Close_Item, 2);
      Seen := Canvas_VM.Steering_Version (Model);
      Canvas_VM.Centre_On_Items (Model);
      Check
        ("canvas-vm-centre-items",
         "TRUE 140 100",
         Image (Canvas_VM.Steering_Version (Model) /= Seen)
         & " "
         & Number (Integer (Canvas_VM.Steering (Model).Centre_X))
         & " "
         & Number (Integer (Canvas_VM.Steering (Model).Centre_Y)));
      Canvas_VM.Execute (Model, Open_Item, 2);
      Canvas_VM.Centre_On_Items (Model);
      Check
        ("canvas-vm-centre-both",
         "380 150",
         Number (Integer (Canvas_VM.Steering (Model).Centre_X))
         & " "
         & Number (Integer (Canvas_VM.Steering (Model).Centre_Y)));
      Canvas_VM.Execute (Model, Close_Item, 1);
      Canvas_VM.Execute (Model, Close_Item, 2);
      Seen := Canvas_VM.Steering_Version (Model);
      Canvas_VM.Centre_On_Items (Model);
      Check ("canvas-vm-centre-none", "FALSE", Image (Canvas_VM.Steering_Version (Model) /= Seen));

      --  The view is kept, from the middle of what is shown; and asked for again.
      Canvas_VM.Restore_View (Model, Found);
      Check ("canvas-vm-no-view", "FALSE", Image (Found));
      Canvas_VM.Save_View (Model);
      Check
        ("canvas-vm-view-kept",
         "TRUE 2 195 140",
         Image (Where.Kept.Saved_View)
         & " "
         & Number (Integer (Where.Kept.Zoom))
         & " "
         & Number (Integer (Where.Kept.Centre_X))
         & " "
         & Number (Integer (Where.Kept.Centre_Y)));
      Seen := Canvas_VM.Steering_Version (Model);
      Canvas_VM.Restore_View (Model, Found);
      Check
        ("canvas-vm-view-restored",
         "TRUE TRUE 2 195",
         Image (Found)
         & " "
         & Image (Canvas_VM.Steering_Version (Model) /= Seen)
         & " "
         & Number (Integer (Canvas_VM.Steering (Model).Zoom))
         & " "
         & Number (Integer (Canvas_VM.Steering (Model).Centre_X)));
      --  Not before it is shown.
      Canvas_VM.Set_Viewport (Model, 0.0, 0.0);
      Where.Kept.Saved_View := False;
      Canvas_VM.Save_View (Model);
      Check ("canvas-vm-view-not-kept", "FALSE", Image (Where.Kept.Saved_View));
   end Camera;

   procedure Handling is
      Where : aliased Setting;
      Model : Canvas_VM.View_Model renames Where.Model;
   begin
      Prepare (Where);
      --  Points of the screen are canvas units over the zoom.
      Canvas_VM.Set_Camera (Model, (Zoom => 2.0, Origin_X => 0.0, Origin_Y => 0.0));
      Canvas_VM.Move_Item (Model, 1, 10.0, 20.0);
      Check ("canvas-vm-moved", "5,10", Where_Is (Models.Details (Where.Slots (1)).Where));
      Canvas_VM.Resize_Item (Model, 1, -1000.0, -1000.0, Still => True);
      Check
        ("canvas-vm-least",
         "160x100",
         Number (Integer (Models.Details (Where.Slots (1)).Where.Width))
         & "x"
         & Number (Integer (Models.Details (Where.Slots (1)).Where.Height)));
      Canvas_VM.Resize_Item (Model, 1, 400.0, 400.0, Still => False);
      Check
        ("canvas-vm-sized",
         "5,10 160x100 FALSE",
         Where_Is (Models.Details (Where.Slots (1)).Where)
         & " "
         & Number (Integer (Models.Details (Where.Slots (1)).Where.Width))
         & "x"
         & Number (Integer (Models.Details (Where.Slots (1)).Where.Height))
         & " "
         & Image (Models.Is_Resizing (Where.Slots (1))));

      --  Tools put away where the pointer was not.
      Models.Select_Tool (Where.Slots (2), Models.Highlighter);
      Canvas_VM.Put_Tool_Away (Model, 2);
      Check ("canvas-vm-tool-away", "POINTER", Models.Tool (Where.Slots (2))'Image);

      --  What is written: all that have a model, and the project said to be changed if any was.
      Where.Kept.Flushed := 0;
      Where.Kept.Touched := 0;
      Canvas_VM.Flush_All (Model, 100, Force => False);
      Check ("canvas-vm-flush-none", "2 0", Number (Where.Kept.Flushed) & " " & Number (Where.Kept.Touched));
      Canvas_VM.Flush_All (Model, 200, Force => True);
      Check ("canvas-vm-flush-forced", "4 1", Number (Where.Kept.Flushed) & " " & Number (Where.Kept.Touched));
   end Handling;

   procedure Linking is
      Where : aliased Setting;
      Model : Canvas_VM.View_Model renames Where.Model;
      Side  : Items.Links.Sides;
   begin
      Prepare (Where);
      Check
        ("canvas-vm-restyle-needs-link",
         "FALSE FALSE FALSE TRUE",
         Image (Canvas_VM.Can_Execute (Model, Set_Stroke, 1))
         & " "
         & Image (Canvas_VM.Can_Execute (Model, Set_Ending, 1))
         & " "
         & Image (Canvas_VM.Can_Execute (Model, Set_Color, 1))
         & " "
         & Image (Canvas_VM.Can_Execute (Model, Pick_Link, 0)));
      Check
        ("canvas-vm-no-links",
         "0 0 FALSE FALSE",
         Number (Canvas_VM.Link_Count (Model))
         & " "
         & Number (Integer (Canvas_VM.Selected_Link (Model)))
         & " "
         & Image (Canvas_VM.Can_Execute (Model, Delete_Link))
         & " "
         & Image (Canvas_VM.Can_Execute (Model, Cancel_Link)));

      --  A line dragged from a pin of one item, let go on a pin of another.
      Canvas_VM.Begin_Link (Model, 1, Items.Links.Right);
      Check
        ("canvas-vm-dragging",
         "1 RIGHT FALSE TRUE",
         Number (Canvas_VM.Link_From (Model))
         & " "
         & Canvas_VM.Link_From_Side (Model)'Image
         & " "
         & Image (Canvas_VM.Is_Moving_Link (Model))
         & " "
         & Image (Canvas_VM.Can_Execute (Model, Cancel_Link)));
      Canvas_VM.End_Link (Model, 2, Items.Links.Left);
      Check
        ("canvas-vm-linked",
         "1 0 1 2",
         Number (Canvas_VM.Link_Count (Model))
         & " "
         & Number (Canvas_VM.Link_From (Model))
         & " "
         & Number (Integer (Canvas_VM.Link_At (Model, 1).From))
         & " "
         & Number (Integer (Canvas_VM.Link_At (Model, 1).To)));
      Check
        ("canvas-vm-linked-sides",
         "RIGHT LEFT",
         Canvas_VM.Link_At (Model, 1).From_Side'Image & " " & Canvas_VM.Link_At (Model, 1).To_Side'Image);
      Check ("canvas-vm-link-kept", "1", Number (Where.Kept.Links.Count));

      --  Not to the item it began at, nor twice, nor onto nothing.
      Canvas_VM.Begin_Link (Model, 1, Items.Links.Top);
      Canvas_VM.End_Link (Model, 1, Items.Links.Bottom);
      Canvas_VM.Begin_Link (Model, 2, Items.Links.Top);
      Canvas_VM.End_Link (Model, 1, Items.Links.Bottom);
      Canvas_VM.Begin_Link (Model, 1, Items.Links.Top);
      Canvas_VM.End_Link (Model, 0, Items.Links.Top);
      Check
        ("canvas-vm-no-more",
         "1 0",
         Number (Canvas_VM.Link_Count (Model)) & " " & Number (Canvas_VM.Link_From (Model)));

      --  Not from an item that is not shown.
      Canvas_VM.Execute (Model, Minimize_Item, 2);
      Canvas_VM.Begin_Link (Model, 1, Items.Links.Top);
      Canvas_VM.End_Link (Model, 2, Items.Links.Top);
      Check ("canvas-vm-not-open", "1", Number (Canvas_VM.Link_Count (Model)));
      Canvas_VM.Execute (Model, Open_Item, 2);

      --  Selected, looked at, moved to another side, drawn another way, and gone.
      Canvas_VM.Select_Link (Model, 1);
      Check
        ("canvas-vm-selected",
         "1 TRUE",
         Number (Integer (Canvas_VM.Selected_Link (Model))) & " " & Image (Canvas_VM.Can_Execute (Model, Delete_Link)));
      Canvas_VM.Begin_Moving_Link (Model);
      Check
        ("canvas-vm-moving",
         "1 TRUE",
         Number (Canvas_VM.Link_From (Model)) & " " & Image (Canvas_VM.Is_Moving_Link (Model)));
      Side := Items.Links.Bottom;
      Canvas_VM.End_Link (Model, 2, Side);
      Check
        ("canvas-vm-moved-link",
         "BOTTOM FALSE",
         Canvas_VM.Link_At (Model, 1).To_Side'Image & " " & Image (Canvas_VM.Is_Moving_Link (Model)));
      Check
        ("canvas-vm-style-ranges",
         "FALSE TRUE FALSE TRUE TRUE FALSE",
         Image (Canvas_VM.Can_Execute (Model, Set_Stroke, 0))
         & " "
         & Image (Canvas_VM.Can_Execute (Model, Set_Stroke, 3))
         & " "
         & Image (Canvas_VM.Can_Execute (Model, Set_Stroke, 4))
         & " "
         & Image (Canvas_VM.Can_Execute (Model, Set_Ending, 2))
         & " "
         & Image (Canvas_VM.Can_Execute (Model, Set_Color, Items.Links.Link_Color_Count))
         & " "
         & Image (Canvas_VM.Can_Execute (Model, Set_Color, Items.Links.Link_Color_Count + 1)));
      Canvas_VM.Execute (Model, Set_Stroke, 3);
      Canvas_VM.Execute (Model, Set_Ending, 2);
      Canvas_VM.Execute (Model, Set_Color, 3);
      Check
        ("canvas-vm-restyled",
         "DASHED ARROW 3",
         Canvas_VM.Link_At (Model, 1).Stroke'Image
         & " "
         & Canvas_VM.Link_At (Model, 1).Ending'Image
         & " "
         & Number (Canvas_VM.Link_At (Model, 1).Color));
      Canvas_VM.Execute (Model, Pick_Link, 99);
      Check ("canvas-vm-pick-none", "0", Number (Integer (Canvas_VM.Selected_Link (Model))));
      Canvas_VM.Execute (Model, Pick_Link, 1);
      Canvas_VM.Execute (Model, Delete_Link);
      Check
        ("canvas-vm-link-deleted",
         "0 0 0",
         Number (Canvas_VM.Link_Count (Model))
         & " "
         & Number (Integer (Canvas_VM.Selected_Link (Model)))
         & " "
         & Number (Where.Kept.Links.Count));

      --  An item that is taken away takes its links.
      Canvas_VM.Join (Model, 1, 2, Items.Links.Right, Items.Links.Left);
      Canvas_VM.Select_Link (Model, 1);
      Canvas_VM.Execute (Model, Remove_Item, 2);
      Check
        ("canvas-vm-link-went",
         "0 0",
         Number (Canvas_VM.Link_Count (Model)) & " " & Number (Integer (Canvas_VM.Selected_Link (Model))));
      Check ("canvas-vm-cancelled", "FALSE", Image (Canvas_VM.Can_Execute (Model, Cancel_Link)));
   end Linking;

   procedure Stored is
      Store   : aliased Projects.Store;
      Kept    : aliased Canvas_VM.Stored.Project_Kept;
      Slots   : aliased Items.Models.Tables.Table;
      Room    : aliased Canvas_VM_Fakes.Room;
      Model   : Canvas_VM.View_Model;
      Project : Projects.Id;
      Slot    : Items.Slot;
      Found   : Items.Info_List;
   begin
      Projects.Open (Store, Projects.Memory);
      Items.Schema.Prepare (Store);
      Project := Projects.Create (Store, "Test");
      Canvas_VM.Stored.Open (Kept, Store'Access);
      Canvas_VM.Stored.Set_Project (Kept, Project);
      Room.Models := Slots'Unchecked_Access;
      Canvas_VM.Initialize (Model, Kept'Access, Room'Access, Slots'Access);
      Canvas_VM.Set_Viewport (Model, 800.0, 600.0);
      Canvas_VM.Enter (Model);
      Check ("canvas-vm-stored-empty", "0", Number (Canvas_VM.Count (Model)));

      Canvas_VM.Add (Model, "First", Items.Note, Slot);
      Canvas_VM.Add (Model, "Second", Items.Source, Slot);
      Items.Records.Load (Store, Project, Found);
      Check
        ("canvas-vm-stored-added",
         "2 First Second",
         Number (Found.Count)
         & " "
         & Projects.Titles.To_String (Found (1).Title)
         & " "
         & Projects.Titles.To_String (Found (2).Title));
      Canvas_VM.Execute (Model, Minimize_Item, 1);
      Items.Records.Load (Store, Project, Found);
      Check ("canvas-vm-stored-state", "MINIMIZED", Found (1).State'Image);
      Canvas_VM.Join (Model, 1, 2, Items.Links.Right, Items.Links.Left);
      Check ("canvas-vm-stored-link", "1", Number (Canvas_VM.Link_Count (Model)));

      --  Left and entered again: as it was kept.
      Canvas_VM.Flush_All (Model, 0, Force => True);
      Canvas_VM.Leave (Model);
      Canvas_VM.Enter (Model);
      Check
        ("canvas-vm-stored-again",
         "2 MINIMIZED 1",
         Number (Canvas_VM.Count (Model))
         & " "
         & Models.Details (Slots (1)).State'Image
         & " "
         & Number (Canvas_VM.Link_Count (Model)));
      Canvas_VM.Execute (Model, Remove_Item, 2);
      Items.Records.Load (Store, Project, Found);
      Check ("canvas-vm-stored-removed", "1 0", Number (Found.Count) & " " & Number (Canvas_VM.Link_Count (Model)));
   end Stored;

end Canvas_VM_Tests;
