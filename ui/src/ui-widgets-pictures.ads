with SDL3.Events;
with SDL3.Windows.Renderers.Textures;
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
package UI.Widgets.Pictures is

   Path_Capacity : constant := 1024;

   Points_Per_Notch : constant Float := 48.0;
   --  How far a notch of the wheel scrolls.

   type Picture is new Widget with private;

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

   overriding function Accepts_Focus (Item : Picture) return Boolean;

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
   end record;

end UI.Widgets.Pictures;
