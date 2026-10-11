with SDL3.Events;
with SDL3.Windows.Renderers;
with UI.Clipboards;
with UI.Themes;
private with Ada.Containers.Vectors;
private with Ada.Strings.Unbounded;
private with Typeset.Documents;
private with Typeset.Views;

--  A box of text to edit: paragraphs wrapped to its width, but no wider
--  than a measure (centred in it when it is wider), with a blinking
--  caret and a selection moved by the keys and the mouse; typing, also
--  through input methods, deleting, cutting, copying and pasting, and
--  undoing. It scrolls, and its owner may zoom its text.
--
--  Its text is in layout units, Density x Zoom pixels each; its outline
--  and padding are in points, Density pixels each.
package UI.Text_Areas is

   type Text_Area is limited private;
   --  Declare it after the Renderer it draws to, and always draw it to
   --  that Renderer.

   procedure Configure
     (Item    : in out Text_Area;
      Family  : String;
      Size    : Float;
      Measure : Float;
      Spacing : Float := 0.0)
     with Pre  => Size > 0.0 and then Measure > 0.0 and then Spacing >= 0.0,
          Post => Is_Configured (Item);
   --  Set the text in font Family at Size layout units, in lines no wider
   --  than Measure, with Spacing between paragraphs.

   function Is_Configured (Item : Text_Area) return Boolean;

   procedure Load (Item : in out Text_Area; Content : String)
     with Pre => Is_Configured (Item);
   --  Replace the text with Content, a paragraph to each line, and show
   --  its start, with the caret there. Nothing is left to undo.

   function Text (Item : Text_Area) return String
     with Pre => Is_Configured (Item);
   --  All of it, a line to each paragraph.

   --  Where it is

   procedure Place
     (Item    : in out Text_Area;
      Left, Top, Width, Height : Float;
      Density : Float;
      Zoom    : Float := 1.0)
     with Pre => Is_Configured (Item)
                 and then Width >= 0.0 and then Height >= 0.0
                 and then Density >= 1.0 and then Zoom > 0.0;
   --  Put it in the part of the target Width x Height pixels with its top
   --  left at Left, Top, which has Density pixels to a point, with its
   --  text Zoom times its size.

   function Contains (Item : Text_Area; X, Y : Float) return Boolean;
   --  Whether pixel X, Y is in it.

   --  Focus: only a focused text area takes typing and shows its caret.

   procedure Set_Focus (Item : in out Text_Area; Focused : Boolean)
     with Pre => Is_Configured (Item);

   function Is_Focused (Item : Text_Area) return Boolean;

   --  The caret and the selection

   type Position is record
      Paragraph : Positive := 1;
      Index     : Positive := 1;  --  the byte of its text it is before
   end record;

   function "<" (Left, Right : Position) return Boolean is
     (Left.Paragraph < Right.Paragraph
      or else (Left.Paragraph = Right.Paragraph
               and then Left.Index < Right.Index));

   function Is_Position (Item : Text_Area; At_Point : Position)
      return Boolean
     with Pre => Is_Configured (Item);
   --  Whether At_Point is in the text, before a character or at the end
   --  of a paragraph.

   function Caret (Item : Text_Area) return Position;

   function Mark (Item : Text_Area) return Position;
   --  The other end of the selection from the caret: what is between
   --  them is selected. Nothing is if they are the same.

   function Has_Selection (Item : Text_Area) return Boolean;

   function Selected_Text (Item : Text_Area) return String
     with Pre => Is_Configured (Item);
   --  A line to each paragraph.

   procedure Select_Range (Item : in out Text_Area; From, To : Position)
     with Pre  => Is_Configured (Item)
                  and then Is_Position (Item, From)
                  and then Is_Position (Item, To),
          Post => Mark (Item) = From and then Caret (Item) = To;
   --  Select from From to To, with the caret at To.

   procedure Select_All (Item : in out Text_Area)
     with Pre => Is_Configured (Item);

   type Motion is
     (Previous_Character, Next_Character, Previous_Word, Next_Word,
      Previous_Line, Next_Line, Line_Start, Line_End,
      Paragraph_Start, Paragraph_End, Text_Start, Text_End);

   procedure Move
     (Item   : in out Text_Area;
      By     : Motion;
      Extend : Boolean := False)
     with Pre => Is_Configured (Item);
   --  Move the caret: a character or a word back or forward; a line up
   --  or down, as near as can be to where it was across (from the first
   --  or last line, to the start or end of the text); or to the start or
   --  end of its line, its paragraph (or the one before or after, from
   --  there), or the text. With Extend the selection is extended to
   --  where it goes. Without, it is dropped, and a character back or
   --  forward goes to its start or end. Then bring the caret into view.

   --  The mouse

   procedure Click
     (Item   : in out Text_Area;
      X, Y   : Float;
      Clicks : Positive := 1;
      Extend : Boolean := False)
     with Pre  => Is_Configured (Item),
          Post => Is_Focused (Item) and then Is_Dragging (Item);
   --  Focus it, with the caret where it is nearest pixel X, Y; with
   --  Extend, the selection extended to there. A double click selects
   --  the word there, a triple its paragraph. Until Release, Drag
   --  extends the selection.

   procedure Drag (Item : in out Text_Area; X, Y : Float)
     with Pre => Is_Configured (Item);
   --  Extend the selection to where it is nearest pixel X, Y, if a click
   --  has not been released.

   procedure Release (Item : in out Text_Area)
     with Post => not Is_Dragging (Item);

   function Is_Dragging (Item : Text_Area) return Boolean;

   --  Editing, at the selection, after which the caret is brought into
   --  view

   procedure Insert (Item : in out Text_Area; Typed : String)
     with Pre => Is_Configured (Item);
   --  Type Typed, in UTF-8, in place of the selection. A line feed in it
   --  breaks the paragraph. Typing in a row is undone together.

   type Deletion is (Character, Word, Line_Part);

   procedure Delete_Backward
     (Item : in out Text_Area; By : Deletion := Character)
     with Pre => Is_Configured (Item);
   procedure Delete_Forward
     (Item : in out Text_Area; By : Deletion := Character)
     with Pre => Is_Configured (Item);
   --  Delete the selection, if there is one; otherwise the character,
   --  the word, or the rest of the line, before or after the caret. At
   --  the start or end of a paragraph, join it to the one before or
   --  after.

   procedure Copy
     (Item  : in out Text_Area;
      Board : in out Clipboards.Clipboard'Class)
     with Pre => Is_Configured (Item);
   --  Put the selection on Board, if there is one.

   procedure Cut
     (Item  : in out Text_Area;
      Board : in out Clipboards.Clipboard'Class)
     with Pre => Is_Configured (Item);
   --  Copy the selection, and delete it.

   procedure Paste
     (Item  : in out Text_Area;
      Board : in out Clipboards.Clipboard'Class)
     with Pre => Is_Configured (Item);
   --  Insert what is on Board, in place of the selection.

   --  Undoing

   procedure Undo (Item : in out Text_Area)
     with Pre => Is_Configured (Item);
   --  Take back the last edit not taken back, selecting what it removed.

   procedure Redo (Item : in out Text_Area)
     with Pre => Is_Configured (Item);
   --  Make the last edit taken back again.

   function Can_Undo (Item : Text_Area) return Boolean;
   function Can_Redo (Item : Text_Area) return Boolean;

   Undo_Depth : constant := 1000;
   --  How many edits back can be undone.

   function State (Item : Text_Area) return Natural;
   --  Names the text as it is: 0 as loaded. Undoing or redoing back to
   --  a state gives the same text, and its name; any other edit gives
   --  one not seen before. So the text is changed since it was saved if
   --  its state is not what it was then.

   --  Input methods, which show what they are given before they send it
   --  as typing

   procedure Compose
     (Item   : in out Text_Area;
      Shown  : String;
      Cursor : Natural)
     with Pre => Is_Configured (Item);
   --  Show Shown, in UTF-8, underlined in place of the selection, with
   --  the caret after Cursor characters of it (at its end, if there are
   --  fewer); "" to show none. Insert takes its place. It is not an edit
   --  to undo, unless something else is done before Insert.

   function Is_Composing (Item : Text_Area) return Boolean;

   procedure Caret_Box
     (Item : in out Text_Area;
      X, Y, Width, Height : out Float)
     with Pre => Is_Configured (Item);
   --  Where the caret is drawn, in pixels, as to show an input method's
   --  choices beside it.

   --  The caret blinks while it has focus: it shows for Blink_Period
   --  after it was last moved or the text edited, then hides for as long,
   --  and so on. It shows until told the time.

   Blink_Period : constant := 500;  --  milliseconds

   procedure Tick
     (Item    : in out Text_Area;
      Now     : SDL3.Events.Milliseconds;
      Changed : out Boolean);
   --  Say the time is Now, as SDL3.Events.Ticks; events tell it too.
   --  Changed says whether the caret has shown or hidden since the time
   --  was last said.

   function Is_Caret_Shown (Item : Text_Area) return Boolean;

   function Until_Blink (Item : Text_Area) return SDL3.Events.Milliseconds
     with Post => Until_Blink'Result in 1 .. Blink_Period;
   --  How long after the time last said it shows or hides.

   --  Scrolling

   procedure Scroll (Item : in out Text_Area; By : Float)
     with Pre => Is_Configured (Item);
   --  Move what is shown By layout units down the text (up, if negative),
   --  but not past either end. The caret stays where it is.

   --  Events

   procedure Handle
     (Item    : in out Text_Area;
      Event   : SDL3.Events.Event;
      Board   : in out Clipboards.Clipboard'Class;
      Handled : out Boolean)
     with Pre => Is_Configured (Item);
   --  Take Event if it is for the text area, and say so; then it is to be
   --  drawn again.
   --
   --  The mouse: a left click in it focuses it and places the caret (with
   --  Shift, extends the selection; two select a word, three a
   --  paragraph), and dragging selects. The wheel over it scrolls, unless
   --  Command is held.
   --
   --  Focused, it takes typing and input methods' text. The arrow keys
   --  move the caret, with Option by words or paragraphs, with Command to
   --  the ends of the line or the text, and with Shift extend the
   --  selection. Backspace and Delete delete, with Option a word, with
   --  Command to the end of the line. Command with A selects all; with
   --  X, C and V cuts, copies and pastes, on Board; with Z undoes, and
   --  with Shift too redoes. Return breaks the paragraph. Escape leaves
   --  it unfocused. While an input method is composing, it leaves the
   --  keys to it.
   --
   --  Page Up, Page Down, Home and End scroll, as the up and down arrows
   --  do when it is not focused. It leaves clicks outside it to its
   --  owner, which might unfocus it.

   procedure Draw
     (Item    : in out Text_Area;
      Target  : SDL3.Windows.Renderers.Renderer;
      Colors  : Themes.Theme;
      Settled : Boolean := True)
     with Pre => Is_Configured (Item);
   --  Draw it where it was placed. Settled says the zoom is not changing:
   --  see Typeset.Views.

private

   use type SDL3.Events.Milliseconds;

   type Edit_Kind is (Typing, Deleting_Back, Deleting_Forward, Other);
   --  Edits of the first three kinds in a row are undone together.

   type Change is record
      From     : Position;
      Removed  : Ada.Strings.Unbounded.Unbounded_String;
      Inserted : Ada.Strings.Unbounded.Unbounded_String;
      --  Each a line to each paragraph.
      Kind     : Edit_Kind := Other;
      Id       : Positive := 1;  --  the state it makes
   end record;
   --  Removed was replaced by Inserted, at From.

   package Change_Vectors is new Ada.Containers.Vectors (Positive, Change);

   type Text_Area is limited record
      Doc      : Typeset.Documents.Document;
      View     : Typeset.Views.View;
      Measure  : Float := 1.0;

      Left, Top, Width, Height : Float := 0.0;  --  in pixels
      Density  : Float := 1.0;
      Zoom     : Float := 1.0;

      Anchor   : Typeset.Documents.Paragraph_Number := 1;
      Offset   : Float := 0.0;
      --  The top of what is shown, from the top of paragraph Anchor.

      At_Caret : Position;
      At_Mark  : Position;
      Has_Goal : Boolean := False;
      Goal     : Float := 0.0;
      --  How far across the caret is to go, moving up and down: where it
      --  was before it moved so.
      Focused  : Boolean := False;
      Dragging : Boolean := False;

      Undos    : Change_Vectors.Vector;
      Redos    : Change_Vectors.Vector;
      Last_Id  : Natural := 0;
      Joining  : Boolean := False;
      --  The next edit may be undone with the last.

      Composing : Boolean := False;
      Composed  : Position;  --  where the input method's text starts
      Composed_Length : Natural := 0;  --  in bytes

      Now      : SDL3.Events.Milliseconds := 0;
      Since    : SDL3.Events.Milliseconds := 0;
      --  When the caret last moved, or the text was edited.
      Caret_On : Boolean := True;
   end record;

end UI.Text_Areas;
