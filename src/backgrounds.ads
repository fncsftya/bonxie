with Pomarine.Themes;
with Ada.Finalization;
with System;
with Pomarine.Widgets.Panels;
with Pomarine.Widgets.Canvases;
with SDL3.Painters;
with SDL3.Windows.Renderers.Textures;

package Backgrounds is

   type Cache is new Ada.Finalization.Limited_Controlled with private;
   procedure Set_Shader (Item : in out Cache; File_Name : String)
     with Pre => File_Name'Length > 0;

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

   overriding procedure Draw
     (Item   : in out Canvas;
      Target : SDL3.Painters.Painter'Class;
      Colors : Pomarine.Themes.Theme);

private

   type Cache is new Ada.Finalization.Limited_Controlled with record
      Image : SDL3.Windows.Renderers.Textures.Texture;
      Native : System.Address := System.Null_Address;
      Seed : Float := 0.0;
      Wide, High : Natural := 0;
      Failed : Boolean := False;
   end record;

   overriding procedure Finalize (Item : in out Cache);

end Backgrounds;
