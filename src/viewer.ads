with Projects;
with SDL3.Cursors;
with SDL3.Events;
with SDL3.Windows.Renderers.Images;
private with Ada.Strings.Unbounded;
private with SDL3.Windows;
private with Scripts;
private with Texts.Documents;
private with UI.Clipboards;
private with UI.Icons;
private with UI.Line_Texts;
private with UI.Widgets.Buttons;
private with UI.Widgets.Canvases;
private with UI.Widgets.Labels;
private with UI.Widgets.Text_Fields;
private with UI.Widgets.Palettes;
private with UI.Widgets.Panels;

--  A window of two screens: the home, with the recent projects and
--  buttons to start with, and a project, with a toolbar and, above it, the
--  project's main view, one at a time, chosen on the toolbar.
package Viewer is

   type Screens is (Home, Project);

   type Modes is (Canvas);
   --  The views of a project. Canvas, an infinite canvas to pan and zoom,
   --  with a floating toolbar to drag, is the first, and so the one shown.

   procedure Run (Source : String; File_Name : String := "");
   --  Open a window, at the home screen, and run until it is closed.
   --  Source is kept as the project's text, a paragraph to each line, and
   --  Command-S saves it to File_Name, if it is given; no view shows it
   --  yet. The projects are kept in Projects.Default_Path. SDL must be
   --  initialized.

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

   function Cursor (Item : Session) return SDL3.Cursors.Kind
     with Pre => Is_Open (Item);
   --  The shape the pointer has, from where it was last seen: the arrow,
   --  or the move cursor over the grip of the floating toolbar and while
   --  panning the canvas.

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
      Tools         : UI.Widgets.Palettes.Palette;
      Tool_Item     : UI.Widgets.Buttons.Button;
      --  The floating toolbar, over the canvas, and its one item.

      Shown        : Screens := Home;
      Store        : Projects.Store;

      Script       : aliased Scripts.Script;
      Win          : SDL3.Windows.Window;
      Target       : SDL3.Windows.Renderers.Renderer;
      --  after Win: it is destroyed first
      Pictures     : aliased UI.Icons.Library;
      --  after Target, which it draws to
      Lines        : aliased UI.Line_Texts.Drawer;
      --  after Target, which it draws to
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
