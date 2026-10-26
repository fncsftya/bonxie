private with Menu_VM;
private with Confirm_VM;
private with Outline_VM;
private with Home_VM;
private with Pomarine.UI;
private with Pomarine.Widgets.Panels;
private with Pomarine.Widgets.Buttons;
private with Settings_VM;
private with Backgrounds;
private with Canvas_VM;
private with Item_List_VM;
private with Search_VM;
private with Writing_VM.Trees;
private with Pomarine.View_Models;
with Nav_VM;
with Projects;
with SDL3.Cursors;
with Pomarine.Events;
with SDL3.Windows.Renderers.Images;
private with Items;
private with Items.Windows;
private with Items.Models.Tables;
private with Items.Windows.Tables;
private with SDL3.Windows;
private with Texts.Documents;
private with Pomarine.Models;
with Pomarine.Widgets;
private with Pomarine.Widgets.Grips;
private with Pomarine.Widgets.Labels;
private with Pomarine.Widgets.Lists;
private with Pomarine.Widgets.Text_Fields;
private with View_Parts.Common;
private with View_Parts.Rows;
private with View_Parts.Pages;
private with View_Parts.Home;
private with View_Parts.Nav;
private with View_Parts.Settings;
private with View_Parts.Outline;
private with View_Parts.Grammar;
private with View_Parts.Canvas;

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
package View is

   type Screens is new Nav_VM.Screens;

   type Modes is new Nav_VM.Modes;
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

   procedure Handle (Item : in out Session; Event : Pomarine.Events.Event)
     with Pre => Is_Open (Item);
   --  As if Event had come.

   function Widget_Tree (Item : aliased in out Session) return access Pomarine.Widgets.Tree
     with Pre => Is_Open (Item);
   --  The widgets of the window, for a test to read what an assistive
   --  technology is told of them (see Pomarine.Testing).

   function Clipboard_Text (Item : Session) return String;
   --  What is on the clipboard the session uses (its own, offscreen).

   procedure Tick (Item : in out Session; Now : Pomarine.Events.Milliseconds)
     with Pre => Is_Open (Item);
   --  As if it were time Now, as Pomarine.Events.Ticks: the caret blinks.

   procedure Resize (Item : in out Session; Width, Height : Positive)
     with Pre => Is_Open (Item);
   --  As if the window were resized to Width x Height points.

   procedure Render
     (Item   : in out Session;
      Result : in out SDL3.Windows.Renderers.Images.Image)
     with Pre => Is_Open (Item);
   --  Draw what is shown, as into the window, into Result.

