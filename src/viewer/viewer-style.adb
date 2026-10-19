package body Viewer.Style is

   package Themes renames Pomarine.Themes;

   Source_Blue_Light : constant Themes.Color := (16#25#, 16#63#, 16#D4#, 255);
   Source_Blue_Dark  : constant Themes.Color := (16#5B#, 16#8D#, 16#F0#, 255);

   Other_Sources : constant array (2 .. Source_Count) of Themes.Color :=
     [(16#27#, 16#72#, 16#2D#, 255),   --  green
      (16#C6#, 16#28#, 16#28#, 255),   --  red
      (16#7A#, 16#4E#, 16#B8#, 255),   --  violet
      (16#0E#, 16#7C#, 16#7B#, 255),   --  teal
      (16#B4#, 16#5A#, 16#09#, 255),   --  rust
      (16#A2#, 16#3B#, 16#72#, 255),   --  plum
      (16#5B#, 16#6B#, 16#2F#, 255)];  --  olive

   function Pastel (Colour : Projects.Sections.Colour_Index; Dark : Boolean) return Themes.Color;
   --  The Colourth of the sections' colours: a hue round the wheel, the
   --  neighbours far apart, light and clear on the light theme, softer
   --  and deeper on the dark.

   function Pastel (Colour : Projects.Sections.Colour_Index; Dark : Boolean) return Themes.Color is
      Hue        : constant Float := Float ((Colour * 150) mod 360);
      Saturation : constant Float := (if Dark then 0.42 else 0.62);
      Lightness  : constant Float := (if Dark then 0.55 else 0.80);
      Chroma     : constant Float := (1.0 - abs (2.0 * Lightness - 1.0)) * Saturation;
      Sector     : constant Float := Hue / 60.0;
      Second     : constant Float := Chroma * (1.0 - abs (Float'Remainder (Sector, 2.0) - 1.0));
      Shift      : constant Float := Lightness - Chroma / 2.0;
      R, G, B    : Float;

      function Byte (Value : Float) return SDL3.Windows.Renderers.Color_Component is
        (SDL3.Windows.Renderers.Color_Component
           (Float'Rounding (Float'Min (1.0, Float'Max (0.0, Value + Shift)) * 255.0)));
   begin
      case Integer (Float'Floor (Sector)) is
         when 0      => R := Chroma; G := Second; B := 0.0;
         when 1      => R := Second; G := Chroma; B := 0.0;
         when 2      => R := 0.0;    G := Chroma; B := Second;
         when 3      => R := 0.0;    G := Second; B := Chroma;
         when 4      => R := Second; G := 0.0;    B := Chroma;
         when others => R := Chroma; G := 0.0;    B := Second;
      end case;
      return (Byte (R), Byte (G), Byte (B), 255);
   end Pastel;

   function Make (Dark : Boolean) return Themes.Theme is
      Base : constant Themes.Theme := (if Dark then Themes.Dark else Themes.Light);
      Back : constant Themes.Color := Base (Themes.Background);
   begin
      return Result : Themes.Theme := Base do
         Themes.Set_Custom (Result, 0, (if Dark then (16#24#, 16#2B#, 16#28#, 255) else (16#B8#, 16#C0#, 16#BB#, 255)));
         Themes.Set_Custom (Result, 1, (if Dark then Base (Themes.Bar) else (16#B8#, 16#C0#, 16#BB#, 255)));
         Themes.Set_Custom (Result, 2, (if Dark then (16#38#, 16#44#, 16#40#, 255) else Base (Themes.Border)));
         Themes.Set_Custom (Result, 3, Themes.Mix (Base (Themes.Foreground), Back, 0.55));
         Themes.Set_Custom
           (Result, 4, Themes.Mix (Base (Themes.Primary), Base (Themes.Foreground), 0.25));
         Themes.Set_Custom
           (Result, Section_First + Projects.Sections.Colour_Index'Last + 1,
            (if Dark then Themes.White else (0, 0, 0, 255)));
         Themes.Set_Custom (Result, Source_First, (if Dark then Source_Blue_Dark else Source_Blue_Light));
         for K in Other_Sources'Range loop
            Themes.Set_Custom (Result, Source_First + K - 1, Other_Sources (K));
         end loop;
         for K in Projects.Sections.Colour_Index loop
            Themes.Set_Custom (Result, Section_First + K, Pastel (K, Dark));
         end loop;
      end return;
   end Make;

   Active : Themes.Theme := Make (Dark => False);
   Dark_In_Use : Boolean := False;
   --  The theme of the window shown.

   function Is_Dark return Boolean is (Dark_In_Use);

   function Colors return Themes.Theme is (Active);

   procedure Use_Dark (Dark : Boolean) is
   begin
      Active := Make (Dark);
      Dark_In_Use := Dark;
   end Use_Dark;

end Viewer.Style;
