with Pomarine.Themes;
with Ada.Finalization;
with System;
with Pomarine.Widgets.Panels;
with Pomarine.Widgets.Canvases;
with SDL3.Painters;
with SDL3.Windows.Renderers.Textures;

package Backgrounds is

   type Cache is new Ada.Finalization.Limited_Controlled with private;

   subtype Seed_Numbers is Natural range 0 .. 16#FF_FFFF#;
   --  Which painting: the shader is given this over 65536, so that it is kept and read back exactly,
   --  and is the same picture on every run.

   function New_Seed return Seed_Numbers;
   --  One from the clock: the only entropy there is.

   procedure Set_Shader (Item : in out Cache; File_Name : String; Seed : Seed_Numbers)
     with Pre => File_Name'Length > 0;
   --  Compile the shader, to paint the picture of Seed.

   function Seed_Number (Item : Cache) return Seed_Numbers;

   procedure Reseed (Item : in out Cache)
     with Post => Seed_Number (Item) /= Seed_Number (Item)'Old;
   --  Paint another picture, at its next drawing.

   function Available (Item : Cache) return Boolean;
   --  Whether there is a painting to show: the shader compiled and has not failed since.

   function Hue (Item : Cache) return Float
     with Post => Hue'Result in 0.0 .. 1.0;
   --  The base hue the painting is made in, as a turn of the colour wheel, which the
   --  application's colours follow. It is the same whether the painting is light or dark, and
   --  whether or not there is a painting to show.

   type Panel is new Pomarine.Widgets.Panels.Panel with record
      Painting : access Cache;
      Dark : Boolean := False;
   end record;

   overriding procedure Draw
     (Item   : in out Panel;
      Target : SDL3.Painters.Painter'Class;
      Colors : Pomarine.Themes.Theme);

   type Canvas is new Pomarine.Widgets.Canvases.Canvas with record
      Transparent : Boolean := False;
   end record;

   type Sample is new Pomarine.Widgets.Widget with record
      Painting : access Cache;
      --  The picture to show, small; none to show the theme's own background.
      Dark : Boolean := False;
      Look : Pomarine.Themes.Theme := Pomarine.Themes.Light;
      --  The colours of the few boxes drawn over it, as a window's would be.
   end record;
   --  A small picture of a window: the background, and a sidebar, two cards and a button on it.

   overriding procedure Draw
     (Item   : in out Sample;
      Target : SDL3.Painters.Painter'Class;
      Colors : Pomarine.Themes.Theme);

   procedure Set_Look
     (Item : in out Sample; Dark : Boolean; Look : Pomarine.Themes.Theme);
   --  Show it for the light or dark painting, with these colours.

   overriding procedure Draw
     (Item   : in out Canvas;
      Target : SDL3.Painters.Painter'Class;
      Colors : Pomarine.Themes.Theme);

private

   type Layer is limited record
      Image : SDL3.Windows.Renderers.Textures.Texture;
      Wide, High : Natural := 0;
      Dark_Drawn : Boolean := False;
      Seed_Drawn : Seed_Numbers := 0;
      --  What the pixels in Image are of: how big, light or dark, and which picture.
   end record;

   type Cache is new Ada.Finalization.Limited_Controlled with record
      Native : System.Address := System.Null_Address;
      Seed : Seed_Numbers := 0;
      Failed : Boolean := False;
      Main : Layer;
      --  The window's background.
      Thumb : Layer;
      --  The small picture in the settings.
   end record;

   overriding procedure Finalize (Item : in out Cache);

end Backgrounds;
