with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Directories;
with Ada.Strings.Fixed;
with UI.Widgets;
with UI.Widgets.Canvases;
with UI.Widgets.Pictures;
with Vision.Jobs;
with Webshot;

package body Viewer.Canvas_Items is

   package Widgets renames UI.Widgets;
   package Canvases renames UI.Widgets.Canvases;
   package Windows renames Items.Windows;

   use type Items.States;
   use type UI.Widgets.Pictures.Tools;
   use type Items.Id;
   use type Projects.Id;
   use type Items.Kinds;
   use type Webshot.States;
   use type Vision.Jobs.States;

   Cascade_Step  : constant Float := 24.0;
   Cascade_Count : constant := 6;
   --  Each new item is put this far down and right of the last, for so
   --  many, so that they are not all on top of each other.

   pragma Assert (Webshot.Slot_Count = Items.Capacity);
   pragma Assert (Vision.Jobs.Slot_Count = Items.Capacity);
   --  A source's picture is taken, and its text found, in the slot of its
   --  window.

   function Epoch_Now (Item : Session) return Projects.Seconds is
     (if Item.Pinned_Time > 0 then Item.Pinned_Time else Projects.Seconds
        (Ada.Calendar."-"
           (Ada.Calendar.Clock,
            Ada.Calendar.Formatting.Time_Of
              (1970, 1, 1, Time_Zone => 0))));
   --  As SQLite's unixepoch.

   function Is_Source (Item : Session; Which : Items.Slot) return Boolean is
     (Windows.Is_Assigned (Item.Windows (Which))
      and then Windows.Details (Item.Windows (Which)).Kind = Items.Source);

   function Capturing (Item : Session) return Boolean is
   begin
      for Which in Items.Slot loop
         if Is_Source (Item, Which)
           and then (Webshot.State (Which) = Webshot.Working
                     or else Vision.Jobs.State (Which) = Vision.Jobs.Working)
         then
            return True;
         end if;
      end loop;
      return False;
   end Capturing;

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
        (Which, Items.Image_File (Item.Store, Item.Current, Key));
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
      Items.Make_Image_Folder (Item.Store, Item.Current);
      Vision.Jobs.Reset (Which);
      Webshot.Reset (Which);
      Webshot.Start
        (Which, Link,
         Items.Image_File
           (Item.Store, Item.Current,
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
      Items.Save_Words (Item.Store, Key, Found, Epoch_Now (Item));
      Windows.Set_Recognized (Item.Windows (Which), Found);
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
                     Items.Set_Captured (Item.Store, Key, Time);
                     Windows.Set_Capture
                       (Item.Windows (Which), Windows.Ready,
                        Items.Image_File (Item.Store, Item.Current, Key),
                        At_Time => Time);
                     Projects.Touch (Item.Store, Item.Current);
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

   procedure Show_Dock (Item : in out Session);
   --  Show the dock if any item is minimised.

   procedure Show_Dock (Item : in out Session) is
      Any : Boolean := False;
   begin
      for Each of Item.Windows loop
         if Windows.Is_Assigned (Each)
           and then Windows.Details (Each).State = Items.Minimized
         then
            Any := True;
         end if;
      end loop;
      if Any /= Widgets.Is_Visible (Item.Dock_Panel) then
         Widgets.Set_Visible (Item.Dock_Panel, Any);
         Widgets.Layout (Item.Widgets, Item.Target);
      end if;
   end Show_Dock;

   procedure Place_All (Item : in out Session);
   --  Put every window where the canvas has them.

   procedure Place_All (Item : in out Session) is
   begin
      Item.Shown_Zoom := Canvases.Zoom (Item.Canvas_View);
      Item.Shown_X := Canvases.Origin_X (Item.Canvas_View);
      Item.Shown_Y := Canvases.Origin_Y (Item.Canvas_View);
      for Each of Item.Windows loop
         Windows.Place (Each, Item.Shown_Zoom, Item.Shown_X, Item.Shown_Y);
      end loop;
   end Place_All;

   procedure Touch (Item : in out Session);
   --  Say the project has been changed, so that it is listed first.

   procedure Touch (Item : in out Session) is
   begin
      Projects.Touch (Item.Store, Item.Current);
   end Touch;

   procedure Centre_On (Item : in out Session; X, Y : Float);
   --  Pan so that the canvas point X, Y is in the middle of the view.

   procedure Centre_On (Item : in out Session; X, Y : Float) is
      View   : UI.Widgets.Canvases.Canvas renames Item.Canvas_View;
      Pixels : constant Float := Widgets.Density (Item.Widgets);
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
      if Items.Has_Words (Item.Store, Key) then
         declare
            Found : Vision.Result;
         begin
            Items.Load_Words (Item.Store, Key, Found);
            Windows.Set_Recognized (Item.Windows (Which), Found);
         end;
      elsif Ada.Directories.Exists
              (Items.Image_File (Item.Store, Item.Current, Key))
      then
         Start_Recognition (Item, Which);
      end if;
   end Recognize_Kept;

   procedure Save_View (Item : in out Session);
   --  Keep how the canvas is seen, for the project to open at again.

   procedure Save_View (Item : in out Session) is
      View   : UI.Widgets.Canvases.Canvas renames Item.Canvas_View;
      Pixels : constant Float := Widgets.Density (Item.Widgets);
   begin
      if Item.Current /= 0 and then Widgets.Width_Of (View) > 0.0 then
         Projects.Set_View
           (Item.Store, Item.Current, Canvases.Zoom (View),
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
      View   : UI.Widgets.Canvases.Canvas renames Item.Canvas_View;
      Pixels : constant Float := Widgets.Density (Item.Widgets);
      Zoom, X, Y : Float;
   begin
      Projects.Get_View (Item.Store, Item.Current, Found, Zoom, X, Y);
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
      Items.Load (Item.Store, Item.Current, Found);
      for I in 1 .. Found.Count loop
         Windows.Assign
           (Item.Windows (I), Found.Items (I),
            Items.Content (Item.Store, Found.Items (I).Key),
            Items.Image_File
              (Item.Store, Item.Current, Found.Items (I).Key));
         Recognize_Kept (Item, I);
         if Found.Items (I).Kind = Items.Source then
            declare
               Kept : Items.Mark_List;
            begin
               Items.Load_Marks (Item.Store, Found.Items (I).Key, Kept);
               Windows.Set_Marks (Item.Windows (I), Kept);
            end;
         end if;
      end loop;
      Restore_View (Item, Restored);
      if not Restored then
         Centre_On_Visible (Item);
      end if;
      Place_All (Item);
      Show_Dock (Item);
      Widgets.Layout (Item.Widgets, Item.Target);
   end Enter;

   procedure Save_All (Item : in out Session) is
      Wrote, Any : Boolean := False;
   begin
      for Each of Item.Windows loop
         if Windows.Is_Assigned (Each) then
            Windows.Flush
              (Each, Item.Store, 0, Force => True, Wrote => Wrote);
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
      for Which in Items.Slot loop
         if Windows.Is_Assigned (Item.Windows (Which)) then
            Windows.Release (Item.Windows (Which));
            Webshot.Reset (Which);
            Vision.Jobs.Reset (Which);
         end if;
      end loop;
      Widgets.Set_Visible (Item.Dock_Panel, False);
   end Leave;

   procedure Add
     (Item : in out Session;
      Name : String := Untitled;
      Kind : Items.Kinds := Items.Note)
   is
      View   : UI.Widgets.Canvases.Canvas renames Item.Canvas_View;
      Pixels : constant Float := Widgets.Density (Item.Widgets);
      Made   : constant Natural := Count (Item);
      Step   : constant Float :=
        Float (Made mod Cascade_Count) * Cascade_Step;
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
      if Free = 0 then
         return;
      end if;
      declare
         Key : constant Items.Id :=
           Items.Create
             (Item.Store, Item.Current, Name, Where, Kind => Kind);
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
         Widgets.Layout (Item.Widgets, Item.Target);
         Windows.Focus_Text (Item.Windows (Free));
      end;
   end Add;

   procedure Set_State
     (Item : in out Session; Which : Items.Slot; To : Items.States) is
   begin
      Windows.Set_State (Item.Windows (Which), To);
      Items.Set_State
        (Item.Store, Windows.Details (Item.Windows (Which)).Key, To);
      Windows.Place
        (Item.Windows (Which),
         Item.Shown_Zoom, Item.Shown_X, Item.Shown_Y);
      Touch (Item);
      Show_Dock (Item);
      Widgets.Layout (Item.Widgets, Item.Target);
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
      Widgets.Layout (Item.Widgets, Item.Target);
   end Reveal;

   procedure Remove (Item : in out Session; Which : Items.Slot) is
   begin
      Webshot.Reset (Which);
      Vision.Jobs.Reset (Which);
      Items.Delete
        (Item.Store, Windows.Details (Item.Windows (Which)).Key);
      Windows.Release (Item.Windows (Which));
      Touch (Item);
      Show_Dock (Item);
      Widgets.Layout (Item.Widgets, Item.Target);
   end Remove;

   procedure Take (Item : in out Session) is
      Action : Windows.Actions;
   begin
      for Which in Items.Slot loop
         if Windows.Is_Assigned (Item.Windows (Which)) then
            Windows.Poll (Item.Windows (Which), Action);
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
            end case;
         end if;
      end loop;
   end Take;

   procedure Pressed (Item : in out Session; X, Y : Float) is
      Pixels : constant Float := Widgets.Density (Item.Widgets);
   begin
      for Each of Item.Windows loop
         if Windows.Is_Assigned (Each)
           and then Windows.Tool (Each) /= UI.Widgets.Pictures.Pointer
         then
            declare
               Box : constant Items.Frame := Windows.Box (Each);
            begin
               if X * Pixels not in Box.Left .. Box.Left + Box.Width
                 or else Y * Pixels not in Box.Top .. Box.Top + Box.Height
               then
                  Windows.Select_Tool (Each, UI.Widgets.Pictures.Pointer);
               end if;
            end;
         end if;
      end loop;
   end Pressed;

   procedure Sync (Item : in out Session) is
   begin
      if Canvases.Zoom (Item.Canvas_View) /= Item.Shown_Zoom
        or else Canvases.Origin_X (Item.Canvas_View) /= Item.Shown_X
        or else Canvases.Origin_Y (Item.Canvas_View) /= Item.Shown_Y
      then
         Place_All (Item);
      end if;
   end Sync;

   procedure Update (Item : in out Session; Now : SDL3.Events.Milliseconds) is
      Wrote, Any : Boolean := False;
   begin
      Sync (Item);
      Poll_Captures (Item);
      for Each of Item.Windows loop
         if Windows.Is_Assigned (Each) then
            Windows.Flush
              (Each, Item.Store, Now, Force => False, Wrote => Wrote);
            Any := Any or else Wrote;
         end if;
      end loop;
      if Any then
         Touch (Item);
      end if;
   end Update;

end Viewer.Canvas_Items;
