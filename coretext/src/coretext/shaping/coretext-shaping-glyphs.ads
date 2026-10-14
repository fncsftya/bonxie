with Ada.Finalization;
with Interfaces;
with System;

package CoreText.Shaping.Glyphs is

   type Image is limited private;
   --  One glyph rasterized: RGBA, eight bits a channel, the colour not
   --  multiplied by the alpha. A glyph of one colour is white, its alpha
   --  how much of each pixel it covers, so that it can be tinted any
   --  colour and smoothed without darkening its edges; colour glyphs (see
   --  Is_Color) are in their own colours. There is a transparent pixel
   --  all round.

   procedure Rasterize
     (Reg      : Registry;
      Item     : Font_Id;
      Id       : Interfaces.Unsigned_16;
      Size     : Float;
      Subpixel : Float;
      Result   : in out Image)
     with Pre => Size > 0.0 and then Subpixel in 0.0 .. 1.0;
   --  Draw glyph Id of font Item at Size pixels, its origin Subpixel
   --  (a fraction of a pixel) right of a pixel boundary, replacing
   --  Result. A glyph with nothing to draw, such as a space, gives an
   --  Image that Is_Blank.

   function Is_Blank (Item : Image) return Boolean;

   function Pixels (Item : Image) return System.Address
     with Pre => not Is_Blank (Item);
   --  Height rows of Pitch bytes, the top row first.

   function Width (Item : Image) return Positive
     with Pre => not Is_Blank (Item);
   function Height (Item : Image) return Positive
     with Pre => not Is_Blank (Item);
   function Pitch (Item : Image) return Positive
     with Pre => not Is_Blank (Item);

   function Left (Item : Image) return Integer
     with Pre => not Is_Blank (Item);
   --  How many pixels right of the glyph's origin the image starts.
   function Top (Item : Image) return Integer
     with Pre => not Is_Blank (Item);
   --  How many pixels above the baseline the image starts.

private

   type Buffer is array (Natural range <>) of Interfaces.Unsigned_8;
   type Buffer_Access is access Buffer;

   type Image is new Ada.Finalization.Limited_Controlled with record
      Data    : Buffer_Access;
      Columns : Natural := 0;
      Rows    : Natural := 0;
      Origin_X : Integer := 0;
      Origin_Y : Integer := 0;
   end record;

   overriding procedure Finalize (Item : in out Image);

end CoreText.Shaping.Glyphs;
