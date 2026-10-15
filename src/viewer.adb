with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Exceptions;
with Ada.Text_IO;
with Files;
with SDL3.Events.Redraws;
with SDL3.Windows.Renderers;
with Viewer.Build;
with Viewer.Canvas_Items;
with Viewer.Deletion;
with Viewer.Gestures;
with Viewer.Home_Screen;
with Viewer.Listing;
with Viewer.Painting;
with Viewer.Responses;
with Viewer.Settings_View;
with Viewer.Style;
with Viewer.Writing;

package body Viewer is

   package Widgets renames Pomarine.Widgets;
   package Labels renames Pomarine.Widgets.Labels;

   use Ada.Strings.Unbounded;
   use type Preferences.Theme_Choices;
   use type SDL3.Events.Event_Kind;
   use type SDL3.Events.Key_Code;
   use type SDL3.Cursors.Kind;
   use SDL3.Windows.Renderers;

   package Redraws is new SDL3.Events.Redraws (Session, Painting.Draw);

   overriding procedure Handle_Event
     (Self   : in out Responder;
      Source : in out Pomarine.Widgets.Widget'Class;
      Event  : Pomarine.Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
   begin
      Responses.Respond (Self.Owner.all, Event);
   end Handle_Event;

   --  Events

   function Cursor (Item : Session) return SDL3.Cursors.Kind is
     (Widgets.Wanted_Cursor (Item.Root.Widgets));

   procedure Show_Cursor (Item : in out Session);
   --  Give the window the cursor the widgets want, if it is not that now.

   procedure Show_Cursor (Item : in out Session) is
      Wanted : constant SDL3.Cursors.Kind := Cursor (Item);
   begin
      if Item.Shell.Windowed and then Wanted /= Item.Shell.Shown_Cursor then
         SDL3.Cursors.Set (Wanted);
         Item.Shell.Shown_Cursor := Wanted;
      end if;
   end Show_Cursor;

   --  Moving the window

   function In_Title_Strip (Item : Session; Y : Float) return Boolean is
     (Y >= 0.0
      and then Y < (if Item.Nav.Shown = Project
                    or else Item.Prefs.Showing_Settings
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
                  SDL3.Windows.Zoom (Item.Host.Win);  --  as a title bar does
               else
                  SDL3.Windows.Get_Geometry
                    (Item.Host.Win, Item.Shell.Grab_Left, Item.Shell.Grab_Top,
                     Width, Height,
                     Found);
                  if Found then
                     SDL3.Windows.Global_Pointer (Item.Shell.Grab_X,
                        Item.Shell.Grab_Y);
                     Item.Shell.Moving := True;
                  end if;
               end if;
            end if;
         when SDL3.Events.Mouse_Move =>
            if Item.Shell.Moving then
               declare
                  X, Y : Float;
               begin
                  SDL3.Windows.Global_Pointer (X, Y);
                  SDL3.Windows.Set_Position
                    (Item.Host.Win,
                     Item.Shell.Grab_Left
                     + Integer (Float'Rounding (X - Item.Shell.Grab_X)),
                     Item.Shell.Grab_Top
                     + Integer (Float'Rounding (Y - Item.Shell.Grab_Y)));
               end;
            end if;
         when SDL3.Events.Mouse_Up =>
            if Event.Button = 1 then
               Item.Shell.Moving := False;
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
            if Item.Nav.Shown = Project then
               Canvas_Items.Save_All (Item);
            end if;
            Item.Shell.Done := True;
         when SDL3.Events.Redraw =>
            Widgets.Invalidate_All (Item.Root.Widgets);
         when SDL3.Events.Theme_Changed =>
            --  Only the system's appearance can change by itself.
            if Item.Prefs.Theme_Chosen = Preferences.System then
               Settings_View.Apply_Theme (Item);
            end if;
         when others =>
            if Item.Prefs.Showing_Settings then
               --  Escape leaves the settings, as their Close button does.
               if Event.Kind = SDL3.Events.Key_Down
                 and then Event.Key = SDL3.Events.Key_Escape
               then
                  if Item.Confirm.Deleting_Model then
                     Deletion.Close (Item);
                  else
                     Settings_View.Close (Item);
                  end if;
                  return;
               end if;
            elsif Item.Item_List.Showing_List then
               --  The list is all that takes events.
               if Event.Kind = SDL3.Events.Key_Down
                 and then Event.Key = SDL3.Events.Key_Escape
               then
                  Listing.Close (Item);
                  return;
               end if;
            elsif Home_Screen.Is_Confirming (Item) then
               --  The dialog is all that takes events.
               if Event.Kind = SDL3.Events.Key_Down
                 and then Event.Key = SDL3.Events.Key_Escape
               then
                  Deletion.Close (Item);
                  return;
               end if;
            --  The text is saved only from a project.
            elsif Item.Nav.Shown = Project
              and then Event.Kind = SDL3.Events.Key_Down
              and then Event.Command and then Event.Key = SDL3.Events.Key_S
            then
               Save (Item);
               Handled := True;
            end if;
            if not Handled then
               if Item.Nav.Shown = Project
                 and then Event.Kind = SDL3.Events.Mouse_Down
               then
                  Canvas_Items.Pressed (Item, Event.Mouse_X, Event.Mouse_Y);
                  Writing.Pressed (Item, Event.Mouse_X, Event.Mouse_Y);
                  if Event.Button = 3 and then not Item.Item_List.Showing_List
                    and then not Home_Screen.Is_Confirming (Item)
                  then
                     Writing.Open_Context
                       (Item, Event.Mouse_X, Event.Mouse_Y, Handled);
                  end if;
               end if;
               if not Handled then
                  Widgets.Dispatch (Item.Root.Widgets, Event, Handled);
                  if Item.Shell.Windowed then
                     Track_Window (Item, Event, Handled);
                  end if;
               end if;
               Gestures.Take (Item);
               Show_Cursor (Item);
            end if;
            if Item.Nav.Shown = Project then
               Canvas_Items.Update (Item, Event.Time);
            end if;
      end case;
   end Handle;

   function Screen (Item : Session) return Screens is (Item.Nav.Shown);

   --  The file

   function Title (Item : Session) return String is
     (case Item.Nav.Shown is
         when Home    => "bonxie",
         when Project =>
           (if Length (Item.Opened.Project_Name) > 0
            then To_String (Item.Opened.Project_Name)
            else Scripts.Title (Item.Host.Script)));

   procedure Save (Item : in out Session) is
   begin
      if Scripts.File_Name (Item.Host.Script) /= "" then
         Scripts.Save (Item.Host.Script);
      end if;
   exception
      when Problem : others =>
         --  Keep the text, to save another time.
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "Could not save " & Scripts.File_Name (Item.Host.Script) & ": "
            & Ada.Exceptions.Exception_Message (Problem));
   end Save;

   procedure Show_Title (Item : in out Session);
   --  In the window's title bar, if it has changed.

   procedure Show_Title (Item : in out Session) is
      Now : constant String := Title (Item);
   begin
      if Now /= To_String (Item.Shell.Shown_Title) then
         SDL3.Windows.Set_Title (Item.Host.Win, Now);
         Labels.Set_Text
           (Item.Root.Header_Title,
            Now (Now'First ..
                 Now'First - 1
                 + Natural'Min (Now'Length, Labels.Text_Capacity)));
         Item.Shell.Shown_Title := To_Unbounded_String (Now);
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
      Item.Shell.Windowed := True;
      SDL3.Windows.Create
        (Item.Host.Win, "bonxie", Style.Window_Width, Style.Window_Height,
         Resizable => True, High_Density => True, Hidden => Hidden);
      Item.Shell.Density := SDL3.Windows.Pixel_Density (Item.Host.Win);
      SDL3.Windows.Extend_Into_Title_Bar (Item.Host.Win);
      --  The bar is dragged by the program (see Track_Window), not by the
      --  system, so that its buttons are only clicked.
      SDL3.Windows.Set_Movable (Item.Host.Win, False);
      Create (Item.Host.Target, Item.Host.Win, VSync => VSync);
      Build.Set_Up (Item, Source, File_Name, Store);
      Settings_View.Apply_Theme (Item);
      SDL3.Windows.Start_Text_Input (Item.Host.Win);
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
      if Widgets.Until_Update (Item.Root.Widgets) >= 0 then
         Wake_In (Widgets.Until_Update (Item.Root.Widgets));
      end if;
      --  A picture of a page is on its way: look for it now and then.
      if Item.Nav.Shown = Project and then Canvas_Items.Capturing (Item) then
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
      Item.Shell.Density := Density;
      Create_Offscreen
        (Item.Host.Target, Pixels (Width, Density), Pixels (Height, Density));
      Build.Set_Up (Item, Source, File_Name, Projects.Memory);
      Settings_View.Apply_Theme (Item);
   end Open;

   function Is_Open (Item : Session) return Boolean is
     (Widgets.Has_Root (Item.Root.Widgets));

   function Text (Item : Session) return String is
     (Scripts.Text (Item.Host.Script));

   procedure Tick (Item : in out Session; Now : SDL3.Events.Milliseconds) is
   begin
      Widgets.Update (Item.Root.Widgets, Now);
      if Item.Nav.Shown = Project then
         Canvas_Items.Update (Item, Now);
      end if;
      if Item.Prefs.Showing_Settings then
         Settings_View.Update (Item);
      end if;
   end Tick;

   procedure Resize (Item : in out Session; Width, Height : Positive) is
   begin
      SDL3.Windows.Renderers.Resize
        (Item.Host.Target,
         Pixels (Width, Item.Shell.Density), Pixels (Height,
            Item.Shell.Density));
      --  Which loses what was drawn.
      Widgets.Invalidate_All (Item.Root.Widgets);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Resize;

   procedure Render
     (Item   : in out Session;
      Result : in out SDL3.Windows.Renderers.Images.Image) is
   begin
      --  Offscreen there is nothing to present to.
      Painting.Paint (Item);
      SDL3.Windows.Renderers.Images.Read (Result, Item.Host.Target);
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
         SDL3.Windows.Set_Size (Item.Host.Win, Value (3), Value (4));
         SDL3.Windows.Set_Position (Item.Host.Win, Value (1), Value (2));
      end if;
   exception
      when others =>
         null;  --  none kept, or unreadable: stay as made
   end Restore_Geometry;

   procedure Save_Geometry (Item : Session) is
      X, Y, W, H : Integer;
      Found      : Boolean;
   begin
      SDL3.Windows.Get_Geometry (Item.Host.Win, X, Y, W, H, Found);
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

      while not Item.Shell.Done loop
         Show_Title (Item);
         if Widgets.Needs_Paint (Item.Root.Widgets) then
            Painting.Draw (Item);
         end if;
         Wait_And_Handle (Item);
      end loop;
      Save_Geometry (Item);
      --  Not to go on fetching what no one will use.
      Speech.Models.Cancel;
   end Run;

end Viewer;
