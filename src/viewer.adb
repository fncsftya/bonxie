with Ada.Command_Line;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Numerics.Elementary_Functions;
with Ada.Text_IO;
with SDL3.Events.Redraws;
with SDL3.Windows.Renderers;
with UI.Text_Areas;
with UI.Themes;
with UI.Widgets;
with Yoga.Nodes;

package body Viewer is

   package Widgets renames UI.Widgets;
   package Editors renames UI.Widgets.Editors;
   package Panels renames UI.Widgets.Panels;
   package Buttons renames UI.Widgets.Buttons;
   package Labels renames UI.Widgets.Labels;
   package Text_Fields renames UI.Widgets.Text_Fields;
   package Docs renames Texts.Documents;

   use Ada.Strings.Unbounded;
   use type Projects.Id;
   use type SDL3.Events.Event_Kind;
   use type SDL3.Events.Key_Code;
   use type SDL3.Events.Milliseconds;
   use SDL3.Windows.Renderers;

   --  The page

   Family     : constant String := "Georgia";
   Font_Size  : constant Float := 18.0;
   Page_Width : constant Float := 640.0;  --  layout units
   Para_Gap   : constant Float := 8.0;

   --  The window

   Window_Width  : constant := 1000;
   Window_Height : constant := 800;
   Toolbar_Size  : constant Float := 32.0;
   Margin        : constant Float := 16.0;
   --  Around the text area.

   --  The home screen, in points

   Home_Margin   : constant Float := 32.0;
   Title_Height  : constant Float := 28.0;
   Row_Height    : constant Float := 36.0;
   Row_Gap       : constant Float := 8.0;
   Rename_Width  : constant Float := 44.0;
   Delete_Width  : constant Float := 44.0;
   --  Of the buttons with icons.
   Dialog_Width  : constant Float := 320.0;
   Dialog_Pad    : constant Float := 24.0;
   Dialog_Line   : constant Float := 24.0;
   Dialog_Button_Width  : constant Float := 96.0;
   Dialog_Button_Height : constant Float := 36.0;
   Outline       : constant Float := 1.0;
   Ok_Width      : constant Float := 48.0;
   Cancel_Width  : constant Float := 64.0;
   Edit_Size     : constant Float := 14.0;
   --  Of the text in the field to rename a project.
   Button_Height : constant Float := 44.0;
   Action_Width  : constant Float := 240.0;
   Gap           : constant Float := 12.0;
   Close_Width   : constant Float := 72.0;
   Close_Height  : constant Float := 24.0;
   Bar_Margin    : constant Float := 4.0;
   Title_Margin  : constant Float := 12.0;
   --  Between the Close button and the toolbar's edge.

   No_Projects : constant String := "No projects yet";

   Colors  : constant UI.Themes.Theme := UI.Themes.Light;
   Toolbar : constant Color := (52, 54, 66, 255);

   --  Zooming

   Min_Zoom       : constant Float := 0.25;
   Max_Zoom       : constant Float := 8.0;
   Zoom_Per_Notch : constant Float := 1.1;
   Settle_MS      : constant := 120;
   --  How long the zoom must hold still to count as settled.

   --  The icons

   function Icon_Directory return String;
   --  Where the SVG files are, in share/bonxie/icons: beside the
   --  executable's folder, as installed or built in place; or from the
   --  current directory, as the tests run in a folder of the project.
   --  "" if none is found.

   function Icon_Directory return String is
      Share : constant String := "share/bonxie/icons";

      function Program_Folder return String is
      begin
         return Ada.Directories.Containing_Directory
                  (Ada.Command_Line.Command_Name);
      exception
         when Ada.Directories.Use_Error | Ada.Directories.Name_Error =>
            return ".";
      end Program_Folder;

      Beside : constant String := Program_Folder & "/../" & Share;
   begin
      if Ada.Directories.Exists (Beside) then
         return Beside;
      elsif Ada.Directories.Exists (Share) then
         return Share;
      elsif Ada.Directories.Exists ("../" & Share) then
         return "../" & Share;
      else
         return "";
      end if;
   end Icon_Directory;

   --  Drawing

   procedure Paint (Item : in out Session);
   --  Draw what is shown, but do not present it.

   procedure Paint (Item : in out Session) is
   begin
      UI.Line_Texts.Begin_Frame (Item.Lines);
      --  The target keeps what is drawn on it, offscreen and in a window,
      --  so that only what has changed need be drawn again.
      Widgets.Paint
        (Item.Widgets, Item.Target, Colors,
         Retained => Keeps_Frame (Item.Target));
   end Paint;

   procedure Tell_Input_Method (Item : in out Session);
   --  Where the caret is, so that an input method can show its choices
   --  beside it.

   procedure Tell_Input_Method (Item : in out Session) is
      X, Y, Width, Height : Float;
   begin
      if Editors.Is_Focused (Item.Area) then
         Editors.Caret_Box (Item.Area, X, Y, Width, Height);
         declare
            Across : constant Integer := Integer (X / Item.Density);
         begin
            --  Once a line, not once a character: the input method's
            --  choices would jump about as it is typed into.
            if Across /= Item.Input_Area then
               Item.Input_Area := Across;
               SDL3.Windows.Set_Text_Input_Area
                 (Item.Win, Across, Integer (Y / Item.Density),
                  Integer (Float'Ceiling (Width / Item.Density)),
                  Integer (Float'Ceiling (Height / Item.Density)));
            end if;
         end;
      end if;
   end Tell_Input_Method;

   procedure Draw (Item : in out Session) is
      Resized : Boolean;
   begin
      --  A window that has changed size has a new image to draw to.
      Fit (Item.Target, Resized);
      if Resized then
         Widgets.Invalidate_All (Item.Widgets);
      end if;
      Paint (Item);
      Present (Item.Target);
      Tell_Input_Method (Item);
   end Draw;

   package Redraws is new SDL3.Events.Redraws (Session, Draw);

   --  Zooming

   procedure Zoom_By (Item : in out Session; Factor : Float) is
      Zoom : constant Float :=
        Float'Min (Max_Zoom, Float'Max (Min_Zoom, Item.Zoom * Factor));
   begin
      if Zoom /= Item.Zoom then
         Item.Zoom := Zoom;
         Item.Settled := False;
         Widgets.Set_Settled (Item.Widgets, False);
         Editors.Set_Zoom (Item.Area, Zoom);
         --  Before the next event, which may be over the text.
         Widgets.Layout (Item.Widgets, Item.Target);
      end if;
   end Zoom_By;

   --  Events

   procedure Handle_Zoom
     (Item : in out Session; Event : SDL3.Events.Event; Handled : out Boolean);
   --  Command with the wheel, =, - or 0.

   procedure Handle_Zoom
     (Item : in out Session; Event : SDL3.Events.Event; Handled : out Boolean)
   is
   begin
      Handled := True;
      Item.Zoomed_At := Event.Time;
      if Event.Kind = SDL3.Events.Mouse_Wheel and then Event.Command then
         Zoom_By
           (Item,
            Ada.Numerics.Elementary_Functions."**"
              (Zoom_Per_Notch, Event.Wheel_Y));
      elsif Event.Kind /= SDL3.Events.Key_Down or else not Event.Command then
         Handled := False;
      elsif Event.Key = SDL3.Events.Key_Equals then
         Zoom_By (Item, Zoom_Per_Notch);
      elsif Event.Key = SDL3.Events.Key_Minus then
         Zoom_By (Item, 1.0 / Zoom_Per_Notch);
      elsif Event.Key = SDL3.Events.Key_0 then
         Zoom_By (Item, 1.0 / Item.Zoom);
      else
         Handled := False;
      end if;
   end Handle_Zoom;

   procedure Close_Dialog (Item : in out Session);
   --  Hide the dialog to confirm deleting: nothing is deleted.

   procedure Take_Clicks (Item : in out Session);
   --  Do what the buttons that have been clicked are for.

   procedure Handle (Item : in out Session; Event : SDL3.Events.Event) is
      Handled : Boolean := False;
   begin
      case Event.Kind is
         when SDL3.Events.Quit =>
            Item.Done := True;
         when SDL3.Events.Redraw =>
            Widgets.Invalidate_All (Item.Widgets);
         when others =>
            if Item.Deleting /= 0 then
               --  The dialog is all that takes events.
               if Event.Kind = SDL3.Events.Key_Down
                 and then Event.Key = SDL3.Events.Key_Escape
               then
                  Close_Dialog (Item);
                  return;
               end if;
            --  The document is shown only in a project.
            elsif Item.Shown = Project then
               Handle_Zoom (Item, Event, Handled);
               if not Handled and then Event.Kind = SDL3.Events.Key_Down
                 and then Event.Command and then Event.Key = SDL3.Events.Key_S
               then
                  Save (Item);
                  Handled := True;
               end if;
            end if;
            if not Handled then
               Widgets.Dispatch (Item.Widgets, Event, Handled);
               Take_Clicks (Item);
            end if;
      end case;
   end Handle;

   --  The screens

   function Screen (Item : Session) return Screens is (Item.Shown);

   function Current_Project (Item : Session) return Projects.Id is
     (Item.Current);

   procedure Cancel_Edit (Item : in out Session);
   --  Put back the buttons of the project being renamed, if any, in place
   --  of the field.

   procedure Cancel_Edit (Item : in out Session) is
      Row : constant Natural := Item.Editing;
   begin
      if Row /= 0 then
         Item.Editing := 0;
         Widgets.Remove (Item.Edit_Panel);
         Widgets.Set_Visible (Item.Recent_Rows (Row), True);
         Widgets.Set_Visible (Item.Rename_Buttons (Row), True);
         Widgets.Set_Visible (Item.Delete_Buttons (Row), True);
         Widgets.Layout (Item.Widgets, Item.Target);
      end if;
   end Cancel_Edit;

   procedure Refresh_Recent (Item : in out Session);
   --  List the most recently updated projects, and stop any being
   --  renamed.

   procedure Refresh_Recent (Item : in out Session) is
   begin
      Cancel_Edit (Item);
      Projects.Recent (Item.Store, Item.Listed);
      for I in Item.Recent_Rows'Range loop
         if I <= Item.Listed.Count then
            declare
               Name : constant String :=
                 Projects.Titles.To_String (Item.Listed.Items (I).Title);
            begin
               --  Cut to fit the button.
               Buttons.Set_Label
                 (Item.Recent_Rows (I),
                  Name (Name'First ..
                        Name'First - 1
                        + Natural'Min (Name'Length, Buttons.Label_Capacity)));
            end;
            Item.Row_Keys (I) := Item.Listed.Items (I).Key;
         end if;
         Widgets.Set_Visible (Item.Row_Panels (I), I <= Item.Listed.Count);
      end loop;
      Widgets.Set_Visible (Item.No_Rows, Item.Listed.Count = 0);
   end Refresh_Recent;

   function Is_Renaming (Item : Session) return Boolean is
     (Item.Editing /= 0);

   function Row_Title (Item : Session; Row : Positive) return String is
     (if Row <= Item.Listed.Count then Buttons.Label (Item.Recent_Rows (Row))
      else "");

   procedure Begin_Rename (Item : in out Session; Row : Positive)
     with Pre => Row <= Item.Listed.Count;
   --  Put a field with the project's title in its row, in place of its
   --  buttons, with the title selected, to type over.

   procedure Begin_Rename (Item : in out Session; Row : Positive) is
      use Yoga.Nodes;
      Pixels : constant Float := Item.Density;
   begin
      Cancel_Edit (Item);
      Item.Editing := Row;
      Widgets.Set_Visible (Item.Recent_Rows (Row), False);
      Widgets.Set_Visible (Item.Rename_Buttons (Row), False);
      Widgets.Set_Visible (Item.Delete_Buttons (Row), False);

      --  Built again each time, top down: it is taken out of the row it
      --  was in, with what is in it.
      Widgets.Add (Item.Row_Panels (Row), Item.Edit_Panel);
      Widgets.Add (Item.Edit_Panel, Item.Edit_Field);
      Widgets.Add (Item.Edit_Panel, Item.Ok_Button);
      Widgets.Add (Item.Edit_Panel, Item.Cancel_Button);
      Set_Flex_Direction (Widgets.Node (Item.Edit_Panel), Yoga.Row);
      Set_Flex_Grow (Widgets.Node (Item.Edit_Panel), 1.0);
      Set_Width (Widgets.Node (Item.Edit_Panel), 0.0);
      Set_Gap
        (Widgets.Node (Item.Edit_Panel), Yoga.All_Gutters, Row_Gap * Pixels);
      Set_Flex_Grow (Widgets.Node (Item.Edit_Field), 1.0);
      Set_Width (Widgets.Node (Item.Edit_Field), 0.0);
      Set_Width (Widgets.Node (Item.Ok_Button), Ok_Width * Pixels);
      Set_Width (Widgets.Node (Item.Cancel_Button), Cancel_Width * Pixels);

      Docs.Load
        (Item.Edit_Doc,
         Projects.Titles.To_String (Item.Listed.Items (Row).Title));
      Text_Fields.Attach (Item.Edit_Field, Item.Edit_Doc'Unchecked_Access);
      UI.Text_Areas.Select_All
        (Text_Fields.Area (Item.Edit_Field).all);
      Widgets.Focus (Item.Edit_Field);
      Widgets.Layout (Item.Widgets, Item.Target);
   end Begin_Rename;

   procedure Accept_Rename (Item : in out Session);
   --  Give the project being renamed the title in the field, unless it is
   --  nothing.

   procedure Accept_Rename (Item : in out Session) is
      Content : constant String := Docs.Whole (Item.Edit_Doc);
      First   : Positive := Content'First;
      Last    : Natural := Content'Last;
   begin
      --  Not spaces about it.
      while First <= Last and then Content (First) = ' ' loop
         First := First + 1;
      end loop;
      while Last >= First and then Content (Last) = ' ' loop
         Last := Last - 1;
      end loop;
      if Last >= First and then Item.Editing /= 0 then
         Projects.Rename
           (Item.Store, Item.Row_Keys (Item.Editing),
            Content (First .. Natural'Min
                                (Last, First + Projects.Title_Capacity - 1)));
         Refresh_Recent (Item);
         Widgets.Layout (Item.Widgets, Item.Target);
      end if;
   end Accept_Rename;

   function Is_Confirming (Item : Session) return Boolean is
     (Item.Deleting /= 0);

   procedure Confirm_Delete (Item : in out Session; Row : Positive)
     with Pre => Row <= Item.Listed.Count;
   --  Show the dialog to confirm deleting the project of the row.

   procedure Confirm_Delete (Item : in out Session; Row : Positive) is
      Name : constant String :=
        Projects.Titles.To_String (Item.Listed.Items (Row).Title);
   begin
      Cancel_Edit (Item);
      Item.Deleting := Item.Listed.Items (Row).Key;
      Labels.Set_Text
        (Item.Confirm_Name,
         Name (Name'First ..
               Name'First - 1
               + Natural'Min (Name'Length, Labels.Text_Capacity)));
      Widgets.Set_Visible (Item.Overlay, True);
      Widgets.Layout (Item.Widgets, Item.Target);
   end Confirm_Delete;

   procedure Close_Dialog (Item : in out Session) is
   begin
      Item.Deleting := 0;
      Widgets.Set_Visible (Item.Overlay, False);
      Widgets.Layout (Item.Widgets, Item.Target);
   end Close_Dialog;

   procedure Delete_Confirmed (Item : in out Session);
   --  Delete the project the dialog is about, and hide it.

   procedure Delete_Confirmed (Item : in out Session) is
      Key : constant Projects.Id := Item.Deleting;
   begin
      Close_Dialog (Item);
      Projects.Delete (Item.Store, Key);
      Refresh_Recent (Item);
      Widgets.Layout (Item.Widgets, Item.Target);
   end Delete_Confirmed;

   procedure Show_Title_Of_Project (Item : in out Session);
   --  Put the title of the current project on the toolbar.

   procedure Show_Title_Of_Project (Item : in out Session) is
      Found  : Boolean;
      Result : Projects.Project;
   begin
      Projects.Find (Item.Store, Item.Current, Found, Result);
      declare
         Name : constant String :=
           (if Found then Projects.Titles.To_String (Result.Title) else "");
      begin
         --  Cut to fit the label.
         Labels.Set_Text
           (Item.Project_Title,
            Name (Name'First ..
                  Name'First - 1
                  + Natural'Min (Name'Length, Labels.Text_Capacity)));
      end;
   end Show_Title_Of_Project;

   procedure Open_Project (Item : in out Session; Key : Projects.Id) is
   begin
      Cancel_Edit (Item);
      Item.Current := Key;
      Show_Title_Of_Project (Item);
      Item.Shown := Project;
      Widgets.Set_Visible (Item.Home_Panel, False);
      Widgets.Set_Visible (Item.Project_Panel, True);
      Widgets.Focus (Item.Area);
      Widgets.Layout (Item.Widgets, Item.Target);
   end Open_Project;

   procedure New_Project (Item : in out Session) is
   begin
      Open_Project
        (Item, Projects.Create (Item.Store, "Untitled project"));
   end New_Project;

   procedure Close_Project (Item : in out Session) is
   begin
      Item.Shown := Home;
      Item.Current := 0;
      Widgets.Set_Visible (Item.Project_Panel, False);
      Widgets.Set_Visible (Item.Home_Panel, True);
      Refresh_Recent (Item);
      Widgets.Layout (Item.Widgets, Item.Target);
   end Close_Project;

   procedure Add_Project
     (Item    : in out Session;
      Name    : String;
      Updated : Projects.Seconds)
   is
      Key : constant Projects.Id :=
        Projects.Create (Item.Store, Name, Time => Updated);
      pragma Unreferenced (Key);
   begin
      Refresh_Recent (Item);
      Widgets.Layout (Item.Widgets, Item.Target);
   end Add_Project;

   procedure Take_Clicks (Item : in out Session) is
      Clicked : Boolean;
   begin
      --  Only the screen that is shown can have been clicked.
      case Item.Shown is
         when Home =>
            Buttons.Take_Click (Item.New_Button, Clicked);
            if Clicked then
               New_Project (Item);
               return;
            end if;
            if Item.Deleting /= 0 then
               Buttons.Take_Click (Item.Confirm_Delete, Clicked);
               if Clicked then
                  Delete_Confirmed (Item);
                  return;
               end if;
               Buttons.Take_Click (Item.Confirm_Cancel, Clicked);
               if Clicked then
                  Close_Dialog (Item);
               end if;
               return;
            end if;
            --  Settings: nothing yet.
            Buttons.Take_Click (Item.Settings_Button, Clicked);
            if Item.Editing /= 0 then
               declare
                  Entered : Boolean;
               begin
                  Text_Fields.Take_Return (Item.Edit_Field, Entered);
                  Buttons.Take_Click (Item.Ok_Button, Clicked);
                  if Clicked or else Entered then
                     Accept_Rename (Item);
                     return;
                  end if;
               end;
               Buttons.Take_Click (Item.Cancel_Button, Clicked);
               if Clicked then
                  Cancel_Edit (Item);
                  return;
               end if;
            end if;
            for I in Item.Recent_Rows'Range loop
               if Widgets.Is_Shown (Item.Recent_Rows (I)) then
                  Buttons.Take_Click (Item.Recent_Rows (I), Clicked);
                  if Clicked then
                     Open_Project (Item, Item.Row_Keys (I));
                     return;
                  end if;
                  Buttons.Take_Click (Item.Rename_Buttons (I), Clicked);
                  if Clicked then
                     Begin_Rename (Item, I);
                     return;
                  end if;
                  Buttons.Take_Click (Item.Delete_Buttons (I), Clicked);
                  if Clicked then
                     Confirm_Delete (Item, I);
                     return;
                  end if;
               end if;
            end loop;
         when Project =>
            Buttons.Take_Click (Item.Close_Button, Clicked);
            if Clicked then
               Close_Project (Item);
            end if;
      end case;
   end Take_Clicks;

   --  The file

   function Title (Item : Session) return String is
     (case Item.Shown is
         when Home    => "bonxie",
         when Project => Scripts.Title (Item.Script));

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
         Item.Shown_Title := To_Unbounded_String (Now);
      end if;
   end Show_Title;

   --  Running

   procedure Set_Up
     (Item       : in out Session;
      Source     : String;
      File_Name  : String;
      Store_Path : String);
   --  Lay out the window and the script in it, once there is a target.

   procedure Build_Home (Item : in out Session);
   --  Add and style the home screen's widgets.

   procedure Build_Home (Item : in out Session) is
      use Yoga.Nodes;
      Pixels : constant Float := Item.Density;

      procedure Halve (Half : Yoga.Nodes.Node) is
      begin
         Set_Flex_Direction (Half, Yoga.Column);
         Set_Flex_Grow (Half, 1.0);
         Set_Width (Half, 0.0);
         Set_Padding (Half, Yoga.All_Edges, Home_Margin * Pixels);
         Set_Gap (Half, Yoga.All_Gutters, Gap * Pixels);
      end Halve;
   begin
      Widgets.Add (Item.Window_Panel, Item.Home_Panel);
      Widgets.Add (Item.Home_Panel, Item.Recent_Panel);
      Widgets.Add (Item.Recent_Panel, Item.Recent_Title);
      Widgets.Add (Item.Recent_Panel, Item.No_Rows);
      for I in Item.Row_Panels'Range loop
         Widgets.Add (Item.Recent_Panel, Item.Row_Panels (I));
         Widgets.Add (Item.Row_Panels (I), Item.Recent_Rows (I));
         Widgets.Add (Item.Row_Panels (I), Item.Rename_Buttons (I));
         Widgets.Add (Item.Row_Panels (I), Item.Delete_Buttons (I));
      end loop;
      Widgets.Add (Item.Home_Panel, Item.Actions_Panel);
      Widgets.Add (Item.Actions_Panel, Item.New_Button);
      Widgets.Add (Item.Actions_Panel, Item.Settings_Button);

      Labels.Set_Text (Item.Recent_Title, "Recent projects");
      Labels.Set_Style (Item.Recent_Title, UI.Line_Texts.Heading);
      Buttons.Set_Label (Item.New_Button, "New Project");
      Buttons.Set_Kind (Item.New_Button, Buttons.Primary);
      Buttons.Set_Label (Item.Settings_Button, "Settings");
      Panels.Set_Fill
        (Item.Actions_Panel,
         UI.Themes.Mix (Colors.Background, Colors.Foreground, 0.06));

      --  Two halves: a width of nothing to grow from, to share equally.
      Set_Flex_Direction (Widgets.Node (Item.Home_Panel), Yoga.Row);
      Set_Flex_Grow (Widgets.Node (Item.Home_Panel), 1.0);
      Halve (Widgets.Node (Item.Recent_Panel));
      Halve (Widgets.Node (Item.Actions_Panel));

      Labels.Set_Text (Item.No_Rows, No_Projects);
      Set_Height (Widgets.Node (Item.Recent_Title), Title_Height * Pixels);
      Set_Height (Widgets.Node (Item.No_Rows), Title_Height * Pixels);
      for I in Item.Row_Panels'Range loop
         Set_Flex_Direction (Widgets.Node (Item.Row_Panels (I)), Yoga.Row);
         Set_Height (Widgets.Node (Item.Row_Panels (I)), Row_Height * Pixels);
         Set_Gap
           (Widgets.Node (Item.Row_Panels (I)), Yoga.All_Gutters,
            Row_Gap * Pixels);
         Set_Flex_Grow (Widgets.Node (Item.Recent_Rows (I)), 1.0);
         Set_Width (Widgets.Node (Item.Recent_Rows (I)), 0.0);
         Set_Width
           (Widgets.Node (Item.Rename_Buttons (I)), Rename_Width * Pixels);
         Buttons.Set_Label (Item.Rename_Buttons (I), "Rename");
         Buttons.Set_Icon (Item.Rename_Buttons (I), UI.Icons.Edit);
         Set_Width
           (Widgets.Node (Item.Delete_Buttons (I)), Delete_Width * Pixels);
         Buttons.Set_Label (Item.Delete_Buttons (I), "Delete");
         Buttons.Set_Icon (Item.Delete_Buttons (I), UI.Icons.Delete);
         Buttons.Set_Kind (Item.Delete_Buttons (I), Buttons.Danger);
      end loop;
      --  The actions, in the middle: wide, but not the width of the half.
      Set_Justify_Content (Widgets.Node (Item.Actions_Panel), Yoga.Center);
      Set_Align_Items (Widgets.Node (Item.Actions_Panel), Yoga.Center);
      Set_Width (Widgets.Node (Item.New_Button), Action_Width * Pixels);
      Set_Height (Widgets.Node (Item.New_Button), Button_Height * Pixels);
      Set_Width (Widgets.Node (Item.Settings_Button), Action_Width * Pixels);
      Set_Height
        (Widgets.Node (Item.Settings_Button), Button_Height * Pixels);
   end Build_Home;

   procedure Build_Project (Item : in out Session);
   --  Add and style the project screen's widgets.

   procedure Build_Project (Item : in out Session) is
      use Yoga.Nodes;
   begin
      Widgets.Add (Item.Window_Panel, Item.Project_Panel);
      Widgets.Add (Item.Project_Panel, Item.Content_Panel);
      Widgets.Add (Item.Content_Panel, Item.Area);
      Widgets.Add (Item.Project_Panel, Item.Toolbar_Panel);
      Widgets.Add (Item.Toolbar_Panel, Item.Project_Title);
      Widgets.Add (Item.Toolbar_Panel, Item.Close_Button);
      Panels.Set_Fill (Item.Toolbar_Panel, Toolbar);
      Buttons.Set_Label (Item.Close_Button, "Close");
      Labels.Set_Style (Item.Project_Title, UI.Line_Texts.Strong);
      Labels.Set_Ink (Item.Project_Title, Colors.Background);

      Set_Flex_Direction (Widgets.Node (Item.Project_Panel), Yoga.Column);
      Set_Flex_Grow (Widgets.Node (Item.Project_Panel), 1.0);
      Set_Flex_Grow (Widgets.Node (Item.Content_Panel), 1.0);
      Set_Flex_Direction (Widgets.Node (Item.Content_Panel), Yoga.Column);
      Set_Padding
        (Widgets.Node (Item.Content_Panel), Yoga.All_Edges,
         Margin * Item.Density);
      Set_Flex_Grow (Widgets.Node (Item.Area), 1.0);

      --  The Close button at the right, in the middle of the bar.
      Set_Height
        (Widgets.Node (Item.Toolbar_Panel), Toolbar_Size * Item.Density);
      Set_Flex_Direction (Widgets.Node (Item.Toolbar_Panel), Yoga.Row);
      Set_Align_Items (Widgets.Node (Item.Toolbar_Panel), Yoga.Center);
      Set_Padding
        (Widgets.Node (Item.Toolbar_Panel), Yoga.Right,
         Bar_Margin * Item.Density);
      Set_Padding
        (Widgets.Node (Item.Toolbar_Panel), Yoga.Left,
         Title_Margin * Item.Density);
      --  The title takes what the Close button leaves.
      Set_Flex_Grow (Widgets.Node (Item.Project_Title), 1.0);
      Set_Width (Widgets.Node (Item.Project_Title), 0.0);
      Set_Height
        (Widgets.Node (Item.Project_Title), Close_Height * Item.Density);
      Set_Width (Widgets.Node (Item.Close_Button), Close_Width * Item.Density);
      Set_Height
        (Widgets.Node (Item.Close_Button), Close_Height * Item.Density);
   end Build_Project;

   procedure Build_Modal (Item : in out Session);
   --  Add and style the dialog to confirm a deletion: over all else.

   procedure Build_Modal (Item : in out Session) is
      use Yoga.Nodes;
      Pixels : constant Float := Item.Density;
   begin
      Widgets.Add (Item.Window_Panel, Item.Overlay);
      Widgets.Add (Item.Overlay, Item.Dialog_Border);
      Widgets.Add (Item.Dialog_Border, Item.Dialog);
      Widgets.Add (Item.Dialog, Item.Confirm_Message);
      Widgets.Add (Item.Dialog, Item.Confirm_Name);
      Widgets.Add (Item.Dialog, Item.Confirm_Note);
      Widgets.Add (Item.Dialog, Item.Confirm_Buttons);
      Widgets.Add (Item.Confirm_Buttons, Item.Confirm_Cancel);
      Widgets.Add (Item.Confirm_Buttons, Item.Confirm_Delete);

      Panels.Set_Fill (Item.Overlay, UI.Themes.Scrim (Colors));
      Panels.Set_Fill (Item.Dialog_Border, Colors.Foreground);
      Panels.Set_Fill (Item.Dialog, Colors.Background);
      Labels.Set_Text (Item.Confirm_Message, "Delete this project?");
      Labels.Set_Text (Item.Confirm_Note, "This cannot be undone.");
      Buttons.Set_Label (Item.Confirm_Cancel, "Cancel");
      Buttons.Set_Label (Item.Confirm_Delete, "Delete");
      Buttons.Set_Kind (Item.Confirm_Delete, Buttons.Danger);

      --  Not in the layout of the screens: over them, all of the window,
      --  with the dialog in the middle.
      Set_Position_Type (Widgets.Node (Item.Overlay), Yoga.Absolute);
      for Side in Yoga.Left .. Yoga.Bottom loop
         Set_Position (Widgets.Node (Item.Overlay), Side, 0.0);
      end loop;
      Set_Flex_Direction (Widgets.Node (Item.Overlay), Yoga.Column);
      Set_Justify_Content (Widgets.Node (Item.Overlay), Yoga.Center);
      Set_Align_Items (Widgets.Node (Item.Overlay), Yoga.Center);

      Set_Width (Widgets.Node (Item.Dialog_Border), Dialog_Width * Pixels);
      Set_Padding
        (Widgets.Node (Item.Dialog_Border), Yoga.All_Edges, Outline * Pixels);
      Set_Flex_Direction (Widgets.Node (Item.Dialog), Yoga.Column);
      Set_Padding
        (Widgets.Node (Item.Dialog), Yoga.All_Edges, Dialog_Pad * Pixels);
      Set_Gap (Widgets.Node (Item.Dialog), Yoga.All_Gutters, Gap * Pixels);
      Set_Height (Widgets.Node (Item.Confirm_Message), Dialog_Line * Pixels);
      Set_Height (Widgets.Node (Item.Confirm_Name), Dialog_Line * Pixels);
      Set_Height (Widgets.Node (Item.Confirm_Note), Dialog_Line * Pixels);

      Set_Flex_Direction (Widgets.Node (Item.Confirm_Buttons), Yoga.Row);
      Set_Justify_Content (Widgets.Node (Item.Confirm_Buttons), Yoga.Flex_End);
      Set_Height
        (Widgets.Node (Item.Confirm_Buttons), Dialog_Button_Height * Pixels);
      Set_Gap
        (Widgets.Node (Item.Confirm_Buttons), Yoga.All_Gutters,
         Row_Gap * Pixels);
      Set_Width
        (Widgets.Node (Item.Confirm_Cancel), Dialog_Button_Width * Pixels);
      Set_Width
        (Widgets.Node (Item.Confirm_Delete), Dialog_Button_Width * Pixels);
   end Build_Modal;

   procedure Set_Up
     (Item       : in out Session;
      Source     : String;
      File_Name  : String;
      Store_Path : String)
   is
      use Yoga.Nodes;
   begin
      Projects.Open (Item.Store, Store_Path);
      Scripts.Load (Item.Script, Source, File_Name);
      Widgets.Set_Density (Item.Widgets, Item.Density);
      Widgets.Set_Line_Texts (Item.Widgets, Item.Lines);
      Widgets.Set_Icons (Item.Widgets, Item.Pictures);
      UI.Icons.Set_Directory (Item.Pictures, Icon_Directory);
      if Item.Windowed then
         Widgets.Set_Clipboard (Item.Widgets, Item.System_Board);
      else
         Widgets.Set_Clipboard (Item.Widgets, Item.Own_Board);
      end if;

      Widgets.Set_Root (Item.Widgets, Item.Window_Panel);
      Set_Flex_Direction (Widgets.Node (Item.Window_Panel), Yoga.Column);
      Build_Home (Item);
      Build_Project (Item);
      Build_Modal (Item);

      Buttons.Set_Label (Item.Ok_Button, "OK");
      Buttons.Set_Label (Item.Cancel_Button, "Cancel");
      Text_Fields.Configure
        (Item.Edit_Field, UI.Line_Texts.System_UI, Edit_Size);
      Editors.Configure (Item.Area, Family, Font_Size, Page_Width, Para_Gap);
      Editors.Attach (Item.Area, Scripts.Document (Item.Script));

      --  It starts at the home screen.
      Widgets.Set_Visible (Item.Project_Panel, False);
      Widgets.Set_Visible (Item.Overlay, False);
      Refresh_Recent (Item);
      --  Before any event: the widgets must know where they are.
      Widgets.Layout (Item.Widgets, Item.Target);
   end Set_Up;

   procedure Open
     (Item : in out Session; Source : String; File_Name : String) is
   begin
      Item.Windowed := True;
      SDL3.Windows.Create
        (Item.Win, "bonxie", Window_Width, Window_Height,
         Resizable => True, High_Density => True);
      Item.Density := SDL3.Windows.Pixel_Density (Item.Win);
      Create (Item.Target, Item.Win);
      Set_Up (Item, Source, File_Name, Projects.Default_Path);
      SDL3.Windows.Start_Text_Input (Item.Win);
   end Open;

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
      --  Nothing to do until something happens, except to settle the
      --  zoom once it has held still, and to blink the caret.
      Tick (Item, SDL3.Events.Ticks);
      if not Item.Settled then
         Wake_In
           (Settle_MS - Integer (SDL3.Events.Ticks - Item.Zoomed_At));
      end if;
      if Widgets.Until_Update (Item.Widgets) >= 0 then
         Wake_In (Widgets.Until_Update (Item.Widgets));
      end if;

      if SDL3.Events.Wait (Event, Timeout_MS => Timeout) then
         Handle (Item, Event);
         while SDL3.Events.Poll (Event) loop
            Handle (Item, Event);
         end loop;
      end if;

      if not Item.Settled
        and then SDL3.Events.Ticks - Item.Zoomed_At >= Settle_MS
      then
         Settle (Item);
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
      Set_Up (Item, Source, File_Name, Projects.Memory);
   end Open;

   function Is_Open (Item : Session) return Boolean is
     (Editors.Has_Document (Item.Area));

   function Text (Item : Session) return String is
     (Scripts.Text (Item.Script));

   procedure Tick (Item : in out Session; Now : SDL3.Events.Milliseconds) is
   begin
      Widgets.Update (Item.Widgets, Now);
   end Tick;

   procedure Settle (Item : in out Session) is
   begin
      if not Item.Settled then
         Item.Settled := True;
         Widgets.Set_Settled (Item.Widgets, True);
      end if;
   end Settle;

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
      Paint (Item);
      SDL3.Windows.Renderers.Images.Read (Result, Item.Target);
   end Render;

   procedure Run (Source : String; File_Name : String := "") is
      Item    : aliased Session;
      Watcher : Redraws.Watch;  --  ends before Item does
   begin
      Open (Item, Source, File_Name);

      --  The redraw watch also draws: the OS blocks the event loop
      --  during a live resize, and only repainting from inside the event
      --  watch avoids a stretched frame.
      Redraws.Install (Watcher, Item);

      while not Item.Done loop
         Show_Title (Item);
         if Widgets.Needs_Paint (Item.Widgets) then
            Draw (Item);
         end if;
         Wait_And_Handle (Item);
      end loop;
   end Run;

end Viewer;
