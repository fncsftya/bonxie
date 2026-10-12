with Ada.Strings.Unbounded;
with CoreText.Fonts;
with CoreText.Shaping;
with CoreText.Strings;
with SDL3.Windows.Renderers;
with Typeset.Glyph_Atlas;

--  Single lines of text, such as labels and buttons have, in the system's
--  user interface font, shared by the widgets of a window: they are
--  shaped, and drawn from a glyph atlas, as a document's text is.
--
--  Declare it after the renderer it draws to, and always draw it to that
--  renderer.
package UI.Line_Texts is

   System_UI : constant String := ".AppleSystemUIFont";
   --  CoreText's name for the font of the system's user interface.

   Bold_System_UI     : constant String := ".AppleSystemUIFontBold";
   Semibold_System_UI : constant String := ".AppleSystemUIFontDemi";

   type Style is (Regular, Strong, Heading);
   --  Regular is the size of the text of a window, in the regular weight;
   --  Strong is the same size, and heavier, as of buttons; Heading is
   --  larger, and heavier still.

   Regular_Size : constant := 13.0;
   Heading_Size : constant := 20.0;
   --  In points.

   function Size (Of_Style : Style) return Float is
     (case Of_Style is
         when Regular | Strong => Regular_Size,
         when Heading          => Heading_Size);

   type Drawer is limited private;

   procedure Begin_Frame (Item : in out Drawer);
   --  Call before drawing a frame, as Typeset.Glyph_Atlas.Begin_Frame.

   function Width
     (Item  : in out Drawer;
      Text  : String;
      Scale : Float;
      Using : Style := Regular) return Float
     with Pre => Scale > 0.0;
   --  Of Text in pixels, at Scale pixels to a point.

   procedure Draw
     (Item   : in out Drawer;
      Target : SDL3.Windows.Renderers.Renderer;
      Value  : SDL3.Windows.Renderers.Color;
      Text   : String;
      Left   : Float;
      Middle : Float;
      Scale  : Float;
      Using  : Style := Regular)
     with Pre => Scale > 0.0;
   --  Draw Text with its start Left pixels, and the middle of its height
   --  Middle pixels, from the top left of the target. It is drawn at
   --  once, so that what is drawn after is over it.

private

   type Face_Array is array (Style) of CoreText.Fonts.Font;

   Cache_Size : constant := 64;
   --  How many lines are kept shaped: more than a screen has.

   type Cached_Line is record
      Used  : Boolean := False;
      Using : Style := Regular;
      Text  : Ada.Strings.Unbounded.Unbounded_String;
      Line  : CoreText.Shaping.Shaped;
   end record;

   type Cache_Array is array (1 .. Cache_Size) of Cached_Line;

   type Drawer is limited record
      Reg    : CoreText.Shaping.Registry;
      Atlas  : Typeset.Glyph_Atlas.Atlas;
      Faces  : Face_Array;
      Source : CoreText.Strings.Text;
      Cache  : Cache_Array;
      Next   : Positive range 1 .. Cache_Size := 1;
      --  The line to replace when one is not there.
   end record;

end UI.Line_Texts;