private

   use View_Parts.Common;
   use View_Parts.Rows;
   package Trees renames Writing_VM.Trees;
   use type Trees.Tree_Kinds;
   use View_Parts.Pages;
   use View_Parts.Home;
   use View_Parts.Nav;
   use View_Parts.Settings;
   use View_Parts.Outline;
   use View_Parts.Grammar;
   use View_Parts.Canvas;

   function View_Mode (Item : Session) return Modes;
   --  The view of the project shown (Canvas at the home screen).

   function Open_Key (Item : Session) return Projects.Id;
   --  The project shown; 0 at the home screen.

   function Items_Listed (Item : Session) return Boolean;
   --  Whether the list of the project's items is up.

   function Takes_Gestures (Item : Session) return Boolean;
   --  Whether the canvas, the writing view and the outline may be worked: at a project, with nothing over it.

   type Session_Access is access all Session;

   type Menu_Router is limited new Menu_VM.Router with record
      Owner : Session_Access;
   end record;
   overriding function Allowed (Self : Menu_Router; What : Menu_VM.Command; Row : Natural) return Boolean;
   overriding procedure Choose (Self : in out Menu_Router; What : Menu_VM.Command; Row : Positive);

   type Panel_Access is access all Pomarine.Widgets.Panels.Panel;
   --  For the children, which build panels (the private withs here are theirs).

   type Responder is limited new Pomarine.Widgets.Listener with record
      Owner : Session_Access;
   end record;
   --  What the widgets of a session say, heard as the session's.

   overriding procedure Handle_Event
     (Self   : in out Responder;
      Source : in out Pomarine.Widgets.Widget'Class;
      Event  : Pomarine.Widgets.Widget_Event);

   type Command_Judge is limited new Pomarine.Widgets.Validator with record
      Owner : Session_Access;
   end record;
   --  What the tree asks about every command of a widget: those of each view-model, which View.Menus asks.

   overriding function Validate
     (Self : Command_Judge; Tag : Integer; Index : Natural) return Pomarine.Widgets.Command_State;

   type Settings_Effects is limited new Settings_VM.Effects with record
      Owner : Session_Access;
   end record;
   --  What the world does about the settings the view-model has changed.

   overriding procedure Done (Self : in out Settings_Effects; What : Settings_VM.Command);
   overriding procedure Ask_To_Delete (Self : in out Settings_Effects; Size : String);

   type Home_Effects is limited new Home_VM.Effects with record
      Owner : Session_Access;
   end record;
   --  The cards follow the projects the view-model lists, and the renaming.

   overriding procedure Home_Changed (Self : in out Home_Effects);

   type Layout_Watch is limited new Pomarine.UI.Observer with record
      Owner : Session_Access;
   end record;
   --  A turn of a form changed what it shows: the tree is laid out again, as when the application does it.

   overriding procedure Turned (Self : in out Layout_Watch);

   type Outline_Effects is limited new Outline_VM.Effects with record
      Owner : Session_Access;
   end record;
   --  The blocks of the outline show what the view-model did.

   overriding procedure Outline_Going (Self : in out Outline_Effects; What : Outline_VM.Command; Index : Natural);
   overriding procedure Outline_Done (Self : in out Outline_Effects; What : Outline_VM.Command; Index : Natural);

   type Confirm_Effects is limited new Confirm_VM.Effects with record
      Owner : Session_Access;
   end record;
   --  The dialog that asks before deleting is shown or hidden, and what it asked is done.

   overriding procedure Dialog_Changed (Self : in out Confirm_Effects);
   overriding procedure Answered (Self : in out Confirm_Effects; Said : Confirm_VM.Answer);

   type Nav_Effects is limited new Nav_VM.Effects with record
      Owner : Session_Access;
   end record;
   --  The screens follow the navigation.

   overriding procedure Going_To_Execute (Self : in out Nav_Effects; What : Nav_VM.Command; Index : Natural);
   overriding procedure Executed (Self : in out Nav_Effects; What : Nav_VM.Command);

   type Room_Maker is limited new Canvas_VM.Surface with record
      Owner : Session_Access;
   end record;
   --  What makes windows for the items the canvas has.

   overriding procedure Make_Room (Self : in out Room_Maker; Slots : Positive);

   type List_Surface is limited new Item_List_VM.Surface with record
      Owner : Session_Access;
   end record;
   overriding procedure Apply (Self : in out List_Surface; What : Canvas_VM.Command; Slot : Items.Slot);

   type Search_Finder is limited new Search_VM.Finder with record
      Owner : Session_Access;
   end record;
   overriding function Valid (Self : Search_Finder; Where : Search_VM.Context) return Boolean;
   overriding procedure Refresh
     (Self : in out Search_Finder; Where : Search_VM.Context; Term : String; Found : out Search_VM.Result);
   overriding procedure Advance (Self : in out Search_Finder; Where : Search_VM.Context; Backwards : Boolean);
   overriding procedure Clear (Self : in out Search_Finder; Where : Search_VM.Context);

   type Item_Rows is limited new Pomarine.Models.List_Model with record
      Owner   : Session_Access;
   end record;
   --  What the list of items shows, a row for each (see View.Listing).

   overriding function Count (Self : Item_Rows) return Natural;

   overriding function Version (Self : Item_Rows) return Natural;

   overriding function Row_Id (Self : Item_Rows; Row : Positive) return Positive;

   overriding procedure Describe_Row
     (Self    : Item_Rows;
      Row     : Positive;
      Content : out Pomarine.Models.Row_Content);

   type Toolbar_Parts is limited record
      Project_Layout : Pomarine.UI.Layout;
      --  A column: the toolbar, the content area, and the dock.
      Content_Layout : Pomarine.UI.Layout;
      Close_Button  : Pomarine.UI.Button_Handle;
      --  Back to the projects.
      Title_Area    : Pomarine.Widgets.Grips.Grip;
      Project_Title : Pomarine.Widgets.Labels.Label;
      --  The project's name, in a grip that takes a double press to
      --  rename it.
      Title_Field   : Pomarine.Widgets.Text_Fields.Text_Field;
      Title_Doc     : aliased Texts.Documents.Document;
      --  In its place while it is renamed.
      Outline_Tab   : Pomarine.UI.Button_Handle;
      Canvas_Tab    : Pomarine.UI.Button_Handle;
      Publish_Tab   : Pomarine.UI.Button_Handle;
      Write_Tab     : Pomarine.UI.Button_Handle;
      --  A tab for each view, in the middle of the toolbar.
   end record;
   --  The project screen: its toolbar (the view's controls, Pomarine.UI), and the title in it that is renamed.

   type Nav_State is limited record
      Store        : aliased Projects.Store;

      Pinned_Time : Projects.Seconds := 0;
      --  The time pictures are taken at, if not 0: see Pin_Capture_Time.

      Fetch_Slot : Natural := 0;
      Fetch_Key  : Items.Id := 0;
      Fetch_Document : Items.Extensions.Text :=
        Items.Extensions.Null_Text;
      --  The window whose source's PDF or e-book is being fetched (see
      --  Downloads, which does one at a time), 0 if none; its item and the
      --  ending of the file.

      Pick_Slot : Natural := 0;
      Pick_Key  : Items.Id := 0;
      --  The window whose source is having a file chosen, in the system's
      --  dialog (see SDL3.Dialogs, which shows one at a time), 0 if none;
      --  its item.
      Export_Waiting : Boolean := False;
      --  Whether the system's dialog is asking where to save the publish view's export.
   end record;
   --  Which screen is shown, the database, and what the canvas was last put
   --  by.

   type List_Parts is limited record
      Overlay       : Pomarine.UI.Layout;
      --  Over the project screen, to grey it out and hold the list of items, which is shown while Nav_VM
      --  says it is up.
      Border        : Pomarine.UI.Layout;
      --  The dialog: a dark bar across its top, as a window's (its title, and a button to close it), and the
      --  list under it.
      List_Close    : Pomarine.UI.Button_Handle;
      --  The dialog's controls are the view's (Pomarine.UI); the list is the application's, borrowed.
      List_View     : Pomarine.Widgets.Lists.List;
      --  A row for each item: its title, to show it, and buttons to show or hide it and to remove it.
      List_Rows     : aliased Item_Rows;
      Model         : Item_List_VM.View_Model;
      Seen          : Pomarine.View_Models.Watch;
      View          : aliased List_Surface;
   end record;
   --  The dialog listing the project's items.

   type Session is tagged limited record
      Replies : aliased Responder;
      Root : Root_Parts;
      Home_View : Home_Parts;
      Confirm : Confirm_Parts;
      Home_Model : Home_Choices;
      Menu_Target : aliased Menu_Router;
      Menu_Model : aliased Menu_VM.Model;
      Nav_Model : Nav_Choices;
      Room : aliased Room_Maker;
      Canvas_Model : Canvas_Choices;
      Dialog_Model : Confirm_Choices;
      Prefs : Settings_Parts;
      Choices : Settings_Choices;
      Settings_Reactions : aliased Settings_Effects;
      Confirm_Reactions : aliased Confirm_Effects;
      Home_Reactions : aliased Home_Effects;
      Layout_Watcher : aliased Layout_Watch;
      Outline_Reactions : aliased Outline_Effects;
      Nav_Reactions : aliased Nav_Effects;
      Judge : aliased Command_Judge;
      Toolbar : Toolbar_Parts;
      Canvas_View   : Backgrounds.Canvas;
      --  In the content area, all of it.
      Page_View : Page_Parts;
      Publish_View : Publish_Parts;
      Section_View : Section_View_Parts;
      Dock : Dock_Parts;
      Nav : Nav_State;
      Item_List : List_Parts;
      Host : Host_Resources;
      Models       : Items.Models.Tables.Table;
      --  What the project's items are, a slot to each: before the windows that show them.
      Windows      : Items.Windows.Tables.Table;
      --  The windows of the project's items, a slot to each: after Target, which they
      --  draw to.
      Docs : Document_State;
      Grammar_Checks : Grammar_State;
      Grammar_Model : Rule_Choices;
      Outline_View : Outline_Parts;
      Outline_Model : Outline_Choices;
      Context : Context_State;
      Section_Menu : Section_Menu_Parts;
      Naming : Renaming_State;
      Reading : Reading_State;
      Dragging : Drag_State;
      Linking : Link_State;
      Searching : Search_State;
      Finding : aliased Search_Finder;
      Shell : Shell_State;
      Forms : Form_Array;
      --  After all the widgets the forms are mounted into: they go first, with their panels out of those.
   end record;

   function Project_Panel (Item : Session) return access Pomarine.Widgets.Widget'Class is
     (Pomarine.UI.Panel_Of (Item.Forms (Project_Region).Screen.all, Item.Toolbar.Project_Layout));
   --  A column: the toolbar, the content area, and the dock.

   function Home_Panel (Item : Session) return access Pomarine.Widgets.Widget'Class is
     (Pomarine.UI.Panel_Of (Item.Forms (Home_Region).Screen.all, Item.Home_View.Home_Layout));
   --  A row: the sidebar of actions, and the recent projects.

   function Tab_Of
     (Item : Session; Which : Pomarine.UI.Button_Handle) return not null access Pomarine.Widgets.Buttons.Button is
     (Pomarine.UI.Widget_Of (Item.Forms (Project_Region).Screen.all, Which));
   --  A button of the project's toolbar.

   function Tray_Panel (Item : Session) return access Pomarine.Widgets.Widget'Class is
     (Pomarine.UI.Panel_Of (Item.Forms (Tray_Region).Screen.all, Item.Dock.Tools));
   --  The tray of tools, over the canvas at the foot.

   function Content_Panel (Item : Session) return access Pomarine.Widgets.Widget'Class is
     (Pomarine.UI.Panel_Of (Item.Forms (Project_Region).Screen.all, Item.Toolbar.Content_Layout));
   --  Where the views of a project are, and the tray and the menus over them.

end View;
