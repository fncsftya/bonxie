with Settings_VM;
with Ada.Directories;
with Items.Links;
with Items.Sources;
with Items.Windows.Callbacks;
with Downloads;
with Preferences;
with Pomarine.Widgets;
with Speech.Jobs;
with Speech.Models;
with View.Links;
with View.Section_Links;
with View.Style;
with View.Writing;
with Vision.Jobs;
with Webshot;
with Pomarine.Widgets.Layouts;
with Canvas_VM.Stored;
with Pomarine.View_Models;
with View.Canvas_Items.Basics;
with View.Canvas_Items.Opening;
with View.Canvas_Items.Placement;
with View.Canvas_Items.Polling;
with View.Canvas_Items.Recognition;

package body View.Canvas_Items is

   package Widgets renames Pomarine.Widgets;
   package Windows renames Items.Windows;
   package Models renames Items.Models;
   package Window_Events is new Items.Windows.Callbacks (Session);

   use type Items.States;
   use type Preferences.Speech_Models;
   use type Models.Tools;
   use type Items.Kinds;
   use type Webshot.States;
   use type Items.Origins;
   use type Vision.Jobs.States;
   use type Speech.Jobs.States;
   use type Models.Dictations;

   function Busy (Item : Session) return Boolean is
     (Capturing (Item)
      or else (for some Which in 1 .. Item.Windows.Count =>
                 Basics.Is_Source (Item, Which)
                 and then Vision.Jobs.State (Which) = Vision.Jobs.Working));

   function Capturing (Item : Session) return Boolean is
   begin
      if Item.Nav.Fetch_Slot /= 0 then
         return True;
      end if;
      for Which in 1 .. Item.Windows.Count loop
         if Windows.Is_Assigned (Item.Windows (Which))
           and then Speech.Jobs.State (Which)
                    in Speech.Jobs.Starting | Speech.Jobs.Listening
                       | Speech.Jobs.Finishing
         then
            return True;
         end if;
         if Basics.Is_Source (Item, Which)
           and then Webshot.State (Which) = Webshot.Working
         then
            return True;
         end if;
      end loop;
      return False;
   end Capturing;

   procedure Toggle_Dictation (Item : in out Session; Which : Items.Slot) is
   begin
      case Speech.Jobs.State (Which) is
         when Speech.Jobs.Idle | Speech.Jobs.Done | Speech.Jobs.Failed =>
            Speech.Jobs.Reset (Which);
            declare
               Model_Directory : constant String :=
                 Preferences.Speech_Model_Directory
                   (Settings_VM.Config_Directory (Item.Choices.Model));
            begin
               if Settings_VM.Speech_Model (Item.Choices.Model) = Preferences.Parakeet then
                  if Speech.Models.Present (Model_Directory) then
                     Speech.Jobs.Start
                       (Which, Speech.Jobs.Model, Model_Directory);
                     Windows.Set_Dictation
                       (Item.Windows (Which), Models.Preparing);
                  else
                     Windows.Set_Dictation
                       (Item.Windows (Which), Models.Failed,
                        "The Parakeet model is not downloaded (Settings)");
                  end if;
               else
                  Speech.Jobs.Start (Which);
                  Windows.Set_Dictation
                    (Item.Windows (Which), Models.Preparing);
               end if;
            end;
         when Speech.Jobs.Starting | Speech.Jobs.Listening =>
            Speech.Jobs.Stop (Which);
            Windows.Set_Dictation
              (Item.Windows (Which), Models.Transcribing);
         when Speech.Jobs.Finishing =>
            null;
      end case;
   end Toggle_Dictation;

   procedure Choose_Origin
     (Item : in out Session; Which : Items.Slot; To : Items.Origins) is
   begin
      Canvas_VM.Choose_Origin (Item.Canvas_Model.Model, Which, To);
      Windows.Show (Item.Windows (Which));
      if To = Items.Remote then
         Windows.Focus_Text (Item.Windows (Which));
      end if;
   end Choose_Origin;

   procedure File_Picked (Item : in out Session; Which : Items.Slot; Path : String) is
   begin
      if Models.Details (Item.Models (Which)).Origin /= Items.Local then
         Choose_Origin (Item, Which, Items.Local);
      end if;
      Models.Set_Link (Item.Models (Which), Path);
      Opening.Start_Capture (Item, Which);
   end File_Picked;

   function Count (Item : Session) return Natural is (Canvas_VM.Count (Item.Canvas_Model.Model));

   procedure Order (Item : Session; Slots : in out Slot_List) is
   begin
      Canvas_VM.Order (Item.Canvas_Model.Model, Slots);
   end Order;

   function Nth (Item : Session; Row : Positive) return Items.Slot is
      Slots : Slot_List;
   begin
      Order (Item, Slots);
      return Slots (Row);
   end Nth;

   procedure Show_Dock (Item : in out Session) is
      Any : Boolean := False;
   begin
      for Each of Item.Models loop
         if Models.Is_Assigned (Each)
           and then Models.Details (Each).State = Items.Minimized
           and then View_Mode (Item) = Canvas
         then
            Any := True;
         end if;
      end loop;
      if Any /= Widgets.Is_Visible (Item.Dock.Dock_Panel) then
         Widgets.Set_Visible (Item.Dock.Dock_Panel, Any);
         Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      end if;
   end Show_Dock;

   procedure Enter (Item : in out Session) is
      Model : Canvas_VM.View_Model renames Item.Canvas_Model.Model;
      Found : Boolean;
   begin
      Canvas_VM.Stored.Set_Project (Item.Canvas_Model.Library, Open_Key (Item));
      Canvas_VM.Enter (Model);
      Placement.Report_Camera (Item);
      for I in 1 .. Item.Models.Count loop
         if Models.Is_Assigned (Item.Models (I)) then
            Windows.Assigned (Item.Windows (I));
            Recognition.Recognize_Kept (Item, I);
            Windows.Show (Item.Windows (I));
         end if;
      end loop;
      --  The pictures of those shown first, then the others.
      for Shown in reverse Boolean loop
         for I in 1 .. Item.Models.Count loop
            if Models.Is_Assigned (Item.Models (I))
              and then (Models.Details (Item.Models (I)).State = Items.Open) = Shown
            then
               Windows.Warm (Item.Windows (I));
            end if;
         end loop;
      end loop;
      Canvas_VM.Restore_View (Model, Found);
      if not Found then
         Canvas_VM.Centre_On_Items (Model);
      end if;
      Placement.Follow (Item);
      Placement.Place_All (Item);
      Show_Dock (Item);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      --  The tray, in the middle of the canvas as it is laid out now.
      Sync (Item);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      Links.Enter (Item);
      Links.Update (Item);
   end Enter;

   procedure Save_All (Item : in out Session) is
   begin
      for Which in 1 .. Item.Models.Count loop
         if Models.Is_Assigned (Item.Models (Which)) then
            Windows.Report (Item.Windows (Which));
         end if;
      end loop;
      Canvas_VM.Flush_All (Item.Canvas_Model.Model, 0, Force => True);
      Placement.Report_Camera (Item);
      Canvas_VM.Save_View (Item.Canvas_Model.Model);
   end Save_All;

   procedure Leave (Item : in out Session) is
   begin
      Save_All (Item);
      Links.Leave (Item);
      for Which in 1 .. Item.Windows.Count loop
         if Windows.Is_Assigned (Item.Windows (Which)) then
            Windows.Release (Item.Windows (Which));
            Webshot.Reset (Which);
            Vision.Jobs.Reset (Which);
            Speech.Jobs.Reset (Which);
            if Item.Nav.Fetch_Slot = Which then
               Downloads.Cancel;
            end if;
         end if;
      end loop;
      Canvas_VM.Leave (Item.Canvas_Model.Model);
      Widgets.Set_Visible (Item.Dock.Dock_Panel, False);
   end Leave;

   procedure Make
     (Item : in out Session;
      Name : String;
      Kind : Items.Kinds;
      Made : out Natural);
   --  Add, saying which window it is in: 0 if none was free.

   procedure Add
     (Item : in out Session;
      Name : String := Untitled;
      Kind : Items.Kinds := Items.Note)
   is
      Made : Natural;
   begin
      Make (Item, Name, Kind, Made);
   end Add;

   procedure Link_Items (Item : in out Session; From, To : Items.Slot) is
   begin
      Canvas_VM.Join (Item.Canvas_Model.Model, From, To, Items.Links.Right, Items.Links.Left);
   end Link_Items;
   --  Draw a line from the right of one item's window to the left of the other's.

   procedure Add_Linked_Source (Item : in out Session; To : Items.Slot) is
      Made : Natural;
   begin
      Make (Item, Untitled_Source, Items.Source, Made);
      if Made /= 0 then
         Link_Items (Item, To, Made);
      end if;
   end Add_Linked_Source;

   procedure Add_Found_Source
     (Item      : in out Session;
      Linked_To : Natural;
      Page_Title, Address, File : String;
      Added     : out Boolean;
      Document  : Boolean := False)
   is
      Made : Natural;
      Name : constant String := (if Page_Title = "" then Address else Page_Title);
   begin
      Made := 0;
      Added := False;
      Make (Item, Name, Items.Source, Made);
      if Made = 0 then
         return;
      end if;
      Added := True;
      declare
         Key  : constant Items.Id := Models.Details (Item.Models (Made)).Key;
         Time : constant Projects.Seconds := Basics.Epoch_Now (Item);
         Kept : constant String :=
           (if Document then Items.Sources.Document_File (Item.Nav.Store, Open_Key (Item), Key, "pdf")
            else Items.Sources.Image_File (Item.Nav.Store, Open_Key (Item), Key));
      begin
         Choose_Origin (Item, Made, Items.Remote);
         Models.Set_Link (Item.Models (Made), Address);
         Items.Sources.Make_Image_Folder (Item.Nav.Store, Open_Key (Item));
         if Ada.Directories.Exists (Kept) then
            Ada.Directories.Delete_File (Kept);  --  of an item that was, with this key
         end if;
         begin
            Ada.Directories.Rename (File, Kept);
         exception
            when Ada.Directories.Use_Error | Ada.Directories.Name_Error =>
               Items.Sources.Copy_File (File, Kept);
               Ada.Directories.Delete_File (File);
         end;
         if Document then
            --  Counted and drawn as a PDF fetched for the source is.
            Opening.Open_Fetched (Item, Made, "pdf");
         else
            Items.Sources.Set_Captured (Item.Nav.Store, Key, Time);
            Models.Set_Capture (Item.Models (Made), Models.Ready, Kept, At_Time => Time);
            Writing.Picture_Taken (Item, Made);
            Recognition.Start_Recognition (Item, Made);
         end if;
         if Linked_To /= 0 then
            Link_Items (Item, Linked_To, Made);
         end if;
         Projects.Touch (Item.Nav.Store, Open_Key (Item));
      end;
   exception
      when Ada.Directories.Use_Error | Ada.Directories.Name_Error =>
         Models.Set_Capture (Item.Models (Made), Models.Failed, Detail => "the picture could not be kept");
   end Add_Found_Source;

   procedure Make
     (Item : in out Session;
      Name : String;
      Kind : Items.Kinds;
      Made : out Natural)
   is
      Free : Items.Slot;
   begin
      --  Where the canvas is looked at from is where it is made.
      Placement.Report_Camera (Item);
      Canvas_VM.Add (Item.Canvas_Model.Model, Name, Kind, Free);
      Made := Free;
      Windows.Assigned (Item.Windows (Free));
      Windows.Place (Item.Windows (Free));
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
      if View_Mode (Item) = Canvas then
         Windows.Focus_Text (Item.Windows (Free));
      end if;
      Writing.Added (Item, Free);
   end Make;

   procedure Set_State
     (Item : in out Session; Which : Items.Slot; To : Items.States) is
      What : constant Canvas_VM.Command :=
        (case To is
            when Items.Open      => Canvas_VM.Open_Item,
            when Items.Minimized => Canvas_VM.Minimize_Item,
            when Items.Closed    => Canvas_VM.Close_Item);
   begin
      if Canvas_VM.Can_Execute (Item.Canvas_Model.Model, What, Which) then
         Canvas_VM.Execute (Item.Canvas_Model.Model, What, Which);
      end if;
      Windows.Show (Item.Windows (Which));
      Windows.Warm (Item.Windows (Which));
      Windows.Place (Item.Windows (Which));
      Show_Dock (Item);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Set_State;

   procedure Reveal (Item : in out Session; Which : Items.Slot) is
   begin
      Canvas_VM.Execute (Item.Canvas_Model.Model, Canvas_VM.Show_Item, Which);
      Windows.Show (Item.Windows (Which));
      Windows.Warm (Item.Windows (Which));
      Show_Dock (Item);
      Sync (Item);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Reveal;

   procedure Remove (Item : in out Session; Which : Items.Slot) is
   begin
      Writing.Removed (Item, Which);
      if Item.Nav.Fetch_Slot = Which then
         Downloads.Cancel;
      end if;
      Webshot.Reset (Which);
      Vision.Jobs.Reset (Which);
      Speech.Jobs.Reset (Which);
      Windows.Release (Item.Windows (Which));
      Canvas_VM.Execute (Item.Canvas_Model.Model, Canvas_VM.Remove_Item, Which);
      Show_Dock (Item);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Remove;

   procedure Window_Asked
     (Item   : in out Session;
      Which  : Items.Slot;
      Action : Windows.Actions);
   --  What a window's buttons asked for.

   procedure Window_Asked
     (Item   : in out Session;
      Which  : Items.Slot;
      Action : Windows.Actions) is
   begin
      if not Takes_Gestures (Item) then
         return;
      end if;
      case Action is
         when Windows.None =>
            null;
         when Windows.Minimize =>
            Set_State (Item, Which, Items.Minimized);
         when Windows.Restore =>
            Set_State (Item, Which, Items.Open);
         when Windows.Close =>
            Set_State (Item, Which, Items.Closed);
         when Windows.Capture =>
            Opening.Start_Capture (Item, Which);
         when Windows.Speak =>
            Toggle_Dictation (Item, Which);
         when Windows.Link_To_Outline =>
            Section_Links.Open (Item, Which);
         when Windows.Choose_Link =>
            Choose_Origin (Item, Which, Items.Remote);
         when Windows.Choose_File =>
            Opening.Pick_File (Item, Which);
         when Windows.Moved =>
            Canvas_VM.Move_Item
              (Item.Canvas_Model.Model, Which, Windows.Gesture (Item.Windows (Which)).Across,
               Windows.Gesture (Item.Windows (Which)).Down);
            Windows.Show (Item.Windows (Which));
         when Windows.Sized =>
            Canvas_VM.Resize_Item
              (Item.Canvas_Model.Model, Which, Windows.Gesture (Item.Windows (Which)).Across,
               Windows.Gesture (Item.Windows (Which)).Down, Windows.Gesture (Item.Windows (Which)).Still);
            Windows.Show (Item.Windows (Which));
         when Windows.Previous_Page =>
            Recognition.Turn_Page (Item, Which, -1);
         when Windows.Next_Page =>
            Recognition.Turn_Page (Item, Which, 1);
      end case;
   end Window_Asked;

   procedure Listen (Item : in out Session; Which : Items.Slot) is
   begin
      Window_Events.On (Item.Windows (Which), Which, Item'Unchecked_Access, Window_Asked'Access);
   end Listen;

   procedure Pressed (Item : in out Session; X, Y : Float) is
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
   begin
      for Which in 1 .. Item.Models.Count loop
         if Models.Is_Assigned (Item.Models (Which))
           and then Models.Tool (Item.Models (Which)) /= Models.Pointer
         then
            declare
               Box : constant Items.Frame := Windows.Box (Item.Windows (Which));
            begin
               if X * Pixels not in Box.Left .. Box.Left + Box.Width
                 or else Y * Pixels not in Box.Top .. Box.Top + Box.Height
               then
                  Canvas_VM.Put_Tool_Away (Item.Canvas_Model.Model, Which);
                  Windows.Show (Item.Windows (Which));
               end if;
            end;
         end if;
      end loop;
   end Pressed;

   procedure Sync (Item : in out Session) is
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Middle : constant Float :=
        Float'Rounding
          ((Widgets.Width_Of (Content_Panel (Item).all)
            - Style.Tray_Width * Pixels) / 2.0);
   begin
      --  The tray of tools, in the middle of the foot.
      if Middle /= Item.Dock.Tray_Left then
         Item.Dock.Tray_Left := Middle;
         Pomarine.Widgets.Layouts.Set_Layout
           (Tray_Panel (Item).all, Position => (Left => Middle, others => <>),
            Unit => Pomarine.Widgets.Layouts.Device_Pixels);
      end if;
      Placement.Follow (Item);
      if Pomarine.View_Models.Changed
           (Item.Canvas_Model.Seen_Raised, Canvas_VM.Raised_Version (Item.Canvas_Model.Model))
        and then Canvas_VM.Raised (Item.Canvas_Model.Model) /= 0
      then
         Windows.Bring_To_Front (Item.Windows (Canvas_VM.Raised (Item.Canvas_Model.Model)));
      end if;
   end Sync;

   function Source_Ink
     (Item : Session; Which : Items.Slot) return Pomarine.Themes.Slot is
     (Style.Source_Ink (Canvas_VM.Source_Rank (Item.Canvas_Model.Model, Which)));

   procedure Update (Item : in out Session; Now : Pomarine.Events.Milliseconds) is
   begin
      Sync (Item);
      for Each of Item.Windows loop
         if Windows.Is_Assigned (Each) then
            if Takes_Gestures (Item) then
               Windows.Update (Each);
            end if;
            Windows.Show (Each);
         end if;
      end loop;
      for Which in 1 .. Item.Windows.Count loop
         if Windows.Is_Assigned (Item.Windows (Which))
           and then Models.Details (Item.Models (Which)).Kind = Items.Source
         then
            Windows.Set_Tag (Item.Windows (Which), Source_Ink (Item, Which));
         end if;
      end loop;
      Polling.Poll_Captures (Item);
      Polling.Poll_Dictation (Item);
      Writing.Update (Item);
      for Which in 1 .. Item.Models.Count loop
         if Models.Is_Assigned (Item.Models (Which)) then
            Windows.Report (Item.Windows (Which));
         end if;
      end loop;
      Canvas_VM.Flush_All (Item.Canvas_Model.Model, Now, Force => False);
      Links.Update (Item);
   end Update;

end View.Canvas_Items;
