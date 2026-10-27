with Ada.Exceptions;
with Ada.Numerics.Elementary_Functions;
with Ada.Text_IO;
with Files;
with Interfaces.C;

package body Backgrounds is

   use type System.Address;
   use type SDL3.Painters.Device_Access;
   package Textures renames SDL3.Windows.Renderers.Textures;

   function Time_Seed return Interfaces.C.C_float
   with Import, Convention => C, External_Name => "bonxie_background_seed";

   function Hue_Of (Style : Interfaces.C.int; Seed : Interfaces.C.C_float) return Interfaces.C.C_float
   with Import, Convention => C, External_Name => "bonxie_background_hue";

   function Mood_Of (Seed : Interfaces.C.C_float) return Interfaces.C.int
   with Import, Convention => C, External_Name => "bonxie_background_mood";

   function Create (Source : Interfaces.C.char_array) return System.Address
   with Import, Convention => C, External_Name => "bonxie_background_create";

   function Render
     (Native        : System.Address;
      Style         : Interfaces.C.int;
      Seed          : Interfaces.C.C_float;
      Width, Height : Interfaces.C.int;
      Dark          : Interfaces.C.int) return System.Address
   with Import, Convention => C, External_Name => "bonxie_background_render";

   procedure Release (Native : System.Address)
   with Import, Convention => C, External_Name => "bonxie_background_release";

   Per_Unit : constant := 65536.0;

   function As_Float (Seed : Seed_Numbers) return Interfaces.C.C_float
   is (Interfaces.C.C_float (Float (Seed) / Per_Unit));

   function New_Seed return Seed_Numbers
   is (Seed_Numbers (Integer (Float'Rounding (Float (Time_Seed) * Per_Unit)) mod (Seed_Numbers'Last + 1)));

   function Style_Strength (Style : Styles) return Float;
   --  What the style's own colours would have the greys take, of a pastel.

   function Mood (Item : Cache) return Moods
   is (Moods'Val (Mood_Of (As_Float (Item.Seed))));

   function Tint_Strength (Style : Styles; Boldness : Moods := Pastel) return Float
   is (Float'Min
         (1.0,
          Style_Strength (Style)
          * (case Boldness is
               when Pastel => 1.0,
               when Vivid  => 1.3,
               when Rich   => 1.15,
               when Muted  => 0.6)));

   function Style_Strength (Style : Styles) return Float
   is (case Style is
         when Watercolour => 1.0,
         when Paper       => 0.60,
         when Ink_Wash    => 0.35,
         when Mist        => 0.70,
         when Grain       => 0.50,
         when Marbling    => 1.0,
         when Risograph   => 0.90,
         when Contours    => 0.55,
         when Bauhaus     => 0.45);

   function Available (Item : Cache; Style : Styles) return Boolean
   is (not Item.Failed and then Item.Native /= System.Null_Address and then not Item.Broken (Style));

   function Seed_Number (Item : Cache) return Seed_Numbers
   is (Item.Seed);

   function Hue (Item : Cache; Style : Styles) return Float
   is (Float (Hue_Of (Interfaces.C.int (Styles'Pos (Style)), As_Float (Item.Seed))));

   procedure Reseed (Item : in out Cache) is
      Was : constant Seed_Numbers := Item.Seed;
   begin
      while Item.Seed = Was loop
         Item.Seed := New_Seed;
      end loop;
   end Reseed;

   overriding
   procedure Finalize (Item : in out Cache) is
   begin
      Release (Item.Native);
      Item.Native := System.Null_Address;
   end Finalize;

   procedure Set_Shader (Item : in out Cache; File_Name : String; Seed : Seed_Numbers) is
   begin
      Finalize (Item);
      Textures.Release (Item.Main.Image);
      for Each of Item.Thumbs loop
         Textures.Release (Each.Image);
         Each.Wide := 0;
         Each.High := 0;
      end loop;
      Item.Broken := [others => False];
      Item.Native := Create (Interfaces.C.To_C (Files.Read (File_Name)));
      Item.Seed := Seed;
      Item.Main.Wide := 0;
      Item.Main.High := 0;
      Item.Failed := Item.Native = System.Null_Address;
   exception
      when Problem : others =>
         Item.Failed := True;
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error, "Backgrounds: " & Ada.Exceptions.Exception_Message (Problem));
   end Set_Shader;

   procedure Ensure
     (Saved      : in out Cache;
      Which      : in out Layer;
      Style      : Styles;
      Device     : SDL3.Painters.Device_Access;
      Wide, High : Positive;
      Dark       : Boolean;
      Ready      : out Boolean) is
   begin
      Ready := False;
      if not Available (Saved, Style) or else Device = null then
         return;
      end if;
      if Wide /= Which.Wide
        or else High /= Which.High
        or else Dark /= Which.Dark_Drawn
        or else Saved.Seed /= Which.Seed_Drawn
        or else Style /= Which.Style_Drawn
      then
         declare
            --  Metal owns the full-size staging buffer; no image-sized
            --  allocation on the Ada stack and no internal resolution cap.
            Pixels : constant System.Address :=
              Render
                (Saved.Native,
                 Interfaces.C.int (Styles'Pos (Style)),
                 As_Float (Saved.Seed),
                 Interfaces.C.int (Wide),
                 Interfaces.C.int (High),
                 (if Dark then 1 else 0));
         begin
            if Pixels = System.Null_Address then
               Saved.Broken (Style) := True;
               Ada.Text_IO.Put_Line
                 (Ada.Text_IO.Standard_Error, "Could not render the " & Styles'Image (Style) & " background");
               return;
            end if;
            Textures.Create_Blank (Which.Image, Device.all, Wide, High, Smooth => False);
            Textures.Update_Region (Which.Image, 0, 0, Wide, High, Pixels, 4 * Wide);
            Which.Wide := Wide;
            Which.High := High;
            Which.Dark_Drawn := Dark;
            Which.Seed_Drawn := Saved.Seed;
            Which.Style_Drawn := Style;
         end;
      end if;
      pragma Assert (not Textures.Is_Empty (Which.Image));
      Ready := True;
   end Ensure;

   overriding
   procedure Draw (Item : in out Panel; Target : SDL3.Painters.Painter'Class; Colors : Pomarine.Themes.Theme) is
      use Pomarine.Widgets;
      Wide, High : Natural;
      Ready      : Boolean;
   begin
      Pomarine.Widgets.Panels.Panel (Item).Draw (Target, Colors);
      if Item.Painting = null then
         return;
      end if;
      Target.Output_Size (Wide, High);
      if Wide = 0 or else High = 0 then
         return;
      end if;
      Ensure (Item.Painting.all, Item.Painting.Main, Item.Style, Target.Device, Wide, High, Item.Dark, Ready);
      if Ready then
         Target.Draw_Scaled
           (Item.Painting.Main.Image, Left_Of (Item), Top_Of (Item), Width_Of (Item), Height_Of (Item));
      end if;
   end Draw;

   procedure Set_Look (Item : in out Sample; Dark : Boolean; Look : Pomarine.Themes.Theme) is
   begin
      Item.Dark := Dark;
      Item.Look := Look;
      if Pomarine.Widgets.Is_Attached (Item) then
         Pomarine.Widgets.Invalidate (Item);
      end if;
   end Set_Look;

   --  An image over a box, its top corners (those in Round) cut by a circle of Radius pixels, a row at a time,
   --  as the painter has only rectangles to clip with.
   procedure Draw_Cut
     (Target                : SDL3.Painters.Painter'Class;
      Image                 : Textures.Texture;
      Left, Top, Wide, High : Float;
      Radius                : Float;
      Round                 : Pomarine.Boxes.Corner_Flags)
   is
      Saved : constant SDL3.Painters.Clip := Target.Current_Clip;
      Rows  : constant Natural := Natural (Radius);

      function Inset (Row : Natural) return Float is
         Across : constant Float := Radius - Float (Row) - 0.5;
      begin
         return Float'Ceiling (Radius - Ada.Numerics.Elementary_Functions.Sqrt (Radius * Radius - Across * Across));
      end Inset;
   begin
      if Rows = 0 or else (not Round.Top_Left and then not Round.Top_Right) then
         Target.Draw_Scaled (Image, Left, Top, Wide, High);
         return;
      end if;
      for Row in 0 .. Rows - 1 loop
         declare
            Cut_Left  : constant Float := (if Round.Top_Left then Inset (Row) else 0.0);
            Cut_Right : constant Float := (if Round.Top_Right then Inset (Row) else 0.0);
         begin
            Target.Narrow_Clip
              (Integer (Left + Cut_Left), Integer (Top) + Row, Integer (Wide - Cut_Left - Cut_Right), 1);
            Target.Draw_Scaled (Image, Left, Top, Wide, High);
            Target.Restore_Clip (Saved);
         end;
      end loop;
      Target.Narrow_Clip (Integer (Left), Integer (Top) + Rows, Integer (Wide), Integer (High) - Rows);
      Target.Draw_Scaled (Image, Left, Top, Wide, High);
      Target.Restore_Clip (Saved);
   end Draw_Cut;

   overriding
   procedure Draw (Item : in out Sample; Target : SDL3.Painters.Painter'Class; Colors : Pomarine.Themes.Theme) is
      pragma Unreferenced (Colors);
      use Pomarine.Widgets;
      use all type SDL3.Painters.Painter;
      package Themes renames Pomarine.Themes;
      Left  : constant Float := Left_Of (Item);
      Top   : constant Float := Top_Of (Item);
      Wide  : constant Float := Width_Of (Item);
      High  : constant Float := Height_Of (Item);
      Line  : constant Float := Float'Max (1.0, Float'Rounding (Density (Item)));
      Look  : Themes.Theme renames Item.Look;
      Ready : Boolean := False;

      --  A box at fractions of the sample's width and height, with an outline a point wide.
      procedure Box (Across, Down, By, Tall : Float; Fill, Edge : Themes.Color) is
         X : constant Float := Float'Rounding (Left + Across * Wide);
         Y : constant Float := Float'Rounding (Top + Down * High);
         W : constant Float := Float'Rounding (By * Wide);
         H : constant Float := Float'Rounding (Tall * High);
      begin
         Fill_Rect (Target, Edge, X, Y, W, H);
         Fill_Rect (Target, Fill, X + Line, Y + Line, W - 2.0 * Line, H - 2.0 * Line);
      end Box;

      procedure Text (Across, Down, By : Float) is
         Ink : constant Themes.Color := Themes.Mix (Look (Themes.Foreground), Look (Themes.Page), 0.55);
      begin
         Fill_Rect
           (Target,
            Ink,
            Float'Rounding (Left + Across * Wide),
            Float'Rounding (Top + Down * High),
            Float'Rounding (By * Wide),
            Line * 2.0);
      end Text;
   begin
      if Item.Painting /= null and then Wide >= 1.0 and then High >= 1.0 then
         Ensure
           (Item.Painting.all,
            Item.Painting.Thumbs (Item.Style),
            Item.Style,
            Target.Device,
            Positive (Float'Rounding (Wide)),
            Positive (Float'Rounding (High)),
            Item.Dark,
            Ready);
      end if;
      if Ready then
         Draw_Cut
           (Target,
            Item.Painting.Thumbs (Item.Style).Image,
            Left,
            Top,
            Wide,
            High,
            Pomarine.Boxes.Corner (Item.Radius, Density (Item)),
            Item.Round);
      else
         Pomarine.Boxes.Fill_Round
           (Target,
            Look (Themes.Background),
            Left,
            Top,
            Wide,
            High,
            Pomarine.Boxes.Corner (Item.Radius, Density (Item)),
            Item.Round);
      end if;
      Box (0.05, 0.10, 0.17, 0.80, Look (Themes.Tint), Look (Themes.Border));
      Box (0.075, 0.18, 0.12, 0.12, Look (Themes.Primary), Look (Themes.Primary));
      Text (0.075, 0.42, 0.12);
      Text (0.075, 0.50, 0.08);
      Box (0.28, 0.10, 0.30, 0.46, Look (Themes.Page), Look (Themes.Border));
      Text (0.30, 0.19, 0.10);
      Text (0.30, 0.31, 0.24);
      Text (0.30, 0.39, 0.20);
      Box (0.64, 0.10, 0.31, 0.46, Look (Themes.Page), Look (Themes.Border));
      Text (0.66, 0.19, 0.12);
      Text (0.66, 0.31, 0.25);
      Text (0.66, 0.39, 0.18);
      Box (0.28, 0.70, 0.17, 0.20, Look (Themes.Face), Look (Themes.Border));
   end Draw;

   overriding
   procedure Draw (Item : in out Canvas; Target : SDL3.Painters.Painter'Class; Colors : Pomarine.Themes.Theme) is
      Palette : Pomarine.Themes.Theme := Colors;
   begin
      if Item.Transparent then
         Palette.Slots (Pomarine.Themes.Background).Alpha := 0;
      end if;
      Pomarine.Widgets.Canvases.Canvas (Item).Draw (Target, Palette);
   end Draw;

end Backgrounds;
