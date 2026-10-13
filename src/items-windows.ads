with Projects;
with SDL3.Events;
with Texts.Documents;
with UI.Themes;
with UI.Widgets.Buttons;
with UI.Widgets.Grips;
with UI.Widgets.Labels;
with UI.Widgets.Pictures;
with UI.Widgets.Progress_Bars;
with UI.Widgets.Sliders;
with UI.Widgets.Panels;
with UI.Widgets.Text_Fields;
with Vision;
with UI.Widgets.Editors;

--  What shows one item: a window on the canvas, which can be dragged by
--  its title bar and sized by its corner, with a title to edit, buttons to
--  minimise and close it, its text to edit, and a status line; and, when
--  it is minimised, a short bar in the dock above the tools.
--
--  A window is of one item at a time, or of none. It keeps the item's
--  details, and what has to be written to the database (see Flush); it
--  says what the buttons have asked for, to be taken (Poll), and the
--  application does it. Zoom and pan are the canvas's: it is told them
--  (Place) and puts the window there; the window's text is zoomed with
--  the canvas, its title bar and status line are not.
package Items.Windows is

   use type UI.Widgets.Pictures.Tools;

   type Window is limited private;

   type Window_Array is array (Slot) of Window;

   type Actions is (None, Minimize, Restore, Close, Capture, Speak);
   --  What a window's buttons ask for, and, of a source, Return in its
   --  link's field: to take the picture of the page. Speak is the button
   --  of a note that starts or stops dictating into it.

   type Dictations is (Silent, Preparing, Listening, Transcribing, Failed);
   --  Of a note: not dictating (or it was taken), the microphone is being
   --  readied, it is listening, what was heard is being made text, or
   --  that could not be done.

   type Captures is (Waiting, Busy, Ready, Failed);
   --  Of a source: there is no picture yet, it is being taken, it is
   --  shown, or it could not be taken.

   Idle_Delay : constant := 500;
   --  Milliseconds the text is left alone for before it is written,
   --  although it is still being typed in.

   function Count_Words (Of_Text : String) return Natural;
   --  Of runs of anything but spaces, tabs and line breaks.

   procedure Build
     (Item    : in out Window;
      Canvas  : in out UI.Widgets.Widget'Class;
      Dock    : in out UI.Widgets.Widget'Class;
      Colors  : UI.Themes.Theme;
      Bar     : UI.Themes.Color;
      Density : Float);
   --  Add the window's widgets, hidden: its window to the canvas, its
   --  bar to the dock, both in the tree already. Do it once, before the
   --  layout, with the tree's density.

   function Is_Assigned (Item : Window) return Boolean;

   procedure Assign
     (Item       : in out Window;
      Of_Item    : Items.Info;
      Saved_Text : String;
      Picture_File : String := "")
     with Pre => not Is_Assigned (Item);
   --  Make it the window of the item, with its text Saved_Text, as saved:
   --  shown as its state says, once it is placed. A source that has been
   --  captured shows Picture_File, a PNG.

   procedure Release (Item : in out Window)
     with Post => not Is_Assigned (Item);
   --  Hide it, and forget the item: whatever was not written is lost.

   function Details (Item : Window) return Items.Info
     with Pre => Is_Assigned (Item);

   procedure Set_Tag (Item : in out Window; To : UI.Themes.Color)
     with Pre => Is_Assigned (Item) and then Details (Item).Kind = Source;
   --  Show the source's colour, in a square before its title, as its
   --  links and its rows elsewhere have it.
   --  As the window has it now: the title as edited, where it has been
   --  moved and sized to.

   function Text (Item : Window) return String
     with Pre => Is_Assigned (Item);
   --  Of a source, its link, as edited.

   procedure Set_Capture
     (Item   : in out Window;
      To     : Captures;
      File   : String := "";
      Detail : String := "";
      At_Time : Projects.Seconds := 0)
     with Pre => Is_Assigned (Item)
                 and then Details (Item).Kind = Source
                 and then (To /= Ready or else File /= "");
   --  Say how the source's picture stands, in its status line: Ready
   --  shows the PNG File, read again, as taken at At_Time; Failed says
   --  why, in Detail.

   function Dictation (Item : Window) return Dictations
     with Pre => Is_Assigned (Item);

   procedure Set_Dictation
     (Item   : in out Window;
      To     : Dictations;
      Detail : String := "")
     with Pre  => Is_Assigned (Item) and then Details (Item).Kind = Note,
          Post => Dictation (Item) = To;
   --  Say how dictating stands: the button is a stop button while it is
   --  Preparing or Listening, and the status line says what is going on
   --  (a Failed one says why, in Detail, until the text is next
   --  changed).

   procedure Set_Level (Item : in out Window; To : Float)
     with Pre => Is_Assigned (Item) and then Details (Item).Kind = Note
                 and then To in 0.0 .. 1.0;
   --  Say how loud what is heard is, while Listening: shown as a bar
   --  along the foot of the status line, filled to that far.

   procedure Add_Dictation (Item : in out Window; Said : String)
     with Pre => Is_Assigned (Item) and then Details (Item).Kind = Note;
   --  Put Said in the note's text, as one edit, to be undone together.
   --  If the text is focused, it goes in at the caret (what is selected
   --  is kept); if it has none yet, it is the text; otherwise it is a
   --  new paragraph after the last.

   procedure Set_Live_Dictation (Item : in out Window; Said : String)
     with Pre => Is_Assigned (Item) and then Details (Item).Kind = Note;
   --  Show what has been heard so far, while Listening, in the note's
   --  text, where Add_Dictation will put it: each call replaces the last
   --  Said. These edits are not recorded (they cannot be undone), and
   --  Add_Dictation, or a failure, takes them back before the final text
   --  goes in. If the text is changed by anything else while it is
   --  shown, it is left as it is, and no more is shown.

   procedure Set_Title_Text (Item : in out Window; To : String)
     with Pre => Is_Assigned (Item) and then To'Length <= 64;
   --  Replace the title as if typed, to be written with the rest.

   procedure Set_Progress (Item : in out Window; To : Float)
     with Pre => Is_Assigned (Item)
                 and then Details (Item).Kind = Source
                 and then To in 0.0 .. 1.0;
   --  Say how far on the picture is, while the capture is Busy: shown as
   --  a bar along the foot of the status line, which any other state of
   --  Set_Capture puts away.

   procedure Set_Recognized
     (Item : in out Window; Found : Vision.Result)
     with Pre => Is_Assigned (Item)
                 and then Details (Item).Kind = Source;
   --  Say what words are in the source's picture, to be selected as text
   --  over it. They are of the picture shown: Set_Capture Ready forgets
   --  them.

   function Recognized_Count (Item : Window) return Natural
     with Pre => Is_Assigned (Item);
   --  How many words there are to select; 0 until Set_Recognized.

   function Selected_Text (Item : Window) return String
     with Pre => Is_Assigned (Item);
   --  What is selected in the source's picture, as it would be copied.

   function Tool (Item : Window) return UI.Widgets.Pictures.Tools
     with Pre => Is_Assigned (Item);
   --  Of a source: what a drag over its picture does.

   procedure Select_Tool
     (Item : in out Window; To : UI.Widgets.Pictures.Tools)
     with Pre => Is_Assigned (Item), Post => Tool (Item) = To;
   --  As the buttons in the status line do: the highlighter, the eraser
   --  of its marks, or the cursor to select text with. The cursor is the
   --  tool again when the window is not open.

   procedure Set_Marks (Item : in out Window; Kept : Items.Mark_List)
     with Pre => Is_Assigned (Item) and then Details (Item).Kind = Source;
   --  Show these highlights on the source's picture, as kept: they are
   --  not written again until it is marked. Set_Capture Ready forgets
   --  them.

   function Mark_Count (Item : Window) return Natural
     with Pre => Is_Assigned (Item);
   --  How many highlights the source's picture has.

   function Status (Item : Window) return String
     with Pre => Is_Assigned (Item);
   --  What its status line says.

   function Box (Item : Window) return Items.Frame
     with Pre => Is_Assigned (Item);
   --  Where its window is on the screen, in pixels, as of the last layout.

   function Is_Hovered (Item : Window) return Boolean;
   --  Whether the pointer is over its window on the canvas, or something
   --  in it.

   function Words (Item : Window) return Natural
     with Pre => Is_Assigned (Item);

   function Title_Document
     (Item : in out Window) return Texts.Documents.Document_Access
     with Pre => Is_Assigned (Item);
   --  The title of the item, for another view to edit: the window sees
   --  its changes, and writes them.

   function Content_Document
     (Item : in out Window) return Texts.Documents.Document_Access
     with Pre => Is_Assigned (Item);
   --  The text of the item, for another view to show and edit: the window
   --  sees its changes, and writes them.

   procedure Hold_Typing (Item : in out Window; To : Boolean);
   --  Say the text is being typed in, in another view, so that Flush
   --  leaves writing it until it has been left alone for a moment, as it
   --  does when its own text is focused.

   function Marks_Version (Item : Window) return Natural
     with Pre => Is_Assigned (Item) and then Details (Item).Kind = Source;
   --  A number that changes when the highlights on the source's picture
   --  do.

   function Is_Marking (Item : Window) return Boolean
     with Pre => Is_Assigned (Item) and then Details (Item).Kind = Source;
   --  Whether the highlighter is being dragged.

   procedure Get_Marks (Item : Window; Into : out Items.Mark_List)
     with Pre => Is_Assigned (Item) and then Details (Item).Kind = Source;
   --  The highlights the source's picture has.

   procedure Set_Zoom (Item : in out Window; To : Float)
     with Pre  => Is_Assigned (Item)
                  and then Details (Item).Kind = Source
                  and then To in Items.Min_Zoom .. Items.Max_Zoom,
          Post => Details (Item).Zoom = To;
   --  Zoom the source's picture within its window, as its slider and
   --  menu do: kept by Flush.

   procedure Set_State (Item : in out Window; To : States)
     with Pre => Is_Assigned (Item), Post => Details (Item).State = To;
   --  Show it as a window, as a bar in the dock, or not at all. Writing
   --  it is for the application. A picture is let go of unless it is a
   --  window (see Warm).

   procedure Warm (Item : in out Window)
     with Pre => Is_Assigned (Item);
   --  Begin to read a source's picture, in the background, if it has one,
   --  to be there when it is drawn: before the others if it is a window,
   --  which is drawn now, and after if it is not, for when it is shown.

   procedure Place
     (Item : in out Window; Zoom, Origin_X, Origin_Y : Float)
     with Pre => Zoom > 0.0;
   --  Put it where the canvas, which is at Zoom with its origin at
   --  Origin_X, Origin_Y points from its top left, has it.

   procedure Bring_To_Front (Item : in out Window)
     with Pre => Is_Assigned (Item);
   --  Put its window over the others on the canvas.

   function Is_Editing_Title (Item : Window) return Boolean;
   --  Whether the title is a field to type in, rather than text: it
   --  becomes one when it is double-clicked, and text again when Return
   --  is pressed, or the focus goes elsewhere.

   procedure Focus_Text (Item : in out Window)
     with Pre => Is_Assigned (Item);
   --  Give the text the focus, at its start.

   procedure Poll (Item : in out Window; Action : out Actions)
     with Pre => Is_Assigned (Item);
   --  Move and size it as dragged, raise it when it is used, keep the
   --  title and word count as edited, and say which button was clicked,
   --  if any.

   function Is_Dragging (Item : Window) return Boolean;
   --  Whether it is being moved or sized.

   procedure Flush
     (Item  : in out Window;
      Store : in out Projects.Store;
      Now   : SDL3.Events.Milliseconds;
      Force : Boolean;
      Wrote : out Boolean)
     with Pre => Is_Assigned (Item) and then Projects.Is_Open (Store);
   --  Write to the database what has changed: where it has been put, once
   --  it is let go; the title and text, once they are no longer being
   --  typed in, or have not changed for Idle_Delay, or whenever Force.
   --  Wrote says whether anything was written. Now is as
   --  SDL3.Events.Ticks.

