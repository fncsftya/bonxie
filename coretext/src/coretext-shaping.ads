with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Vectors;
with Ada.Finalization;
with Ada.Strings.Hash;
with Interfaces;
with System;
with CoreText.Fonts;
with CoreText.Strings;

package CoreText.Shaping is

   type Registry is limited private;
   --  The fonts glyphs have been shaped in. A line is set in one font,
   --  but CoreText substitutes others for what it lacks, such as emoji
   --  and other scripts; the registry numbers each font it meets so that
   --  a glyph can name its own. Keep a registry as long as any glyph
   --  shaped with it.

   type Font_Id is new Positive;

   type Glyph is record
      Id   : Interfaces.Unsigned_16;
      Font : Font_Id;
      X    : Float;  --  of the glyph's origin from the line's start
   end record;

   package Glyph_Vectors is new Ada.Containers.Vectors (Positive, Glyph);

   type Shaped is record
      Glyphs : Glyph_Vectors.Vector;
      Width  : Float := 0.0;
   end record;
   --  One line of text as glyphs on a baseline, in the units of the
   --  font it was set in.

   procedure Shape
     (Reg    : in out Registry;
      Using  : Fonts.Font;
      Text   : Strings.Text;
      First, Stop : Natural;
      Result : out Shaped)
     with Pre => Fonts.Is_Open (Using) and then Strings.Is_Set (Text)
                 and then First <= Stop and then Stop <= Strings.Length (Text);
   --  Set the UTF-16 range [First, Stop) of Text, a line without
   --  newlines, in Using, replacing Result.

   function Is_Color (Reg : Registry; Item : Font_Id) return Boolean;
   --  Whether Item draws its own colours (emoji), which tinting would
   --  spoil.

   function Font_Count (Reg : Registry) return Natural;

private

   type Font_Entry is record
      Handle : System.Address;  --  a CTFont, at size 1
      Color  : Boolean;
   end record;

   package Entry_Vectors is new Ada.Containers.Vectors (Font_Id, Font_Entry);

   package Name_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (String, Font_Id, Ada.Strings.Hash, "=");

   type Registry is new Ada.Finalization.Limited_Controlled with record
      Fonts : Entry_Vectors.Vector;
      Names : Name_Maps.Map;
   end record;

   overriding procedure Finalize (Item : in out Registry);

end CoreText.Shaping;
