with Ada.Strings.Unbounded;
with Editor_VM;
with Items.Marks;
with Pomarine.Events;
with Pomarine.View_Models;
with Projects;
with Texts;
with Texts.Documents;
with Vision;

--  What an item is, as the program means it, and nothing of how it looks: its details, its title and text, where it
--  is on the canvas and whether it is shown, how a source's picture was taken, how a note is being dictated, what is
--  to be written to the database and when. It names no widget, so the tests run it without a window.
--
--  A window (Items.Windows) shows an item and says, as calls on it, what the person did there. Whatever the window
--  has that the person can change (the caret, the highlighter being dragged, how far the text is scrolled) it tells
--  the item from time to time (Report), so that what is to be kept is kept once, here.
package Items.Models is

   package Docs renames Texts.Documents;

   package Parts renames Pomarine.View_Models;

   type Captures is (Waiting, Busy, Ready, Failed);
   --  Of a source: there is no picture yet, it is being taken, it is shown, or it could not be taken.

   type Dictations is (Silent, Preparing, Listening, Transcribing, Failed);
   --  Of a note: not dictating (or it was taken), the microphone is being readied, it is listening, what was heard is
   --  being made text, or that could not be done.

   type Tools is (Pointer, Highlighter, Eraser);
   --  Of a source's picture: what a drag over it does: selects the words, marks them, or takes the marks away.

   Idle_Delay : constant := 500;
   --  Milliseconds the text is left alone for before it is written, although it is still being typed in.

   function Count_Words (Of_Text : String) return Natural;
   --  Of runs of anything but spaces, tabs and line breaks.

   function Day (Taken : Projects.Seconds) return String;
   --  As 13 Oct 2026, in UTC.

   type Camera is record
      Zoom     : Float := 1.0;
      --  Screen points to a canvas unit.
      Origin_X : Float := 0.0;
      Origin_Y : Float := 0.0;
      --  Where the canvas's origin is, in points from the top left of the canvas.
   end record;
   --  Where the canvas is looked at from: the windows are put where it has them.

   type Item is limited private;

   function Is_Assigned (Self : Item) return Boolean;

   procedure Assign
     (Self         : in out Item;
      Of_Item      : Items.Info;
      Saved_Text   : String;
      Shown_File   : String := "")
     with Pre => not Is_Assigned (Self);
   --  Make it the item, with its versioned text Saved_Text (or legacy plain text), as saved. A source that has been
   --  captured shows Shown_File, a PNG (or a text file, for a source that is one).

   procedure Release (Self : in out Item)
     with Post => not Is_Assigned (Self);
   --  Forget the item: whatever was not written is lost.

   function Details (Self : Item) return Items.Info
     with Pre => Is_Assigned (Self);
   --  As it is now: the title as edited, where it has been moved and sized to.

   --  The documents: the window edits them, and the item sees what was typed.

   function Title_Document (Self : in out Item) return Docs.Document_Access;

   function Content_Document (Self : in out Item) return Docs.Document_Access;
   --  The text of a note; of a source, its link or its file's path.

   function Text_Document (Self : in out Item) return Docs.Document_Access;
   --  What a source that is a text file says, which is not for changing.

   function Text (Self : Item) return String
     with Pre => Is_Assigned (Self);
   --  Of a source, its link, as edited.

   function Stored_Text (Self : Item) return String
     with Pre => Is_Assigned (Self);
   --  As Text, as kept: with its styles and versions as markup.

   function Shown_Text (Self : Item) return String
     with Pre => Is_Assigned (Self) and then Details (Self).Kind = Source;
   --  The text of a source that is a text file, as shown.

   function Words (Self : Item) return Natural
     with Pre => Is_Assigned (Self);

   procedure Set_Title_Text (Self : in out Item; To : String)
     with Pre => Is_Assigned (Self);
   --  Replace the title as if typed, to be written with the rest.

   procedure Set_Link (Self : in out Item; To : String)
     with Pre => Is_Assigned (Self) and then Details (Self).Kind = Source;
   --  Make the source's text, its link or its file's path, To: as if it had been typed, so that it is kept.

   procedure Refresh (Self : in out Item)
     with Pre => Is_Assigned (Self);
   --  Take what was typed: the title, and the words of a note, which say it is not being dictated any more (a failure
   --  to dictate is told until the text is next changed).

   --  Where it is

   procedure Move (Self : in out Item; Across, Down : Float)
     with Pre => Is_Assigned (Self);
   --  Put it that far over and down, in canvas units, to be written once it is let go.

   procedure Resize (Self : in out Item; Across, Down : Float; Still : Boolean)
     with Pre => Is_Assigned (Self);
   --  Make it that much bigger in canvas units, but not under the least: the size the pointer asks for, which may
   --  be under it, is remembered while the corner is held (Still), so that coming back takes it at once.

   function Is_Resizing (Self : Item) return Boolean;

   procedure Set_State (Self : in out Item; To : Items.States)
     with Pre => Is_Assigned (Self), Post => Details (Self).State = To;
   --  Shown as a window, as a bar in the dock, or not at all. Writing it is for the application. A picture is let
   --  go of unless it is a window, and the tool goes back to the pointer.

   --  A source

   function Capture (Self : Item) return Captures
     with Pre => Is_Assigned (Self);

   procedure Set_Capture
     (Self    : in out Item;
      To      : Captures;
      File    : String := "";
      Detail  : String := "";
      At_Time : Projects.Seconds := 0)
     with Pre => Is_Assigned (Self)
                 and then Details (Self).Kind = Source
                 and then (To /= Ready or else File /= "");
   --  Say how the source's picture stands: Ready shows the file, as taken at At_Time; Failed says why, in Detail.

   function Picture_File (Self : Item) return String
     with Pre => Is_Assigned (Self);
   --  The picture, or the text file of a source that is one; "" if none is shown.

   procedure Set_Origin (Self : in out Item; To : Items.Origins)
     with Pre => Is_Assigned (Self) and then Details (Self).Kind = Source,
          Post => Details (Self).Origin = To;
   --  Say whether the source is yet to be said to be a link or a file, a link, or a file (its path is its text, which
   --  cannot be typed over).

   procedure Set_Pages (Self : in out Item; Document : String; Page, Count : Natural)
     with Pre => Is_Assigned (Self)
                 and then Details (Self).Kind = Source
                 and then Page <= Count,
          Post => Details (Self).Page = Page and then Details (Self).Page_Count = Count;
   --  Say the source's picture is of the Page'th of the Count pages of its document, a file of that ending ("" and 0
   --  for a web page).

   procedure Show_Text (Self : in out Item; File : String; At_Time : Projects.Seconds)
     with Pre => Is_Assigned (Self) and then Details (Self).Kind = Source and then File /= "";
   --  Show the text of the file, which cannot be changed in the window, as taken at At_Time, in place of a picture.

   function Shows_Picture (Self : Item) return Boolean
     with Pre => Is_Assigned (Self);
   --  Whether the source has a picture to show, the pages of a document or a file: not if it could not be taken.

   function Is_Unchosen (Self : Item) return Boolean;
   --  A source that is yet to say where it comes from.

   function Is_Text_Source (Self : Item) return Boolean;
   --  A source that shows a text file, not a picture.

   function Is_Open_Source (Self : Item) return Boolean;

   function Wants_Pages (Self : Item) return Boolean
     with Pre => Is_Assigned (Self);
   --  Whether the source's document is to be shown as all its pages one under another, drawn from what is on them
   --  (see Items.Vector_Pages): a PDF that has been taken, as a page.

   procedure Pages_Opened (Self : in out Item; Ok : Boolean; Message : String := "")
     with Pre => Is_Assigned (Self);
   --  Say whether it was: not, it is a failed capture, and says why.

   function Is_Paged (Self : Item) return Boolean
     with Pre => Is_Assigned (Self);
   --  Whether the pages are shown one under another.

   procedure Set_Progress (Self : in out Item; To : Float)
     with Pre => Is_Assigned (Self) and then Details (Self).Kind = Source and then To in 0.0 .. 1.0;
   --  How far on the picture is, while the capture is Busy.

   function Progress (Self : Item) return Float
     with Pre => Is_Assigned (Self);

   function Shows_Progress (Self : Item) return Boolean
     with Pre => Is_Assigned (Self);
   --  While a source's picture is being taken, or a note is being listened to.

   function Recognized (Self : in out Item) return access Vision.Result
     with Pre => Is_Assigned (Self);
   --  The words found in the source's picture, to be selected as text over it.

   procedure Set_Recognized (Self : in out Item; Found : Vision.Result)
     with Pre => Is_Assigned (Self) and then Details (Self).Kind = Source;
   --  They are of the picture shown: Set_Capture Ready forgets them.

   procedure Clear_Recognized (Self : in out Item);

   function Recognized_Version (Self : Item) return Parts.Version_Number;

   function Picture_Version (Self : Item) return Parts.Version_Number;
   --  Different whenever the picture, or text file, is another one, or the same taken again: the window loads it.

   procedure Set_Zoom (Self : in out Item; To : Float)
     with Pre  => Is_Assigned (Self)
                  and then Details (Self).Kind = Source
                  and then To in Items.Min_Zoom .. Items.Max_Zoom,
          Post => Details (Self).Zoom = To;
   --  Zoom the source's picture within its window: kept by Flush.

   function Tool (Self : Item) return Tools
     with Pre => Is_Assigned (Self);

   procedure Select_Tool (Self : in out Item; To : Tools)
     with Pre => Is_Assigned (Self), Post => Tool (Self) = To;

   --  What was marked on the picture, and what the window knows of that.

   procedure Set_Marks (Self : in out Item; Kept : Items.Marks.Mark_List)
     with Pre => Is_Assigned (Self) and then Details (Self).Kind = Source;
   --  These highlights are on the source's picture, as kept: they are not written again until it is marked. The
   --  window shows them (Marks_To_Show).

   function Marks_To_Show (Self : Item) return Parts.Version_Number;
   --  Different whenever the window is to be given the marks again (see Kept_Marks).

   function Kept_Marks (Self : Item) return Items.Marks.Mark_List
     with Pre => Is_Assigned (Self);

   procedure Report_Marks (Self : in out Item; Made : Items.Marks.Mark_List; Version : Natural)
     with Pre => Is_Assigned (Self) and then Details (Self).Kind = Source;
   --  The person marked the picture: these are the highlights now, as of the window's Version of them.

   function Mark_Count (Self : Item) return Natural
     with Pre => Is_Assigned (Self);

   function Marks_Reported (Self : Item) return Natural
     with Pre => Is_Assigned (Self);
   --  The Version of the window's marks last Reported or shown.

   procedure Marks_Shown_As (Self : in out Item; Version : Natural)
     with Pre => Is_Assigned (Self);
   --  The window shows the marks that Marks_To_Show asked for, and its Version of them is that: they are not to be
   --  taken for the person's.

   --  A note

   function Dictation (Self : Item) return Dictations
     with Pre => Is_Assigned (Self);

   procedure Set_Dictation (Self : in out Item; To : Dictations; Detail : String := "")
     with Pre  => Is_Assigned (Self) and then Details (Self).Kind = Note,
          Post => Dictation (Self) = To;
   --  Say how dictating stands: a Failed one says why, in Detail, until the text is next changed.

   procedure Change_Dictation
     (Self : in out Item; View : in out Editor_VM.Editor'Class; To : Dictations; Detail : String := "")
     with Pre => Is_Assigned (Self) and then Details (Self).Kind = Note,
          Post => Dictation (Self) = To;
   --  Apply a speech-job state. Failure takes provisional speech back through the editor before showing its status.

   procedure Set_Level (Self : in out Item; To : Float)
     with Pre => Is_Assigned (Self) and then Details (Self).Kind = Note and then To in 0.0 .. 1.0;
   --  How loud what is heard is, while Listening, in steps.

   function Editor (Self : in out Item) return access Editor_VM.View_Model
     with Pre => Is_Assigned (Self) and then Details (Self).Kind = Note;
   --  Dictation's document rules and provisional text, shared by the canvas and writing editors.

   --  What is said of it

   function Status (Self : Item) return String
     with Pre => Is_Assigned (Self);
   --  What its status line says: how a source's picture stands, the page of its document, or how a note is being
   --  dictated.

   function Page_Status (Self : Item) return String
     with Pre => Is_Assigned (Self);
   --  "Page 2 of 5".

   --  What the window knows that only it can say, as it changes

   type Facts is record
      Dragging : Boolean := False;
      --  The window is being moved.
      Sizing   : Boolean := False;
      --  Its corner is being dragged.
      Zooming  : Boolean := False;
      --  The slider of the picture's zoom is.
      Typing   : Boolean := False;
      --  Its title or text has the focus (or is typed in elsewhere: see Hold_Typing).
      Marking  : Boolean := False;
      --  The highlighter is being dragged.
      Scroll   : Float := 0.0;
      Across   : Float := 0.0;
      --  How far the content is scrolled, as Details.Scroll and Scroll_Across are.
      Pending  : Boolean := False;
      --  A note's text is to be scrolled to Details.Scroll once it has a width to be laid out in (Scrolled).
   end record;

   procedure Report (Self : in out Item; What : Facts)
     with Pre => Is_Assigned (Self);

   procedure Hold_Typing (Self : in out Item; To : Boolean);
   --  Say the text is being typed in, in another view, so that Flush leaves writing it until it has been left alone
   --  for a moment, as it does when its own text is focused.

   function Scroll_Pending (Self : Item) return Boolean;

   procedure Scrolled (Self : in out Item; Scroll : Float)
     with Pre => Is_Assigned (Self);
   --  The window scrolled the note's text to where it was kept.

   procedure Flush
     (Self  : in out Item;
      Store : in out Projects.Store;
      Now   : Pomarine.Events.Milliseconds;
      Force : Boolean;
      Wrote : out Boolean)
     with Pre => Is_Assigned (Self) and then Projects.Is_Open (Store);
   --  Write to the database what has changed: where it has been put, once it is let go; the title and text, once they
   --  are no longer being typed in, or have not changed for Idle_Delay, or whenever Force. Wrote says whether
   --  anything was written. Now is as Pomarine.Events.Ticks.

   --  What changed

   function Where_Version (Self : Item) return Parts.Version_Number;
   --  Different whenever it is moved or sized, or its state changes.

   function Look_Version (Self : Item) return Parts.Version_Number;
   --  Different whenever the kind of the item is, or where a source is from.

   function Shape_Version (Self : Item) return Parts.Version_Number;
   --  Different whenever what a source shows is another: a picture, its text, its pages, or nothing yet.

   function Zoom_Version (Self : Item) return Parts.Version_Number;
   --  Different whenever the source's picture is zoomed.

   function Tool_Version (Self : Item) return Parts.Version_Number;
   --  Different whenever the tool is another.

private

   package Unbounded renames Ada.Strings.Unbounded;

   use type Docs.Version;

   type Item is limited record
      Assigned     : Boolean := False;
      Fields       : Items.Info;
      Title_Doc    : aliased Docs.Document;
      Content_Doc  : aliased Docs.Document;
      Text_Doc     : aliased Docs.Document;
      --  The text of a source that is a text file.
      Title_Saved  : Natural := 0;
      Content_Saved : Natural := 0;
      --  The states of the documents when they were written.
      Title_Seen   : Natural := 0;
      Content_Seen : Natural := 0;
      Changed_At   : Pomarine.Events.Milliseconds := 0;
      --  The last time either was seen to differ from what it was.
      Title_Version : Docs.Version := 0;
      Content_Version : Docs.Version := 0;
      --  What Refresh last took.
      Word_Count   : Natural := 0;
      Frame_Dirty  : Boolean := False;
      --  Moved or sized, and not written.
      Zoom_Dirty   : Boolean := False;
      Scroll_Seen, Across_Seen : Float := 0.0;
      Scroll_At    : Pomarine.Events.Milliseconds := 0;
      --  How far the content was scrolled when last looked at, and when that changed: it is written once it has
      --  stayed (Idle_Delay).
      Scroll_Waits : Boolean := False;
      --  A note's text is to be scrolled to Details.Scroll once it has a width to be laid out in.
      Marks_Saved  : Natural := 0;
      --  The window's Version of the marks when they were written.
      Marks_Now    : Natural := 0;
      --  And as last Reported.
      Marks_Kept   : Items.Marks.Mark_List;
      Marks_Dirty  : Boolean := False;
      Marks_Shown  : Pomarine.View_Models.Change_Counter;
      Held         : Boolean := False;
      --  Typed in elsewhere: see Hold_Typing.
      Raw_Width, Raw_Height : Float := 0.0;
      --  While the corner is dragged, the size the pointer asks for, which may be under the minimum; the item itself
      --  is held at the minimum.
      Sizing       : Boolean := False;
      Known        : Facts;
      --  What the window said last.
      Capturing    : Captures := Waiting;
      Failure      : Unbounded.Unbounded_String;
      File         : Unbounded.Unbounded_String;
      Paged        : Boolean := False;
      Working      : Float := 0.0;
      --  How far the picture is, or how loud what is heard.
      Using_Tool   : Tools := Pointer;
      Dictating    : Dictations := Silent;
      Speech       : Unbounded.Unbounded_String;
      --  Why dictation failed.
      Editing      : aliased Editor_VM.View_Model;
      Found        : aliased Vision.Result;
      Words_Found  : Pomarine.View_Models.Change_Counter;
      Pictures     : Pomarine.View_Models.Change_Counter;
      Wheres       : Pomarine.View_Models.Change_Counter;
      Looks        : Pomarine.View_Models.Change_Counter;
      Shapes       : Pomarine.View_Models.Change_Counter;
      Zooms        : Pomarine.View_Models.Change_Counter;
      Choices      : Pomarine.View_Models.Change_Counter;
   end record;

end Items.Models;
