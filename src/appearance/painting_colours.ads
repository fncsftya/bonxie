with SDL3.Pictures;

--  A restrained tint derived from the visible pixels of a painting.

package Painting_Colours is
   procedure Sample (Picture : SDL3.Pictures.Decoded; Hue, Strength : out Float)
   with Pre => not SDL3.Pictures.Is_Empty (Picture), Post => Hue in 0.0 .. 1.0 and then Strength in 0.0 .. 1.0;
   --  Hue is a turn of the colour wheel. Neutral images give zero strength.
end Painting_Colours;
