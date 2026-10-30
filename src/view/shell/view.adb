with SDL3.Dialogs;
with Sidebar_VM;
with Pomarine.Widgets.Menus;
with Speech.Models;
with Scripts;
with Pomarine.Accessibility;
with Preferences;
with Ada.Strings.Unbounded;
with Ada.Strings;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Exceptions;
with Ada.Text_IO;
with Files;
with Pomarine.Application;
with Pomarine.System_Settings;
with SDL3.Events.Redraws;
with SDL3.Windows.Renderers;
with View.Search;
with View.Build;
with View.Browsers;
with View.Canvas_Items;
with View.Deletion;
with View.Menus;
with View.Navigation;
with View.Recent;
with View.Outlines;
with View.Section_Links;
with View.Listing;
with View.Painting;
with View.Responses;
with View.Settings_View;
with View.Style;
with View.Updates;
with View.Writing;
with View.Grammar;

package body View is

   package Widgets renames Pomarine.Widgets;
   package Labels renames Pomarine.Widgets.Labels;

   function Menu_Of (Self : Menu_Router; What : Menu_VM.Command) return access Pomarine.Widgets.Menus.Menu is
   begin
      case What is
         when Menu_VM.Source_Menu  =>
            return Self.Owner.Page_View.Menu'Unrestricted_Access;

         when Menu_VM.Context_Menu =>
            return Self.Owner.Context.Context_Menu'Unrestricted_Access;

         when Menu_VM.Section_Menu =>
            return Self.Owner.Section_Menu.Menu'Unrestricted_Access;

         when Menu_VM.Grammar_Menu =>
            return Self.Owner.Grammar_Checks.Inline_Menu'Unrestricted_Access;
      end case;
   end Menu_Of;

   overriding
   function Allowed (Self : Menu_Router; What : Menu_VM.Command; Row : Natural) return Boolean is
   begin
      if Self.Owner = null then
         return False;
      end if;
      declare
         Menu : Pomarine.Widgets.Menus.Menu renames Menu_Of (Self, What).all;
      begin
         return
           Widgets.Is_Showing (Menu)
           and then Row in 1 .. Pomarine.Widgets.Menus.Row_Count (Menu)
           and then Pomarine.Widgets.Menus.Is_Enabled (Menu, Row);
      end;
   end Allowed;

   overriding
   procedure Choose (Self : in out Menu_Router; What : Menu_VM.Command; Row : Positive) is
      Item  : Session renames Self.Owner.all;
      Event : constant Widgets.Widget_Event := (Kind => Widgets.Choose, Row => Row, others => <>);
   begin
      case What is
         when Menu_VM.Source_Menu  =>
            Writing.Source_Chosen (Item, Item.Page_View.Menu, Event);

         when Menu_VM.Context_Menu =>
            Writing.Context_Chosen (Item, Item.Context.Context_Menu, Event);

         when Menu_VM.Section_Menu =>
            Section_Links.Choose (Item, Row);

         when Menu_VM.Grammar_Menu =>
            Grammar.Choose_Inline (Item, Row);
      end case;
   end Choose;

   use Ada.Strings.Unbounded;
   use type Pomarine.View_Models.Version_Number;
   use type Preferences.Theme_Choices;
   use type Pomarine.Events.Event_Kind;
   use type Pomarine.Events.Key_Code;
   use type SDL3.Cursors.Kind;
   use SDL3.Windows.Renderers;

   package Redraws is new SDL3.Events.Redraws (Session, Painting.Draw);

   overriding
   function Validate (Self : Command_Judge; Tag : Integer; Index : Natural) return Pomarine.Widgets.Command_State
   is (Menus.Validate (Self.Owner.all, Tag, Index));

   overriding
   procedure Outline_Going (Self : in out Outline_Effects; What : Outline_VM.Command; Index : Natural) is
      pragma Unreferenced (Index);
   begin
      Outlines.Going (Self.Owner.all, What);
   end Outline_Going;

   overriding
   procedure Outline_Done (Self : in out Outline_Effects; What : Outline_VM.Command; Index : Natural) is
   begin
      Outlines.Done (Self.Owner.all, What, Index);
   end Outline_Done;

   overriding
   procedure Turned (Self : in out Layout_Watch) is
   begin
      Widgets.Layout (Self.Owner.Root.Widgets, Self.Owner.Host.Target);
   end Turned;

   overriding
   procedure Turned (Self : in out Sidebar_Watch) is
   begin
      if Pomarine.View_Models.Changed (Self.Seen, Sidebar_VM.Version (Self.Owner.Page_View.Folding)) then
         Writing.Fit_Sidebar (Self.Owner.all);
         Widgets.Layout (Self.Owner.Root.Widgets, Self.Owner.Host.Target);
      end if;
   end Turned;

   overriding
   procedure Toggle_Source (Self : in out Source_Effects; Slot : Items.Slot) is
   begin
      Writing.Apply_Source_Command (Self.Owner.all, Slot);
   end Toggle_Source;

   overriding
   procedure Open_Sources (Self : in out Writing_Effects; Rank : Positive) is
   begin
      Writing.Open_Sources (Self.Owner.all, Rank);
   end Open_Sources;

   overriding
   procedure Toggle_Dictation (Self : in out Writing_Effects; Slot : Items.Slot) is
   begin
      Canvas_Items.Toggle_Dictation (Self.Owner.all, Slot);
   end Toggle_Dictation;

   overriding
   procedure Use_Tool (Self : in out Writing_Effects; Rank : Positive; Tool : Positive) is
   begin
      Writing.Tool_Used (Self.Owner.all, Rank, Tool);
   end Use_Tool;

   overriding
   procedure Follow_Link (Self : in out Writing_Effects; Rank : Positive) is
   begin
      Writing.Link_Followed (Self.Owner.all, Rank);
   end Follow_Link;

   overriding
   procedure Ask_Link (Self : in out Writing_Effects; Rank : Positive) is
   begin
      Writing.Link_Asked (Self.Owner.all, Rank);
   end Ask_Link;

   overriding
   procedure Begin_Page_Title (Self : in out Writing_Effects; Rank : Positive) is
   begin
      Writing.Begin_Page_Title (Self.Owner.all, Rank);
   end Begin_Page_Title;

   overriding
   procedure End_Page_Title (Self : in out Writing_Effects; Rank : Positive) is
   begin
      Writing.End_Page_Title (Self.Owner.all, Rank);
   end End_Page_Title;

   overriding
   procedure Open_Section_Menu (Self : in out Writing_Effects; Rank : Positive) is
   begin
      Section_Links.Open_Page_Menu (Self.Owner.all, Rank);
   end Open_Section_Menu;

   overriding
   procedure Select_Row (Self : in out Writing_Effects; Row : Positive) is
   begin
      Writing.Select_Row (Self.Owner.all, Row);
   end Select_Row;

   overriding
   procedure Rename_Row (Self : in out Writing_Effects; Row : Positive) is
   begin
      Writing.Rename_Row (Self.Owner.all, Row);
   end Rename_Row;

   overriding
   procedure End_Name_Edit (Self : in out Writing_Effects) is
   begin
      Writing.End_Name_Edit (Self.Owner.all);
   end End_Name_Edit;

   overriding
   procedure End_Source_Name_Edit (Self : in out Writing_Effects) is
   begin
      Writing.End_Source_Name_Edit (Self.Owner.all);
   end End_Source_Name_Edit;

   overriding
   function Export_Available (Self : Publishing_Effects) return Boolean is
      use type SDL3.Dialogs.States;
   begin
      return SDL3.Windows.Is_Open (Self.Owner.Host.Win) and then SDL3.Dialogs.State /= SDL3.Dialogs.Waiting;
   end Export_Available;

   overriding
   function Copy_Available (Self : Publishing_Effects) return Boolean is
      use type Widgets.Clipboard_Access;
   begin
      return Widgets.Clipboard (Self.Owner.Publish_View.Copy) /= null;
   end Copy_Available;

   overriding
   function Render (Self : Publishing_Effects; Which : Publish_VM.Formats) return String
   is (Writing.Rendered (Self.Owner.all, Which));

   overriding
   function Clock (Self : Publishing_Effects) return Pomarine.Events.Milliseconds is
      pragma Unreferenced (Self);
   begin
      return Pomarine.Events.Ticks;
   end Clock;

   overriding
   procedure Ask_Export (Self : in out Publishing_Effects; Which : Publish_VM.Formats) is
   begin
      SDL3.Dialogs.Reset;
      SDL3.Dialogs.Save_File
        (Self.Owner.Host.Win,
         Publish_VM.Label (Which),
         Publish_VM.Extension (Which),
         "Export." & Publish_VM.Extension (Which));
   end Ask_Export;

   overriding
   procedure Export_Result
     (Self : in out Publishing_Effects; State : out Publish_VM.Export_States; Path : out Long_Texts.Text)
   is
      pragma Unreferenced (Self);
   begin
      Path := Long_Texts.Null_Text;
      case SDL3.Dialogs.State is
         when SDL3.Dialogs.Waiting                                             =>
            State := Publish_VM.Waiting;

         when SDL3.Dialogs.Chosen                                              =>
            State := Publish_VM.Chosen;
            Path := Long_Texts.To_Text (SDL3.Dialogs.Path);
            SDL3.Dialogs.Reset;

         when SDL3.Dialogs.Idle | SDL3.Dialogs.Cancelled | SDL3.Dialogs.Failed =>
            State := Publish_VM.Cancelled;
            SDL3.Dialogs.Reset;
      end case;
   end Export_Result;

   overriding
   procedure Copy_Text (Self : in out Publishing_Effects; Words : String; Succeeded : out Boolean) is
      use type Widgets.Clipboard_Access;
      Board : constant Widgets.Clipboard_Access := Widgets.Clipboard (Self.Owner.Publish_View.Copy);
   begin
      Succeeded := False;
      if Board /= null then
         Board.Set_Text (Words);
         Succeeded := Board.Text = Words;
      end if;
   end Copy_Text;

   overriding
   procedure Turned (Self : in out Publish_Watch) is
   begin
      if Pomarine.View_Models.Changed (Self.Seen, Publish_VM.Version (Self.Owner.Publish_View.Options)) then
         Writing.Synchronize_Publish (Self.Owner.all);
      end if;
   end Turned;

   overriding
   procedure Home_Changed (Self : in out Home_Effects) is
   begin
      Recent.Sync (Self.Owner.all);
   end Home_Changed;

   overriding
   function Inspect
     (Self : Grammar_Effects; What : Grammar_VM.Card_Command; Index : Natural) return Grammar_VM.Card_State
   is (Grammar.Inspect (Self.Owner.all, What, Index));

   overriding
   procedure Perform (Self : in out Grammar_Effects; What : Grammar_VM.Card_Command; Index : Natural) is
   begin
      Grammar.Perform (Self.Owner.all, What, Index);
   end Perform;

   overriding
   procedure Entry_Ended (Self : in out Grammar_Effects; Accepted : Boolean) is
   begin
      Grammar.Entry_Ended (Self.Owner.all, Accepted);
   end Entry_Ended;

   overriding
   procedure Dialog_Changed (Self : in out Confirm_Effects) is
   begin
      Deletion.Sync (Self.Owner.all);
   end Dialog_Changed;

   overriding
   procedure Answered (Self : in out Confirm_Effects; Said : Confirm_VM.Answer) is
   begin
      Deletion.Answered (Self.Owner.all, Said);
   end Answered;

   overriding
   procedure Going_To_Execute (Self : in out Nav_Effects; What : Nav_VM.Command; Index : Natural) is
      pragma Unreferenced (Index);
   begin
      Navigation.Going_To_Execute (Self.Owner.all, What);
   end Going_To_Execute;

   overriding
   procedure Executed (Self : in out Nav_Effects; What : Nav_VM.Command; Index : Natural) is
   begin
      Navigation.Executed (Self.Owner.all, What, Index);
   end Executed;

   overriding
   procedure Done (Self : in out Settings_Effects; What : Settings_VM.Command) is
   begin
      Settings_View.Done (Self.Owner.all, What);
   end Done;

   overriding
   function New_Picture_Seed (Self : in out Settings_Effects) return Natural is
   begin
      return Settings_View.New_Picture_Seed (Self.Owner.all);
   end New_Picture_Seed;

   overriding
   procedure Ask_To_Delete (Self : in out Settings_Effects; Size : String) is
   begin
      Settings_View.Confirm_Delete (Self.Owner.all, Size);
   end Ask_To_Delete;

   overriding
   procedure Handle_Event
     (Self : in out Responder; Source : in out Pomarine.Widgets.Widget'Class; Event : Pomarine.Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
   begin
      Responses.Perform (Self.Owner.all, Event);
   end Handle_Event;

   procedure Open_Screen (Item : in out Session; Region : Form_Kinds) is
   begin
      Open (Item.Forms (Region), Item.Root.Widgets'Unchecked_Access, Region);
   end Open_Screen;

   procedure Sync_Screen (Item : Session; Region : Form_Kinds) is
   begin
      Pomarine.UI.Synchronize (Item.Forms (Region).Screen.all);
   end Sync_Screen;

   function View_Mode (Item : Session) return Modes
   is (Modes (Nav_VM.Mode (Item.Nav_Model.Model)));

   function Open_Key (Item : Session) return Projects.Id
   is (Nav_VM.Project_Key (Item.Nav_Model.Model));

   function Items_Listed (Item : Session) return Boolean
   is (Nav_VM.Is_Listing (Item.Nav_Model.Model));

   function Takes_Gestures (Item : Session) return Boolean
   is (Nav_VM.Takes_Gestures (Item.Nav_Model.Model));

   overriding
   procedure Make_Room (Self : in out Room_Maker; Slots : Positive) is
   begin
      Build.Reserve_Items (Self.Owner.all, Slots);
   end Make_Room;

   overriding
   procedure Apply (Self : in out List_Surface; What : Canvas_VM.Command; Slot : Items.Slot) is
   begin
      case What is
         when Canvas_VM.Show_Item   =>
            Canvas_Items.Reveal (Self.Owner.all, Slot);

         when Canvas_VM.Open_Item   =>
            Canvas_Items.Set_State (Self.Owner.all, Slot, Items.Open);

         when Canvas_VM.Close_Item  =>
            Canvas_Items.Set_State (Self.Owner.all, Slot, Items.Closed);

         when Canvas_VM.Remove_Item =>
            Canvas_Items.Remove (Self.Owner.all, Slot);

         when others                =>
            raise Program_Error;
      end case;
   end Apply;

   overriding
   function Valid (Self : Search_Finder; Where : Search_VM.Context) return Boolean
   is (Search.Valid (Self.Owner.all, Where));

   overriding
   procedure Refresh
     (Self : in out Search_Finder; Where : Search_VM.Context; Term : String; Found : out Search_VM.Result) is
   begin
      Search.Refresh_Engine (Self.Owner.all, Where, Term, Found);
   end Refresh;

   overriding
   procedure Advance (Self : in out Search_Finder; Where : Search_VM.Context; Backwards : Boolean) is
   begin
      Search.Step_Engine (Self.Owner.all, Where, Backwards);
   end Advance;

   overriding
   procedure Clear (Self : in out Search_Finder; Where : Search_VM.Context) is
   begin
      Search.Clear_Engine (Self.Owner.all, Where);
   end Clear;

   --  What the list of items shows

   overriding
   function Count (Self : Item_Rows) return Natural
   is (Item_List_VM.Count (Self.Owner.Item_List.Model));

   overriding
   function Version (Self : Item_Rows) return Natural
   is (Natural (Item_List_VM.Version (Self.Owner.Item_List.Model) mod 2**31));

   overriding
   function Row_Id (Self : Item_Rows; Row : Positive) return Positive
   is (Item_List_VM.Row_Id (Self.Owner.Item_List.Model, Row));
   --  Selection follows the item across row movement and is not inherited by a slot's replacement.

   overriding
   procedure Describe_Row (Self : Item_Rows; Row : Positive; Content : out Pomarine.Models.Row_Content) is
   begin
      Listing.Describe (Self.Owner.all, Row, Content);
   end Describe_Row;

   --  Events

   function Cursor (Item : Session) return SDL3.Cursors.Kind
   is (if Item.Grammar_Checks.Over_Diagnostic then SDL3.Cursors.Pointer else Widgets.Wanted_Cursor (Item.Root.Widgets));

   function Title_Strip_Height (Item : Session) return Float
   is (if Screen (Item) = Project or else Settings_VM.Is_Showing (Item.Choices.Model)
       then Style.Toolbar_Size
       else Style.Header_Size);
   --  How tall the bar across the top is, on this screen.

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

   function In_Title_Strip (Item : Session; Y : Float) return Boolean
   is (Y >= 0.0 and then Y < Title_Strip_Height (Item));
   --  Whether a point is in the bar across the top, or over the home
   --  screen, where the window is moved from. The window has no native
   --  title bar drag (see Open_Window), so this is what moves it.

   procedure Track_Window (Item : in out Session; Event : Pomarine.Events.Event; Taken : Boolean) is
      Width, Height : Integer;
      Found         : Boolean;
   begin
      case Event.Kind is
         when Pomarine.Events.Mouse_Down =>
            --  A press on a button is for the button, not for a drag.
            if Event.Button = 1 and then not Taken and then In_Title_Strip (Item, Event.Mouse_Y) then
               if Event.Clicks >= 2 then
                  SDL3.Windows.Zoom (Item.Host.Win);  --  as a title bar does

               else
                  SDL3.Windows.Get_Geometry
                    (Item.Host.Win, Item.Shell.Grab_Left, Item.Shell.Grab_Top, Width, Height, Found);
                  if Found then
                     SDL3.Windows.Global_Pointer (Item.Shell.Grab_X, Item.Shell.Grab_Y);
                     Item.Shell.Moving := True;
                  end if;
               end if;
            end if;

         when Pomarine.Events.Mouse_Move =>
            if Item.Shell.Moving then
               declare
                  X, Y : Float;
               begin
                  SDL3.Windows.Global_Pointer (X, Y);
                  SDL3.Windows.Set_Position
                    (Item.Host.Win,
                     Item.Shell.Grab_Left + Integer (Float'Rounding (X - Item.Shell.Grab_X)),
                     Item.Shell.Grab_Top + Integer (Float'Rounding (Y - Item.Shell.Grab_Y)));
               end;
            end if;

         when Pomarine.Events.Mouse_Up   =>
            if Event.Button = 1 then
               Item.Shell.Moving := False;
            end if;

         when others                     =>
            null;
      end case;
   end Track_Window;

   procedure Handle (Item : in out Session; Event : Pomarine.Events.Event) is
      Handled : Boolean := False;
   begin
      Search.Update (Item);
      if Nav_VM.Takes_Search (Item.Nav_Model.Model) then
         Search.Handle (Item, Event, Handled);
         if Handled then
            Search.Update (Item);
            return;
         end if;
      end if;
      if Item.Context.Context_Kind /= No_Context
        and then Event.Kind = Pomarine.Events.Key_Down
        and then Event.Key = Pomarine.Events.Key_Escape
      then
         Writing.Dismiss_Context (Item);
         return;
      end if;
      if (Item.Grammar_Checks.Showing or else Item.Grammar_Checks.Inline_Open)
        and then Event.Kind = Pomarine.Events.Key_Down
        and then Event.Key = Pomarine.Events.Key_Escape
      then
         Grammar.Close (Item);
         return;
      end if;
      case Event.Kind is
         when Pomarine.Events.Quit          =>
            if Screen (Item) = Project then
               Canvas_Items.Save_All (Item);
            end if;
            Item.Shell.Done := True;

         when Pomarine.Events.Redraw        =>
            Widgets.Invalidate_All (Item.Root.Widgets);

         when Pomarine.Events.Theme_Changed =>
            --  Only the system's appearance can change by itself.
            if Settings_VM.Theme (Item.Choices.Model) = Preferences.System then
               Settings_View.Apply_Theme (Item);
            end if;

         when others                        =>
            if Nav_VM.Is_Over (Item.Nav_Model.Model) then
               --  What is over the screen is all that takes events; Escape puts it away.
               if Event.Kind = Pomarine.Events.Key_Down and then Event.Key = Pomarine.Events.Key_Escape then
                  Navigation.Do_Command (Item, Nav_VM.Dismiss);
                  Deletion.Sync (Item);
                  return;
               end if;
            --  The text is saved only from a project.
            elsif Screen (Item) = Project
              and then Event.Kind = Pomarine.Events.Key_Down
              and then Event.Command
              and then Event.Key = Pomarine.Events.Key_S
            then
               Save (Item);
               Handled := True;
            end if;
            if not Handled then
               Grammar.Before_Event (Item, Event);
               if Screen (Item) = Project and then Event.Kind = Pomarine.Events.Mouse_Down then
                  Canvas_Items.Pressed (Item, Event.Mouse_X, Event.Mouse_Y);
                  Writing.Pressed (Item, Event.Mouse_X, Event.Mouse_Y);
                  Section_Links.Pressed (Item, Event.Mouse_X, Event.Mouse_Y);
                  Outlines.Pressed (Item, Event.Mouse_X, Event.Mouse_Y);
                  if Event.Button = 3 and then not Nav_VM.Is_Over (Item.Nav_Model.Model) then
                     Writing.Open_Context (Item, Event.Mouse_X, Event.Mouse_Y, Handled);
                  end if;
               end if;
               if not Handled then
                  Widgets.Dispatch (Item.Root.Widgets, Event, Handled);
                  if Handled then
                     Menus.Key_Taken (Item, Event);
                  end if;
                  if Item.Shell.Windowed then
                     Track_Window (Item, Event, Handled);
                  end if;
                  Grammar.Released (Item, Event);
               end if;
               Grammar.Update_Cursor (Item);
               Show_Cursor (Item);
            end if;
            if Screen (Item) = Project then
               Canvas_Items.Update (Item, Event.Time);
               Search.Update (Item);
            end if;
      end case;
   end Handle;

   function Screen (Item : Session) return Screens
   is (Screens (Nav_VM.Screen (Item.Nav_Model.Model)));

   --  The file

   function Title (Item : Session) return String
   is (case Screen (Item) is
         when Home    => "bonxie",
         when Project =>
           (if Nav_VM.Name (Item.Nav_Model.Model) /= ""
            then Nav_VM.Name (Item.Nav_Model.Model)
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
            "Could not save "
            & Scripts.File_Name (Item.Host.Script)
            & ": "
            & Ada.Exceptions.Exception_Message (Problem));
   end Save;

   procedure Show_Title (Item : in out Session);
   --  In the window's title bar, if it has changed.

   procedure Show_Title (Item : in out Session) is
      Now : constant String := Title (Item);
   begin
      if Now /= To_String (Item.Shell.Shown_Title) then
         SDL3.Windows.Set_Title (Item.Host.Win, Now);
         Labels.Set_Text (Item.Root.Header_Title, Now);
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
        (Item.Host.Win,
         "bonxie",
         Style.Window_Width,
         Style.Window_Height,
         Resizable    => True,
         High_Density => True,
         Hidden       => Hidden);
      Item.Shell.Density := SDL3.Windows.Pixel_Density (Item.Host.Win);
      SDL3.Windows.Extend_Into_Title_Bar (Item.Host.Win);
      --  The bar is dragged by the program (see Track_Window), not by the
      --  system, so that its buttons are only clicked.
      SDL3.Windows.Set_Movable (Item.Host.Win, False);
      Create (Item.Host.Target, Item.Host.Win, VSync => VSync);
      Pomarine.Accessibility.Attach (Item.Host.Assistive, Item.Host.Win);
      Build.Set_Up (Item, Source, File_Name, Store);
      Widgets.Set_Title (Item.Root.Widgets, "bonxie");
      Menus.Build (Item);
      Settings_View.Apply_Theme (Item);
      SDL3.Windows.Start_Text_Input (Item.Host.Win);
   end Open_Window;

   procedure Draw_Frame (Item : in out Session) renames Painting.Draw;

   procedure Paint_Frame (Item : in out Session) renames Painting.Paint;

   Capture_Poll : constant := 100;
   --  Milliseconds between looks for a picture being taken.

   procedure Wait_And_Handle (Item : in out Session) is
      Event   : Pomarine.Events.Event;
      Timeout : Integer := -1;  --  none

      procedure Wake_In (Milliseconds : Integer) is
      begin
         Timeout :=
           (if Timeout < 0
            then Integer'Max (0, Milliseconds)
            else Integer'Min (Timeout, Integer'Max (0, Milliseconds)));
      end Wake_In;
   begin
      --  Nothing to do until something happens, except to blink a caret.
      Tick (Item, Pomarine.Events.Ticks);
      if Widgets.Until_Update (Item.Root.Widgets) >= 0 then
         Wake_In (Widgets.Until_Update (Item.Root.Widgets));
      end if;
      if Grammar.Until_Update (Item, Pomarine.Events.Ticks) >= 0 then
         Wake_In (Grammar.Until_Update (Item, Pomarine.Events.Ticks));
      end if;
      if Writing.Until_Copy_Ends (Item) >= 0 then
         Wake_In (Writing.Until_Copy_Ends (Item));
      end if;
      --  A picture of a page is on its way: look for it now and then.
      if Screen (Item) = Project and then Canvas_Items.Capturing (Item) then
         Wake_In (Capture_Poll);
      end if;
      --  So is the file for the speech model: look at how far on it is.
      if Settings_View.Downloading (Item) or else Updates.Busy (Item) then
         Wake_In (Capture_Poll);
      end if;
      --  A worker result or popout update collected by Tick needs a
      --  frame even when no more background work remains to poll.
      if Widgets.Needs_Paint (Item.Root.Widgets) then
         Wake_In (0);
      end if;

      if Pomarine.Events.Wait (Event, Timeout_MS => Timeout) then
         Handle (Item, Event);
         while Pomarine.Events.Poll (Event) loop
            Handle (Item, Event);
         end loop;
      end if;
      --  Work other tasks have posted (Pomarine.Application.Post).
      Pomarine.Application.Run_Posted;

      Tick (Item, Pomarine.Events.Ticks);
   end Wait_And_Handle;

   --  Without a window

   function Pixels (Points : Positive; Density : Float) return Positive
   is (Positive (Float (Points) * Density));

   procedure Open
     (Item      : in out Session;
      Source    : String;
      Width     : Positive;
      Height    : Positive;
      Density   : Float := 2.0;
      File_Name : String := "") is
   begin
      Item.Shell.Density := Density;
      Create_Offscreen (Item.Host.Target, Pixels (Width, Density), Pixels (Height, Density));
      Build.Set_Up (Item, Source, File_Name, Projects.Memory);
      Settings_View.Apply_Theme (Item);
   end Open;

   function Is_Open (Item : Session) return Boolean
   is (Widgets.Has_Root (Item.Root.Widgets));

   function Text (Item : Session) return String
   is (Scripts.Text (Item.Host.Script));

   function Widget_Tree (Item : aliased in out Session) return access Pomarine.Widgets.Tree
   is (Item.Root.Widgets'Unchecked_Access);

   function Clipboard_Text (Item : Session) return String
   is (Widgets.Clipboard (Item.Publish_View.Copy).Text);

   function Published_As (Item : Session; Which : Publish_VM.Formats) return String
   is (Writing.Rendered (Item, Which));

   procedure Tick (Item : in out Session; Now : Pomarine.Events.Milliseconds) is
   begin
      Publish_VM.Poll (Item.Publish_View.Options);
      Widgets.Update (Item.Root.Widgets, Now);
      Recent.Sync (Item);
      Deletion.Sync (Item);
      Updates.Tick (Item);
      if Updates.Leaving (Item) and then not Item.Shell.Done then
         --  The script that puts the new version in place is waiting for this to end, as a quit does.
         if Screen (Item) = Project then
            Canvas_Items.Save_All (Item);
         end if;
         Item.Shell.Done := True;
      end if;
      if Screen (Item) = Project then
         Canvas_Items.Update (Item, Now);
         if Items_Listed (Item) then
            Listing.Refresh (Item);
         end if;
         Outlines.Update (Item);
         Section_Links.Update (Item);
      end if;
      --  After the views have taken what was typed in them: the name of the project, for one.
      Navigation.Sync (Item);
      Grammar.Update (Item, Now);
      if Settings_VM.Is_Showing (Item.Choices.Model) or else Settings_View.Downloading (Item) then
         Settings_View.Update (Item);
      end if;
      Grammar.Update_Cursor (Item);
      Show_Cursor (Item);
   end Tick;

   procedure Resize (Item : in out Session; Width, Height : Positive) is
   begin
      Grammar.Close_Inline (Item);
      SDL3.Windows.Renderers.Resize
        (Item.Host.Target, Pixels (Width, Item.Shell.Density), Pixels (Height, Item.Shell.Density));
      --  Which loses what was drawn.
      Widgets.Invalidate_All (Item.Root.Widgets);
      Widgets.Layout (Item.Root.Widgets, Item.Host.Target);
   end Resize;

   procedure Render (Item : in out Session; Result : in out SDL3.Windows.Renderers.Images.Image) is
   begin
      --  Offscreen there is nothing to present to.
      Painting.Paint (Item);
      SDL3.Windows.Renderers.Images.Read (Result, Item.Host.Target);
   end Render;

   --  Where the window was left

   function Geometry_Path return String
   is (Ada.Directories.Containing_Directory (Projects.Default_Path) & "/window");

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
         Files.Write (Geometry_Path, X'Image & Y'Image & W'Image & H'Image);
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
        (Item,
         Source,
         File_Name,
         VSync =>
           Ada.Environment_Variables.Exists ("BONXIE_VSYNC")
           and then Ada.Environment_Variables.Value ("BONXIE_VSYNC") = "1");
      Restore_Geometry (Item);
      if Settings_VM.VSync (Item.Choices.Model) then
         SDL3.Windows.Renderers.Set_VSync (Item.Host.Target, True);
      end if;

      --  The redraw watch also draws: the OS blocks the event loop
      --  during a live resize, and only repainting from inside the event
      --  watch avoids a stretched frame.
      Redraws.Install (Watcher, Item);

      while not Item.Shell.Done loop
         Show_Title (Item);
         Painting.Fit_Density (Item);
         Painting.Fit_Buttons (Item);
         if Widgets.Needs_Paint (Item.Root.Widgets) then
            Painting.Draw (Item);
         end if;
         Wait_And_Handle (Item);
         Menus.Update (Item);
         Browsers.Update (Item);
         --  The person's setting for less movement is theirs to change at any
         --  time.
         Widgets.Set_Reduced_Motion (Item.Root.Widgets, Pomarine.System_Settings.Reduce_Motion);
         --  What an assistive technology asks, and what it is told.
         if Pomarine.Accessibility.Is_Attached (Item.Host.Assistive) then
            Pomarine.Accessibility.Update (Item.Host.Assistive, Item.Root.Widgets);
         end if;
      end loop;
      Save_Geometry (Item);
      --  Not to go on fetching what no one will use.
      Speech.Models.Cancel;
      Updates.Stop (Item);
   end Run;

end View;
