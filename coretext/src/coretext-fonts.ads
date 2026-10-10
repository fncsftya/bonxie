with Ada.Containers.Indefinite_Vectors;
with Ada.Finalization;
with Ada.Strings.Unbounded;
with System;

package CoreText.Fonts is

   Default_Family : constant String := "Georgia";
   --  A serif face that ships with every macOS install.

   type Font is limited private;
   --  A font at a size, with its metrics. Closed when it goes out of
   --  scope.

   procedure Open (Item : in out Font; Family : String; At_Size : Float)
     with Pre => At_Size > 0.0, Post => Is_Open (Item);
   --  Open a font by PostScript or family name at At_Size pixels, closing
   --  Item first if it is open. CoreText substitutes a fallback for an
   --  unknown name; Family_Name reports the face actually chosen.

   procedure Close (Item : in out Font)
     with Post => not Is_Open (Item);

   function Is_Open (Item : Font) return Boolean;

   function Family_Name (Item : Font) return String
     with Pre => Is_Open (Item);
   function Size (Item : Font) return Float
     with Pre => Is_Open (Item);
   function Ascent (Item : Font) return Float
     with Pre => Is_Open (Item);
   function Descent (Item : Font) return Float
     with Pre => Is_Open (Item);
   function Leading (Item : Font) return Float
     with Pre => Is_Open (Item);

   function Line_Height (Item : Font) return Float
     with Pre => Is_Open (Item);
   --  Ascent + Descent + Leading.

   package Family_Vectors is new Ada.Containers.Indefinite_Vectors
     (Positive, String);

   function Families return Family_Vectors.Vector;
   --  The names of the font families installed, as Open takes them,
   --  alphabetically, ignoring case. Leaves out the system's hidden
   --  families, whose names start with a dot.

   function Attributes (Item : Font) return System.Address
     with Pre => Is_Open (Item);
   --  The CFDictionary of text attributes for CoreText.Lines and
   --  CoreText.Wrapping. Not for other use.

private

   type Font is new Ada.Finalization.Limited_Controlled with record
      Handle     : System.Address := System.Null_Address;
      Attrs      : System.Address := System.Null_Address;
      Pixels     : Float := 0.0;
      Up         : Float := 0.0;
      Down       : Float := 0.0;
      Gap        : Float := 0.0;
      Family     : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   overriding procedure Finalize (Item : in out Font);

end CoreText.Fonts;
