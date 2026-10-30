with Ada.Strings.Unbounded;

--  The gallery's catalogue and one cached picture. A replacement is decoded
--  before it is atomically installed; a failed transfer leaves the old one.

package Gallery_Pictures is
   type States is (Idle, Running, Done, Failed);
   type Source is limited private;

   function State (Item : Source) return States;
   procedure Open
     (Item : in out Source; Catalogue, Directory : String; Image_Base : String := "https://api.nga.gov/iiif/");
   procedure Start (Item : in out Source)
   with Pre => State (Item) /= Running;
   procedure Poll (Item : in out Source);
   function Fraction (Item : Source) return Float;
   function Message (Item : Source) return String;
   function File_Name (Item : Source) return String;
   function Present (Item : Source) return Boolean;
   function Version (Item : Source) return Natural;
   function Hue (Item : Source) return Float;
   function Strength (Item : Source) return Float;

private
   type Source is limited record
      Catalogue       : Ada.Strings.Unbounded.Unbounded_String;
      Directory       : Ada.Strings.Unbounded.Unbounded_String;
      Image_Base      : Ada.Strings.Unbounded.Unbounded_String;
      Reason          : Ada.Strings.Unbounded.Unbounded_String;
      Last            : Ada.Strings.Unbounded.Unbounded_String;
      Current         : States := Idle;
      Serial          : Natural := 0;
      Colour_Hue      : Float := 0.0;
      Colour_Strength : Float := 0.0;
   end record;
end Gallery_Pictures;
