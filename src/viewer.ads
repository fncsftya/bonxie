with Projects;
with SDL3.Cursors;
with SDL3.Events;
with SDL3.Windows.Renderers.Images;
private with Items;
private with Items.Windows;
private with SDL3.Windows;
private with Texts.Documents;
private with Pomarine.Models;
private with Pomarine.Widgets;
private with Pomarine.Widgets.Buttons;
private with Pomarine.Widgets.Canvases;
private with Pomarine.Widgets.Commands;
private with Pomarine.Widgets.Grips;
private with Pomarine.Widgets.Labels;
private with Pomarine.Widgets.Lists;
private with Pomarine.Widgets.Text_Fields;
private with Pomarine.Widgets.Panels;
private with Viewer_Parts.Common;
private with Viewer_Parts.Rows;
private with Viewer_Parts.Pages;
private with Viewer_Parts.Home;
private with Viewer_Parts.Settings;
private with Viewer_Parts.Outline;
private with Viewer_Parts.Grammar;
private with Viewer_Parts.Canvas;
private with Viewer_Parts.Finder;

--  A window of two screens: the home, with the recent projects and
--  buttons to start with, and a project, with a toolbar and, above it, the
--  project's main view, one at a time, chosen on the toolbar.
--
--  This package is the session and how it is run. What it shows is in its
--  children, which a test uses to look at it and move it about without
--  finding the buttons:
--    Home_Screen     the recent projects, to start or open one
--    Settings        the speech model and the theme
--    Project_Screen  the project shown, and the view of it
--    Outlines        the title, description and sections of the project
--    Canvas_Camera   how the canvas is zoomed and panned
--    Canvas_Windows  the items on the canvas
--    Canvas_Links    the links between them, and their pins
--    Documents       the pages of the writing view, and its directories
--    Sources         the sources of the writing view, and the pinned one
package Viewer is

   type Screens is (Home, Project);

   type Modes is (Outline, Canvas, Write, Publish);
   --  The views of a project, in the order of their tabs. Outline, the
   --  first, is the project's title and description, and the sections it is
   --  to be written in, in the order they are to come in; a project opens to
   --  the one it was last left at, to Outline if it never was. Canvas is an
   --  infinite canvas to pan and zoom, with a toolbar of tools above the
   --  main one. Write shows the items that are not sources, as documents,
   --  one after another, each on a page, with a list of them and of the
   --  sources beside them; a source is read in a window of its own, or
   --  pinned in a pane at the right.

   procedure Run (Source : String; File_Name : String := "");
   --  Open a window, at the home screen, and run until it is closed.
   --  Source is kept as the project's text, a paragraph to each line, and
   --  Command-S saves it to File_Name, if it is given; no view shows it
   --  yet. The projects are kept in Projects.Default_Path. SDL must be
   --  initialized. Drawing does not wait for the display's refresh, so that
   --  what is dragged is not a frame or two behind the pointer; with
   --  BONXIE_VSYNC=1 in the environment it does, which may tear less.

   --  Without a window, to test what is shown

   type Session is tagged limited private;
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

   use Viewer_Parts.Common;
   use Viewer_Parts.Rows;
   use Viewer_Parts.Pages;
   use Viewer_Parts.Home;
   use Viewer_Parts.Settings;
   use Viewer_Parts.Outline;
   use Viewer_Parts.Grammar;
   use Viewer_Parts.Canvas;
   use Viewer_Parts.Finder;

   --  What the menu bar and the keys can ask for, apart from what edits
   --  text: each is said as a command (see Viewer.Menus), to be done by
   --  Viewer.Responses. The buttons that do the same are given the command
   --  too (see Viewer.Build), to be on or off as it is. What each button
   --  does is its own (see Pomarine.Widgets.Callbacks).

   type Command is
     (Start_Project,
      Open_Settings,
      Leave_Project,
      Show_Outline,
      Show_Canvas,
      Show_Writing,
      Show_Publish,
      Open_List);

   package Commands is new Pomarine.Widgets.Commands (Command);

   type Session_Access is access all Session;

   type Responder is limited new Pomarine.Widgets.Listener with record
      Owner : Session_Access;
   end record;
   --  What the widgets of a session say, heard as the session's.

   overriding procedure Handle_Event
     (Self   : in out Responder;
      Source : in out Pomarine.Widgets.Widget'Class;
      Event  : Pomarine.Widgets.Widget_Event);

   type Item_Rows is limited new Pomarine.Models.List_Model with record
      Owner   : Session_Access;
      Found   : Natural := 0;
      --  How many items are listed: the slots are the session's Row_Slots.
      Changed : Natural := 0;
   end record;
   --  What the list of items shows, a row for each (see Viewer.Listing).

   overriding function Count (Self : Item_Rows) return Natural;

   overriding function Version (Self : Item_Rows) return Natural;

   overriding function Row_Id (Self : Item_Rows; Row : Positive) return Positive;

   overriding procedure Describe_Row
     (Self    : Item_Rows;
      Row     : Positive;
      Content : out Pomarine.Models.Row_Content);

   type Toolbar_Parts is limited record
      Project_Panel : Pomarine.Widgets.Panels.Panel;
      --  A column: the toolbar, the content area, and the dock.
      Content_Panel : Pomarine.Widgets.Panels.Panel;
      Toolbar_Panel : Pomarine.Widgets.Panels.Panel;
      Toolbar_Start : Pomarine.Widgets.Panels.Panel;
      --  On the left of the toolbar: the way back, and the project's name.
      Close_Button  : Pomarine.Widgets.Buttons.Button;
      --  Back to the projects.
      Bar_Rule      : Pomarine.Widgets.Panels.Panel;
      Title_Area    : Pomarine.Widgets.Grips.Grip;
      Project_Title : Pomarine.Widgets.Labels.Label;
      --  The project's name, in a grip that takes a double press to
      --  rename it.
      Title_Field   : Pomarine.Widgets.Text_Fields.Text_Field;
      Title_Doc     : aliased Texts.Documents.Document;
      Renaming      : Boolean := False;
      --  In its place while it is renamed.
      Tabs          : Pomarine.Widgets.Panels.Panel;
      Outline_Tab   : Pomarine.Widgets.Buttons.Button;
      Canvas_Tab    : Pomarine.Widgets.Buttons.Button;
      Publish_Tab   : Pomarine.Widgets.Buttons.Button;
      Write_Tab     : Pomarine.Widgets.Buttons.Button;
      --  A tab for each view, in the middle of the toolbar.
      Toolbar_End   : Pomarine.Widgets.Panels.Panel;
      --  On the right: the list of items.
      Mode          : Modes := Canvas;
      --  The view shown: its tab is selected. Canvas is the one the widgets
      --  are built showing; a project shown at once goes to its own.
   end record;
   --  The project screen: its panels, the toolbar and the view shown.

   type Nav_State is limited record
      Shown        : Screens := Home;
      Store        : Projects.Store;

      Pinned_Time : Projects.Seconds := 0;
      --  The time pictures are taken at, if not 0: see Pin_Capture_Time.

      Shown_Zoom, Shown_X, Shown_Y : Float := 0.0;
      --  Of the canvas, as the items' windows have been put by it.

      Fetch_Slot : Natural := 0;
      Fetch_Key  : Items.Id := 0;
      Fetch_Document : Items.Extensions.Bounded_String :=
        Items.Extensions.Null_Bounded_String;
      --  The window whose source's PDF or e-book is being fetched (see
      --  Downloads, which does one at a time), 0 if none; its item and the
      --  ending of the file.

      Pick_Slot : Natural := 0;
      Pick_Key  : Items.Id := 0;
      --  The window whose source is having a file chosen, in the system's
      --  dialog (see SDL3.Dialogs, which shows one at a time), 0 if none;
      --  its item.
   end record;
   --  Which screen is shown, the database, and what the canvas was last put
   --  by.

   type List_Parts is limited record
      List_Overlay  : Pomarine.Widgets.Panels.Panel;
      --  Over the project screen, to grey it out and hold the list of
      --  items, which is shown when Showing_List.
      List_Border   : Pomarine.Widgets.Panels.Panel;
      List_Head     : Pomarine.Widgets.Panels.Panel;
      List_Heading  : Pomarine.Widgets.Labels.Label;
      List_Close    : Pomarine.Widgets.Buttons.Button;
      --  A dark bar across its top, as a window's: its title, and a
      --  button to close it.
      List_Dialog   : Pomarine.Widgets.Panels.Panel;
      List_View     : Pomarine.Widgets.Lists.List;
      --  A row for each item: its title, to show it, and buttons to show
      --  or hide it and to remove it.
      List_None     : Pomarine.Widgets.Labels.Label;
      --  Shown when there are no items.
      List_Rows     : aliased Item_Rows;
      Row_Slots     : Slot_Array := [others => 1];
      --  The window of the item each row is of.
      Showing_List  : Boolean := False;
   end record;
   --  The dialog listing the project's items.

   type Session is tagged limited record
      Replies : aliased Responder;
      Root : Root_Parts;
      Home_View : Home_Parts;
      Confirm : Confirm_Parts;
      Prefs : Settings_Parts;
      Toolbar : Toolbar_Parts;
      Canvas_View   : Pomarine.Widgets.Canvases.Canvas;
      --  In the content area, all of it.
      Page_View : Page_Parts;
      Publish_View : Publish_Parts;
      Section_View : Section_View_Parts;
      Dock : Dock_Parts;
      Nav : Nav_State;
      Item_List : List_Parts;
      Host : Host_Resources;
      Windows      : Items.Windows.Window_Array;
      --  The windows of the project's items: after Target, which they
      --  draw to.
      Docs : Document_State;
      Grammar_Checks : Grammar_State;
      Outline_View : Outline_Parts;
      Finder : Finder_Parts;
      Context : Context_State;
      Section_Menu : Section_Menu_Parts;
      Naming : Renaming_State;
      Reading : Reading_State;
      Dragging : Drag_State;
      Linking : Link_State;
      Title_Edit : Title_Edit_State;
      Opened : Opened_State;
      Shell : Shell_State;
   end record;

end Viewer;
