with Ada.Numerics.Elementary_Functions;

package body Adaptive_Themes is

   package Themes renames Pomarine.Themes;
   use Ada.Numerics.Elementary_Functions;

   Light_Saturation : constant := 0.26;
   Dark_Saturation  : constant := 0.34;
   --  How much of its hue a grey has: enough to see against the painting, little enough to
   --  stay a neutral under text.

   function Linear (Component : SDL3.Windows.Renderers.Color_Component) return Float is
      Value : constant Float := Float (Component) / 255.0;
   begin
      return (if Value <= 0.04045 then Value / 12.92 else ((Value + 0.055) / 1.055)**2.4);
   end Linear;

   function Luminance (Value : Themes.Color) return Float
   is (Float'Min (1.0, 0.2126 * Linear (Value.Red) + 0.7152 * Linear (Value.Green) + 0.0722 * Linear (Value.Blue)));

   function Contrast (A, B : Themes.Color) return Float is
      Bright : constant Float := Float'Max (Luminance (A), Luminance (B));
      Dim    : constant Float := Float'Min (Luminance (A), Luminance (B));
   begin
      return (Bright + 0.05) / (Dim + 0.05);
   end Contrast;

   function From_Chroma
     (Hue : Hues; Chroma, Shift : Float; Alpha : SDL3.Windows.Renderers.Color_Component := 255) return Themes.Color
   is
      Sector  : constant Float := Hue * 6.0;
      Second  : constant Float := Chroma * (1.0 - abs (Sector - 2.0 * Float'Floor (Sector / 2.0) - 1.0));
      R, G, B : Float;

      function Byte (Value : Float) return SDL3.Windows.Renderers.Color_Component
      is (SDL3.Windows.Renderers.Color_Component
            (Float'Rounding (Float'Min (1.0, Float'Max (0.0, Value + Shift)) * 255.0)));
   begin
      case Integer (Float'Floor (Sector)) is
         when 0      =>
            R := Chroma;
            G := Second;
            B := 0.0;

         when 1      =>
            R := Second;
            G := Chroma;
            B := 0.0;

         when 2      =>
            R := 0.0;
            G := Chroma;
            B := Second;

         when 3      =>
            R := 0.0;
            G := Second;
            B := Chroma;

         when 4      =>
            R := Second;
            G := 0.0;
            B := Chroma;

         when others =>
            R := Chroma;
            G := 0.0;
            B := Second;
      end case;
      return (Byte (R), Byte (G), Byte (B), Alpha);
   end From_Chroma;

   function From_HSL
     (Hue, Saturation, Lightness : Float; Alpha : SDL3.Windows.Renderers.Color_Component := 255) return Themes.Color
   is
      Chroma : constant Float := (1.0 - abs (2.0 * Lightness - 1.0)) * Saturation;
   begin
      return From_Chroma (Hue, Chroma, Lightness - Chroma / 2.0, Alpha);
   end From_HSL;

   function Retint (Value : Themes.Color; Hue : Hues; Saturation : Float) return Themes.Color is
      Wanted : constant Float := Luminance (Value);
      Low    : Float := 0.0;
      High   : Float := 1.0;
   begin
      --  Luminance only rises with lightness, at a hue and saturation: find where it is Wanted.
      for Step in 1 .. 16 loop
         if Luminance (From_HSL (Hue, Saturation, (Low + High) / 2.0, Value.Alpha)) < Wanted then
            Low := (Low + High) / 2.0;
         else
            High := (Low + High) / 2.0;
         end if;
      end loop;
      return From_HSL (Hue, Saturation, (Low + High) / 2.0, Value.Alpha);
   end Retint;

   function Grey (Value : Themes.Color; Dark : Boolean; Hue : Hues; Strength : Strengths := 1.0) return Themes.Color
   is (Retint (Value, Hue, Strength * (if Dark then Dark_Saturation else Light_Saturation)));

   function Palette_For (Dark : Boolean; Hue : Hues; Strength : Strengths := 1.0) return Themes.Palette is
      function Tint (Value : Themes.Color) return Themes.Color
      is (Grey (Value, Dark, Hue, Strength));
   begin
      return Result : Themes.Palette := (if Dark then Themes.Dark_Palette else Themes.Light_Palette) do
         Result.Background := Tint (Result.Background);
         Result.Foreground := Tint (Result.Foreground);
         Result.Face := Tint (Result.Face);
         Result.Edge := Tint (Result.Edge);
         Result.Border := Tint (Result.Border);
         Result.Shadow := Tint (Result.Shadow);
         Result.Bar := Tint (Result.Bar);
         Result.Tint := Tint (Result.Tint);
         Result.Strip := Tint (Result.Strip);
         Result.Scrim := Tint (Result.Scrim);
         Result.Drop_Shadow := Tint (Result.Drop_Shadow);
         Result.Face_Hover := Tint (Result.Face_Hover);
         Result.Face_Pressed := Tint (Result.Face_Pressed);
         Result.Face_Light := Tint (Result.Face_Light);
         Result.Face_Shade := Tint (Result.Face_Shade);
         if Dark then
            --  The light theme's pages stay white, whatever is behind them.
            Result.Page := Tint (Result.Page);
         end if;
      end return;
   end Palette_For;

end Adaptive_Themes;
