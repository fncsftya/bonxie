with Ada.Finalization;
with Interfaces;
with System;
with CoreText.Fonts;

package CoreText.Lines is

   type Line is limited private;
   --  Some text with no newlines, set in a font as one line, for
   --  measuring or drawing. Independent of the Font it was set in.

   procedure Make (Item : in out Line; Using : Fonts.Font; Text : String)
     with Pre => Fonts.Is_Open (Using);
   --  Set Text in Using, replacing Item's text. Text may be "".

   function Length (Item : Line) return Natural;
   --  The line's text length in UTF-16 units.

   function Width (Item : Line) return Float;
   --  How wide the line is in pixels.

   function Offset_For_Index (Item : Line; Index : Natural) return Float
     with Pre => Index <= Length (Item);
   --  Horizontal pixel offset of the caret before UTF-16 unit Index.

   function Index_For_Position (Item : Line; X : Float) return Natural
     with Post => Index_For_Position'Result <= Length (Item);
   --  The UTF-16 index nearest pixel offset X.

   --  Rasterizing

   type Bitmap is tagged limited private;
   --  Premultiplied RGBA, eight bits a channel, in the line's final
   --  colour: tinting white text on the GPU would also tint colour glyphs
   --  such as emoji.

   type Channel is new Interfaces.Unsigned_8;

   procedure Rasterize
     (Item   : Line;
      Red, Green, Blue : Channel;
      Result : in out Bitmap'Class)
     with Pre => Length (Item) > 0;
   --  Draw Item in the colour given, on transparent, replacing Result.

   function Is_Empty (Item : Bitmap) return Boolean;

   function Pixels (Item : Bitmap) return System.Address
     with Pre => not Is_Empty (Item);
   --  The first row of Height rows of Pitch bytes. Valid until Item is
   --  rasterized into again or finalized.

   function Width (Item : Bitmap) return Positive
     with Pre => not Is_Empty (Item);
   function Height (Item : Bitmap) return Positive
     with Pre => not Is_Empty (Item);
   function Pitch (Item : Bitmap) return Positive
     with Pre => not Is_Empty (Item);
   --  In pixels, pixels and bytes.

   Pad : constant := 2;
   --  The blank margin in pixels left of the line's origin and above its
   --  ascent, room for glyph overhang.

   function Baseline (Item : Bitmap) return Positive
     with Pre => not Is_Empty (Item);
   --  The baseline's distance from the bitmap's top.

private

   type Line is new Ada.Finalization.Limited_Controlled with record
      Handle : System.Address := System.Null_Address;
      Units  : Natural := 0;
   end record;

   overriding procedure Finalize (Item : in out Line);

   type Buffer is array (Natural range <>) of Interfaces.Unsigned_8;
   type Buffer_Access is access Buffer;

   type Bitmap is new Ada.Finalization.Limited_Controlled with record
      Data     : Buffer_Access;
      Columns  : Natural := 0;
      Rows     : Natural := 0;
      Base     : Natural := 0;
   end record;

   overriding procedure Finalize (Item : in out Bitmap);

end CoreText.Lines;
