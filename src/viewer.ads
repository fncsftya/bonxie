with Items;
with Projects;
with SDL3.Cursors;
with SDL3.Events;
with SDL3.Windows.Renderers.Images;
private with Ada.Strings.Unbounded;
private with Items.Windows;
private with SDL3.Windows;
private with Scripts;
private with Texts.Documents;
private with UI.Clipboards;
private with UI.Icons;
private with UI.Line_Texts;
private with UI.Widgets.Buttons;
private with UI.Widgets.Canvases;
private with UI.Widgets.Grips;
private with UI.Widgets.Labels;
private with UI.Widgets.Text_Fields;
private with UI.Widgets.Panels;
private with UI.Widgets.Scrollers;

--  A window of two screens: the home, with the recent projects and
--  buttons to start with, and a project, with a toolbar and, above it, the
--  project's main view, one at a time, chosen on the toolbar.
package Viewer is

   type Screens is (Home, Project);

   type Modes is (Canvas);
   --  The views of a project. Canvas, an infinite canvas to pan and zoom,
   --  with a toolbar of tools above the main one, is the first, and so the
   --  one shown.

   procedure Run (Source : String; File_Name : String := "");
   --  Open a window, at the home screen, and run until it is closed.
   --  Source is kept as the project's text, a paragraph to each line, and
   --  Command-S saves it to File_Name, if it is given; no view shows it
   --  yet. The projects are kept in Projects.Default_Path. SDL must be
   --  initialized. Drawing does not wait for the display's refresh, so that
   --  what is dragged is not a frame or two behind the pointer; with
   --  BONXIE_VSYNC=1 in the environment it does, which may tear less.

   --  Without a window, to test what is shown

   type Session is limited private;
   --  What Run shows, and how it is moved about.

   procedure Open
     (Item      : in out Session;
      Source    : String;
      Width     : Positive;
      Height    : Positive;
      Density   : Float := 2.0;
      File_Name : String := "")
     with Pre  => not Is_Open (Item) and then Density >= 1.0,
          Post => Is_Open (Item);
   --  Open as Run would, in a window Width x Height points of Density
   --  pixels each, but drawn offscreen, in software. It cuts, copies and
   --  pastes on a clipboard of its own, and keeps its projects in
   --  memory.

   function Is_Open (Item : Session) return Boolean;

   procedure Open_Window
     (Item      : in out Session;
      Source    : String;
      File_Name : String := "";
      Hidden    : Boolean := False;
      Store     : String := Projects.Default_Path;
      VSync     : Boolean := True)
     with Pre  => not Is_Open (Item),
          Post => Is_Open (Item);
   --  Open as Run does, in a window, which is not shown if Hidden, for
   --  measuring what drawing it costs on the GPU: see Draw_Frame. The projects
   --  are kept in the database at Store. Without VSync, presenting does not
   --  wait for the display, to time drawing. SDL must be initialized.

   procedure Paint_Frame (Item : in out Session)
     with Pre => Is_Open (Item);
   --  Draw what has changed in the window, without presenting it: the
   --  part of Draw_Frame that is not waiting for the display.

   procedure Draw_Frame (Item : in out Session)
     with Pre => Is_Open (Item);
   --  Draw what has changed in the window, and present it, as Run does
   --  when something needs drawing. Not for a session opened offscreen.

   function Screen (Item : Session) return Screens
     with Pre => Is_Open (Item);
   --  Which is shown.

   function Mode (Item : Session) return Modes
     with Pre => Is_Open (Item) and then Screen (Item) = Project;
   --  Which view of the project is shown.

   function Current_Project (Item : Session) return Projects.Id
     with Pre => Is_Open (Item) and then Screen (Item) = Project;
   --  The one the project screen is of.

   procedure New_Project (Item : in out Session)
     with Pre  => Is_Open (Item) and then Screen (Item) = Home,
          Post => Screen (Item) = Project;
   --  Keep a new project, and go to the project screen, as the New
   --  Project button does.

   procedure Open_Project (Item : in out Session; Key : Projects.Id)
     with Pre  => Is_Open (Item) and then Screen (Item) = Home,
          Post => Screen (Item) = Project;
   --  Go to the screen of the project Key, as a click on it in the recent
   --  projects does.

   function Is_Renaming (Item : Session) return Boolean
     with Pre => Is_Open (Item);
   --  Whether a project listed on the home screen has a field to rename
   --  it, in place of its button.

   function Is_Confirming (Item : Session) return Boolean
     with Pre => Is_Open (Item);
   --  Whether the dialog to confirm deleting a project is shown, over the
   --  home screen.

   function Row_Title (Item : Session; Row : Positive) return String
     with Pre => Is_Open (Item) and then Row <= Projects.Recent_Count;
   --  What the button of the Rowth project listed shows, "" if none.

   procedure Close_Project (Item : in out Session)
     with Pre  => Is_Open (Item) and then Screen (Item) = Project,
          Post => Screen (Item) = Home;
   --  Go back to the home screen, as the Close button does.

   procedure Add_Project
     (Item    : in out Session;
      Name    : String;
      Updated : Projects.Seconds)
     with Pre => Is_Open (Item) and then Updated >= 0;
   --  Keep a project last updated at Updated, to be listed.

   function Canvas_Zoom (Item : Session) return Float
     with Pre => Is_Open (Item);
   --  Of the canvas: screen points to a canvas unit.

   function Canvas_Origin_X (Item : Session) return Float
     with Pre => Is_Open (Item);
   function Canvas_Origin_Y (Item : Session) return Float
     with Pre => Is_Open (Item);
   --  Where the canvas's origin is, in points from the top left of the
   --  canvas.

   --  The items on the project's canvas, in the order they were made

   function Item_Count (Item : Session) return Natural
     with Pre => Is_Open (Item) and then Screen (Item) = Project;
   --  How many the project has, whether shown or not.

   procedure Add_Item
     (Item : in out Session;
      Name : String := "Untitled item";
      Kind : Items.Kinds := Items.Note)
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Name'Length <= Projects.Title_Capacity;
   --  Add one called Name in the middle of the canvas, with the focus in
   --  its text, as the Add Item button does (or, of a Source, as Add
   --  Source does, in its link); none if the project has Items.Capacity.

   function Item_Title (Item : Session; Row : Positive) return String
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Item_Count (Item);

   function Item_Text (Item : Session; Row : Positive) return String
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Item_Count (Item);

   function Item_Kind (Item : Session; Row : Positive) return Items.Kinds
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Item_Count (Item);

   function Item_Status (Item : Session; Row : Positive) return String
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Item_Count (Item);
   --  What the status line of the item says.

   function Item_Picture_File (Item : Session; Row : Positive) return String
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Item_Count (Item);
   --  Where the picture of the item, if a source, is kept.

   procedure Pin_Capture_Time (Item : in out Session; To : Projects.Seconds)
     with Pre => To > 0;
   --  Record every picture taken from now on as taken at To, whatever
   --  the time is: for tests.

   function Is_Capturing (Item : Session) return Boolean
     with Pre => Is_Open (Item) and then Screen (Item) = Project;
   --  Whether the picture of a page is being taken, for some source.

   function Item_Words (Item : Session; Row : Positive) return Natural
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Item_Count (Item);
   --  As the status line of the item says.

   function Item_State (Item : Session; Row : Positive) return Items.States
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Item_Count (Item);

   function Item_Frame (Item : Session; Row : Positive) return Items.Frame
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Item_Count (Item);
   --  Where it is on the canvas.

   function Item_Box (Item : Session; Row : Positive) return Items.Frame
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Item_Count (Item);
   --  Where its window is on the screen, in pixels, as of the last layout.

   function Is_Editing_Title (Item : Session; Row : Positive) return Boolean
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Item_Count (Item);
   --  Whether the item's title is a field to type in, not text.

   function Is_Listing (Item : Session) return Boolean
     with Pre => Is_Open (Item);
   --  Whether the list of the project's items is shown, over the project
   --  screen.

   function Cursor (Item : Session) return SDL3.Cursors.Kind
     with Pre => Is_Open (Item);
   --  The shape the pointer has, from where it was last seen: the arrow,
   --  the move cursor while panning the canvas or dragging an item, or the
   --  resize cursor over the corner of an item.

   function Text (Item : Session) return String
     with Pre => Is_Open (Item);
   --  The project's text, a line to each paragraph.

   function Title (Item : Session) return String
     with Pre => Is_Open (Item);
   --  Of the window: "bonxie" at the home screen; at the project screen,
   --  the file's name, and whether it has been edited since it was opened
   --  or saved.

   procedure Save (Item : in out Session)
     with Pre => Is_Open (Item);
   --  Write the text to the file, if there is one, a line to each
   --  paragraph, as Command-S does.

   procedure Handle (Item : in out Session; Event : SDL3.Events.Event)
     with Pre => Is_Open (Item);
   --  As if Event had come.

   procedure Tick (Item : in out Session; Now : SDL3.Events.Milliseconds)
     with Pre => Is_Open (Item);
   --  As if it were time Now, as SDL3.Events.Ticks: the caret blinks.

   procedure Resize (Item : in out Session; Width, Height : Positive)
     with Pre => Is_Open (Item);
   --  As if the window were resized to Width x Height points.

   procedure Render
     (Item   : in out Session;
      Result : in out SDL3.Windows.Renderers.Images.Image)
     with Pre => Is_Open (Item);
   --  Draw what is shown, as into the window, into Result.

