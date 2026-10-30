with Pomarine.Boxes;
with Pomarine.Themes;
with Ada.Finalization;
with Ada.Strings.Unbounded;
with System;
with Pomarine.Widgets.Panels;
with Pomarine.Widgets.Canvases;
with SDL3.Painters;
with SDL3.Windows.Renderers.Textures;

package Backgrounds is

   type Cache is new Ada.Finalization.Limited_Controlled with private;

   type Styles is (Watercolour, Paper, Ink_Wash, Mist, Grain, Marbling, Risograph, Contours, Bauhaus);
   --  The pictures that can be painted, in the order of the shader's kernels.

   type Moods is (Pastel, Vivid, Rich, Muted);
   --  How bold a seed's colours are, whatever the style: soft, saturated and bright, deep and saturated,
   --  or half saturated. Light or dark, they are held in the band that keeps ink readable on them.

   function Tint_Strength (Style : Styles; Boldness : Moods := Pastel) return Float
   with Post => Tint_Strength'Result in 0.0 .. 1.0;
   --  How much of the picture's hue the application's greys take on: a lot for the colourful, less
   --  for the ones that are nearly grey, more for bold colours and less for muted.

   subtype Seed_Numbers is Natural range 0 .. 16#FF_FFFF#;
   --  Which painting: the shader is given this over 65536, so that it is kept and read back exactly,
   --  and is the same picture on every run.

   function New_Seed return Seed_Numbers;
   --  One from the clock: the only entropy there is.

   procedure Set_Shader (Item : in out Cache; File_Name : String; Seed : Seed_Numbers)
   with Pre => File_Name'Length > 0;
   --  Compile the shader, to paint the picture of Seed.

   function Seed_Number (Item : Cache) return Seed_Numbers;

   function Mood (Item : Cache) return Moods;
   --  How bold the pictures of the seed are.

   procedure Reseed (Item : in out Cache)
   with Post => Seed_Number (Item) /= Seed_Number (Item)'Old;
   --  Paint another picture, at its next drawing.

   procedure Set_Gallery (Item : in out Cache; File_Name : String);

   function Available (Item : Cache; Style : Styles) return Boolean;
   --  Whether there is a painting of Style to show: the shader compiled and has not failed since.

   function Hue (Item : Cache; Style : Styles) return Float
   with Post => Hue'Result in 0.0 .. 1.0;
   --  The base hue the painting is made in, as a turn of the colour wheel, which the
   --  application's colours follow. It is the same whether the painting is light or dark, and
   --  whether or not there is a painting to show.

   type Panel is new Pomarine.Widgets.Panels.Panel with record
      Painting : access Cache;
      Style    : Styles := Watercolour;
      Dark     : Boolean := False;
      Gallery  : Boolean := False;
   end record;

   overriding
   procedure Draw (Item : in out Panel; Target : SDL3.Painters.Painter'Class; Colors : Pomarine.Themes.Theme);

   type Canvas is new Pomarine.Widgets.Canvases.Canvas with record
      Transparent : Boolean := False;
   end record;

   type Sample is new Pomarine.Widgets.Widget with record
      Painting : access Cache;
      Style    : Styles := Watercolour;
      --  The picture to show, small; none to show the theme's own background.
      Dark     : Boolean := False;
      Gallery  : Boolean := False;
      Look     : Pomarine.Themes.Theme := Pomarine.Themes.Light;
      Radius   : Float := 0.0;
      Round    : Pomarine.Boxes.Corner_Flags := Pomarine.Boxes.Top_Corners;
      --  How round its top corners are, in points: as those of the box it is in, or its square corner would
      --  show beyond the box's outline.
      --  The colours of the few boxes drawn over it, as a window's would be.
   end record;
   --  A small picture of a window: the background, and a sidebar, two cards and a button on it.

   overriding
   procedure Draw (Item : in out Sample; Target : SDL3.Painters.Painter'Class; Colors : Pomarine.Themes.Theme);

   procedure Set_Look (Item : in out Sample; Dark : Boolean; Look : Pomarine.Themes.Theme);
   --  Show it for the light or dark painting, with these colours.

   overriding
   procedure Draw (Item : in out Canvas; Target : SDL3.Painters.Painter'Class; Colors : Pomarine.Themes.Theme);

private

   type Layer is limited record
      Image       : SDL3.Windows.Renderers.Textures.Texture;
      Wide, High  : Natural := 0;
      Dark_Drawn  : Boolean := False;
      Seed_Drawn  : Seed_Numbers := 0;
      Style_Drawn : Styles := Watercolour;
      --  What the pixels in Image are of: how big, light or dark, and which picture.
   end record;

   type Style_Flags is array (Styles) of Boolean;
   type Layer_Array is array (Styles) of Layer;

   type Cache is new Ada.Finalization.Limited_Controlled with record
      Native        : System.Address := System.Null_Address;
      Seed          : Seed_Numbers := 0;
      Failed        : Boolean := False;
      --  The shader would not compile.
      Broken        : Style_Flags := [others => False];
      --  Which of the pictures would not paint.
      Main          : Layer;
      --  The window's background.
      Thumbs        : Layer_Array;
      Gallery_File  : Ada.Strings.Unbounded.Unbounded_String;
      Gallery_Image : SDL3.Windows.Renderers.Textures.Texture;
      --  The small pictures in the settings.
   end record;

   overriding
   procedure Finalize (Item : in out Cache);

end Backgrounds;
