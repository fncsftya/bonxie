with Interfaces;

package body Painting_Colours is
   procedure Sample (Picture : SDL3.Pictures.Decoded; Hue, Strength : out Float) is
      type Bytes is array (Natural) of Interfaces.Unsigned_8;
      Pixels                   : Bytes
      with Import, Address => SDL3.Pictures.Pixels (Picture);
      Wide                     : constant Positive := SDL3.Pictures.Width (Picture);
      High                     : constant Positive := SDL3.Pictures.Height (Picture);
      Pitch                    : constant Positive := SDL3.Pictures.Pitch (Picture);
      Step_X                   : constant Positive := Positive'Max (1, Wide / 64);
      Step_Y                   : constant Positive := Positive'Max (1, High / 64);
      Red, Green, Blue, Weight : Float := 0.0;
   begin
      for Y in 0 .. (High - 1) / Step_Y loop
         for X in 0 .. (Wide - 1) / Step_X loop
            declare
               Offset : constant Natural := Y * Step_Y * Pitch + 4 * X * Step_X;
               Alpha  : constant Float := Float (Pixels (Offset + 3)) / 255.0;
            begin
               Red := @ + Float (Pixels (Offset)) * Alpha;
               Green := @ + Float (Pixels (Offset + 1)) * Alpha;
               Blue := @ + Float (Pixels (Offset + 2)) * Alpha;
               Weight := @ + Alpha;
            end;
         end loop;
      end loop;
      Hue := 0.0;
      Strength := 0.0;
      if Weight = 0.0 then
         return;
      end if;
      Red := @ / (Weight * 255.0);
      Green := @ / (Weight * 255.0);
      Blue := @ / (Weight * 255.0);
      declare
         Highest : constant Float := Float'Max (Red, Float'Max (Green, Blue));
         Lowest  : constant Float := Float'Min (Red, Float'Min (Green, Blue));
         Chroma  : constant Float := Highest - Lowest;
         Sector  : Float;
      begin
         if Chroma < 0.01 or else Highest = 0.0 then
            return;
         end if;
         Strength := Float'Min (1.0, Chroma / Highest * 1.5);
         if Highest = Red then
            Sector := (Green - Blue) / Chroma;
         elsif Highest = Green then
            Sector := 2.0 + (Blue - Red) / Chroma;
         else
            Sector := 4.0 + (Red - Green) / Chroma;
         end if;
         if Sector < 0.0 then
            Sector := @ + 6.0;
         end if;
         Hue := Float'Min (1.0, Float'Max (0.0, Sector / 6.0));
      end;
   end Sample;
end Painting_Colours;