private

   type Row_Array is
     array (1 .. Projects.Recent_Count) of UI.Widgets.Buttons.Button;
   type Row_Panel_Array is
     array (Row_Array'Range) of UI.Widgets.Panels.Panel;
   type Key_Array is array (Row_Array'Range) of Projects.Id;

   type Item_Row is limited record
      Panel  : UI.Widgets.Panels.Panel;
      Name   : UI.Widgets.Grips.Grip;
      --  The title: clicked, to show the item.
      Caption : UI.Widgets.Labels.Label;
      Toggle : UI.Widgets.Buttons.Button;
      Remove : UI.Widgets.Buttons.Button;
   end record;
   --  A row of the list of items: its title, a button to show it on the
   --  canvas or hide it, and one to remove it.

   type Item_Row_Array is array (Items.Slot) of Item_Row;
   type Slot_Array is array (Items.Slot) of Items.Slot;

   type Session is limited record
      Widgets      : UI.Widgets.Tree;
      Window_Panel : UI.Widgets.Panels.Panel;
      --  The root, of both screens, one of which is hidden.
      Header_Panel : UI.Widgets.Panels.Panel;
      Header_Title : UI.Widgets.Labels.Label;
      --  Across the top of a window, where its title bar was: under the
      --  window's own buttons.

      Home_Panel     : UI.Widgets.Panels.Panel;
      --  A row: the recent projects, and the actions.
      Recent_Panel   : UI.Widgets.Panels.Panel;
      Recent_Title   : UI.Widgets.Labels.Label;
      Row_Panels     : Row_Panel_Array;
      --  A row to each of the projects listed, of its button to open it
      --  and its button to rename it; or of the field to rename it.
      Recent_Rows    : Row_Array;
      Rename_Buttons : Row_Array;
      Row_Keys       : Key_Array := [others => 0];
      Listed         : Projects.Recent_List;
      --  The projects the rows are of.
      No_Rows        : UI.Widgets.Labels.Label;
      --  Shown when there are none.
      Actions_Panel  : UI.Widgets.Panels.Panel;
      New_Button     : UI.Widgets.Buttons.Button;
      Settings_Button : UI.Widgets.Buttons.Button;

      Edit_Panel     : UI.Widgets.Panels.Panel;
      Ok_Button      : UI.Widgets.Buttons.Button;
      Cancel_Button  : UI.Widgets.Buttons.Button;
      --  Put in the row of the project being renamed, in place of its
      --  buttons, which are hidden.
      Editing        : Natural := 0;
      --  Which row, 0 if none.

      Delete_Buttons : Row_Array;

      Overlay        : UI.Widgets.Panels.Panel;
      --  Over both screens, to grey them out and hold the dialog, which
      --  is shown to confirm deleting a project.
      Dialog_Border  : UI.Widgets.Panels.Panel;
      Dialog         : UI.Widgets.Panels.Panel;
      Confirm_Message : UI.Widgets.Labels.Label;
      Confirm_Name   : UI.Widgets.Labels.Label;
      Confirm_Note   : UI.Widgets.Labels.Label;
      Confirm_Buttons : UI.Widgets.Panels.Panel;
      Confirm_Cancel : UI.Widgets.Buttons.Button;
      Confirm_Delete : UI.Widgets.Buttons.Button;
      Deleting       : Projects.Id := 0;
      --  The project the dialog is about, 0 if it is not shown.

      Project_Panel : UI.Widgets.Panels.Panel;
      --  A column, of the content area above the toolbar.
      Content_Panel : UI.Widgets.Panels.Panel;
      Toolbar_Panel : UI.Widgets.Panels.Panel;
      Project_Title : UI.Widgets.Labels.Label;
      --  On the left of the toolbar: the title of the project shown.
      Canvas_Tab    : UI.Widgets.Buttons.Button;
      --  A tab for each view, in a row before the Close button.
      Close_Button  : UI.Widgets.Buttons.Button;
      --  On the right of the toolbar.
      Mode          : Modes := Canvas;
      --  The view shown: its tab is selected.

      Canvas_View   : UI.Widgets.Canvases.Canvas;
      --  In the content area, all of it.
      Dock_Panel    : UI.Widgets.Panels.Panel;
      --  A bar above the tools, of the bars of the items that are
      --  minimised: shown only when there are any.
      Tools         : UI.Widgets.Panels.Panel;
      Tool_Item     : UI.Widgets.Buttons.Button;
      Tool_Source   : UI.Widgets.Buttons.Button;
      Tool_List     : UI.Widgets.Buttons.Button;
      --  The tools of the view: a bar above the toolbar. Add Item, Add
      --  Source, and the list of items.

      Shown        : Screens := Home;
      Store        : Projects.Store;

      Pinned_Time : Projects.Seconds := 0;
      --  The time pictures are taken at, if not 0: see Pin_Capture_Time.

      Shown_Zoom, Shown_X, Shown_Y : Float := 0.0;
      --  Of the canvas, as the items' windows have been put by it.

      List_Overlay  : UI.Widgets.Panels.Panel;
      --  Over the project screen, to grey it out and hold the list of
      --  items, which is shown when Showing_List.
      List_Border   : UI.Widgets.Panels.Panel;
      List_Dialog   : UI.Widgets.Panels.Panel;
      List_Head     : UI.Widgets.Panels.Panel;
      List_Heading  : UI.Widgets.Labels.Label;
      List_Close    : UI.Widgets.Buttons.Button;
      List_Scroll   : UI.Widgets.Scrollers.Scroller;
      List_Content  : UI.Widgets.Panels.Panel;
      List_None     : UI.Widgets.Labels.Label;
      --  Shown when there are no items.
      List_Rows     : Item_Row_Array;
      Row_Slots     : Slot_Array := [others => 1];
      --  The window of the item each row is of.
      Showing_List  : Boolean := False;

      Script       : aliased Scripts.Script;
      Win          : SDL3.Windows.Window;
      Target       : SDL3.Windows.Renderers.Renderer;
      --  after Win: it is destroyed first
      Pictures     : aliased UI.Icons.Library;
      --  after Target, which it draws to
      Lines        : aliased UI.Line_Texts.Drawer;
      --  after Target, which it draws to
      Windows      : Items.Windows.Window_Array;
      --  The windows of the project's items: after Target, which they
      --  draw to.
      Edit_Doc     : aliased Texts.Documents.Document;
      Edit_Field   : UI.Widgets.Text_Fields.Text_Field;
      --  The title being renamed, and the field for it, which is in the
      --  edit panel: after Target, and the document.
      Current      : Projects.Id := 0;
      --  The project shown, at the project screen.
      Density      : Float := 1.0;
      --  Pixels to a point of the window.

      Shown_Cursor : SDL3.Cursors.Kind := SDL3.Cursors.Default;
      --  The one the window has been given.

      Shown_Title  : Ada.Strings.Unbounded.Unbounded_String;

      Windowed     : Boolean := False;
      System_Board : UI.Clipboards.System_Clipboard;
      Own_Board    : UI.Clipboards.Memory_Clipboard;
      --  The clipboard used offscreen.

      Done         : Boolean := False;
   end record;

end Viewer;
