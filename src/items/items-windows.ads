with System;
with Items.Marks;
with Projects;
with SDL3.Events;
with Texts.Documents;
with Pomarine.Themes;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Frames;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Pictures;
with Pomarine.Widgets.Progress_Bars;
with Pomarine.Widgets.Sliders;
with Pomarine.Widgets.Panels;
with Items.Vector_Pages;
with Pomarine.Pages;
with Pomarine.Widgets.Page_Views;
with Vision;
with Pomarine.Widgets.Editors;

--  What shows one item: a window on the canvas, which can be dragged by
--  its title bar and sized by its corner, with a title to edit, buttons to
--  minimise and close it, its text to edit, and a status line; and, when
--  it is minimised, a short bar in the dock above the tools.
--
--  A window is of one item at a time, or of none. It keeps the item's
--  details, and what has to be written to the database (see Flush); it
--  says what the buttons have asked for (see Items.Windows.Callbacks), and
--  the application does it. Zoom and pan are the canvas's: it is told them
--  (Place) and puts the window there; the window's text is zoomed with
--  the canvas, its title bar and status line are not.
package Items.Windows is

   use type Pomarine.Widgets.Pictures.Tools;

   type Window is limited private;

   type Actions is (None, Minimize, Restore, Close, Capture, Speak, Previous_Page, Next_Page,
                    Choose_Link, Choose_File, Link_To_Outline, Find_Sources);
   --  What a window's buttons ask for, and, of a source, Return in its
   --  link's field: to take the picture of the page. Speak is the button
   --  of a note that starts or stops dictating into it. Previous_Page and
   --  Next_Page are the buttons over the picture of a source that is a
   --  PDF or e-book of more than one page. Choose_Link and Choose_File are
   --  the two buttons of a source that is yet to say where it comes from;
   --  Choose_File too is what clicking the path of a source that is a file
   --  asks: to choose another. Link_To_Outline is the button of a note
   --  that opens the menu of the outline's sections, to make it the one
   --  that a section is read from. Find_Sources is the button of a note's
   --  toolbar that asks for sources to be found for its text.

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

   subtype Shared_Access is Pomarine.Widgets.Editors.Shared_Access;

   procedure Set_Shared
     (Item   : in out Window;
      Shared : not null Shared_Access);
   --  Direct the window's body and title editors to share font registry
   --  and glyph atlas.

   procedure Build
     (Item    : in out Window;
      Canvas  : in out Pomarine.Widgets.Widget'Class;
      Dock    : in out Pomarine.Widgets.Widget'Class;
      Bar     : Pomarine.Themes.Slot;
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
   --  Make it the window of the item, with its versioned text Saved_Text (or legacy plain text), as saved:
   --  shown as its state says, once it is placed. A source that has been
   --  captured shows Picture_File, a PNG.

   procedure Release (Item : in out Window)
     with Post => not Is_Assigned (Item);
   --  Hide it, and forget the item: whatever was not written is lost.

   procedure Set_Outline_Link
     (Item   : in out Window;
      Linked : Boolean;
      Ink    : Pomarine.Themes.Slot;
      Open   : Boolean);
   --  Show, of a note, whether it is the own of a section, by the square
   --  of the section's colour (Ink) before its title and the button that
   --  asks for the menu, which looks pressed in while Open.

   function Outline_Box (Item : Window) return Items.Frame;
   --  Where the button that asks for the menu is, in points of the window.

   function Details (Item : Window) return Items.Info
     with Pre => Is_Assigned (Item);

   procedure Set_Tag (Item : in out Window; To : Pomarine.Themes.Slot)
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

   procedure Set_Origin (Item : in out Window; To : Items.Origins)
     with Pre => Is_Assigned (Item) and then Details (Item).Kind = Source,
          Post => Details (Item).Origin = To;
   --  Say whether the source is yet to be said to be a link or a file
   --  (it shows two buttons to say so), a link, or a file (its path is
   --  its text, which cannot be typed over, and clicked asks for another).

   procedure Set_Link (Item : in out Window; To : String)
     with Pre => Is_Assigned (Item) and then Details (Item).Kind = Source;
   --  Make the source's text, its link or its file's path, To: as if it
   --  had been typed, so that it is kept.

   procedure Show_Text (Item : in out Window; File : String; At_Time : Projects.Seconds)
     with Pre => Is_Assigned (Item) and then Details (Item).Kind = Source
                 and then File /= "";
   --  Show the text of the file, which cannot be changed in the window,
   --  as taken at At_Time, in place of a picture.

   function Selected_Shown_Text (Item : Window) return String
     with Pre => Is_Assigned (Item) and then Details (Item).Kind = Source;
   --  What is selected in it.

   function Shown_Text (Item : Window) return String
     with Pre => Is_Assigned (Item) and then Details (Item).Kind = Source;
   --  The text of a source that is a text file, as shown.

   procedure Set_Pages
     (Item : in out Window; Document : String; Page, Count : Natural)
     with Pre => Is_Assigned (Item)
                 and then Details (Item).Kind = Source
                 and then Page <= Count,
          Post => Details (Item).Page = Page
                  and then Details (Item).Page_Count = Count;
   --  Say the source's picture is of the Page'th of the Count pages of its
   --  document, a file of that ending ("" and 0 for a web page): with more than one, buttons
   --  to turn the page are over the picture, and the status line says
   --  which it is once it is shown (Set_Capture Ready).

   procedure Allow_Find_Sources (Item : in out Window; To : Boolean)
     with Pre => Is_Assigned (Item);
   --  Say whether the note's Find Sources button can be used (the AI is on):
   --  it is on only while the note has some text as well.

   function Find_Sources_Is_Enabled (Item : Window) return Boolean
     with Pre => Is_Assigned (Item);
   --  Whether the button can be clicked now.

   procedure Find_Sources_Center (Item : Window; Shown : out Boolean; X, Y : out Float)
     with Pre => Is_Assigned (Item);
   --  Whether the button is shown, and where its middle is, in points of the
   --  window: for tests.

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

   procedure Set_Live_Dictation (Item : in out Window; Said : String; Settled : Natural := 0)
     with Pre => Is_Assigned (Item) and then Details (Item).Kind = Note;
   --  Show what has been heard so far, while Listening, in the note's
   --  text, where Add_Dictation will put it: each call replaces the last
   --  Said. These edits are not recorded (they cannot be undone), and
   --  Add_Dictation, or a failure, takes them back before the final text
   --  goes in. If the text is changed by anything else while it is
   --  shown, what is shown is kept as text, and nothing more is shown
   --  while it is being changed; then what is heard after goes in at the
   --  caret. The first Settled bytes of Said are drawn as text; the rest,
   --  which may yet change, faintly.

   procedure Set_Title_Text (Item : in out Window; To : String)
     with Pre => Is_Assigned (Item);
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

   function Shows_Picture (Item : Window) return Boolean
     with Pre => Is_Assigned (Item);
   --  Whether the source has a picture to show, the pages of a document or
   --  a file (that may not be read yet): not if Set_Capture Ready failed.

   function Is_Paged (Item : Window) return Boolean
     with Pre => Is_Assigned (Item);
   --  Whether the source's document is shown as all its pages one under
   --  another, drawn from what is on them (see Items.Vector_Pages), whose
   --  words are its own text.

   function Document_Page (Item : Window) return Natural
     with Pre => Is_Assigned (Item);
   --  Of a document shown as pages, the page being read; 0 if it is not.

   procedure Go_To_Page (Item : in out Window; Page : Positive)
     with Pre => Is_Assigned (Item) and then Is_Paged (Item);
   --  Scroll to the page.

   function Recognized_Count (Item : Window) return Natural
     with Pre => Is_Assigned (Item);
   --  How many words there are to select; 0 until Set_Recognized.

   function Selected_Text (Item : Window) return String
     with Pre => Is_Assigned (Item);
   --  What is selected in the source's picture, as it would be copied.

   function Tool (Item : Window) return Pomarine.Widgets.Pictures.Tools
     with Pre => Is_Assigned (Item);
   --  Of a source: what a drag over its picture does.

   procedure Select_Tool
     (Item : in out Window; To : Pomarine.Widgets.Pictures.Tools)
     with Pre => Is_Assigned (Item), Post => Tool (Item) = To;
   --  As the buttons in the status line do: the highlighter, the eraser
   --  of its marks, or the cursor to select text with. The cursor is the
   --  tool again when the window is not open.

   procedure Set_Marks (Item : in out Window; Kept : Items.Marks.Mark_List)
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

   --  A right click on a window: what is under it, and what the menu can
   --  do to the text or the picture.

   type Text_Acts is (Copy, Cut, Paste, Select_All);

   function Owns (Item : Window; Hit : Pomarine.Widgets.Widget_Access)
     return Boolean;
   --  Whether the widget, or one of those it is in, is the window's.

   function Text_Contains (Item : Window; X, Y : Float) return Boolean
     with Pre => Is_Assigned (Item);
   --  Whether pixel X, Y is in its text (a source's link).

   function Over_Text_Selection
     (Item : in out Window; X, Y : Float) return Boolean
     with Pre => Is_Assigned (Item);
   --  Whether pixel X, Y is over selected text.

   procedure Put_Caret (Item : in out Window; X, Y : Float)
     with Pre => Is_Assigned (Item);
   --  Focus the text, with the caret nearest pixel X, Y.

   procedure Edit_Text (Item : in out Window; Act : Text_Acts)
     with Pre => Is_Assigned (Item);
   --  Do it to the text's selection, with the tree's clipboard.

   function Picture_Contains (Item : Window; X, Y : Float) return Boolean
     with Pre => Is_Assigned (Item);

   function Over_Picture_Selection
     (Item : Window; X, Y : Float) return Boolean
     with Pre => Is_Assigned (Item);

   function Has_Words (Item : Window) return Boolean
     with Pre => Is_Assigned (Item);
   --  Whether the picture has words to select.

   procedure Select_All_Words (Item : in out Window)
     with Pre => Is_Assigned (Item);

   procedure Copy_Words (Item : Window)
     with Pre => Is_Assigned (Item);

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

   procedure Get_Marks (Item : Window; Into : out Items.Marks.Mark_List)
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

   procedure Update (Item : in out Window)
     with Pre => Is_Assigned (Item);
   --  Raise it when it is used, keep the title and word count as edited,
   --  and scroll a note's text to where it was. What the buttons, the
   --  bars and the title say is done as it is said, and what is for the
   --  application is told to it (see Items.Windows.Callbacks).

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
   type Panel_Rows is array (1 .. 2) of Pomarine.Widgets.Panels.Panel;
   type Preset_Buttons is array (Preset_Index) of Pomarine.Widgets.Buttons.Button;

   type Said_Runner is access procedure
     (Self, Proc : System.Address; Which : Slot; Action : Actions);

   type Window is limited record
      Assigned : Boolean := False;
      Said      : Said_Runner;
      Said_Self : System.Address := System.Null_Address;
      Said_Proc : System.Address := System.Null_Address;
      Said_Which : Slot := Slot'First;
      --  Who is told what its buttons ask for.
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
      Face_Of : Kinds := Note;
      --  What the text area's font is for: a note's text, or a source's
      --  link.
      Zoom, Origin_X, Origin_Y : Float := 1.0;
      Placed_Once : Boolean := False;

      Chrome       : Pomarine.Widgets.Frames.Frame;
      --  On the canvas: the outline, round the bar, the text and the
      --  status line; and the bar in the dock. A source's tag is a
      --  square of its colour before its title.
      Body_Text    : Pomarine.Widgets.Editors.Editor;
      --  The text of a note. Of a source it is one line, its link, which
      --  a text area costs too much to have another of: a field with an
      --  icon of a link before it, a hint while it is empty, and room at
      --  its right for Fetch_Button.
      Fetch_Button : Pomarine.Widgets.Buttons.Button;
      --  Of a source whose picture has not been taken, over the right of
      --  its link: takes it, as Return does.
      Zoom_Slider  : Pomarine.Widgets.Sliders.Slider;
      Zoom_Button  : Pomarine.Widgets.Buttons.Button;
      --  Of a source, in its status line: a slider to zoom its picture,
      --  and a button, saying how far, that opens a menu of zooms.
      Speak_Button : Pomarine.Widgets.Buttons.Button;
      --  Of a note, in its status line: starts and stops dictating.
      Outline_Button : Pomarine.Widgets.Buttons.Button;
      --  Of a note, at the right of its status line: a dropdown, to link
      --  it to a section of the outline.
      Dictating    : Dictations := Silent;
      Live_Shown   : Boolean := False;
      Live_Moved   : Boolean := False;
      Live_Done    : Natural := 0;
      Live_Upto    : Natural := 0;
      Live_Version : Docs.Version := 0;
      Live_Break   : Boolean := False;
      Live_From    : Texts.Position;
      Live_To      : Texts.Position;
      Live_Seen    : Docs.Version := 0;
      --  Of a note: the text of what is being said is in the document
      --  from Live_From to Live_To (after a line feed, if Live_Break),
      --  as of version Live_Seen. If it is changed by something else, what
      --  is shown is kept as typed text: Live_Done bytes of what has been
      --  heard are in the text for good (Live_Upto, with what is shown),
      --  and Live_Moved says the rest goes in at the caret, which the
      --  person has moved. Live_Version is the version last looked at.
      Tools        : Pomarine.Widgets.Panels.Panel;
      Cursor_Button : Pomarine.Widgets.Buttons.Button;
      Marker_Button : Pomarine.Widgets.Buttons.Button;
      Eraser_Button : Pomarine.Widgets.Buttons.Button;
      --  Of a source, in the middle of its status line: the cursor, the
      --  highlighter and the eraser, one of which is chosen.
      Pager        : Pomarine.Widgets.Panels.Panel;
      Prev_Button  : Pomarine.Widgets.Buttons.Button;
      Next_Button  : Pomarine.Widgets.Buttons.Button;
      --  Of a source of more than one page, over the foot of its picture,
      --  in the middle: to the page before and after.
      Wizard       : Pomarine.Widgets.Panels.Panel;
      Link_Button  : Pomarine.Widgets.Buttons.Button;
      File_Button  : Pomarine.Widgets.Buttons.Button;
      --  Of a source that is yet to say where it comes from, in place of
      --  its link and picture: its two ways.
      Text_Doc     : aliased Docs.Document;
      Text_View    : Pomarine.Widgets.Editors.Editor;
      --  Of a source that is a text file: what it says, which is not for
      --  changing, in place of a picture.
      Zoom_Menu    : Pomarine.Widgets.Panels.Panel;
      Menu_Rows    : Panel_Rows;
      Menu_Buttons : Preset_Buttons;
      --  Over the picture, hidden until the button is clicked.
      Picture      : Pomarine.Widgets.Pictures.Picture;
      --  Of a source, below its link: what is shown.
      Recognized   : aliased Vision.Result;
      --  The words in it, that the picture lets be selected.
      Pages        : Pomarine.Widgets.Page_Views.Page_View;
      Paged        : Boolean := False;
      --  Of a document, its pages one under another, in place of Picture.
      Doc_Sizes    : Pomarine.Pages.Size_Array_Access;
      Doc_Source   : aliased Items.Vector_Pages.File_Source;
      Progress     : Pomarine.Widgets.Progress_Bars.Progress_Bar;
      --  Along the foot of the status line while the picture is taken.
      Status       : Pomarine.Widgets.Labels.Label;
   end record;

end Items.Windows;