private

   package Docs renames Texts.Documents;

   subtype Preset_Index is Positive range 1 .. 6;
   type Panel_Rows is array (1 .. 2) of UI.Widgets.Panels.Panel;
   type Preset_Buttons is array (Preset_Index) of UI.Widgets.Buttons.Button;

   type Window is limited record
      Assigned : Boolean := False;
      Details  : Items.Info;
      Title_Doc    : aliased Docs.Document;
      Content_Doc  : aliased Docs.Document;
      --  Before the widgets that show them.
      Title_Saved   : Natural := 0;
      Content_Saved : Natural := 0;
      --  The states of the documents when they were written.
      Title_Seen    : Natural := 0;
      Content_Seen  : Natural := 0;
      Changed_At    : SDL3.Events.Milliseconds := 0;
      --  The last time either was seen to differ from what it was.
      Title_Version : Docs.Version := 0;
      Content_Version : Docs.Version := 0;
      Word_Count    : Natural := 0;
      Frame_Dirty   : Boolean := False;
      --  Moved or sized, and not written.
      Zoom_Dirty    : Boolean := False;
      --  Zoomed, and not written.
      Scroll_Seen, Across_Seen : Float := 0.0;
      Scroll_At     : SDL3.Events.Milliseconds := 0;
      --  How far the content was scrolled when last looked at, and when
      --  that changed: it is written once it has stayed (Idle_Delay).
      Scroll_Pending : Boolean := False;
      --  A note's text is to be scrolled to Details.Scroll once it has a
      --  width to be laid out in.
      Marks_Saved   : Natural := 0;
      --  The picture's Marks_Version when its highlights were written.
      Was_Used      : Boolean := False;
      Held          : Boolean := False;
      --  Typed in elsewhere: see Hold_Typing.
      Resizing      : Boolean := False;
      Raw_Width, Raw_Height : Float := 0.0;
      --  While the corner is dragged, the size the cursor asks for, which
      --  may be under the minimum; the item itself is held at the minimum.
      Pixels : Float := 1.0;
      Ring_Ink : UI.Themes.Color := (0, 0, 0, 255);
      --  Round the window while it is typed in.
      Face_Of : Kinds := Note;
      --  What the text area's font is for: a note's text, or a source's
      --  link.
      Zoom, Origin_X, Origin_Y : Float := 1.0;
      Placed_Once : Boolean := False;

      Frame        : UI.Widgets.Panels.Panel;
      --  On the canvas: the outline, round the bar, the text and the
      --  status line.
      Title_Bar    : UI.Widgets.Grips.Grip;
      Title_Area   : UI.Widgets.Grips.Grip;
      Tag          : UI.Widgets.Panels.Panel;
      --  Of a source, before its title: a square of its colour.
      Title_Label  : UI.Widgets.Labels.Label;
      --  The title as text, in the place the field takes to edit it.
      Editing      : Boolean := False;
      Title_Field  : UI.Widgets.Text_Fields.Text_Field;
      Spacer       : UI.Widgets.Panels.Panel;
      Minimize_Button : UI.Widgets.Buttons.Button;
      Close_Button : UI.Widgets.Buttons.Button;
      Body_Text    : UI.Widgets.Editors.Editor;
      --  The text of a note. Of a source it is one line, its link, which
      --  a text area costs too much to have another of.
      Zoom_Slider  : UI.Widgets.Sliders.Slider;
      Zoom_Button  : UI.Widgets.Buttons.Button;
      --  Of a source, in its status line: a slider to zoom its picture,
      --  and a button, saying how far, that opens a menu of zooms.
      Speak_Button : UI.Widgets.Buttons.Button;
      --  Of a note, in its status line: starts and stops dictating.
      Dictating    : Dictations := Silent;
      Live_Shown   : Boolean := False;
      Live_Lost    : Boolean := False;
      Live_Break   : Boolean := False;
      Live_From    : Texts.Position;
      Live_To      : Texts.Position;
      Live_Seen    : Docs.Version := 0;
      --  Of a note: the text of what is being said is in the document
      --  from Live_From to Live_To (after a line feed, if Live_Break),
      --  as of version Live_Seen. Live_Lost: it was changed by something
      --  else, so it is left alone.
      Tools        : UI.Widgets.Panels.Panel;
      Cursor_Button : UI.Widgets.Buttons.Button;
      Marker_Button : UI.Widgets.Buttons.Button;
      Eraser_Button : UI.Widgets.Buttons.Button;
      --  Of a source, in the middle of its status line: the cursor, the
      --  highlighter and the eraser, one of which is chosen.
      Zoom_Menu    : UI.Widgets.Panels.Panel;
      Menu_Rows    : Panel_Rows;
      Menu_Buttons : Preset_Buttons;
      --  Over the picture, hidden until the button is clicked.
      Picture      : UI.Widgets.Pictures.Picture;
      --  Of a source, below its link: what is shown.
      Recognized   : aliased Vision.Result;
      --  The words in it, that the picture lets be selected.
      Status_Bar   : UI.Widgets.Panels.Panel;
      Progress     : UI.Widgets.Progress_Bars.Progress_Bar;
      --  Along the foot of the status line while the picture is taken.
      Status       : UI.Widgets.Labels.Label;
      Corner       : UI.Widgets.Grips.Grip;

      Mini         : UI.Widgets.Panels.Panel;
      --  In the dock.
      Mini_Area    : UI.Widgets.Grips.Grip;
      --  Over the title: clicked, it asks to Restore the window.
      Mini_Title   : UI.Widgets.Labels.Label;
      Mini_Close   : UI.Widgets.Buttons.Button;
   end record;

end Items.Windows;
