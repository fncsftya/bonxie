with Projects;
with SDL3.Cursors;
with SDL3.Events;
with SDL3.Windows.Renderers.Images;
private with Ada.Strings.Unbounded;
private with MLX.Hub;
private with MLX.Jobs;
private with Speech.Models;
private with Items;
private with Items.Directories;
private with Items.Links;
private with Items.Readers;
private with Items.Windows;
private with Preferences;
private with Previews;
private with SDL3.Windows;
private with Scripts;
private with Texts.Documents;
private with Typeset.Views;
private with Pomarine.Accessibility;
private with Pomarine.Clipboards;
private with Pomarine.Native_Menus;
private with Pomarine.Icons;
private with Pomarine.Line_Texts;
private with Pomarine.Models;
private with Pomarine.Widgets;
private with Pomarine.Widgets.Buttons;
private with Pomarine.Widgets.Checks;
private with Pomarine.Widgets.Canvases;
private with Pomarine.Widgets.Commands;
private with Pomarine.Widgets.Editors;
private with Pomarine.Widgets.Grips;
private with Pomarine.Widgets.Labels;
private with Pomarine.Widgets.Lists;
private with Pomarine.Widgets.Menus;
private with Pomarine.Widgets.Text_Fields;
private with Pomarine.Widgets.Panels;
private with Pomarine.Widgets.Pins;
private with Pomarine.Widgets.Progress_Bars;
private with Pomarine.Widgets.Scrollers;
private with Pomarine.Widgets.Selects;
private with Pomarine.Widgets.Switches;

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
--    Canvas_Camera   how the canvas is zoomed and panned
--    Canvas_Windows  the items on the canvas
--    Canvas_Links    the links between them, and their pins
--    Documents       the pages of the writing view, and its directories
--    Sources         the sources of the writing view, and the pinned one
package Viewer is

   type Screens is (Home, Project);

   type Modes is (Canvas, Write);
   --  The views of a project. Canvas, an infinite canvas to pan and zoom,
   --  with a toolbar of tools above the main one, is the first, and so the
   --  one shown. Write shows the items that are not sources, as documents,
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

   --  What the menu bar and the keys can ask for, apart from what edits
   --  text: each is said as a command (see Viewer.Menus), to be done by
   --  Viewer.Responses. The buttons that do the same are given the command
   --  too (see Viewer.Build), to be on or off as it is. What each button
   --  does is its own (see Pomarine.Widgets.Callbacks).

   type Command is
     (Start_Project,
      Open_Settings,
      Leave_Project,
      Show_Canvas,
      Show_Writing,
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

   type Project_Card is limited record
      Panel   : Pomarine.Widgets.Panels.Panel;
      --  A column, outlined, with a shadow: the picture, and below it
      --  the name and the buttons.
      Peek    : Pomarine.Widgets.Grips.Grip;
      Picture : Previews.Preview;
      --  Of its canvas: clicked, to open it.
      Info    : Pomarine.Widgets.Panels.Panel;
      Name    : Pomarine.Widgets.Grips.Grip;
      --  Clicked, to open it; in the place of which, the field to rename
      --  it.
      Title   : Pomarine.Widgets.Labels.Label;
      Meta    : Pomarine.Widgets.Labels.Label;
      --  How many documents and sources it has.
      Rename  : Pomarine.Widgets.Buttons.Button;
      Delete  : Pomarine.Widgets.Buttons.Button;
   end record;
   --  A project listed on the home screen.

   type Card_Array is array (1 .. Projects.Recent_Count) of Project_Card;
   type Key_Array is array (Card_Array'Range) of Projects.Id;

   type Slot_Array is array (Items.Slot) of Items.Slot;
   type Dir_Array is array (Items.Slot) of Natural;

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

   type Pin_Grid is
     array (Items.Slot, Items.Links.Sides) of aliased Pomarine.Widgets.Pins.Pin;
   --  The handles to link items by: four round each window.

   type Stroke_Button_Array is
     array (Items.Links.Strokes) of Pomarine.Widgets.Buttons.Button;
   type End_Button_Array is
     array (Items.Links.Endings) of Pomarine.Widgets.Buttons.Button;
   type Color_Button_Array is
     array (Items.Links.Link_Colors) of Pomarine.Widgets.Buttons.Button;

   type Pin_Places is array (Items.Slot, Items.Links.Sides) of Float;

   type Doc_Page is limited record
      Box     : Pomarine.Widgets.Panels.Panel;
      --  A column: the bar above, and the page.
      Bar     : Pomarine.Widgets.Panels.Panel;
      Heading_Area : Pomarine.Widgets.Grips.Grip;
      Heading : Pomarine.Widgets.Labels.Label;
      --  The title, in a grip that takes a double press to rename it.
      Title_Field : Pomarine.Widgets.Text_Fields.Text_Field;
      --  In its place while it is renamed, on the title of the window.
      Renaming : Boolean := False;
      Sources_Button : Pomarine.Widgets.Buttons.Button;
      --  A dropdown: opens the menu of the sources the document is
      --  linked to, and shows how many.
      Mic_Button : Pomarine.Widgets.Buttons.Button;
      --  Starts and stops dictating into the document.
      Sheet   : Pomarine.Widgets.Panels.Panel;
      --  The white page.
      Text    : Pomarine.Widgets.Editors.Editor;
      --  The text of a document, which its window on the canvas has too.
      Words   : Pomarine.Widgets.Labels.Label;
      --  Below the page, at the right: how many words it has.
      Bound   : Natural := 0;
      --  The window it shows, 0 if none.
      Wide, High : Float := 0.0;
      --  The width of the sheet and the height of the text, in points, as
      --  last set.
      Caret_For  : Texts.Position := (1, 1);
      Caret_Seen : Texts.Documents.Version := 0;
      --  Where the caret was, in what version of the document, when last
      --  brought into view.
   end record;

   type Page_Array is array (Items.Slot) of Doc_Page;

   Tree_Capacity : constant :=
     1 + Items.Directories.Max_Directories + Items.Capacity;
   --  The rows of the tree of documents: the Overview, every directory,
   --  and every document.

   subtype Tree_Row is Positive range 1 .. Tree_Capacity;

   type Tree_Kinds is (Overview_Node, Directory_Node, Document_Leaf);

   type Tree_Entry is record
      Kind : Tree_Kinds := Overview_Node;
      Dir  : Natural := 0;
      --  Of a directory, which it is (of Dirs); of a document, the
      --  directory it is in, 0 if none.
      Doc  : Natural := 0;
      --  Of a document, its window.
   end record;
   --  What a row of the tree is of.

   type Tree_Entry_Array is array (Tree_Row) of Tree_Entry;

   type Drop_Kinds is (No_Drop, Into_Node, Between);
   --  Where a row dragged would go: nowhere, into the Overview or a
   --  directory (the row of the tree under the pointer), or between two
   --  rows of the tree.

   type Drop_Target is record
      Kind  : Drop_Kinds := No_Drop;
      Row   : Natural := 0;
      --  Of Into_Node: the row dropped on.
      Index : Natural := 0;
      --  Of Between: the row it would be put before (one past the last
      --  if it goes last).
      Dir   : Natural := 0;
      --  Of Between: the directory it would be in, 0 if none.
   end record;

   type Context_Kinds is
     (No_Context, Tree_Context, Text_Context, Picture_Context);
   --  What the menu shown at a right click is of: a row (of the tree, or a
   --  source), the text of a page, or a source's picture.

   type Context_Acts is
     (No_Act, Rename_Act, Delete_Act, Copy_Act, Cut_Act, Paste_Act,
      Select_All_Act);
   --  What a row of it does.

   type Act_Array is array (1 .. 4) of Context_Acts;

   type Index_Row is limited record
      Row     : Pomarine.Widgets.Grips.Grip;
      --  Clicked to go to the document, or to open the source; dragged to
      --  put a document elsewhere in the order.
      Tag     : Pomarine.Widgets.Panels.Panel;
      --  Of a source: a square of its colour.
      Caption : Pomarine.Widgets.Labels.Label;
      Count   : Pomarine.Widgets.Labels.Label;
      --  Of a document: how many words it has; of a directory, how many
      --  documents.
      Indent  : Float := 0.0;
      --  How far in, in points, it has been put.
   end record;
   --  A row of a list in the writing view's sidebar.

   type Index_Row_Array is array (Items.Slot) of Index_Row;
   type Tree_Row_Array is array (Tree_Row) of Index_Row;

   type Sync_State is record
      Own, Peer : Natural := 0;
   end record;
   --  Of a reader's highlights: the version of its picture's, and of its
   --  window's on the canvas, when they were last made the same.

   type Sync_Array is array (Items.Slot) of Sync_State;

   type Placed_Array is array (Items.Slot) of Boolean;

   type Root_Parts is limited record
      Widgets      : Pomarine.Widgets.Tree;
      Window_Panel : Pomarine.Widgets.Panels.Panel;
      --  The root, of both screens, one of which is hidden.
      Header_Panel : Pomarine.Widgets.Panels.Panel;
      Header_Title : Pomarine.Widgets.Labels.Label;
      --  Across the top of a window, where its title bar was: under the
      --  window's own buttons.
   end record;
   --  The tree of widgets and the panels at the top of both screens.

   type Home_Parts is limited record
      Home_Panel     : Pomarine.Widgets.Panels.Panel;
      --  A row: the sidebar of actions, and the recent projects.
      Home_Side      : Pomarine.Widgets.Panels.Panel;
      Logo           : Pomarine.Widgets.Panels.Panel;
      Logo_Name      : Pomarine.Widgets.Labels.Label;
      New_Button     : Pomarine.Widgets.Buttons.Button;
      Side_Room      : Pomarine.Widgets.Panels.Panel;
      --  Between New Project at the top and Settings at the foot.
      Settings_Button : Pomarine.Widgets.Buttons.Button;
      Home_Rule      : Pomarine.Widgets.Panels.Panel;
      --  The line between the sidebar and the projects.
      Recent_Panel   : Pomarine.Widgets.Panels.Panel;
      Recent_Title   : Pomarine.Widgets.Labels.Label;
      Cards_Scroll   : Pomarine.Widgets.Scrollers.Scroller;
      Cards_Content  : Pomarine.Widgets.Panels.Panel;
      --  The cards, in rows that wrap, scrolled.
      Cards          : Card_Array;
      --  A card to each of the projects listed.
      Row_Keys       : Key_Array := [others => 0];
      Listed         : Projects.Recent_List;
      --  The projects the cards are of.
      No_Rows        : Pomarine.Widgets.Labels.Label;
      --  Shown when there are none.
      New_Card       : Pomarine.Widgets.Grips.Grip;
      New_Card_Plus  : Pomarine.Widgets.Buttons.Button;
      New_Card_Label : Pomarine.Widgets.Labels.Label;
      --  After the cards: an outline of one, in dashes, to make a project.

      Edit_Panel     : Pomarine.Widgets.Panels.Panel;
      Ok_Button      : Pomarine.Widgets.Buttons.Button;
      Cancel_Button  : Pomarine.Widgets.Buttons.Button;
      --  Put in the card of the project being renamed, in place of its
      --  name and buttons, which are hidden.
      Editing        : Natural := 0;
      --  Which card, 0 if none.
   end record;
   --  The home screen: the sidebar, the recent projects as cards, and the
   --  field to rename one.

   type Confirm_Parts is limited record
      Overlay        : Pomarine.Widgets.Panels.Panel;
      --  Over both screens, to grey them out and hold the dialog, which
      --  is shown to confirm deleting a project.
      Dialog_Border  : Pomarine.Widgets.Panels.Panel;
      Dialog_Bar     : Pomarine.Widgets.Panels.Panel;
      Dialog_Title   : Pomarine.Widgets.Labels.Label;
      Dialog_Close   : Pomarine.Widgets.Buttons.Button;
      --  A dark bar across its top, as a window's: its title, and a
      --  button to close it, as Cancel does.
      Dialog         : Pomarine.Widgets.Panels.Panel;
      Confirm_Message : Pomarine.Widgets.Labels.Label;
      Confirm_Note   : Pomarine.Widgets.Labels.Label;
      Dialog_Rule    : Pomarine.Widgets.Panels.Panel;
      Confirm_Buttons : Pomarine.Widgets.Panels.Panel;
      --  The white body, saying what is to be deleted, a line, and a
      --  tinted foot with the buttons.
      Confirm_Cancel : Pomarine.Widgets.Buttons.Button;
      Confirm_Delete : Pomarine.Widgets.Buttons.Button;
      Deleting       : Projects.Id := 0;
      --  The project the dialog is about, 0 if it is not shown.
      Deleting_Model : Boolean := False;
      --  Or the dialog is about the speech model's files (see Settings_View).
      Deleting_Node  : Tree_Entry;
      --  Or, in the writing view, the document or directory it is about:
      --  the Overview's if it is about none.
   end record;
   --  The dialog, over both screens, to confirm deleting.

   AI_Note_Lines : constant := 6;
   --  Lines of what is said under the AI model: why it will not run, or
   --  what it replied to the test.

   type AI_Note_Array is array (1 .. AI_Note_Lines) of Pomarine.Widgets.Labels.Label;

   type Settings_Parts is limited record
      Settings_Panel : Pomarine.Widgets.Panels.Panel;
      --  A column, in the home screen's place while Showing_Settings: a
      --  bar across the top, which stays, and below it the form, scrolled.
      Settings_Bar   : Pomarine.Widgets.Panels.Panel;
      Settings_Title : Pomarine.Widgets.Labels.Label;
      Settings_Close : Pomarine.Widgets.Buttons.Button;
      Settings_Scroll  : Pomarine.Widgets.Scrollers.Scroller;
      Settings_Content : Pomarine.Widgets.Panels.Panel;
      --  Centres the form, which is as wide as a page in the writing view.
      Settings_Form  : Pomarine.Widgets.Panels.Panel;
      Form_Wide      : Float := 0.0;
      --  Its width, in points, as last set (see Settings_View.Fit).
      Speech_Heading : Pomarine.Widgets.Labels.Label;
      Model_Name     : Pomarine.Widgets.Labels.Label;
      Model_Native   : Pomarine.Widgets.Checks.Check;
      Model_Parakeet : Pomarine.Widgets.Checks.Check;
      --  Speech's one option, Model: a radio for each.
      Display_Heading : Pomarine.Widgets.Labels.Label;
      Theme_Name     : Pomarine.Widgets.Labels.Label;
      Theme_Light    : Pomarine.Widgets.Checks.Check;
      Theme_Dark     : Pomarine.Widgets.Checks.Check;
      Theme_System   : Pomarine.Widgets.Checks.Check;
      --  Display's one option, Theme: a radio for each.
      Download_Row   : Pomarine.Widgets.Panels.Panel;
      Download_Button : Pomarine.Widgets.Buttons.Button;
      Delete_Button  : Pomarine.Widgets.Buttons.Button;
      Download_State : Pomarine.Widgets.Labels.Label;
      Download_Bar   : Pomarine.Widgets.Progress_Bars.Progress_Bar;
      --  Under the radios, with Parakeet chosen: the button to fetch its
      --  file, shown while it is not there, or else the button to delete
      --  it; what is the matter with it, or how big it is, or, while it
      --  comes, how far.
      AI_Heading     : Pomarine.Widgets.Labels.Label;
      AI_Enable      : Pomarine.Widgets.Switches.Switch;
      AI_Model_Name  : Pomarine.Widgets.Labels.Label;
      AI_Hub_Note    : Pomarine.Widgets.Labels.Label;
      AI_Select      : Pomarine.Widgets.Selects.Select_Field;
      AI_Test_Row    : Pomarine.Widgets.Panels.Panel;
      AI_Test_Button : Pomarine.Widgets.Buttons.Button;
      AI_Test_State  : Pomarine.Widgets.Labels.Label;
      AI_Notes       : AI_Note_Array;
      --  AI: Enable, a switch; and, with it on, Model: a field to choose
      --  from the models of the Hugging Face cache (or, if there is
      --  none, a note that it is not found), the menu it opens (AI_Menu,
      --  over the form), then a Test button with how the test is, and
      --  under it what is to be said.
      AI_Menu        : Pomarine.Widgets.Menus.Menu;
      AI_Menu_Open   : Boolean := False;
      AI_Menu_Left   : Float := -1.0E9;
      AI_Menu_Top    : Float := -1.0E9;
      --  Where the menu was last put, in points of the settings panel.
      AI_On          : Boolean := False;
      AI_Model       : Ada.Strings.Unbounded.Unbounded_String;
      --  The model chosen, "provider/name", empty for none.
      AI_Found       : MLX.Hub.Models;
      AI_Problem     : Ada.Strings.Unbounded.Unbounded_String;
      --  Why the model chosen will not run, empty if it will.
      AI_Tested      : Ada.Strings.Unbounded.Unbounded_String;
      --  The model the test was begun for: what it says is of that one.
      AI_Job         : MLX.Jobs.Job;
      --  The test of the model chosen, asked in the background.
      AI_Test_Seen   : MLX.Jobs.States := MLX.Jobs.Idle;
      --  How the test was when the form last showed it.
      Showing_Settings : Boolean := False;
      Speech_Choice  : Preferences.Speech_Models := Preferences.MacOS;
      Theme_Chosen   : Preferences.Theme_Choices := Preferences.System;
      Dark_Shown     : Boolean := False;
      --  Whether the windows are drawn in the dark theme, as last applied.
      Config_Dir     : Ada.Strings.Unbounded.Unbounded_String;
      --  Where the settings and the files they need are kept.
      Persist        : Boolean := False;
      --  Whether the settings are written there: not offscreen.
      Download_Seen  : Speech.Models.States := Speech.Models.Idle;
      --  How the download was when the form last showed it.
   end record;
   --  The settings, and what is chosen in them.

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
      Canvas_Tab    : Pomarine.Widgets.Buttons.Button;
      Write_Tab     : Pomarine.Widgets.Buttons.Button;
      --  A tab for each view, in the middle of the toolbar.
      Toolbar_End   : Pomarine.Widgets.Panels.Panel;
      --  On the right: the list of items.
      Mode          : Modes := Canvas;
      --  The view shown: its tab is selected.
   end record;
   --  The project screen: its panels, the toolbar and the view shown.

   type Page_Parts is limited record
      Write_View    : Pomarine.Widgets.Panels.Panel;
      --  A row, in the content area in the canvas's place when Mode is
      --  Write: the sidebar, the pages, and the pane of the pinned source;
      --  and the windows of the sources, over them.
      Sidebar       : Pomarine.Widgets.Panels.Panel;
      Sidebar_Rule  : Pomarine.Widgets.Panels.Panel;
      --  The line at its right.
      Docs_Head     : Pomarine.Widgets.Panels.Panel;
      Docs_Heading  : Pomarine.Widgets.Labels.Label;
      Docs_Add      : Pomarine.Widgets.Buttons.Button;
      Docs_Folder   : Pomarine.Widgets.Buttons.Button;
      --  Beside the name of the list: add a document, and a directory.
      Docs_Scroll   : Pomarine.Widgets.Scrollers.Scroller;
      Docs_Content  : Pomarine.Widgets.Panels.Panel;
      Docs_None     : Pomarine.Widgets.Labels.Label;
      Sources_Heading : Pomarine.Widgets.Labels.Label;
      Sources_Scroll  : Pomarine.Widgets.Scrollers.Scroller;
      Sources_Content : Pomarine.Widgets.Panels.Panel;
      Sources_None  : Pomarine.Widgets.Labels.Label;
      --  The two lists of the sidebar: of the documents, in the order they
      --  are written in, and of the sources.
      Pages_Scroll  : Pomarine.Widgets.Scrollers.Scroller;
      Pages_Content : Pomarine.Widgets.Panels.Panel;
      --  The pages, one above the next, scrolled together.
      Pane          : Pomarine.Widgets.Panels.Panel;
      Pane_Edge     : Pomarine.Widgets.Grips.Grip;
      Pane_Body     : Pomarine.Widgets.Panels.Panel;
      --  At the right, the full height of the view, shown while a source
      --  is pinned; the edge is dragged to size it.
      Menu          : Pomarine.Widgets.Menus.Menu;
      --  Over the pages, hidden until a document's Sources button is
      --  clicked: a heading, a box for each source the document is linked
      --  to, ticked if it is the one pinned (or a note that there are
      --  none), a line, and Add Source.
      Menu_Page     : Natural := 0;
      --  The page the menu is of, 0 if it is not shown.
      Menu_Slots    : Slot_Array := [others => 1];
      Menu_Count    : Natural := 0;
      --  The windows of the sources the boxes are of, from the second
      --  row.
      Menu_Left, Menu_Top : Float := -1.0E9;
      --  Where it was last put, in points of the writing view.
      Pane_Wide     : Float := 0.0;
      --  How wide, in points.
   end record;
   --  The writing view: the sidebar, the pages, the pane of the pinned source
   --  and the menu of a page.

   type Dock_Parts is limited record
      Dock_Panel    : Pomarine.Widgets.Panels.Panel;
      Dock_Scroll   : Pomarine.Widgets.Scrollers.Scroller;
      Dock_Content  : Pomarine.Widgets.Panels.Panel;
      --  The bars sit in a row in Dock_Content, which scrolls across
      --  when they are wider than the window.
      --  A bar above the tools, of the bars of the items that are
      --  minimised: shown only when there are any.
      Tools         : Pomarine.Widgets.Panels.Panel;
      Tool_Item     : Pomarine.Widgets.Buttons.Button;
      Tool_Source   : Pomarine.Widgets.Buttons.Button;
      --  The tray of the canvas's tools, over it at the foot, in the
      --  middle: Add Document, Add Source.
      Tray_Left     : Float := -1.0E9;
      --  Where it was last put, in pixels from the left of the content.
      Tool_List     : Pomarine.Widgets.Buttons.Button;
      --  At the right of the toolbar: the list of items.
   end record;
   --  The dock of minimised items and the tray of tools, over the canvas.

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

   type Host_Resources is limited record
      Script       : aliased Scripts.Script;
      Win          : SDL3.Windows.Window;
      Assistive    : Pomarine.Accessibility.Adapter;
      Menus        : Pomarine.Native_Menus.Menu_Bar;
      --  after Win: it is let go of the window first
      Target       : SDL3.Windows.Renderers.Renderer;
      --  after Win: it is destroyed first
      Pictures     : aliased Pomarine.Icons.Library;
      --  after Target, which it draws to
      Lines        : aliased Pomarine.Line_Texts.Drawer;
      --  after Target, which it draws to
      Doc_Resources : aliased Typeset.Views.Shared_Resources;
      --  after Target, which its atlas draws to
   end record;
   --  The text, the window and what draws to it: declared in the order they
   --  are destroyed in, the last first.

   type Document_State is limited record
      Pages        : Page_Array;
      --  The pages of the writing view: after Windows, whose documents
      --  they show.
      Doc_Rows     : Tree_Row_Array;
      Tree         : Tree_Entry_Array;
      Tree_Count   : Natural := 0;
      --  The rows of the documents' tree, from the top: the Overview,
      --  then each directory directly followed by its documents, and
      --  the documents in none among them. What each is of.
      Dirs         : Items.Directories.Directory_List;
      Doc_Dir      : Dir_Array := [others => 0];
      --  The directories, and which of them each document's window is in,
      --  0 if none. Tree is the order of it all.
      Shown_Dir    : Natural := 0;
      --  The directory whose documents are the pages, 0 for the Overview:
      --  all of them.
      Drop         : Drop_Target;
      --  Where the document being dragged would go.
      Drop_Line    : Pomarine.Widgets.Panels.Panel;
      --  The line between two rows where it would go between documents,
      --  over the rows and out of the way of their layout.
   end record;
   --  The pages of the writing view, the tree of documents and where a row
   --  dragged would go.

   type Context_State is limited record
      Context_Menu : Pomarine.Widgets.Menus.Menu;
      Context_Kind : Context_Kinds := No_Context;
      Context_Node : Tree_Entry;
      --  A document or directory, or a source (a leaf, of the slot of its
      --  window).
      Context_Page : Natural := 0;
      --  Of Text_Context: the page.
      Context_Canvas : Natural := 0;
      --  Of Text_Context and Picture_Context: the window on the canvas the
      --  menu is of, if it is of one, not of a page or a reader.
      Context_Reader : Natural := 0;
      --  Of Picture_Context: the window of the source whose reader, or 0
      --  if the pinned one.
      Context_Acts : Act_Array := [others => No_Act];
      --  Over the writing view, hidden until the right button is pressed
      --  on a row of the sidebar, a page's text or a source's picture;
      --  what it is of, and what each of its rows does.
   end record;
   --  The menu at a right click.

   type Renaming_State is limited record
      Dir_Field    : Pomarine.Widgets.Text_Fields.Text_Field;
      Dir_Doc      : aliased Texts.Documents.Document;
      Renaming_Dir : Natural := 0;
      Renaming_Doc : Natural := 0;
      Source_Field : Pomarine.Widgets.Text_Fields.Text_Field;
      Renaming_Source : Natural := 0;
      --  The directory, the document or the source being renamed, 0 if
      --  none, in the field over its row (of Source_Field, for a source).
   end record;
   --  The fields over a row being renamed.

   type Reading_State is limited record
      Source_Rows  : Index_Row_Array;
      Readers      : Items.Readers.Reader_Array;
      --  The windows of the sources in the writing view, of the same
      --  slots as Windows.
      Pane_Reader  : Items.Readers.Reader;
      --  The pinned source, in the pane.
      Reader_Sync  : Sync_Array;
      Pane_Sync    : Sync_State;
      Reader_Placed : Placed_Array := [others => False];
      --  Whether a reader has been given a place yet.
      Write_Order  : Slot_Array := [others => 1];
      Write_Count  : Natural := 0;
      --  The windows of the documents, in the order they are written in.
      Source_Order : Slot_Array := [others => 1];
      Source_Total : Natural := 0;
      --  The windows of the sources, the earliest made first.
      Pinned_Slot  : Natural := 0;
      --  The window of the source in the pane, 0 if none.
   end record;
   --  The sources in the writing view, and the orders of the windows of
   --  documents and of sources.

   type Drag_State is limited record
      Drag_Row     : Natural := 0;
      Drag_Total   : Float := 0.0;
      Drag_Moved   : Boolean := False;
      --  The row of the list of documents being dragged, how far, and the
      --  order when it was pressed.
      Dropped_Moved : Boolean := False;
      --  Whether the row last let go had been dragged, so that it is not
      --  clicked as well.
   end record;
   --  The row of the list of documents being dragged.

   type Link_State is limited record
      Pins         : Pin_Grid;
      --  On the canvas, over the windows, shown where the pointer is.
      Pin_Left, Pin_Top : Pin_Places := [others => [others => -1.0E9]];
      --  Where each was last put, in pixels, to put it again only if it
      --  moves.
      Link_Handle  : Pomarine.Widgets.Pins.Pin;
      --  Over the target end of the selected link, to drag it to another
      --  pin by.
      Link_Bar     : Pomarine.Widgets.Panels.Panel;
      Stroke_Buttons : Stroke_Button_Array;
      End_Buttons    : End_Button_Array;
      Color_Buttons  : Color_Button_Array;
      Delete_Link    : Pomarine.Widgets.Buttons.Button;
      --  Beside the selected link: how it is drawn, and to delete it.
      Link_Key     : Items.Id := 0;
      --  The link selected, 0 if none.
      Link_Moving  : Boolean := False;
      --  Whether the target end of the selected link is being dragged,
      --  rather than a new link from a pin.
      Handle_Left, Handle_Top, Bar_Left, Bar_Top : Float := -1.0E9;
      --  Where they were last put, in pixels.
      Link_Set     : Items.Links.Link_List;
      --  The links between the project's items.
      Link_From    : Natural := 0;
      Link_From_Side : Items.Links.Sides := Items.Links.Top;
      --  The window and side of the pin a line is being dragged from;
      --  0 if none is.
   end record;
   --  The pins, and the links being made, selected and drawn.

   type Title_Edit_State is limited record
      Edit_Doc     : aliased Texts.Documents.Document;
      Edit_Field   : Pomarine.Widgets.Text_Fields.Text_Field;
      --  The title being renamed, and the field for it, which is in the
      --  edit panel: after Target, and the document.
   end record;
   --  The title of an item on the canvas being renamed.

   type Opened_State is limited record
      Current      : Projects.Id := 0;
      --  The project shown, at the project screen.
      Project_Name : Ada.Strings.Unbounded.Unbounded_String;
      --  Its name, for the window's title.
   end record;
   --  The project shown.

   type Shell_State is limited record
      Density      : Float := 1.0;
      --  Pixels to a point of the window.

      Shown_Cursor : SDL3.Cursors.Kind := SDL3.Cursors.Default;
      --  The one the window has been given.

      Shown_Title  : Ada.Strings.Unbounded.Unbounded_String;

      Windowed     : Boolean := False;
      Moving       : Boolean := False;
      --  Whether a press on the bar is moving the window, from where the
      --  pointer and the window were when it was pressed.
      Grab_X, Grab_Y       : Float := 0.0;
      Grab_Left, Grab_Top  : Integer := 0;
      System_Board : Pomarine.Clipboards.System_Clipboard;
      Own_Board    : Pomarine.Clipboards.Memory_Clipboard;
      --  The clipboard used offscreen.

      Done         : Boolean := False;
   end record;
   --  The window as the system has it, and the clipboards.

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
      Dock : Dock_Parts;
      Nav : Nav_State;
      Item_List : List_Parts;
      Host : Host_Resources;
      Windows      : Items.Windows.Window_Array;
      --  The windows of the project's items: after Target, which they
      --  draw to.
      Docs : Document_State;
      Context : Context_State;
      Naming : Renaming_State;
      Reading : Reading_State;
      Dragging : Drag_State;
      Linking : Link_State;
      Title_Edit : Title_Edit_State;
      Opened : Opened_State;
      Shell : Shell_State;
   end record;

end Viewer;
