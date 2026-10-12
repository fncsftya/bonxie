with SDL3.Events;
with SDL3.Windows.Renderers.Images;
private with Ada.Strings.Unbounded;
private with SDL3.Windows;
private with Scripts;
private with UI.Clipboards;
private with UI.Widgets.Editors;
private with UI.Widgets.Panels;

--  A window showing a document to edit, scroll and zoom.
package Viewer is

   procedure Run (Source : String; File_Name : String := "");
   --  Open a window with the text Source to edit, a paragraph to each
   --  line, and run until it is closed. Command-S saves it to File_Name,
   --  if it is given. SDL must be initialized.

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
   --  Show Source as Run would, in a window Width x Height points of
   --  Density pixels each, but drawn offscreen, in software. It cuts,
   --  copies and pastes on a clipboard of its own.

   function Is_Open (Item : Session) return Boolean;

   function Text (Item : Session) return String
     with Pre => Is_Open (Item);
   --  As edited, a line to each paragraph.

   function Title (Item : Session) return String
     with Pre => Is_Open (Item);
   --  Of the window: the file's name, and whether it has been edited
   --  since it was opened or saved.

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

   procedure Settle (Item : in out Session)
     with Pre => Is_Open (Item);
   --  As if the zoom had held still for long enough to settle.

   procedure Resize (Item : in out Session; Width, Height : Positive)
     with Pre => Is_Open (Item);
   --  As if the window were resized to Width x Height points.

   procedure Render
     (Item   : in out Session;
      Result : in out SDL3.Windows.Renderers.Images.Image)
     with Pre => Is_Open (Item);
   --  Draw what is shown, as into the window, into Result.

private

   type Session is limited record
      Widgets      : UI.Widgets.Tree;
      Window_Panel : UI.Widgets.Panels.Panel;
      --  The root: a column, of the content area above the toolbar.
      Content_Panel : UI.Widgets.Panels.Panel;
      Toolbar_Panel : UI.Widgets.Panels.Panel;

      Script       : aliased Scripts.Script;
      Win          : SDL3.Windows.Window;
      Target       : SDL3.Windows.Renderers.Renderer;
      --  after Win: it is destroyed first
      Area         : UI.Widgets.Editors.Editor;
      --  in the content area, after Target, and Script, which it shows
      Density      : Float := 1.0;
      --  Pixels to a point of the window.

      Zoom         : Float := 1.0;
      Settled      : Boolean := True;
      --  The zoom has stopped changing.
      Zoomed_At    : SDL3.Events.Milliseconds := 0;

      Shown_Title  : Ada.Strings.Unbounded.Unbounded_String;

      Windowed     : Boolean := False;
      System_Board : UI.Clipboards.System_Clipboard;
      Own_Board    : UI.Clipboards.Memory_Clipboard;
      --  The clipboard used offscreen.
      Input_Area   : Integer := Integer'First;
      --  Where the input method was last told the text is, across.

      Done         : Boolean := False;
   end record;

end Viewer;
