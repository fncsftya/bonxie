with Items;
with Preferences;
with Projects;
with SDL3.Cursors;
with SDL3.Events;
with SDL3.Windows.Renderers.Images;
private with Ada.Strings.Unbounded;
private with Downloads;
private with Items.Readers;
private with Items.Windows;
private with Previews;
private with SDL3.Windows;
private with Scripts;
private with Texts.Documents;
private with UI.Clipboards;
private with UI.Icons;
private with UI.Line_Texts;
private with UI.Widgets.Buttons;
private with UI.Widgets.Checks;
private with UI.Widgets.Canvases;
private with UI.Widgets.Editors;
private with UI.Widgets.Grips;
private with UI.Widgets.Labels;
private with UI.Widgets.Menus;
private with UI.Widgets.Text_Fields;
private with UI.Widgets.Panels;
private with UI.Widgets.Pins;
private with UI.Widgets.Progress_Bars;
private with UI.Widgets.Scrollers;

--  A window of two screens: the home, with the recent projects and
--  buttons to start with, and a project, with a toolbar and, above it, the
--  project's main view, one at a time, chosen on the toolbar.
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

   procedure Set_Mode (Item : in out Session; To : Modes)
     with Pre  => Is_Open (Item) and then Screen (Item) = Project,
          Post => Mode (Item) = To;
   --  Show the view, as its tab does.

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

   function Is_Settings_Open (Item : Session) return Boolean
     with Pre => Is_Open (Item);
   --  Whether the settings are shown, in place of the home screen.

   procedure Open_Settings (Item : in out Session)
     with Pre  => Is_Open (Item) and then Screen (Item) = Home
                  and then not Is_Settings_Open (Item),
          Post => Is_Settings_Open (Item);
   --  Show the settings, as the Settings button does.

   procedure Close_Settings (Item : in out Session)
     with Pre  => Is_Open (Item) and then Is_Settings_Open (Item),
          Post => not Is_Settings_Open (Item);
   --  Go back to the home screen, as the settings' Close button does.

   function Speech_Model (Item : Session) return Preferences.Speech_Models
     with Pre => Is_Open (Item);
   --  What is chosen to turn speech into text.

   procedure Choose_Speech_Model
     (Item : in out Session; To : Preferences.Speech_Models)
     with Pre  => Is_Open (Item) and then Is_Settings_Open (Item),
          Post => Preferences."=" (Speech_Model (Item), To);
   --  Choose it, as its radio does.

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

   function Link_Count (Item : Session) return Natural
     with Pre => Is_Open (Item) and then Screen (Item) = Project;
   --  How many links there are between the project's items.

   procedure Link_Items (Item : in out Session; From, To : Positive)
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then From <= Item_Count (Item)
                 and then To <= Item_Count (Item) and then From /= To;
   --  Join the Fromth and Toth items, as dragging from a pin of one to a
   --  pin of the other does: for tests, which need not find the pins.

   function Link_Selected (Item : Session) return Boolean
     with Pre => Is_Open (Item) and then Screen (Item) = Project;
   --  Whether a link is selected.

   function Link_Description
     (Item : Session; Number : Positive) return String
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Number <= Link_Count (Item);
   --  How the link is drawn and where it ends, as words: its stroke, its
   --  end, its colour's number, and the side it ends on.

   function Pin_Count (Item : Session) return Natural
     with Pre => Is_Open (Item) and then Screen (Item) = Project;
   --  How many pins, to drag a link from, are shown.

   procedure Add_Item
     (Item : in out Session;
      Name : String := "Untitled item";
      Kind : Items.Kinds := Items.Note)
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Name'Length <= Projects.Title_Capacity;
   --  Add one called Name in the middle of the canvas, with the focus in
   --  its text, as the Add Item button does (or, of a Source, as Add
   --  Source does, in its link); none if the project has Items.Capacity.

   --  The writing view

   function Document_Count (Item : Session) return Natural
     with Pre => Is_Open (Item) and then Screen (Item) = Project;
   --  How many items there are that are not sources: the pages.

   function Document_Title (Item : Session; Row : Positive) return String
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Document_Count (Item);
   --  The title of the Rowth page, in the order they are written in.

   procedure Move_Document (Item : in out Session; From, To : Positive)
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then From <= Document_Count (Item)
                 and then To <= Document_Count (Item);
   --  Put the From-th page at the To-th, as dragging its row in the list
   --  does, and keep that order.

   function Source_Count (Item : Session) return Natural
     with Pre => Is_Open (Item) and then Screen (Item) = Project;
   --  How many sources there are, listed beside the pages.

   function Source_Title (Item : Session; Row : Positive) return String
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Source_Count (Item);

   function Source_Is_Open (Item : Session; Row : Positive) return Boolean
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Source_Count (Item);
   --  Whether the Rowth source has a window in the writing view, or is
   --  pinned.

   function Source_Marks (Item : Session; Row : Positive) return Natural
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Source_Count (Item);
   --  How many highlights the Rowth source's picture has in the writing
   --  view.

   function Pinned_Source (Item : Session) return Natural
     with Pre => Is_Open (Item) and then Screen (Item) = Project;
   --  Which of the sources is pinned, 0 if none.

   function Item_Title (Item : Session; Row : Positive) return String
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Item_Count (Item);

   function Item_Text (Item : Session; Row : Positive) return String
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Item_Count (Item);

   procedure Dictate_Live
     (Item : in out Session; Row : Positive; Said : String)
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Item_Count (Item)
                 and then Items."=" (Item_Kind (Item, Row), Items.Note);
   --  Show Said in the note's text, as what has been heard so far is
   --  while dictating (see Items.Windows.Set_Live_Dictation): for tests.

   procedure Dictate_Into
     (Item : in out Session; Row : Positive; Said : String)
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Item_Count (Item)
                 and then Items."=" (Item_Kind (Item, Row), Items.Note);
   --  Put Said in the note's text, as what was dictated is when the
   --  microphone is stopped (see Items.Windows.Add_Dictation): for tests,
   --  which cannot speak.

   function Item_Kind (Item : Session; Row : Positive) return Items.Kinds
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Item_Count (Item);

   function Item_Status (Item : Session; Row : Positive) return String
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Item_Count (Item);
   --  What the status line of the item says.

   function Item_Zoom (Item : Session; Row : Positive) return Float
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Item_Count (Item)
                 and then Items."=" (Item_Kind (Item, Row), Items.Source);
   --  How far the picture of the item is zoomed within its window.

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

   function Item_Recognized (Item : Session; Row : Positive) return Natural
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Item_Count (Item)
                 and then Items."=" (Item_Kind (Item, Row), Items.Source);
   --  How many words of text have been found in the picture of the
   --  source, to be selected over it.

   function Item_Selected_Text (Item : Session; Row : Positive) return String
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Item_Count (Item)
                 and then Items."=" (Item_Kind (Item, Row), Items.Source);
   --  What is selected in the picture of the source: what copying gives.

   function Item_Marks (Item : Session; Row : Positive) return Natural
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Item_Count (Item);
   --  How many highlights the item's picture has.

   function Item_Highlighting (Item : Session; Row : Positive) return Boolean
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Item_Count (Item);
   --  Whether the highlighter is the tool of the item's window.

   function Item_Erasing (Item : Session; Row : Positive) return Boolean
     with Pre => Is_Open (Item) and then Screen (Item) = Project
                 and then Row <= Item_Count (Item);
   --  Whether the eraser is the tool of the item's window.

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

   type Project_Card is limited record
      Panel   : UI.Widgets.Panels.Panel;
      --  A column, outlined, with a shadow: the picture, and below it
      --  the name and the buttons.
      Peek    : UI.Widgets.Grips.Grip;
      Picture : Previews.Preview;
      --  Of its canvas: clicked, to open it.
      Info    : UI.Widgets.Panels.Panel;
      Name    : UI.Widgets.Grips.Grip;
      --  Clicked, to open it; in the place of which, the field to rename
      --  it.
      Title   : UI.Widgets.Labels.Label;
      Meta    : UI.Widgets.Labels.Label;
      --  How many documents and sources it has.
      Rename  : UI.Widgets.Buttons.Button;
      Delete  : UI.Widgets.Buttons.Button;
   end record;
   --  A project listed on the home screen.

   type Card_Array is array (1 .. Projects.Recent_Count) of Project_Card;
   type Key_Array is array (Card_Array'Range) of Projects.Id;

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

   type Pin_Grid is
     array (Items.Slot, Items.Sides) of aliased UI.Widgets.Pins.Pin;
   --  The handles to link items by: four round each window.

   type Stroke_Button_Array is
     array (Items.Strokes) of UI.Widgets.Buttons.Button;
   type End_Button_Array is
     array (Items.Endings) of UI.Widgets.Buttons.Button;
   type Color_Button_Array is
     array (Items.Link_Colors) of UI.Widgets.Buttons.Button;

   type Pin_Places is array (Items.Slot, Items.Sides) of Float;

   type Doc_Page is limited record
      Box     : UI.Widgets.Panels.Panel;
      --  A column: the bar above, and the page.
      Bar     : UI.Widgets.Panels.Panel;
      Heading_Area : UI.Widgets.Grips.Grip;
      Heading : UI.Widgets.Labels.Label;
      --  The title, in a grip that takes a double press to rename it.
      Title_Field : UI.Widgets.Text_Fields.Text_Field;
      --  In its place while it is renamed, on the title of the window.
      Renaming : Boolean := False;
      Sources_Button : UI.Widgets.Buttons.Button;
      --  A dropdown: opens the menu of the sources the document is
      --  linked to, and shows how many.
      Mic_Button : UI.Widgets.Buttons.Button;
      --  Starts and stops dictating into the document.
      Sheet   : UI.Widgets.Panels.Panel;
      --  The white page.
      Text    : UI.Widgets.Editors.Editor;
      --  The text of a document, which its window on the canvas has too.
      Words   : UI.Widgets.Labels.Label;
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

   type Index_Row is limited record
      Row     : UI.Widgets.Grips.Grip;
      --  Clicked to go to the document, or to open the source; dragged to
      --  put a document elsewhere in the order.
      Tag     : UI.Widgets.Panels.Panel;
      --  Of a source: a square of its colour.
      Caption : UI.Widgets.Labels.Label;
      Count   : UI.Widgets.Labels.Label;
      --  Of a document: how many words it has.
   end record;
   --  A row of a list in the writing view's sidebar.

   type Index_Row_Array is array (Items.Slot) of Index_Row;

   type Sync_State is record
      Own, Peer : Natural := 0;
   end record;
   --  Of a reader's highlights: the version of its picture's, and of its
   --  window's on the canvas, when they were last made the same.

   type Sync_Array is array (Items.Slot) of Sync_State;

   type Placed_Array is array (Items.Slot) of Boolean;

   type Session is limited record
      Widgets      : UI.Widgets.Tree;
      Window_Panel : UI.Widgets.Panels.Panel;
      --  The root, of both screens, one of which is hidden.
      Header_Panel : UI.Widgets.Panels.Panel;
      Header_Title : UI.Widgets.Labels.Label;
      --  Across the top of a window, where its title bar was: under the
      --  window's own buttons.

      Home_Panel     : UI.Widgets.Panels.Panel;
      --  A row: the sidebar of actions, and the recent projects.
      Home_Side      : UI.Widgets.Panels.Panel;
      Logo           : UI.Widgets.Panels.Panel;
      Logo_Mark      : UI.Widgets.Panels.Panel;
      Logo_Name      : UI.Widgets.Labels.Label;
      New_Button     : UI.Widgets.Buttons.Button;
      Side_Room      : UI.Widgets.Panels.Panel;
      --  Between New Project at the top and Settings at the foot.
      Settings_Button : UI.Widgets.Buttons.Button;
      Home_Rule      : UI.Widgets.Panels.Panel;
      --  The line between the sidebar and the projects.
      Recent_Panel   : UI.Widgets.Panels.Panel;
      Recent_Title   : UI.Widgets.Labels.Label;
      Cards_Scroll   : UI.Widgets.Scrollers.Scroller;
      Cards_Content  : UI.Widgets.Panels.Panel;
      --  The cards, in rows that wrap, scrolled.
      Cards          : Card_Array;
      --  A card to each of the projects listed.
      Row_Keys       : Key_Array := [others => 0];
      Listed         : Projects.Recent_List;
      --  The projects the cards are of.
      No_Rows        : UI.Widgets.Labels.Label;
      --  Shown when there are none.
      New_Card       : UI.Widgets.Grips.Grip;
      New_Card_Plus  : UI.Widgets.Buttons.Button;
      New_Card_Label : UI.Widgets.Labels.Label;
      --  After the cards: an outline of one, in dashes, to make a project.

      Edit_Panel     : UI.Widgets.Panels.Panel;
      Ok_Button      : UI.Widgets.Buttons.Button;
      Cancel_Button  : UI.Widgets.Buttons.Button;
      --  Put in the card of the project being renamed, in place of its
      --  name and buttons, which are hidden.
      Editing        : Natural := 0;
      --  Which card, 0 if none.

      Overlay        : UI.Widgets.Panels.Panel;
      --  Over both screens, to grey them out and hold the dialog, which
      --  is shown to confirm deleting a project.
      Dialog_Border  : UI.Widgets.Panels.Panel;
      Dialog_Bar     : UI.Widgets.Panels.Panel;
      Dialog_Title   : UI.Widgets.Labels.Label;
      Dialog_Close   : UI.Widgets.Buttons.Button;
      --  A dark bar across its top, as a window's: its title, and a
      --  button to close it, as Cancel does.
      Dialog         : UI.Widgets.Panels.Panel;
      Confirm_Message : UI.Widgets.Labels.Label;
      Confirm_Note   : UI.Widgets.Labels.Label;
      Dialog_Rule    : UI.Widgets.Panels.Panel;
      Confirm_Buttons : UI.Widgets.Panels.Panel;
      --  The white body, saying what is to be deleted, a line, and a
      --  tinted foot with the buttons.
      Confirm_Cancel : UI.Widgets.Buttons.Button;
      Confirm_Delete : UI.Widgets.Buttons.Button;
      Deleting       : Projects.Id := 0;
      --  The project the dialog is about, 0 if it is not shown.

      Settings_Panel : UI.Widgets.Panels.Panel;
      --  A column, in the home screen's place while Showing_Settings: a
      --  bar across the top, which stays, and below it the form, scrolled.
      Settings_Bar   : UI.Widgets.Panels.Panel;
      Settings_Title : UI.Widgets.Labels.Label;
      Settings_Close : UI.Widgets.Buttons.Button;
      Settings_Scroll  : UI.Widgets.Scrollers.Scroller;
      Settings_Content : UI.Widgets.Panels.Panel;
      --  Centres the form, which is as wide as a page in the writing view.
      Settings_Form  : UI.Widgets.Panels.Panel;
      Form_Wide      : Float := 0.0;
      --  Its width, in points, as last set (see Settings_View.Fit).
      Speech_Heading : UI.Widgets.Labels.Label;
      Model_Name     : UI.Widgets.Labels.Label;
      Model_Native   : UI.Widgets.Checks.Check;
      Model_Parakeet : UI.Widgets.Checks.Check;
      --  Speech's one option, Model: a radio for each.
      Download_Row   : UI.Widgets.Panels.Panel;
      Download_Button : UI.Widgets.Buttons.Button;
      Download_State : UI.Widgets.Labels.Label;
      Download_Bar   : UI.Widgets.Progress_Bars.Progress_Bar;
      --  Under the radios, with Parakeet chosen: the button to fetch its
      --  file, enabled only while it is not there, what is the matter with
      --  it, and, while it comes, how far.
      Showing_Settings : Boolean := False;
      Speech_Choice  : Preferences.Speech_Models := Preferences.MacOS;
      Config_Dir     : Ada.Strings.Unbounded.Unbounded_String;
      --  Where the settings and the files they need are kept.
      Persist        : Boolean := False;
      --  Whether the settings are written there: not offscreen.
      Download_Seen  : Downloads.States := Downloads.Idle;
      --  How the download was when the form last showed it.

      Project_Panel : UI.Widgets.Panels.Panel;
      --  A column: the toolbar, the content area, and the dock.
      Content_Panel : UI.Widgets.Panels.Panel;
      Toolbar_Panel : UI.Widgets.Panels.Panel;
      Toolbar_Start : UI.Widgets.Panels.Panel;
      --  On the left of the toolbar: the way back, and the project's name.
      Close_Button  : UI.Widgets.Buttons.Button;
      --  Back to the projects.
      Bar_Rule      : UI.Widgets.Panels.Panel;
      Project_Title : UI.Widgets.Labels.Label;
      Tabs          : UI.Widgets.Panels.Panel;
      Canvas_Tab    : UI.Widgets.Buttons.Button;
      Write_Tab     : UI.Widgets.Buttons.Button;
      --  A tab for each view, in the middle of the toolbar.
      Toolbar_End   : UI.Widgets.Panels.Panel;
      --  On the right: the list of items.
      Mode          : Modes := Canvas;
      --  The view shown: its tab is selected.

      Canvas_View   : UI.Widgets.Canvases.Canvas;
      --  In the content area, all of it.
      Write_View    : UI.Widgets.Panels.Panel;
      --  A row, in the content area in the canvas's place when Mode is
      --  Write: the sidebar, the pages, and the pane of the pinned source;
      --  and the windows of the sources, over them.
      Sidebar       : UI.Widgets.Panels.Panel;
      Sidebar_Rule  : UI.Widgets.Panels.Panel;
      --  The line at its right.
      Docs_Head     : UI.Widgets.Panels.Panel;
      Docs_Heading  : UI.Widgets.Labels.Label;
      Docs_Add      : UI.Widgets.Buttons.Button;
      --  Beside the name of the list: adds a document.
      Docs_Scroll   : UI.Widgets.Scrollers.Scroller;
      Docs_Content  : UI.Widgets.Panels.Panel;
      Docs_None     : UI.Widgets.Labels.Label;
      Sources_Heading : UI.Widgets.Labels.Label;
      Sources_Scroll  : UI.Widgets.Scrollers.Scroller;
      Sources_Content : UI.Widgets.Panels.Panel;
      Sources_None  : UI.Widgets.Labels.Label;
      --  The two lists of the sidebar: of the documents, in the order they
      --  are written in, and of the sources.
      Pages_Scroll  : UI.Widgets.Scrollers.Scroller;
      Pages_Content : UI.Widgets.Panels.Panel;
      --  The pages, one above the next, scrolled together.
      Pane          : UI.Widgets.Panels.Panel;
      Pane_Edge     : UI.Widgets.Grips.Grip;
      Pane_Body     : UI.Widgets.Panels.Panel;
      --  At the right, the full height of the view, shown while a source
      --  is pinned; the edge is dragged to size it.
      Menu          : UI.Widgets.Menus.Menu;
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
      Dock_Panel    : UI.Widgets.Panels.Panel;
      Dock_Scroll   : UI.Widgets.Scrollers.Scroller;
      Dock_Content  : UI.Widgets.Panels.Panel;
      --  The bars sit in a row in Dock_Content, which scrolls across
      --  when they are wider than the window.
      --  A bar above the tools, of the bars of the items that are
      --  minimised: shown only when there are any.
      Tools         : UI.Widgets.Panels.Panel;
      Tool_Item     : UI.Widgets.Buttons.Button;
      Tool_Source   : UI.Widgets.Buttons.Button;
      --  The tray of the canvas's tools, over it at the foot, in the
      --  middle: Add Document, Add Source.
      Tray_Left     : Float := -1.0E9;
      --  Where it was last put, in pixels from the left of the content.
      Tool_List     : UI.Widgets.Buttons.Button;
      --  At the right of the toolbar: the list of items.

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
      List_Head     : UI.Widgets.Panels.Panel;
      List_Heading  : UI.Widgets.Labels.Label;
      List_Close    : UI.Widgets.Buttons.Button;
      --  A dark bar across its top, as a window's: its title, and a
      --  button to close it.
      List_Dialog   : UI.Widgets.Panels.Panel;
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
      Pages        : Page_Array;
      --  The pages of the writing view: after Windows, whose documents
      --  they show.
      Doc_Rows     : Index_Row_Array;
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
      Drag_Row     : Natural := 0;
      Drag_Total   : Float := 0.0;
      Drag_Start   : Slot_Array := [others => 1];
      Drag_Moved   : Boolean := False;
      Drag_Target  : Natural := 0;
      --  The row of the list of documents being dragged, how far, and the
      --  order when it was pressed.
      Pins         : Pin_Grid;
      --  On the canvas, over the windows, shown where the pointer is.
      Pin_Left, Pin_Top : Pin_Places := [others => [others => -1.0E9]];
      --  Where each was last put, in pixels, to put it again only if it
      --  moves.
      Link_Handle  : UI.Widgets.Pins.Pin;
      --  Over the target end of the selected link, to drag it to another
      --  pin by.
      Link_Bar     : UI.Widgets.Panels.Panel;
      Stroke_Buttons : Stroke_Button_Array;
      End_Buttons    : End_Button_Array;
      Color_Buttons  : Color_Button_Array;
      Delete_Link    : UI.Widgets.Buttons.Button;
      --  Beside the selected link: how it is drawn, and to delete it.
      Link_Key     : Items.Id := 0;
      --  The link selected, 0 if none.
      Link_Moving  : Boolean := False;
      --  Whether the target end of the selected link is being dragged,
      --  rather than a new link from a pin.
      Handle_Left, Handle_Top, Bar_Left, Bar_Top : Float := -1.0E9;
      --  Where they were last put, in pixels.
      Link_Set     : Items.Link_List;
      --  The links between the project's items.
      Link_From    : Natural := 0;
      Link_From_Side : Items.Sides := Items.Top;
      --  The window and side of the pin a line is being dragged from;
      --  0 if none is.
      Edit_Doc     : aliased Texts.Documents.Document;
      Edit_Field   : UI.Widgets.Text_Fields.Text_Field;
      --  The title being renamed, and the field for it, which is in the
      --  edit panel: after Target, and the document.
      Current      : Projects.Id := 0;
      --  The project shown, at the project screen.
      Project_Name : Ada.Strings.Unbounded.Unbounded_String;
      --  Its name, for the window's title.
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
