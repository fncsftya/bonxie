with Ada.Strings.Unbounded;
with SDL3.Windows.Renderers.Textures;
with SDL3.Windows.Renderers;

--  Icons, drawn from SVG files in a folder: the outline pictures buttons
--  show, drawn in one colour (the files' own colours are not used), at
--  the size they are wanted, made once each.
--
--  Declare a library after the renderer it draws to, and always draw it
--  to that renderer.
package UI.Icons is

   type Icon is
     (Edit, Delete, Window, Minimize, Restore, Close, List, Show, Hide, Link);
   --  The file of each is its name in lower case, with ".svg".

   File_Extension : constant String := ".svg";

   function File_Name (Which : Icon) return String;

   type Library is limited private;

   procedure Set_Directory (Item : in out Library; Path : String);
   --  Where the files are. Icons made already are forgotten.

   procedure Draw
     (Item   : in out Library;
      Target : SDL3.Windows.Renderers.Renderer;
      Which  : Icon;
      Value  : SDL3.Windows.Renderers.Color;
      Left, Top : Float;
      Size   : Positive;
      Drawn  : out Boolean);
   --  Draw it in colour Value, Size pixels square, with its top left at
   --  Left, Top. The file is read, and rasterized, the first time. Drawn
   --  says whether it was: not if there is no file, or it cannot be read
   --  (which is not tried again).

private

   type Made is record
      Image  : SDL3.Windows.Renderers.Textures.Texture;
      Size   : Natural := 0;     --  in pixels, of Image; 0 if none
      Failed : Natural := 0;     --  the size that could not be made
   end record;

   type Made_Array is array (Icon) of Made;

   type Library is limited record
      Folder : Ada.Strings.Unbounded.Unbounded_String;
      Icons  : Made_Array;
   end record;

end UI.Icons;
