--  Ada-style interface to CoreText (macOS only): fonts, lines of text
--  set in them, line breaking and rasterization into RGBA bitmaps.
--  The C bindings are hidden in CoreText.Thin.
--
--  Strings are UTF-8 Ada Strings. CoreText indexes text in UTF-16 code
--  units, and every index in this crate is one; UTF16_Length converts a
--  string's length.
package CoreText is

   Error : exception;
   --  A CoreText or CoreGraphics call failed.

   function UTF16_Length (Text : String) return Natural;
   --  How many UTF-16 code units the UTF-8 Text takes.

end CoreText;
