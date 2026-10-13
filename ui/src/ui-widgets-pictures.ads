with SDL3.Cursors;
with SDL3.Events;
with SDL3.Windows.Renderers.Textures;
with UI.Scrollbars;
with Vision;

--  A picture from a PNG file, as wide as the box, and as tall as that
--  makes it, of which the box shows a part: scrolled with the wheel (or a
--  trackpad's two fingers), and by Scroll_To. It is not read until it is
--  drawn, and is let go of again by Unload.
--
--  The picture is scaled to the box's width, so it zooms with the box,
--  and a scroll is kept as how far down the picture it is, not in pixels.
--  It can also be zoomed within its box (Set_Zoom): at 2.0 it is twice as
--  wide as the box, and scrolls across as well as down.
--
--  If it is told the words in the picture (Set_Words, from Vision), they
--  can be selected as text over it: by dragging from one to another, a
--  double click for a word and a triple for a line, and Command with A
--  for all; and copied with Command and C. The words' boxes are
--  fractions of the picture, so they stay on the words wherever the
--  picture is, and however big; it is the full-size picture that was
--  read, not the size it is shown at.
--
--  With the highlighter as its tool (Set_Tool), a drag over the picture
--  does not select, but marks it: a translucent band, one line of text
--  tall, along the way the pointer went from where it was pressed (it
--  stays on the line pressed on). Marks are only drawn: they are kept as
--  fractions of the picture, as the words' boxes are, so they follow its
--  zoom and scroll, and can be set (Set_Marks) and read (Mark_At) to be
--  kept elsewhere; Marks_Version says when a mark was made.
package UI.Widgets.Pictures is

   Path_Capacity : constant := 1024;

   Points_Per_Notch : constant Float := 48.0;
   --  How far a notch of the wheel scrolls.

   type Picture is new Widget with private;

   type Tools is (Pointer, Highlighter, Eraser);
   --  What a drag does: select words, or highlight; and what a click does
   --  on a mark, with the eraser: remove it.

   Max_Marks : constant := 256;

   Mark_Height : constant Float := 0.024;
   --  How tall a mark is, as a fraction of the picture's width.

   type Mark is record
      Left, Right, Y : Float := 0.0;
   end record
     with Dynamic_Predicate =>
       Mark.Left in 0.0 .. 1.0 and then Mark.Right in Mark.Left .. 1.0
       and then Mark.Y in 0.0 .. 1.0;
   --  A band from Left to Right, of the picture's width, centred Y down
   --  it, of its height.

   type Mark_Array is array (Positive range <>) of Mark;

   function Tool (Item : Picture) return Tools;

   function Is_Marking (Item : Picture) return Boolean;
   --  Whether a mark is being made: the pointer is down, with the
   --  highlighter.

   procedure Set_Tool (Item : in out Picture; To : Tools)
     with Post => Tool (Item) = To and then not Is_Marking (Item);
   --  Any mark being made is dropped.

   function Mark_Count (Item : Picture) return Natural;

   function Mark_At (Item : Picture; Index : Positive) return Mark
     with Pre => Index <= Mark_Count (Item);

   function Marks_Version (Item : Picture) return Natural;
   --  Changes when a mark is made or they are cleared; not by Set_Marks.

   procedure Set_Marks (Item : in out Picture; To : Mark_Array)
     with Pre  => To'Length <= Max_Marks,
          Post => Mark_Count (Item) = To'Length;
   --  Show these, in place of those made.

   procedure Clear_Marks (Item : in out Picture)
     with Post => Mark_Count (Item) = 0;

   procedure Set_File (Item : in out Picture; Path : String)
     with Pre => Path'Length <= Path_Capacity;
   --  Show the PNG file, from its top. "" shows none. It is read at the
   --  next draw, even if it is the file that was shown, which may have
   --  changed.

   function File_Name (Item : Picture) return String;

   function Has_Picture (Item : Picture) return Boolean;
   --  Whether it has been read, and can be drawn.

   function Has_Failed (Item : Picture) return Boolean;
   --  Whether the file was there to show but could not be read.

   procedure Unload (Item : in out Picture);
   --  Give back the picture's memory: it is read again when drawn.

   function Scrolled (Item : Picture) return Float;
   --  How far down the picture the top of the box is, from 0.0, its top,
   --  to 1.0, its bottom (as of the last draw).

   procedure Scroll_To (Item : in out Picture; To : Float)
     with Pre => To in 0.0 .. 1.0;

   function Scrolled_Across (Item : Picture) return Float;
   --  How far across the picture the box is, from 0.0, the left edge
   --  of it at the box's, to 1.0, the right edge at the box's. It is 0.0
   --  while the picture is no wider than the box.

   procedure Scroll_Across_To (Item : in out Picture; To : Float)
     with Pre => To in 0.0 .. 1.0;

   procedure Set_Zoom (Item : in out Picture; To : Float)
     with Pre => To > 0.0, Post => Zoom (Item) = To;
   --  Show it To times as wide as the box (1.0 to begin with), kept at
   --  the same place along and down it.

   function Zoom (Item : Picture) return Float;

   procedure Set_Words (Item : in out Picture; Found : Vision.Result_Access);
   --  The words in the picture, as of the file shown: null for none. They
   --  must be there as long as they are set. The selection is cleared.

   function Has_Words (Item : Picture) return Boolean;

   function Has_Selection (Item : Picture) return Boolean;

   function Word_Box (Item : Picture; Index : Positive) return Pixel_Box
     with Pre => Has_Words (Item) and then Index <= Word_Count (Item);
   --  Where the word is, in pixels from the top left of the target, as of
   --  the last draw (empty before the picture is drawn).

   function Word_Count (Item : Picture) return Natural;

   function Selected_Text (Item : Picture) return String;
   --  The selected words, a space between those of one line and a line
   --  break between lines; "" if none.

   procedure Select_All (Item : in out Picture);

   procedure Clear_Selection (Item : in out Picture)
     with Post => not Has_Selection (Item);

   overriding procedure Draw
     (Item   : in out Picture;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme);

   overriding procedure Handle
     (Item    : in out Picture;
      Event   : SDL3.Events.Event;
      Handled : out Boolean);

   overriding function Cursor (Item : Picture) return SDL3.Cursors.Kind;

   overriding function Accepts_Focus (Item : Picture) return Boolean;

   overriding procedure Hover_Changed
     (Item : in out Picture; Hovered : Boolean);

   overriding procedure Focus_Changed
     (Item : in out Picture; Focused : Boolean);

private

   type Picture is new Widget with record
      Name    : String (1 .. Path_Capacity) := [others => ' '];
      Length  : Natural range 0 .. Path_Capacity := 0;
      Loaded  : Boolean := False;
      Failed  : Boolean := False;
      Pixels  : SDL3.Windows.Renderers.Textures.Texture;
      Down    : Float := 0.0;
      --  How far the picture is scrolled, as a fraction of its height.
      Zoomed  : Float := 1.0;
      Across  : Float := 0.0;
      --  How far across the picture is scrolled, as a fraction of how much
      --  wider it is than the box.
      Fitted  : Float := 0.0;
      --  The picture's height as of the last draw, in pixels.
      Found   : Vision.Result_Access;
      Anchor  : Natural := 0;
      --  The word a drag began at, 0 if none.
      Head    : Natural := 0;
      --  The word it has reached, 0 if it has not left the first: the
      --  selection is the words from Anchor to Head, either way round.
      Held    : Boolean := False;
      Chosen  : Tools := Pointer;
      Marked  : Mark_Array (1 .. Max_Marks + 1);
      Marks   : Natural range 0 .. Max_Marks := 0;
      Version : Natural := 0;
      Down_Bar   : Scrollbars.Bar;
      Across_Bar : Scrollbars.Bar;
      --  The bars down its side and along its foot.
      Marking : Boolean := False;
      Started : Float := 0.0;
      --  While a mark is made, where along the picture it began, of its
      --  width; it is in Marked (Marks + 1), not counted until done.
   end record;

end UI.Widgets.Pictures;
