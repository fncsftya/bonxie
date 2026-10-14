with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Exceptions;
with Ada.Text_IO;
with Files;
with SDL3.Events.Redraws;
with SDL3.Windows.Renderers;
with UI.Widgets;
with UI.Widgets.Pictures;
with Viewer.Build;
with Viewer.Canvas_Items;
with Viewer.Links;
with Viewer.Clicks;
with Viewer.Deletion;
with Viewer.Listing;
with Viewer.Navigation;
with Viewer.Painting;
with Viewer.Settings_View;
with Viewer.Style;
with Viewer.Writing;

package body Viewer is

   package Widgets renames UI.Widgets;
   package Canvases renames UI.Widgets.Canvases;
   package Labels renames UI.Widgets.Labels;

   use Ada.Strings.Unbounded;
   use type Items.Id;
   use type Projects.Id;
   use type Preferences.Theme_Choices;
   use type SDL3.Events.Event_Kind;
   use type SDL3.Events.Key_Code;
   use type SDL3.Cursors.Kind;
   use SDL3.Windows.Renderers;

   package Redraws is new SDL3.Events.Redraws (Session, Painting.Draw);

   --  Events

   function Cursor (Item : Session) return SDL3.Cursors.Kind is
     (Widgets.Wanted_Cursor (Item.Widgets));

   procedure Show_Cursor (Item : in out Session);
   --  Give the window the cursor the widgets want, if it is not that now.

   procedure Show_Cursor (Item : in out Session) is
      Wanted : constant SDL3.Cursors.Kind := Cursor (Item);
   begin
      if Item.Windowed and then Wanted /= Item.Shown_Cursor then
         SDL3.Cursors.Set (Wanted);
         Item.Shown_Cursor := Wanted;
      end if;
   end Show_Cursor;

   --  Moving the window

   function In_Title_Strip (Item : Session; Y : Float) return Boolean is
     (Y >= 0.0
      and then Y < (if Item.Shown = Project or else Item.Showing_Settings
                    then Style.Toolbar_Size
                    else Style.Header_Size));
   --  Whether a point is in the bar across the top, or over the home
   --  screen, where the window is moved from. The window has no native
   --  title bar drag (see Open_Window), so this is what moves it.

   procedure Track_Window
     (Item  : in out Session;
      Event : SDL3.Events.Event;
      Taken : Boolean)
   is
      Width, Height : Integer;
      Found         : Boolean;
   begin
      case Event.Kind is
         when SDL3.Events.Mouse_Down =>
            --  A press on a button is for the button, not for a drag.
            if Event.Button = 1 and then not Taken
              and then In_Title_Strip (Item, Event.Mouse_Y)
            then
               if Event.Clicks >= 2 then
                  SDL3.Windows.Zoom (Item.Win);  --  as a title bar does
               else
                  SDL3.Windows.Get_Geometry
                    (Item.Win, Item.Grab_Left, Item.Grab_Top, Width, Height,
                     Found);
                  if Found then
                     SDL3.Windows.Global_Pointer (Item.Grab_X, Item.Grab_Y);
                     Item.Moving := True;
                  end if;
               end if;
            end if;
         when SDL3.Events.Mouse_Move =>
            if Item.Moving then
               declare
                  X, Y : Float;
               begin
                  SDL3.Windows.Global_Pointer (X, Y);
                  SDL3.Windows.Set_Position
                    (Item.Win,
                     Item.Grab_Left
                     + Integer (Float'Rounding (X - Item.Grab_X)),
                     Item.Grab_Top
                     + Integer (Float'Rounding (Y - Item.Grab_Y)));
               end;
            end if;
         when SDL3.Events.Mouse_Up =>
            if Event.Button = 1 then
               Item.Moving := False;
            end if;
         when others =>
            null;
      end case;
   end Track_Window;

   procedure Handle (Item : in out Session; Event : SDL3.Events.Event) is
      Handled : Boolean := False;
   begin
      case Event.Kind is
         when SDL3.Events.Quit =>
            if Item.Shown = Project then
               Canvas_Items.Save_All (Item);
            end if;
            Item.Done := True;
         when SDL3.Events.Redraw =>
            Widgets.Invalidate_All (Item.Widgets);
         when SDL3.Events.Theme_Changed =>
            --  Only the system's appearance can change by itself.
            if Item.Theme_Chosen = Preferences.System then
               Settings_View.Apply_Theme (Item);
            end if;
         when others =>
            if Item.Showing_Settings then
               --  Escape leaves the settings, as their Close button does.
               if Event.Kind = SDL3.Events.Key_Down
                 and then Event.Key = SDL3.Events.Key_Escape
               then
                  Settings_View.Close (Item);
                  return;
               end if;
            elsif Item.Showing_List then
               --  The list is all that takes events.
               if Event.Kind = SDL3.Events.Key_Down
                 and then Event.Key = SDL3.Events.Key_Escape
               then
                  Listing.Close (Item);
                  return;
               end if;
            elsif Item.Deleting /= 0 then
               --  The dialog is all that takes events.
               if Event.Kind = SDL3.Events.Key_Down
                 and then Event.Key = SDL3.Events.Key_Escape
               then
                  Deletion.Close (Item);
                  return;
               end if;
            --  The text is saved only from a project.
            elsif Item.Shown = Project
              and then Event.Kind = SDL3.Events.Key_Down
              and then Event.Command and then Event.Key = SDL3.Events.Key_S
            then
               Save (Item);
               Handled := True;
            end if;
            if not Handled then
               if Item.Shown = Project
                 and then Event.Kind = SDL3.Events.Mouse_Down
               then
                  Canvas_Items.Pressed (Item, Event.Mouse_X, Event.Mouse_Y);
                  Writing.Pressed (Item, Event.Mouse_X, Event.Mouse_Y);
               end if;
               Widgets.Dispatch (Item.Widgets, Event, Handled);
               if Item.Windowed then
                  Track_Window (Item, Event, Handled);
               end if;
               Clicks.Take (Item);
               Show_Cursor (Item);
            end if;
            if Item.Shown = Project then
               Canvas_Items.Update (Item, Event.Time);
            end if;
      end case;
   end Handle;

   --  The screens

   function Screen (Item : Session) return Screens is (Item.Shown);

   function Mode (Item : Session) return Modes is (Item.Mode);

   procedure Set_Mode (Item : in out Session; To : Modes) is
   begin
      Writing.Show (Item, To);
   end Set_Mode;

   function Current_Project (Item : Session) return Projects.Id is
     (Item.Current);

   procedure New_Project (Item : in out Session)
     renames Navigation.Enter_New;

   procedure Open_Project (Item : in out Session; Key : Projects.Id)
     renames Navigation.Enter;

   procedure Close_Project (Item : in out Session)
     renames Navigation.Leave;

   function Is_Settings_Open (Item : Session) return Boolean is
     (Item.Showing_Settings);

   procedure Open_Settings (Item : in out Session)
     renames Settings_View.Open;

   procedure Close_Settings (Item : in out Session)
     renames Settings_View.Close;

   function Speech_Model (Item : Session) return Preferences.Speech_Models is
     (Item.Speech_Choice);

   procedure Choose_Speech_Model
     (Item : in out Session; To : Preferences.Speech_Models)
     renames Settings_View.Choose;

   function Theme_Choice (Item : Session) return Preferences.Theme_Choices is
     (Item.Theme_Chosen);

   procedure Choose_Theme
     (Item : in out Session; To : Preferences.Theme_Choices)
     renames Settings_View.Choose_Appearance;

   function Is_Dark (Item : Session) return Boolean is (Item.Dark_Shown);

   procedure Add_Project
     (Item    : in out Session;
      Name    : String;
      Updated : Projects.Seconds)
     renames Navigation.Keep;

   --  The items

   function Item_Count (Item : Session) return Natural is
     (Canvas_Items.Count (Item));

   function Link_Count (Item : Session) return Natural is
     (Item.Link_Set.Count);

   function Link_Selected (Item : Session) return Boolean is
     (Item.Link_Key /= 0);

   function Link_Description
     (Item : Session; Number : Positive) return String
   is
      Each : Items.Link renames Item.Link_Set.Links (Number);
   begin
      return Items.Strokes'Image (Each.Stroke) & ' '
        & Items.Endings'Image (Each.Ending) & ' '
        & Integer'Image (Each.Color) & ' '
        & Items.Sides'Image (Each.To_Side);
   end Link_Description;

   function Pin_Count (Item : Session) return Natural is
     (Links.Shown_Pins (Item));

   procedure Add_Item
     (Item : in out Session;
      Name : String := "Untitled item";
      Kind : Items.Kinds := Items.Note)
     renames Canvas_Items.Add;

   function Is_Listing (Item : Session) return Boolean is
     (Item.Showing_List);

   function Nth (Item : Session; Row : Positive) return Items.Slot;
   --  The window of the Rowth item.

   function Nth (Item : Session; Row : Positive) return Items.Slot is
      Slots : Canvas_Items.Slot_List (1 .. Items.Capacity);
      Found : Natural;
   begin
      Canvas_Items.Order (Item, Slots, Found);
      return Slots (Row);
   end Nth;

   function Document_Count (Item : Session) return Natural is
     (Item.Write_Count);

   function Document_Title (Item : Session; Row : Positive) return String is
     (Projects.Titles.To_String
        (Items.Windows.Details
           (Item.Windows (Item.Write_Order (Row))).Title));

   procedure Move_Document (Item : in out Session; From, To : Positive) is
   begin
      Writing.Move (Item, From, To);
   end Move_Document;

   function Directory_Count (Item : Session) return Natural is
     (Item.Dirs.Count);

   function Directory_Title (Item : Session; Row : Positive) return String is
     (Projects.Titles.To_String (Item.Dirs.Directories (Row).Title));

   procedure Add_Directory
     (Item : in out Session; Name : String := "Untitled folder") is
   begin
      Writing.Make_Directory (Item, Name);
   end Add_Directory;

   function Document_Directory
     (Item : Session; Row : Positive) return Natural is
     (Item.Doc_Dir (Item.Write_Order (Row)));

   procedure Move_Document_To
     (Item : in out Session; Row : Positive; Directory : Natural) is
   begin
      Writing.Move_To_Directory (Item, Row, Directory);
   end Move_Document_To;

   function Shown_Directory (Item : Session) return Natural is
     (Item.Shown_Dir);

   procedure Show_Directory (Item : in out Session; Directory : Natural) is
   begin
      Writing.Select_Directory (Item, Directory);
   end Show_Directory;

   function Source_Count (Item : Session) return Natural is
     (Item.Source_Total);

   function Source_Title (Item : Session; Row : Positive) return String is
     (Projects.Titles.To_String
        (Items.Windows.Details
           (Item.Windows (Item.Source_Order (Row))).Title));

   function Source_Is_Open (Item : Session; Row : Positive) return Boolean is
     (Item.Pinned_Slot = Item.Source_Order (Row)
      or else Items."=" (Items.Readers.Details
                           (Item.Readers (Item.Source_Order (Row))).State,
                         Items.Open));

   function Source_Marks (Item : Session; Row : Positive) return Natural is
      Kept : Items.Mark_List;
   begin
      Items.Readers.Get_Marks
        (Item.Readers (Item.Source_Order (Row)), Kept);
      return Kept.Count;
   end Source_Marks;

   function Pinned_Source (Item : Session) return Natural is
   begin
      for Row in 1 .. Item.Source_Total loop
         if Item.Source_Order (Row) = Item.Pinned_Slot then
            return Row;
         end if;
      end loop;
      return 0;
   end Pinned_Source;

   procedure Link_Items (Item : in out Session; From, To : Positive) is
      Added : Boolean;
   begin
      Items.Add_Link
        (Item.Store,
         (From => Items.Windows.Details (Item.Windows (Nth (Item, From))).Key,
          To   => Items.Windows.Details (Item.Windows (Nth (Item, To))).Key,
          others => <>),
         Added);
      Links.Reload (Item);
   end Link_Items;

   function Item_Title (Item : Session; Row : Positive) return String is
     (Projects.Titles.To_String
        (Items.Windows.Details (Item.Windows (Nth (Item, Row))).Title));

   function Item_Text (Item : Session; Row : Positive) return String is
     (Items.Windows.Text (Item.Windows (Nth (Item, Row))));

   procedure Dictate_Live
     (Item : in out Session; Row : Positive; Said : String) is
   begin
      Items.Windows.Set_Live_Dictation (Item.Windows (Nth (Item, Row)), Said);
   end Dictate_Live;

   procedure Dictate_Into
     (Item : in out Session; Row : Positive; Said : String)
   is
   begin
      Items.Windows.Add_Dictation (Item.Windows (Nth (Item, Row)), Said);
   end Dictate_Into;

   function Item_Kind (Item : Session; Row : Positive) return Items.Kinds is
     (Items.Windows.Details (Item.Windows (Nth (Item, Row))).Kind);

   function Item_Status (Item : Session; Row : Positive) return String is
     (Items.Windows.Status (Item.Windows (Nth (Item, Row))));

   function Item_Zoom (Item : Session; Row : Positive) return Float is
     (Items.Windows.Details (Item.Windows (Nth (Item, Row))).Zoom);

   function Item_Picture_File (Item : Session; Row : Positive) return String
   is
     (Items.Image_File
        (Item.Store, Item.Current,
         Items.Windows.Details (Item.Windows (Nth (Item, Row))).Key));

   procedure Pin_Capture_Time (Item : in out Session; To : Projects.Seconds) is
   begin
      Item.Pinned_Time := To;
   end Pin_Capture_Time;

   function Is_Capturing (Item : Session) return Boolean is
     (Canvas_Items.Capturing (Item));

   function Item_Recognized (Item : Session; Row : Positive) return Natural is
     (Items.Windows.Recognized_Count (Item.Windows (Nth (Item, Row))));

   function Item_Selected_Text (Item : Session; Row : Positive) return String
   is
     (Items.Windows.Selected_Text (Item.Windows (Nth (Item, Row))));

   function Item_Marks (Item : Session; Row : Positive) return Natural is
     (Items.Windows.Mark_Count (Item.Windows (Nth (Item, Row))));

   function Item_Highlighting (Item : Session; Row : Positive) return Boolean
   is
     (UI.Widgets.Pictures."=" (Items.Windows.Tool
        (Item.Windows (Nth (Item, Row))), UI.Widgets.Pictures.Highlighter));

   function Item_Erasing (Item : Session; Row : Positive) return Boolean is
     (UI.Widgets.Pictures."=" (Items.Windows.Tool
        (Item.Windows (Nth (Item, Row))), UI.Widgets.Pictures.Eraser));

   function Item_Words (Item : Session; Row : Positive) return Natural is
     (Items.Windows.Words (Item.Windows (Nth (Item, Row))));

   function Item_State (Item : Session; Row : Positive) return Items.States is
     (Items.Windows.Details (Item.Windows (Nth (Item, Row))).State);

   function Item_Box (Item : Session; Row : Positive) return Items.Frame is
     (Items.Windows.Box (Item.Windows (Nth (Item, Row))));

   function Is_Editing_Title (Item : Session; Row : Positive) return Boolean is
     (Items.Windows.Is_Editing_Title (Item.Windows (Nth (Item, Row))));

   function Item_Frame (Item : Session; Row : Positive) return Items.Frame is
     (Items.Windows.Details (Item.Windows (Nth (Item, Row))).Where);

   function Is_Renaming (Item : Session) return Boolean is
     (Item.Editing /= 0);

   function Is_Confirming (Item : Session) return Boolean is
     (Item.Deleting /= 0);

   function Row_Title (Item : Session; Row : Positive) return String is
     (if Row <= Item.Listed.Count then Labels.Text (Item.Cards (Row).Title)
      else "");

   --  The file

   function Title (Item : Session) return String is
     (case Item.Shown is
         when Home    => "bonxie",
         when Project =>
           (if Length (Item.Project_Name) > 0
            then To_String (Item.Project_Name)
            else Scripts.Title (Item.Script)));

   procedure Save (Item : in out Session) is
   begin
      if Scripts.File_Name (Item.Script) /= "" then
         Scripts.Save (Item.Script);
      end if;
   exception
      when Problem : others =>
         --  Keep the text, to save another time.
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "Could not save " & Scripts.File_Name (Item.Script) & ": "
            & Ada.Exceptions.Exception_Message (Problem));
   end Save;

   procedure Show_Title (Item : in out Session);
   --  In the window's title bar, if it has changed.

   procedure Show_Title (Item : in out Session) is
      Now : constant String := Title (Item);
   begin
      if Now /= To_String (Item.Shown_Title) then
         SDL3.Windows.Set_Title (Item.Win, Now);
         Labels.Set_Text
           (Item.Header_Title,
            Now (Now'First ..
                 Now'First - 1
                 + Natural'Min (Now'Length, Labels.Text_Capacity)));
         Item.Shown_Title := To_Unbounded_String (Now);
      end if;
   end Show_Title;

   --  Running

   procedure Open_Window
     (Item      : in out Session;
      Source    : String;
      File_Name : String := "";
      Hidden    : Boolean := False;
      Store     : String := Projects.Default_Path;
      VSync     : Boolean := True) is
   begin
      Item.Windowed := True;
      SDL3.Windows.Create
        (Item.Win, "bonxie", Style.Window_Width, Style.Window_Height,
         Resizable => True, High_Density => True, Hidden => Hidden);
      Item.Density := SDL3.Windows.Pixel_Density (Item.Win);
      SDL3.Windows.Extend_Into_Title_Bar (Item.Win);
      --  The bar is dragged by the program (see Track_Window), not by the
      --  system, so that its buttons are only clicked.
      SDL3.Windows.Set_Movable (Item.Win, False);
      Create (Item.Target, Item.Win, VSync => VSync);
      Build.Set_Up (Item, Source, File_Name, Store);
      Settings_View.Apply_Theme (Item);
      SDL3.Windows.Start_Text_Input (Item.Win);
   end Open_Window;

   procedure Draw_Frame (Item : in out Session) renames Painting.Draw;

   procedure Paint_Frame (Item : in out Session) renames Painting.Paint;

   Capture_Poll : constant := 100;
   --  Milliseconds between looks for a picture being taken.

   procedure Wait_And_Handle (Item : in out Session) is
      Event   : SDL3.Events.Event;
      Timeout : Integer := -1;  --  none

      procedure Wake_In (Milliseconds : Integer) is
      begin
         Timeout :=
           (if Timeout < 0 then Integer'Max (0, Milliseconds)
            else Integer'Min (Timeout, Integer'Max (0, Milliseconds)));
      end Wake_In;
   begin
      --  Nothing to do until something happens, except to blink a caret.
      Tick (Item, SDL3.Events.Ticks);
      if Widgets.Until_Update (Item.Widgets) >= 0 then
         Wake_In (Widgets.Until_Update (Item.Widgets));
      end if;
      --  A picture of a page is on its way: look for it now and then.
      if Item.Shown = Project and then Canvas_Items.Capturing (Item) then
         Wake_In (Capture_Poll);
      end if;
      --  So is the file for the speech model: look at how far on it is.
      if Settings_View.Downloading (Item) then
         Wake_In (Capture_Poll);
      end if;

      if SDL3.Events.Wait (Event, Timeout_MS => Timeout) then
         Handle (Item, Event);
         while SDL3.Events.Poll (Event) loop
            Handle (Item, Event);
         end loop;
      end if;

      Tick (Item, SDL3.Events.Ticks);
   end Wait_And_Handle;

   --  Without a window

   function Pixels (Points : Positive; Density : Float) return Positive is
     (Positive (Float (Points) * Density));

   procedure Open
     (Item      : in out Session;
      Source    : String;
      Width     : Positive;
      Height    : Positive;
      Density   : Float := 2.0;
      File_Name : String := "") is
   begin
      Item.Density := Density;
      Create_Offscreen
        (Item.Target, Pixels (Width, Density), Pixels (Height, Density));
      Build.Set_Up (Item, Source, File_Name, Projects.Memory);
      Settings_View.Apply_Theme (Item);
   end Open;

   function Is_Open (Item : Session) return Boolean is
     (Widgets.Has_Root (Item.Widgets));

   function Canvas_Zoom (Item : Session) return Float is
     (Canvases.Zoom (Item.Canvas_View));

   function Canvas_Origin_X (Item : Session) return Float is
     (Canvases.Origin_X (Item.Canvas_View));

   function Canvas_Origin_Y (Item : Session) return Float is
     (Canvases.Origin_Y (Item.Canvas_View));

   function Text (Item : Session) return String is
     (Scripts.Text (Item.Script));

   procedure Tick (Item : in out Session; Now : SDL3.Events.Milliseconds) is
   begin
      Widgets.Update (Item.Widgets, Now);
      if Item.Shown = Project then
         Canvas_Items.Update (Item, Now);
      end if;
      if Item.Showing_Settings then
         Settings_View.Update (Item);
      end if;
   end Tick;

   procedure Resize (Item : in out Session; Width, Height : Positive) is
   begin
      SDL3.Windows.Renderers.Resize
        (Item.Target,
         Pixels (Width, Item.Density), Pixels (Height, Item.Density));
      --  Which loses what was drawn.
      Widgets.Invalidate_All (Item.Widgets);
      Widgets.Layout (Item.Widgets, Item.Target);
   end Resize;

   procedure Render
     (Item   : in out Session;
      Result : in out SDL3.Windows.Renderers.Images.Image) is
   begin
      --  Offscreen there is nothing to present to.
      Painting.Paint (Item);
      SDL3.Windows.Renderers.Images.Read (Result, Item.Target);
   end Render;

   --  Where the window was left

   function Geometry_Path return String is
     (Ada.Directories.Containing_Directory (Projects.Default_Path)
      & "/window");

   procedure Restore_Geometry (Item : in out Session) is
      Value : array (1 .. 4) of Integer;
   begin
      declare
         Saved : constant String := Files.Read (Geometry_Path);
         First : Positive := Saved'First;
         Last  : Natural;
      begin
         for V of Value loop
            while First <= Saved'Last and then Saved (First) = ' ' loop
               First := First + 1;
            end loop;
            Last := First;
            while Last < Saved'Last and then Saved (Last + 1) /= ' ' loop
               Last := Last + 1;
            end loop;
            V := Integer'Value (Saved (First .. Last));
            First := Last + 1;
         end loop;
      end;
      if Value (3) > 0 and then Value (4) > 0 then
         SDL3.Windows.Set_Size (Item.Win, Value (3), Value (4));
         SDL3.Windows.Set_Position (Item.Win, Value (1), Value (2));
      end if;
   exception
      when others =>
         null;  --  none kept, or unreadable: stay as made
   end Restore_Geometry;

   procedure Save_Geometry (Item : Session) is
      X, Y, W, H : Integer;
      Found      : Boolean;
   begin
      SDL3.Windows.Get_Geometry (Item.Win, X, Y, W, H, Found);
      if Found then
         Files.Write
           (Geometry_Path,
            X'Image & Y'Image & W'Image & H'Image);
      end if;
   exception
      when others =>
         null;  --  losing the place of the window is not worth a crash
   end Save_Geometry;

   procedure Run (Source : String; File_Name : String := "") is
      Item    : aliased Session;
      Watcher : Redraws.Watch;  --  ends before Item does
   begin
      Open_Window
        (Item, Source, File_Name,
         VSync => Ada.Environment_Variables.Exists ("BONXIE_VSYNC")
                  and then Ada.Environment_Variables.Value
                             ("BONXIE_VSYNC") = "1");
      Restore_Geometry (Item);

      --  The redraw watch also draws: the OS blocks the event loop
      --  during a live resize, and only repainting from inside the event
      --  watch avoids a stretched frame.
      Redraws.Install (Watcher, Item);

      while not Item.Done loop
         Show_Title (Item);
         if Widgets.Needs_Paint (Item.Widgets) then
            Painting.Draw (Item);
         end if;
         Wait_And_Handle (Item);
      end loop;
      Save_Geometry (Item);
      --  Not to go on fetching what no one will use.
      Downloads.Cancel;
   end Run;

end Viewer;
