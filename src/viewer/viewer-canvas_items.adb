with Items.Links;
with Items.Marks;
with Items.Records;
with Items.Sources;
with Items.Windows.Callbacks;
with Ada.Strings.Unbounded;
with Downloads;
with Preferences;
with Pomarine.Widgets;
with Pomarine.Widgets.Canvases;
with Pomarine.Widgets.Pictures;
with Speech.Jobs;
with Speech.Models;
with Viewer.Gestures;
with Viewer.Links;
with Viewer.Section_Links;
with Viewer.Style;
with Viewer.Writing;
with Vision.Jobs;
with Webshot;
with Pomarine.Widgets.Layouts;
with Viewer.Canvas_Items.Basics;
with Viewer.Canvas_Items.Opening;
with Viewer.Canvas_Items.Placement;
with Viewer.Canvas_Items.Polling;
with Viewer.Canvas_Items.Recognition;

package body Viewer.Canvas_Items is

   package Widgets renames Pomarine.Widgets;
   package Canvases renames Pomarine.Widgets.Canvases;
   package Windows renames Items.Windows;
   package Window_Events is new Items.Windows.Callbacks (Session);

   use type Items.States;
   use type Preferences.Speech_Models;
   use type Pomarine.Widgets.Pictures.Tools;
   use type Items.Id;
   use type Items.Kinds;
   use type Webshot.States;
   use type Items.Origins;
   use type Vision.Jobs.States;
   use type Speech.Jobs.States;
   use type Windows.Dictations;

   pragma Assert (Webshot.Slot_Count = Items.Capacity);
   pragma Assert (Vision.Jobs.Slot_Count = Items.Capacity);
   pragma Assert (Speech.Jobs.Slot_Count = Items.Capacity);

   Cascade_Step  : constant Float := 24.0;

   Cascade_Count : constant := 6;
   --  Each new item is put this far down and right of the last, for so
   --  many, so that they are not all on top of each other.

   function Busy (Item : Session) return Boolean is
     (Capturing (Item)
      or else (for some Which in Items.Slot =>
                 Basics.Is_Source (Item, Which)
                 and then Vision.Jobs.State (Which) = Vision.Jobs.Working));

   function Capturing (Item : Session) return Boolean is
   begin
      if Item.Nav.Fetch_Slot /= 0 then
         return True;
      end if;
      for Which in Items.Slot loop
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
                   (Ada.Strings.Unbounded.To_String (Item.Prefs.Config_Dir));
            begin
               if Item.Prefs.Speech_Choice = Preferences.Parakeet then
                  if Speech.Models.Present (Model_Directory) then
                     Speech.Jobs.Start
                       (Which, Speech.Jobs.Model, Model_Directory);
                     Windows.Set_Dictation
                       (Item.Windows (Which), Windows.Preparing);
                  else
                     Windows.Set_Dictation
                       (Item.Windows (Which), Windows.Failed,
                        "The Parakeet model is not downloaded (Settings)");
                  end if;
               else
                  Speech.Jobs.Start (Which);
                  Windows.Set_Dictation
                    (Item.Windows (Which), Windows.Preparing);
               end if;
            end;
         when Speech.Jobs.Starting | Speech.Jobs.Listening =>
            Speech.Jobs.Stop (Which);
            Windows.Set_Dictation
              (Item.Windows (Which), Windows.Transcribing);
         when Speech.Jobs.Finishing =>
            null;
      end case;
   end Toggle_Dictation;

   procedure Choose_Origin
     (Item : in out Session; Which : Items.Slot; To : Items.Origins) is
   begin
      Items.Sources.Set_Origin
        (Item.Nav.Store, Windows.Details (Item.Windows (Which)).Key, To);
      Windows.Set_Origin (Item.Windows (Which), To);
      if To = Items.Remote then
         Windows.Focus_Text (Item.Windows (Which));
      end if;
      Projects.Touch (Item.Nav.Store, Item.Opened.Current);
   end Choose_Origin;

   procedure File_Picked (Item : in out Session; Which : Items.Slot; Path : String) is
   begin
      if Windows.Details (Item.Windows (Which)).Origin /= Items.Local then
         Choose_Origin (Item, Which, Items.Local);
      end if;
      Windows.Set_Link (Item.Windows (Which), Path);
      Opening.Start_Capture (Item, Which);
   end File_Picked;

   function Count (Item : Session) return Natural is
      Found : Natural := 0;
   begin
      for Each of Item.Windows loop
         if Windows.Is_Assigned (Each) then
            Found := Found + 1;
         end if;
      end loop;
      return Found;
   end Count;

   procedure Order
     (Item : Session; Slots : out Slot_List; Found : out Natural) is
   begin
      Found := 0;
      Slots := [others => Items.Slot'First];
      for Which in Items.Slot loop
         if Windows.Is_Assigned (Item.Windows (Which)) then
            --  Inserted among those before it by when they were made,
            --  which the ids give.
            declare
               Key : constant Items.Id :=
                 Windows.Details (Item.Windows (Which)).Key;
               At_Index : Natural := Found;
            begin
               while At_Index >= 1
                 and then Windows.Details
                            (Item.Windows
                               (Slots (Slots'First + At_Index - 1))).Key > Key
               loop
                  Slots (Slots'First + At_Index) :=
                    Slots (Slots'First + At_Index - 1);
                  At_Index := At_Index - 1;
               end loop;
               Slots (Slots'First + At_Index) := Which;
               Found := Found + 1;
            end;
         end if;
      end loop;
   end Order;

   function Nth (Item : Session; Row : Positive) return Items.Slot is
      Slots : Slot_List (1 .. Items.Capacity);
      Found : Natural;
   begin
      Order (Item, Slots, Found);
      return Slots (Row);
   end Nth;

   procedure Show_Dock (Item : in out Session) is
      Any : Boolean := False;
   begin
      for Each of Item.Windows loop
         if Windows.Is_Assigned (Each)
           and then Windows.Details (Each).State = Items.Minimized
           and then Item.Toolbar.Mode = Canvas
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
      Found    : Items.Info_List;
      Restored : Boolean;
   begin
      Items.Records.Load (Item.Nav.Store, Item.Opened.Current, Found);
      for I in 1 .. Found.Count loop
         Windows.Assign
           (Item.Windows (I), Found.Items (I),
            Items.Records.Stored_Content (Item.Nav.Store, Found.Items (I).Key),
            Items.Sources.Shown_File
              (Item.Nav.Store, Item.Opened.Current, Found.Items (I)));
         Recognition.Recognize_Kept (Item, I);
         if Found.Items (I).Kind = Items.Source then
            declare
               Kept : Items.Marks.Mark_List;
            begin
               Items.Marks.Load_Marks
                 (Item.Nav.Store, Found.Items (I).Key, Kept);
               Windows.Set_Marks (Item.Windows (I), Kept);
            end;
         end if;
      end loop;
      --  The pictures of those shown first, then the others.
      for Shown in reverse Boolean loop
         for I in 1 .. Found.Count loop
            if (Found.Items (I).State = Items.Open) = Shown then
               Windows.Warm (Item.Windows (I));
            end if;
         end loop;
      end loop;
      Placement.Restore_View (Item, Restored);
      if not Restored then
         Placement.Centre_On_Visible (Item);
      end if;
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
      Wrote, Any : Boolean := False;
   begin
      for Each of Item.Windows loop
         if Windows.Is_Assigned (Each) then
            Windows.Flush
              (Each, Item.Nav.Store, 0, Force => True, Wrote => Wrote);
            Any := Any or else Wrote;
         end if;
      end loop;
      if Any then
         Basics.Touch (Item);
      end if;
      Placement.Save_View (Item);
   end Save_All;

   procedure Leave (Item : in out Session) is
   begin
      Save_All (Item);
      Links.Leave (Item);
      for Which in Items.Slot loop
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

   procedure Add_Linked_Source (Item : in out Session; To : Items.Slot) is
      Made  : Natural;
      Added : Boolean;
   begin
      Make (Item, Untitled_Source, Items.Source, Made);
      if Made /= 0 then
         Items.Links.Add_Link
           (Item.Nav.Store,
            (From      => Windows.Details (Item.Windows (To)).Key,
             To        => Windows.Details (Item.Windows (Made)).Key,
             From_Side => Items.Links.Right,
             To_Side   => Items.Links.Left,
             others    => <>),
            Added);
         if Added then
            Links.Reload (Item);
         end if;
      end if;
   end Add_Linked_Source;

   procedure Make
     (Item : in out Session;
      Name : String;
      Kind : Items.Kinds;
      Made : out Natural)
   is
      View   : Pomarine.Widgets.Canvases.Canvas renames Item.Canvas_View;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Before : constant Natural := Count (Item);
      Step   : constant Float :=
        Float (Before mod Cascade_Count) * Cascade_Step;
      Middle_X : constant Float :=
        Canvases.To_Canvas_X (View, Widgets.Width_Of (View) / Pixels / 2.0);
      Middle_Y : constant Float :=
        Canvases.To_Canvas_Y (View, Widgets.Height_Of (View) / Pixels / 2.0);
      Wide   : constant Float :=
        (if Kind = Items.Source then Items.Source_Width
         else Items.Default_Width);
      Where  : constant Items.Frame :=
        (Left   => Middle_X - Wide / 2.0 + Step,
         Top    => Middle_Y - Items.Default_Height / 2.0 + Step,
         Width  => Wide,
         Height => Items.Default_Height);
      Free   : Natural := 0;
   begin
      for Which in Items.Slot loop
         if Free = 0 and then not Windows.Is_Assigned (Item.Windows (Which))
         then
            Free := Which;
         end if;
      end loop;
      Made := Free;
      if Free = 0 then
         return;
      end if;
      declare
         Key : constant Items.Id :=
           Items.Records.Create
             (Item.Nav.Store, Item.Opened.Current, Name, Where, Kind => Kind);
      begin
         Windows.Assign
           (Item.Windows (Free),
            (Key   => Key,
             Title => Projects.Titles.To_Bounded_String (Name),
             Where => Where,
             State => Items.Open,
             Kind  => Kind,
             Captured_At => 0,
             Zoom  => 1.0,
             Scroll => 0.0,
             Scroll_Across => 0.0,
             Recognized_At => 0,
             Origin => (if Kind = Items.Source then Items.Unchosen else Items.Remote),
             Page => 0, Page_Count => 0,
             Document => Items.Extensions.Null_Bounded_String),
            "");
         Windows.Place
           (Item.Windows (Free),
            Canvases.Zoom (View), Canvases.Origin_X (View),
            Canvases.Origin_Y (View));
         Basics.Touch (Item);
         Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
         if Item.Toolbar.Mode = Canvas then
            Windows.Focus_Text (Item.Windows (Free));
         end if;
         Writing.Added (Item, Free);
      end;
   end Make;

   procedure Set_State
     (Item : in out Session; Which : Items.Slot; To : Items.States) is
   begin
      Windows.Set_State (Item.Windows (Which), To);
      Windows.Warm (Item.Windows (Which));
      Items.Records.Set_State
        (Item.Nav.Store, Windows.Details (Item.Windows (Which)).Key, To);
      Windows.Place
        (Item.Windows (Which),
         Item.Nav.Shown_Zoom, Item.Nav.Shown_X, Item.Nav.Shown_Y);
      Basics.Touch (Item);
      Show_Dock (Item);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Set_State;

   procedure Reveal (Item : in out Session; Which : Items.Slot) is
      Where  : constant Items.Frame :=
        Windows.Details (Item.Windows (Which)).Where;
   begin
      if Windows.Details (Item.Windows (Which)).State /= Items.Open then
         Set_State (Item, Which, Items.Open);
      end if;
      Placement.Centre_On (Item, Where.Left + Where.Width / 2.0,
                 Where.Top + Where.Height / 2.0);
      Windows.Bring_To_Front (Item.Windows (Which));
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
      Items.Records.Delete
        (Item.Nav.Store, Windows.Details (Item.Windows (Which)).Key);
      Windows.Release (Item.Windows (Which));
      Links.Reload (Item);
      Basics.Touch (Item);
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
      if not Gestures.Active (Item) then
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
         when Windows.Previous_Page =>
            Recognition.Turn_Page (Item, Which, -1);
         when Windows.Next_Page =>
            Recognition.Turn_Page (Item, Which, 1);
      end case;
   end Window_Asked;

   procedure Listen (Item : in out Session) is
   begin
      for Which in Items.Slot loop
         Window_Events.On (Item.Windows (Which), Which, Item'Unchecked_Access, Window_Asked'Access);
      end loop;
   end Listen;

   procedure Pressed (Item : in out Session; X, Y : Float) is
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
   begin
      for Each of Item.Windows loop
         if Windows.Is_Assigned (Each)
           and then Windows.Tool (Each) /= Pomarine.Widgets.Pictures.Pointer
         then
            declare
               Box : constant Items.Frame := Windows.Box (Each);
            begin
               if X * Pixels not in Box.Left .. Box.Left + Box.Width
                 or else Y * Pixels not in Box.Top .. Box.Top + Box.Height
               then
                  Windows.Select_Tool (Each, Pomarine.Widgets.Pictures.Pointer);
               end if;
            end;
         end if;
      end loop;
   end Pressed;

   procedure Sync (Item : in out Session) is
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Middle : constant Float :=
        Float'Rounding
          ((Widgets.Width_Of (Item.Toolbar.Content_Panel)
            - Style.Tray_Width * Pixels) / 2.0);
   begin
      --  The tray of tools, in the middle of the foot.
      if Middle /= Item.Dock.Tray_Left then
         Item.Dock.Tray_Left := Middle;
         Pomarine.Widgets.Layouts.Set_Layout
           (Item.Dock.Tools, Position => (Left => Middle, others => <>),
            Unit => Pomarine.Widgets.Layouts.Device_Pixels);
      end if;
      if Canvases.Zoom (Item.Canvas_View) /= Item.Nav.Shown_Zoom
        or else Canvases.Origin_X (Item.Canvas_View) /= Item.Nav.Shown_X
        or else Canvases.Origin_Y (Item.Canvas_View) /= Item.Nav.Shown_Y
      then
         Placement.Place_All (Item);
      end if;
   end Sync;

   function Source_Ink
     (Item : Session; Which : Items.Slot) return Pomarine.Themes.Slot
   is
      Key  : constant Items.Id := Windows.Details (Item.Windows (Which)).Key;
      Rank : Natural := 0;
   begin
      for Each of Item.Windows loop
         if Windows.Is_Assigned (Each)
           and then Windows.Details (Each).Kind = Items.Source
           and then Windows.Details (Each).Key <= Key
         then
            Rank := Rank + 1;
         end if;
      end loop;
      return Style.Source_Ink (Rank);
   end Source_Ink;

   procedure Update (Item : in out Session; Now : SDL3.Events.Milliseconds) is
      Wrote, Any : Boolean := False;
   begin
      Sync (Item);
      if Gestures.Active (Item) then
         for Each of Item.Windows loop
            if Windows.Is_Assigned (Each) then
               Windows.Update (Each);
            end if;
         end loop;
      end if;
      for Which in Items.Slot loop
         if Windows.Is_Assigned (Item.Windows (Which))
           and then Windows.Details (Item.Windows (Which)).Kind = Items.Source
         then
            Windows.Set_Tag (Item.Windows (Which), Source_Ink (Item, Which));
         end if;
      end loop;
      Polling.Poll_Captures (Item);
      Polling.Poll_Dictation (Item);
      Writing.Update (Item);
      for Each of Item.Windows loop
         if Windows.Is_Assigned (Each) then
            Windows.Flush
              (Each, Item.Nav.Store, Now, Force => False, Wrote => Wrote);
            Any := Any or else Wrote;
         end if;
      end loop;
      if Any then
         Basics.Touch (Item);
      end if;
      Links.Update (Item);
   end Update;

end Viewer.Canvas_Items;
