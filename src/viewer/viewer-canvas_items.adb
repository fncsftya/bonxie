with Items.Links;
with Items.Marks;
with Items.Records;
with Items.Sources;
with Items.Windows.Callbacks;
with Items.Words;
with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Preferences;
with Pomarine.Widgets;
with Pomarine.Widgets.Canvases;
with Pomarine.Widgets.Pictures;
with Speech.Jobs;
with Speech.Models;
with Viewer.Gestures;
with Viewer.Links;
with Viewer.Style;
with Viewer.Writing;
with Vision.Jobs;
with Webshot;
with Pomarine.Widgets.Layouts;

package body Viewer.Canvas_Items is

   package Widgets renames Pomarine.Widgets;
   package Canvases renames Pomarine.Widgets.Canvases;
   package Windows renames Items.Windows;
   package Window_Events is new Items.Windows.Callbacks (Session);

   use type Items.States;
   use type Preferences.Speech_Models;
   use type Pomarine.Widgets.Pictures.Tools;
   use type Items.Id;
   use type Projects.Id;
   use type Items.Kinds;
   use type Webshot.States;
   use type Vision.Jobs.States;
   use type Speech.Jobs.States;
   use type Windows.Dictations;

   Cascade_Step  : constant Float := 24.0;
   Cascade_Count : constant := 6;
   --  Each new item is put this far down and right of the last, for so
   --  many, so that they are not all on top of each other.

   pragma Assert (Webshot.Slot_Count = Items.Capacity);
   pragma Assert (Vision.Jobs.Slot_Count = Items.Capacity);
   pragma Assert (Speech.Jobs.Slot_Count = Items.Capacity);
   --  A source's picture is taken, and its text found, and a note is
   --  dictated into, in the slot of its window.

   function Epoch_Now (Item : Session) return Projects.Seconds is
     (if Item.Nav.Pinned_Time > 0
      then Item.Nav.Pinned_Time else Projects.Seconds
        (Ada.Calendar."-"
           (Ada.Calendar.Clock,
            Ada.Calendar.Formatting.Time_Of
              (1970, 1, 1, Time_Zone => 0))));
   --  As SQLite's unixepoch.

   function Is_Source (Item : Session; Which : Items.Slot) return Boolean is
     (Windows.Is_Assigned (Item.Windows (Which))
      and then Windows.Details (Item.Windows (Which)).Kind = Items.Source);

   function Busy (Item : Session) return Boolean is
     (Capturing (Item)
      or else (for some Which in Items.Slot =>
                 Is_Source (Item, Which)
                 and then Vision.Jobs.State (Which) = Vision.Jobs.Working));

   function Capturing (Item : Session) return Boolean is
   begin
      for Which in Items.Slot loop
         if Windows.Is_Assigned (Item.Windows (Which))
           and then Speech.Jobs.State (Which)
                    in Speech.Jobs.Starting | Speech.Jobs.Listening
                       | Speech.Jobs.Finishing
         then
            return True;
         end if;
         if Is_Source (Item, Which)
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

   procedure Poll_Dictation (Item : in out Session);
   --  Show how dictating stands, and put in a note what has been heard.

   procedure Poll_Dictation (Item : in out Session) is
      Heard : Speech.Transcript;
   begin
      for Which in Items.Slot loop
         if Windows.Is_Assigned (Item.Windows (Which))
           and then Windows.Details (Item.Windows (Which)).Kind = Items.Note
         then
            declare
               Each : Windows.Window renames Item.Windows (Which);
               procedure Show (To : Windows.Dictations) is
               begin
                  if Windows.Dictation (Each) /= To then
                     Windows.Set_Dictation (Each, To);
                  end if;
               end Show;
            begin
               case Speech.Jobs.State (Which) is
                  when Speech.Jobs.Idle =>
                     null;
                  when Speech.Jobs.Starting =>
                     Show (Windows.Preparing);
                  when Speech.Jobs.Listening =>
                     Show (Windows.Listening);
                     Windows.Set_Level (Each, Speech.Jobs.Loudness (Which));
                     Speech.Jobs.Heard_So_Far (Which, Heard);
                     Windows.Set_Live_Dictation
                       (Each, Speech.Image (Heard), Heard.Settled);
                  when Speech.Jobs.Finishing =>
                     Show (Windows.Transcribing);
                  when Speech.Jobs.Done =>
                     Speech.Jobs.Take (Which, Heard);
                     Windows.Set_Dictation (Each, Windows.Silent);
                     Windows.Add_Dictation (Each, Speech.Image (Heard));
                  when Speech.Jobs.Failed =>
                     Windows.Set_Dictation
                       (Each, Windows.Failed, Speech.Jobs.Message (Which));
                     Speech.Jobs.Reset (Which);
               end case;
            end;
         end if;
      end loop;
   end Poll_Dictation;

   function Link_Of (Typed : String) return String;
   --  What was typed, as a link: with https:// if it has no scheme.

   function Link_Of (Typed : String) return String is
      Trimmed : constant String :=
        Ada.Strings.Fixed.Trim (Typed, Ada.Strings.Both);
   begin
      return (if Trimmed = ""
                or else Ada.Strings.Fixed.Index (Trimmed, "://") > 0
              then Trimmed else "https://" & Trimmed);
   end Link_Of;

   procedure Start_Recognition (Item : in out Session; Which : Items.Slot);
   --  Begin to find the words in the source's picture, in the background,
   --  at the full size it was taken: they are what its window lets be
   --  selected.

   procedure Start_Recognition (Item : in out Session; Which : Items.Slot) is
      Key : constant Items.Id :=
        Windows.Details (Item.Windows (Which)).Key;
   begin
      Vision.Jobs.Reset (Which);
      Vision.Jobs.Start
        (Which,
         Items.Sources.Image_File
           (Item.Nav.Store, Item.Opened.Current, Key));
   end Start_Recognition;

   procedure Start_Capture (Item : in out Session; Which : Items.Slot);
   --  Begin to take the picture of the page the source's text links to.

   procedure Start_Capture (Item : in out Session; Which : Items.Slot) is
      Link : constant String :=
        Link_Of (Windows.Text (Item.Windows (Which)));
   begin
      if Webshot.State (Which) = Webshot.Working then
         return;
      end if;
      if Link = "" then
         Windows.Set_Capture
           (Item.Windows (Which), Windows.Failed, Detail => "no link");
         return;
      end if;
      Items.Sources.Make_Image_Folder (Item.Nav.Store, Item.Opened.Current);
      Vision.Jobs.Reset (Which);
      Webshot.Reset (Which);
      Webshot.Start
        (Which, Link,
         Items.Sources.Image_File
           (Item.Nav.Store, Item.Opened.Current,
            Windows.Details (Item.Windows (Which)).Key));
      Windows.Set_Capture (Item.Windows (Which), Windows.Busy);
   end Start_Capture;

   procedure Keep_Recognition (Item : in out Session; Which : Items.Slot);
   --  Take the words that have been found: write them to the database,
   --  and give them to the window.

   procedure Keep_Recognition (Item : in out Session; Which : Items.Slot) is
      Found : Vision.Result;
      Key   : constant Items.Id :=
        Windows.Details (Item.Windows (Which)).Key;
   begin
      Vision.Jobs.Take (Which, Found);
      Items.Words.Save_Words (Item.Nav.Store, Key, Found, Epoch_Now (Item));
      Windows.Set_Recognized (Item.Windows (Which), Found);
      Writing.Words_Found (Item, Which, Found);
   end Keep_Recognition;

   procedure Name_From_Page (Item : in out Session; Which : Items.Slot);
   --  Give a source still called Untitled_Source the title of its page.

   procedure Name_From_Page (Item : in out Session; Which : Items.Slot) is
      Raw  : String := Webshot.Page_Title (Which);
      Last : Natural := 0;
   begin
      for C of Raw loop
         if C in ASCII.NUL .. ' ' then
            C := ' ';
         end if;
      end loop;
      declare
         Page : constant String :=
           Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
      begin
         Last := Natural'Min (Page'Length, Projects.Title_Capacity);
         --  Not in the middle of a UTF-8 character.
         while Last > 0 and then Last < Page'Length
           and then Character'Pos (Page (Page'First + Last))
                    in 16#80# .. 16#BF#
         loop
            Last := Last - 1;
         end loop;
         if Last > 0
           and then Projects.Titles.To_String
                      (Windows.Details (Item.Windows (Which)).Title)
                    = Untitled_Source
         then
            Windows.Set_Title_Text
              (Item.Windows (Which),
               Page (Page'First .. Page'First + Last - 1));
         end if;
      end;
   end Name_From_Page;

   procedure Poll_Captures (Item : in out Session);
   --  Take the pictures that have been taken, and say what failed.

   procedure Poll_Captures (Item : in out Session) is
   begin
      for Which in Items.Slot loop
         if Is_Source (Item, Which) then
            case Webshot.State (Which) is
               when Webshot.Done =>
                  declare
                     Key  : constant Items.Id :=
                       Windows.Details (Item.Windows (Which)).Key;
                     Time : constant Projects.Seconds := Epoch_Now (Item);
                  begin
                     Name_From_Page (Item, Which);
                     Items.Sources.Set_Captured (Item.Nav.Store, Key, Time);
                     Windows.Set_Capture
                       (Item.Windows (Which), Windows.Ready,
                        Items.Sources.Image_File
                          (Item.Nav.Store, Item.Opened.Current, Key),
                        At_Time => Time);
                     Writing.Picture_Taken (Item, Which);
                     Projects.Touch (Item.Nav.Store, Item.Opened.Current);
                  end;
                  Webshot.Reset (Which);
                  Start_Recognition (Item, Which);
               when Webshot.Failed =>
                  Windows.Set_Capture
                    (Item.Windows (Which), Windows.Failed,
                     Detail => Webshot.Message (Which));
                  Webshot.Reset (Which);
               when Webshot.Working =>
                  Windows.Set_Progress
                    (Item.Windows (Which), Webshot.Progress (Which));
               when Webshot.Idle =>
                  null;
            end case;
            case Vision.Jobs.State (Which) is
               when Vision.Jobs.Done =>
                  Keep_Recognition (Item, Which);
               when Vision.Jobs.Failed =>
                  --  The picture still shows, just not as text.
                  Vision.Jobs.Reset (Which);
               when Vision.Jobs.Idle | Vision.Jobs.Working =>
                  null;
            end case;
         end if;
      end loop;
   end Poll_Captures;

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

   procedure Place_All (Item : in out Session);
   --  Put every window where the canvas has them.

   procedure Place_All (Item : in out Session) is
   begin
      Item.Nav.Shown_Zoom := Canvases.Zoom (Item.Canvas_View);
      Item.Nav.Shown_X := Canvases.Origin_X (Item.Canvas_View);
      Item.Nav.Shown_Y := Canvases.Origin_Y (Item.Canvas_View);
      for Each of Item.Windows loop
         Windows.Place (Each, Item.Nav.Shown_Zoom, Item.Nav.Shown_X,
                        Item.Nav.Shown_Y);
      end loop;
   end Place_All;

   procedure Touch (Item : in out Session);
   --  Say the project has been changed, so that it is listed first.

   procedure Touch (Item : in out Session) is
   begin
      Projects.Touch (Item.Nav.Store, Item.Opened.Current);
   end Touch;

   procedure Centre_On (Item : in out Session; X, Y : Float);
   --  Pan so that the canvas point X, Y is in the middle of the view.

   procedure Centre_On (Item : in out Session; X, Y : Float) is
      View   : Pomarine.Widgets.Canvases.Canvas renames Item.Canvas_View;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Zoom   : constant Float := Canvases.Zoom (View);
   begin
      Canvases.Pan_By
        (View,
         Widgets.Width_Of (View) / Pixels / 2.0
           - (Canvases.Origin_X (View) + X * Zoom),
         Widgets.Height_Of (View) / Pixels / 2.0
           - (Canvases.Origin_Y (View) + Y * Zoom));
   end Centre_On;

   procedure Centre_On_Visible (Item : in out Session);
   --  Centre the view on the middle of the bounding box of the windows
   --  that are open, if there are any.

   procedure Centre_On_Visible (Item : in out Session) is
      Any : Boolean := False;
      Left, Top, Right, Bottom : Float := 0.0;
   begin
      for Each of Item.Windows loop
         if Windows.Is_Assigned (Each)
           and then Windows.Details (Each).State = Items.Open
         then
            declare
               Where : constant Items.Frame := Windows.Details (Each).Where;
            begin
               if Any then
                  Left   := Float'Min (Left, Where.Left);
                  Top    := Float'Min (Top, Where.Top);
                  Right  := Float'Max (Right, Where.Left + Where.Width);
                  Bottom := Float'Max (Bottom, Where.Top + Where.Height);
               else
                  Any    := True;
                  Left   := Where.Left;
                  Top    := Where.Top;
                  Right  := Where.Left + Where.Width;
                  Bottom := Where.Top + Where.Height;
               end if;
            end;
         end if;
      end loop;
      if Any then
         pragma Assert (Right >= Left and then Bottom >= Top);
         Centre_On (Item, (Left + Right) / 2.0, (Top + Bottom) / 2.0);
      end if;
   end Centre_On_Visible;

   procedure Recognize_Kept (Item : in out Session; Which : Items.Slot);
   --  Of a source with a picture: show the words kept for it, or, if
   --  there are none (it was made before they were kept, or the program
   --  stopped before they were found), find them.

   procedure Recognize_Kept (Item : in out Session; Which : Items.Slot) is
      Key : constant Items.Id :=
        Windows.Details (Item.Windows (Which)).Key;
   begin
      if not Is_Source (Item, Which)
        or else Windows.Details (Item.Windows (Which)).Captured_At = 0
      then
         return;
      end if;
      if Items.Words.Has_Words (Item.Nav.Store, Key) then
         declare
            Found : Vision.Result;
         begin
            Items.Words.Load_Words (Item.Nav.Store, Key, Found);
            Windows.Set_Recognized (Item.Windows (Which), Found);
         end;
      elsif Ada.Directories.Exists
              (Items.Sources.Image_File
                 (Item.Nav.Store, Item.Opened.Current, Key))
      then
         Start_Recognition (Item, Which);
      end if;
   end Recognize_Kept;

   procedure Save_View (Item : in out Session);
   --  Keep how the canvas is seen, for the project to open at again.

   procedure Save_View (Item : in out Session) is
      View   : Pomarine.Widgets.Canvases.Canvas renames Item.Canvas_View;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
   begin
      if Item.Opened.Current /= 0 and then Widgets.Width_Of (View) > 0.0 then
         Projects.Set_View
           (Item.Nav.Store, Item.Opened.Current, Canvases.Zoom (View),
            Canvases.To_Canvas_X
              (View, Widgets.Width_Of (View) / Pixels / 2.0),
            Canvases.To_Canvas_Y
              (View, Widgets.Height_Of (View) / Pixels / 2.0));
      end if;
   end Save_View;

   procedure Restore_View
     (Item : in out Session; Found : out Boolean);
   --  Put the canvas as it was kept, if it was.

   procedure Restore_View
     (Item : in out Session; Found : out Boolean)
   is
      View   : Pomarine.Widgets.Canvases.Canvas renames Item.Canvas_View;
      Pixels : constant Float := Widgets.Density (Item.Root.Widgets);
      Zoom, X, Y : Float;
   begin
      Projects.Get_View (Item.Nav.Store, Item.Opened.Current, Found, Zoom, X,
                         Y);
      if Found then
         Canvases.Zoom_By
           (View,
            Float'Min (Canvases.Max_Zoom, Float'Max (Canvases.Min_Zoom, Zoom))
              / Canvases.Zoom (View),
            Widgets.Width_Of (View) / Pixels / 2.0,
            Widgets.Height_Of (View) / Pixels / 2.0);
         Centre_On (Item, X, Y);
      end if;
   end Restore_View;

   procedure Enter (Item : in out Session) is
      Found    : Items.Info_List;
      Restored : Boolean;
   begin
      Items.Records.Load (Item.Nav.Store, Item.Opened.Current, Found);
      for I in 1 .. Found.Count loop
         Windows.Assign
           (Item.Windows (I), Found.Items (I),
            Items.Records.Content (Item.Nav.Store, Found.Items (I).Key),
            Items.Sources.Image_File
              (Item.Nav.Store, Item.Opened.Current, Found.Items (I).Key));
         Recognize_Kept (Item, I);
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
      Restore_View (Item, Restored);
      if not Restored then
         Centre_On_Visible (Item);
      end if;
      Place_All (Item);
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
         Touch (Item);
      end if;
      Save_View (Item);
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
             Recognized_At => 0),
            "");
         Windows.Place
           (Item.Windows (Free),
            Canvases.Zoom (View), Canvases.Origin_X (View),
            Canvases.Origin_Y (View));
         Touch (Item);
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
      Touch (Item);
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
      Centre_On (Item, Where.Left + Where.Width / 2.0,
                 Where.Top + Where.Height / 2.0);
      Windows.Bring_To_Front (Item.Windows (Which));
      Sync (Item);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Reveal;

   procedure Remove (Item : in out Session; Which : Items.Slot) is
   begin
      Writing.Removed (Item, Which);
      Webshot.Reset (Which);
      Vision.Jobs.Reset (Which);
      Speech.Jobs.Reset (Which);
      Items.Records.Delete
        (Item.Nav.Store, Windows.Details (Item.Windows (Which)).Key);
      Windows.Release (Item.Windows (Which));
      Links.Reload (Item);
      Touch (Item);
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
            Start_Capture (Item, Which);
         when Windows.Speak =>
            Toggle_Dictation (Item, Which);
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
         Place_All (Item);
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
      Poll_Captures (Item);
      Poll_Dictation (Item);
      Writing.Update (Item);
      for Each of Item.Windows loop
         if Windows.Is_Assigned (Each) then
            Windows.Flush
              (Each, Item.Nav.Store, Now, Force => False, Wrote => Wrote);
            Any := Any or else Wrote;
         end if;
      end loop;
      if Any then
         Touch (Item);
      end if;
      Links.Update (Item);
   end Update;

end Viewer.Canvas_Items;
