with SDL3.Events;
with SDL3.Windows.Renderers.Textures;

--  A picture from a PNG file, as wide as the box, and as tall as that
--  makes it, of which the box shows a part: scrolled with the wheel (or a
--  trackpad's two fingers), and by Scroll_To. It is not read until it is
--  drawn, and is let go of again by Unload.
--
--  The picture is scaled to the box's width, so it zooms with the box,
--  and a scroll is kept as how far down the picture it is, not in pixels.
package UI.Widgets.Pictures is

   Path_Capacity : constant := 1024;

   Points_Per_Notch : constant Float := 48.0;
   --  How far a notch of the wheel scrolls.

   type Picture is new Widget with private;

   procedure Set_File (Item : in out Picture; Path : String)
     with Pre => Path'Length <= Path_Capacity;
   --  Show the PNG file, from its top. "" shows none. It is read at the
   --  next draw, even if it is the file that was shown, which may have
   --  changed.

   function File_Name (Item : Picture) return String;

   function Has_Picture (Item : Picture) return Boolean;
   --  Whether it has been read, and can be drawn.

   function Has_Failed (Item : Picture) return Boolean;
   --  Whether the file was there to show but could not be read.

   procedure Unload (Item : in out Picture);
   --  Give back the picture's memory: it is read again when drawn.

   function Scrolled (Item : Picture) return Float;
   --  How far down the picture the top of the box is, from 0.0, its top,
   --  to 1.0, its bottom (as of the last draw).

   procedure Scroll_To (Item : in out Picture; To : Float)
     with Pre => To in 0.0 .. 1.0;

   overriding procedure Draw
     (Item   : in out Picture;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme);

   overriding procedure Handle
     (Item    : in out Picture;
      Event   : SDL3.Events.Event;
      Handled : out Boolean);

private

   type Picture is new Widget with record
      Name    : String (1 .. Path_Capacity) := [others => ' '];
      Length  : Natural range 0 .. Path_Capacity := 0;
      Loaded  : Boolean := False;
      Failed  : Boolean := False;
      Pixels  : SDL3.Windows.Renderers.Textures.Texture;
      Down    : Float := 0.0;
      --  How far the picture is scrolled, as a fraction of its height.
      Fitted  : Float := 0.0;
      --  The picture's height as of the last draw, in pixels.
   end record;

end UI.Widgets.Pictures;
