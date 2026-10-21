with Pomarine.Themes;
with SDL3.Windows.Renderers;

--  Colours that go with a painted background: the library's light or dark
--  palette, its neutral greys moved to the painting's hue.
--
--  Only the hue of a colour changes, never how bright it looks (its relative
--  luminance), so the contrasts the library's themes were made with, of text
--  on a surface and of a surface on its neighbour, hold for every hue. What
--  means something in itself (the primary action's green, the danger's red,
--  the accent, the focus ring, the model's purple, the highlighter) stays.
package Adaptive_Themes is

   use type SDL3.Windows.Renderers.Color_Component;

   subtype Hues is Float range 0.0 .. 1.0;
   --  A turn of the colour wheel: 0.0 is red, 1.0 is red again.

   function Luminance (Value : Pomarine.Themes.Color) return Float
     with Post => Luminance'Result in 0.0 .. 1.0;
   --  How bright it looks, as the relative luminance of sRGB: 0.0 for black, 1.0 for white.

   function Palette_For (Dark : Boolean; Hue : Hues) return Pomarine.Themes.Palette
     with Post => Palette_For'Result.Dark = Dark;
   --  The light palette, or the dark, with its greys in Hue.

   function Grey (Value : Pomarine.Themes.Color; Dark : Boolean; Hue : Hues) return Pomarine.Themes.Color;
   --  One of the greys the application makes for itself, in Hue as the palette's are (see Palette_For).

   function Retint
     (Value      : Pomarine.Themes.Color;
      Hue        : Hues;
      Saturation : Float) return Pomarine.Themes.Color
     with Pre  => Saturation in 0.0 .. 1.0,
          Post => Retint'Result.Alpha = Value.Alpha
                  and then abs (Luminance (Retint'Result) - Luminance (Value)) < 0.01;
   --  Value in Hue, as saturated as Saturation says (of what the colour's lightness allows),
   --  and as bright as it was.

   function Contrast (A, B : Pomarine.Themes.Color) return Float
     with Post => Contrast'Result >= 1.0;
   --  The ratio of the two colours' luminances, each a little raised (WCAG): 1.0 for the same,
   --  21.0 for black and white. 4.5 is enough to read text.

end Adaptive_Themes;
