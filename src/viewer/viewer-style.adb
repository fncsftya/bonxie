package body Viewer.Style is

   package Themes renames Pomarine.Themes;

   Source_Blue_Light : constant Themes.Color := (16#45#, 16#70#, 16#B8#, 255);
   Source_Blue_Dark  : constant Themes.Color := (16#5B#, 16#8D#, 16#F0#, 255);

   Other_Sources : constant array (2 .. Source_Count) of Themes.Color :=
     [(16#3D#, 16#7A#, 16#4C#, 255),   --  green
      (16#B4#, 16#48#, 16#3F#, 255),   --  red
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

   function Section_Ink (Colour : Projects.Sections.Colour_Value) return Themes.Slot is
      subtype Byte is SDL3.Windows.Renderers.Color_Component;
      RGB : constant Natural := (if Colour >= Projects.Sections.Palette_Size
                                 then Colour - Projects.Sections.Palette_Size else 0);
   begin
      if Colour < Projects.Sections.Palette_Size then
         return Section_Inks (Colour);
      end if;
      return Themes.Fixed ((Byte (RGB / 65536), Byte ((RGB / 256) mod 256), Byte (RGB mod 256), 255));
   end Section_Ink;

   type Tints is (Own, Painted);

   function Slotted
     (Base : Themes.Theme; Dark : Boolean; Tint : Tints; Hue : Adaptive_Themes.Hues;
      Strength : Adaptive_Themes.Strengths) return Themes.Theme;
   --  Base, with the slots of the application set from it; its greys, with Painted, in Hue.

   function Make (Dark : Boolean) return Themes.Theme is
     (Slotted ((if Dark then Themes.Dark else Themes.Light), Dark, Own, 0.0, 0.0));

   function Make
     (Dark : Boolean; Hue : Adaptive_Themes.Hues; Strength : Adaptive_Themes.Strengths := 1.0)
      return Themes.Theme is
     (Slotted (Themes.Make (Adaptive_Themes.Palette_For (Dark, Hue, Strength)), Dark, Painted, Hue, Strength));

   function Slotted
     (Base : Themes.Theme; Dark : Boolean; Tint : Tints; Hue : Adaptive_Themes.Hues;
      Strength : Adaptive_Themes.Strengths) return Themes.Theme
   is
      function Grey (Value : Themes.Color) return Themes.Color is
        (if Tint = Painted then Adaptive_Themes.Grey (Value, Dark, Hue, Strength) else Value);

      Back : constant Themes.Color := Base (Themes.Background);
   begin
      return Result : Themes.Theme := Base do
         Themes.Set_Custom
           (Result, 0, Grey (if Dark then (16#24#, 16#2B#, 16#28#, 255) else (16#C9#, 16#D1#, 16#CC#, 255)));
         Themes.Set_Custom
           (Result, 1, Grey (if Dark then Base (Themes.Bar) else (16#C9#, 16#D1#, 16#CC#, 255)));
         Themes.Set_Custom
           (Result, 2, Grey (if Dark then (16#38#, 16#44#, 16#40#, 255) else (16#B7#, 16#BF#, 16#BA#, 255)));
         Themes.Set_Custom (Result, 3, Themes.Mix (Base (Themes.Foreground), Back, 0.55));
         Themes.Set_Custom
           (Result, 4, Themes.Mix (Base (Themes.Primary), Base (Themes.Foreground), 0.25));
         if Tint = Painted then
            --  Some of what is drawn is on the painting itself, not on a panel: a count, a hint, the
            --  dashed edge of the card to add a project. The painting is neither the panel's colour
            --  nor even, so these keep close to the text's colour, which reads on all of it.
            Result.Slots (Themes.Muted) := Themes.Mix (Base (Themes.Foreground), Back, 0.08);
            Result.Slots (Themes.Hint)  := Themes.Mix (Base (Themes.Foreground), Back, 0.12);
            Result.Slots (Themes.Border) := Themes.Mix (Base (Themes.Border), Base (Themes.Foreground), 0.65);
            Themes.Set_Custom (Result, 3, Themes.Mix (Base (Themes.Foreground), Back, 0.2));
            Themes.Set_Custom
              (Result, 4, Themes.Mix (Base (Themes.Primary), Base (Themes.Foreground), 0.6));
         end if;
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
   end Slotted;

   Active : Themes.Theme := Make (Dark => False);
   Dark_In_Use : Boolean := False;
   Adaptive_In_Use : Boolean := False;
   --  The theme of the window shown.

   function Is_Dark return Boolean is (Dark_In_Use);

   function Is_Adaptive return Boolean is (Adaptive_In_Use);

   function Colors return Themes.Theme is (Active);

   procedure Use_Dark (Dark : Boolean) is
   begin
      Active := Make (Dark);
      Dark_In_Use := Dark;
      Adaptive_In_Use := False;
   end Use_Dark;

   procedure Use_Adaptive
     (Dark : Boolean; Hue : Adaptive_Themes.Hues; Strength : Adaptive_Themes.Strengths := 1.0) is
   begin
      Active := Make (Dark, Hue, Strength);
      Dark_In_Use := Dark;
      Adaptive_In_Use := True;
   end Use_Adaptive;

end Viewer.Style;
