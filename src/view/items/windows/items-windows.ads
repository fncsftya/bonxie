with System;
with Item_Window_VM;
with Pomarine.UI.Hosts;
with Items.Marks;
with Items.Models;
with Pomarine.View_Models;
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
with Pomarine.Widgets.Editors;

--  What shows one item (Items.Models): a window on the canvas, which can be dragged by
--  its title bar and sized by its corner, with a title to edit, buttons to
--  minimise and close it, its text to edit, and a status line; and, when
--  it is minimised, a short bar in the dock above the tools.
--
--  A window holds nothing that is the item's: that is in its model, which
--  it shows (Show), and which it tells what the person did there (what
--  a button asks for, see Items.Windows.Callbacks, which the application
--  does; and Report).
--  Zoom and pan are the canvas's: it is told them (Place) and puts the
--  window there; the window's text is zoomed with the canvas, its title bar
--  and status line are not.

package Items.Windows is

   type Window is limited private;

   type Actions is
     (None,
      Minimize,
      Restore,
      Close,
      Capture,
      Speak,
      Previous_Page,
      Next_Page,
      Choose_Link,
      Choose_File,
      Link_To_Outline,
      Moved,
      Sized);
   --  What a window's buttons ask for, and, of a source, Return in its
   --  link's field: to take the picture of the page. Speak is the button
   --  of a note that starts or stops dictating into it. Previous_Page and
   --  Next_Page are the buttons over the picture of a source that is a
   --  PDF or e-book of more than one page. Choose_Link and Choose_File are
   --  the two buttons of a source that is yet to say where it comes from;
   --  Choose_File too is what clicking the path of a source that is a file
   --  asks: to choose another. Link_To_Outline is the button of a note
   --  that opens the menu of the outline's sections, to make it the one
   --  that a section is read from. Moved and Sized are the title bar and
   --  the corner dragged: see Gesture.

   type Gestures is record
      Across, Down : Float := 0.0;
      --  How far the pointer went, in points of the screen.
      Still        : Boolean := False;
      --  Whether it is still held.
   end record;

   function Gesture (Item : Window) return Gestures;
   --  What was dragged last: for Moved and Sized.

   Meter_Offset : constant := 27;
   --  Which of the application's theme slots is the colour of the level
   --  meter while dictating (the theme, View.Style, sets it).

   Meter_Slot : constant Pomarine.Themes.Slot := Pomarine.Themes.Custom (Meter_Offset);

   function Is_Assigned (Item : Window) return Boolean;
   --  Whether its model has an item.

   procedure Mount_Search_Bar (Item : in out Window; Screen : in out Pomarine.UI.View; Content : Pomarine.UI.Layout);
   --  Place the search view's declared bar after the item content, before its status line.

   function Searchable (Item : Window) return Boolean;
   procedure Search (Item : in out Window; Term : String);
   procedure Search_Step (Item : in out Window; Backwards : Boolean := False);
   function Search_Busy (Item : Window) return Boolean;
   function Search_Count (Item : Window) return Natural;
   function Search_Current (Item : Window) return Natural;

   subtype Shared_Access is Pomarine.Widgets.Editors.Shared_Access;

   procedure Set_Shared (Item : in out Window; Shared : not null Shared_Access);
   --  Direct the window's body and title editors to share font registry
   --  and glyph atlas.

   procedure Build
     (Item    : in out Window;
      Model   : not null access Items.Models.Item;
      Looking : not null access constant Items.Models.Camera;
      Canvas  : in out Pomarine.Widgets.Widget'Class;
      Dock    : in out Pomarine.Widgets.Widget'Class;
      Bar     : Pomarine.Themes.Slot;
      Density : Float);
   --  Add the window's widgets, hidden: its window to the canvas, its
   --  bar to the dock, both in the tree already. It shows the item that
   --  Model is, when it has one, in the place that Looking says the canvas is
   --  looked at from. Do it once, before the layout, with the tree's density.
   --  Model and Looking must be there as long as the window is.

   procedure Show (Item : in out Window);
   --  Show what the model says: where the item is and whether it is
   --  shown, its title, what it has of its kind, how a source's picture
   --  stands and what is on it, how a note is dictated. What is the same
   --  as it was is not looked at again (the model's versions) and the
   --  setters do nothing when given what a widget has, so it is cheap to
   --  call after anything.

   procedure Assigned (Item : in out Window)
   with Pre => Is_Assigned (Item);
   --  The model has been given another item: show it from the start.

   procedure Release (Item : in out Window);
   --  The window is of the item no more: hide it. Do it before the model lets go of its item.

   procedure Warm (Item : in out Window)
   with Pre => Is_Assigned (Item);
   --  Begin to read a source's picture, in the background, if it has one, to be there when it is drawn: before the
   --  others if it is a window, which is drawn now, and after if it is not, for when it is shown.

   procedure Set_Outline_Link (Item : in out Window; Linked : Boolean; Ink : Pomarine.Themes.Slot; Open : Boolean);
   --  Show, of a note, whether it is the own of a section, by the square
   --  of the section's colour (Ink) before its title and the button that
   --  asks for the menu, which looks pressed in while Open.

   function Outline_Box (Item : Window) return Items.Frame;
   --  Where the button that asks for the menu is, in points of the window.

   procedure Set_Tag (Item : in out Window; To : Pomarine.Themes.Slot)
   with Pre => Is_Assigned (Item);
   --  Show the source's colour, in a square before its title, as its
   --  links and its rows elsewhere have it.

   function Selected_Shown_Text (Item : Window) return String
   with Pre => Is_Assigned (Item);
   --  What is selected in the text of a source that is a text file.

   procedure Set_Dictation_Editor (Item : in out Window; To : access Pomarine.Widgets.Editors.Editor)
   with Pre => Is_Assigned (Item);
   --  The editor, other than the window's own, that shows the note's text
   --  now (the page in the writing view), if any: dictation goes in at
   --  its caret when it has the focus. Null for the window's own.

   procedure Set_Dictation (Item : in out Window; To : Items.Models.Dictations; Detail : String := "")
   with Pre => Is_Assigned (Item);
   --  Say how dictating stands (see Items.Models.Set_Dictation); a failure
   --  takes back what was shown while listening.

   procedure Add_Dictation (Item : in out Window; Said : String)
   with Pre => Is_Assigned (Item);
   --  Put Said in the note's text, as one edit, to be undone together.
   --  If the text is focused, it goes in at the caret (what is selected
   --  is kept); if it has none yet, it is the text; otherwise it is a
   --  new paragraph after the last.

   procedure Set_Live_Dictation (Item : in out Window; Said : String; Settled : Natural := 0)
   with Pre => Is_Assigned (Item);
   --  Show what has been heard so far, while Listening, in the note's
   --  text, where Add_Dictation will put it: each call replaces the last
   --  Said. These edits are not recorded (they cannot be undone), and
   --  Add_Dictation, or a failure, takes them back before the final text
   --  goes in. If the text is changed by anything else while it is
   --  shown, what is shown is kept as text, and nothing more is shown
   --  while it is being changed; then what is heard after goes in at the
   --  caret. The first Settled bytes of Said are drawn as text; the rest,
   --  which may yet change, faintly.

   function Box (Item : Window) return Items.Frame
   with Pre => Is_Assigned (Item);
   --  Where its window is on the screen, in pixels, as of the last layout.

   --  A right click on a window: what is under it, and what the menu can
   --  do to the text or the picture.

   type Text_Acts is (Copy, Cut, Paste, Select_All);

   function Owns (Item : Window; Hit : Pomarine.Widgets.Widget_Access) return Boolean;
   --  Whether the widget, or one of those it is in, is the window's.

   function Text_Contains (Item : Window; X, Y : Float) return Boolean
   with Pre => Is_Assigned (Item);
   --  Whether pixel X, Y is in its text (a source's link).

   function Over_Text_Selection (Item : in out Window; X, Y : Float) return Boolean
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

   function Over_Picture_Selection (Item : Window; X, Y : Float) return Boolean
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

   function Recognized_Count (Item : Window) return Natural
   with Pre => Is_Assigned (Item);
   --  How many words there are to select; 0 until the model has some.

   function Selected_Text (Item : Window) return String
   with Pre => Is_Assigned (Item);
   --  What is selected in the source's picture, as it would be copied.

   function Document_Page (Item : Window) return Natural
   with Pre => Is_Assigned (Item);
   --  Of a document shown as pages, the page being read; 0 if it is not.

   procedure Go_To_Page (Item : in out Window; Page : Positive)
   with Pre => Is_Assigned (Item);
   --  Scroll to the page, of a document that is shown as pages.

   function Marks_Version (Item : Window) return Natural
   with Pre => Is_Assigned (Item);
   --  A number that changes when the highlights on the source's picture do.

   function Is_Marking (Item : Window) return Boolean
   with Pre => Is_Assigned (Item);
   --  Whether the highlighter is being dragged.

   procedure Get_Marks (Item : Window; Into : out Items.Marks.Mark_List)
   with Pre => Is_Assigned (Item);
   --  The highlights the source's picture has.

   procedure Place (Item : in out Window);
   --  Put it where the canvas, as it is looked at now, has it.

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
   --  Raise it when it is used, and scroll a note's text to where it was.
   --  What the buttons, the bars and the title say is done as it is said,
   --  and what is for the application is told to it (see
   --  Items.Windows.Callbacks).

   procedure Report (Item : in out Window)
   with Pre => Is_Assigned (Item);
   --  Tell the model what only the window can say: what is being dragged
   --  or typed in, how far the text is scrolled and what is marked. Do it
   --  before the model is written (Items.Models.Flush).

   function Is_Dragging (Item : Window) return Boolean;
   --  Whether it is being moved or sized.

private

   package Docs renames Texts.Documents;

   subtype Preset_Index is Positive range 1 .. 6;
   type Panel_Rows is array (1 .. 2) of Pomarine.Widgets.Panels.Panel;
   type Preset_Buttons is array (Preset_Index) of Pomarine.Widgets.Buttons.Button;

   type Said_Runner is access procedure (Self, Proc : System.Address; Which : Slot; Action : Actions);

   type Model_Access is access all Items.Models.Item;
   type Camera_Access is access constant Items.Models.Camera;

   type Window_Access is access all Window;
   type Command_Effects is limited new Item_Window_VM.Effects with record
      Owner : Window_Access;
   end record;
   overriding
   procedure Requested (Self : in out Command_Effects; What : Item_Window_VM.Command; Index : Natural);
   overriding
   procedure Changed (Self : in out Command_Effects);

   type Window is limited record
      Model        : Model_Access;
      Looking      : Camera_Access;
      --  What it shows, and from where the canvas is looked at: set by Build, as long as the window.
      Dragged      : Gestures;
      Said         : Said_Runner;
      Said_Self    : System.Address := System.Null_Address;
      Said_Proc    : System.Address := System.Null_Address;
      Said_Which   : Slot := Slot'First;
      --  Who is told what its buttons ask for.
      Seen_Where   : Pomarine.View_Models.Watch;
      Seen_Picture : Pomarine.View_Models.Watch;
      Seen_Look    : Pomarine.View_Models.Watch;
      Seen_Shape   : Pomarine.View_Models.Watch;
      Seen_Zoom    : Pomarine.View_Models.Watch;
      Seen_Tool    : Pomarine.View_Models.Watch;
      Seen_Words   : Pomarine.View_Models.Watch;
      Seen_Marks   : Pomarine.View_Models.Watch;
      --  The versions of the model as last shown.
      Title_Shown  : Docs.Version := 0;
      --  The version of the title that the bar shows.
      Was_Used     : Boolean := False;
      Pixels       : Float := 1.0;
      Face_Of      : Kinds := Note;
      --  What the text area's font is for: a note's text, or a source's
      --  link.
      Placed_Once  : Boolean := False;

      Chrome          : Pomarine.Widgets.Frames.Frame;
      --  On the canvas: the outline, round the bar, the text and the
      --  status line; and the bar in the dock. A source's tag is a
      --  square of its colour before its title.
      Body_Text       : Pomarine.Widgets.Editors.Editor;
      Dictate_In      : access Pomarine.Widgets.Editors.Editor;
      --  The text of a note. Of a source it is one line, its link, which
      --  a text area costs too much to have another of: a field with an
      --  icon of a link before it, a hint while it is empty, and room at
      --  its right for Fetch_Button.
      Fetch_Button    : Pomarine.Widgets.Buttons.Button;
      --  Of a source whose picture has not been taken, over the right of
      --  its link: takes it, as Return does.
      Zoom_Slider     : Pomarine.Widgets.Sliders.Slider;
      Zoom_Button     : Pomarine.Widgets.Buttons.Button;
      --  Of a source, in its status line: a slider to zoom its picture,
      --  and a button, saying how far, that opens a menu of zooms.
      Speak_Button    : Pomarine.Widgets.Buttons.Button;
      --  Of a note, in its status line: starts and stops dictating.
      Outline_Button  : Pomarine.Widgets.Buttons.Button;
      --  Of a note, at the right of its status line: a dropdown, to link
      --  it to a section of the outline.
      Tools           : Pomarine.Widgets.Panels.Panel;
      Cursor_Button   : Pomarine.Widgets.Buttons.Button;
      Marker_Button   : Pomarine.Widgets.Buttons.Button;
      Eraser_Button   : Pomarine.Widgets.Buttons.Button;
      --  Of a source, in the middle of its status line: the cursor, the
      --  highlighter and the eraser, one of which is chosen.
      Pager           : Pomarine.Widgets.Panels.Panel;
      Prev_Button     : Pomarine.Widgets.Buttons.Button;
      Next_Button     : Pomarine.Widgets.Buttons.Button;
      --  Of a source of more than one page, over the foot of its picture,
      --  in the middle: to the page before and after.
      Wizard          : Pomarine.Widgets.Panels.Panel;
      Link_Button     : Pomarine.Widgets.Buttons.Button;
      File_Button     : Pomarine.Widgets.Buttons.Button;
      --  Of a source that is yet to say where it comes from, in place of
      --  its link and picture: its two ways.
      Text_View       : Pomarine.Widgets.Editors.Editor;
      --  Of a source that is a text file: what it says, which is not for
      --  changing, in place of a picture.
      Zoom_Menu       : Pomarine.Widgets.Panels.Panel;
      Menu_Rows       : Panel_Rows;
      Menu_Buttons    : Preset_Buttons;
      --  Over the picture, hidden until the button is clicked.
      Picture         : Pomarine.Widgets.Pictures.Picture;
      --  Of a source, below its link: what is shown.
      Pages           : Pomarine.Widgets.Page_Views.Page_View;
      --  Of a document, its pages one under another, in place of Picture.
      Doc_Sizes       : Pomarine.Pages.Size_Array_Access;
      Doc_Source      : aliased Items.Vector_Pages.File_Source;
      Progress        : Pomarine.Widgets.Progress_Bars.Progress_Bar;
      --  Along the foot of the status line while the picture is taken.
      Status          : Pomarine.Widgets.Labels.Label;
      Control_Effects : aliased Command_Effects;
      Controls        : aliased Item_Window_VM.Model;
      UI_Host         : Pomarine.UI.Hosts.Host;
      --  Last: detach the borrowed controls before their finalization.
   end record;

end Items.Windows;
