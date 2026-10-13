with Ada.Finalization;
with System;
private with SDL3.Thin;

--  PNG files in memory, apart from any renderer: so that they can be read
--  on a thread of their own, and turned into a texture (see
--  SDL3.Windows.Renderers.Textures.Create_From_Decoded) on the one that
--  draws.
package SDL3.Pictures is

   procedure Size (File_Name : String; Wide, High : out Natural);
   --  How big the PNG file's picture is, in pixels, from its header alone,
   --  without reading the rest; 0 and 0 if it is not a PNG, or cannot be
   --  read.

   type Decoded is limited private;
   --  A picture's pixels, eight bits a channel, as R, G, B, A bytes.

   procedure Decode
     (Item : in out Decoded; File_Name : String; Dark : out Boolean)
     with Post => not Is_Empty (Item);
   --  Replace Item with the PNG file, whole. Dark is whether it is darker
   --  than not, by a sample of its pixels. Raises an error if the file
   --  cannot be read. It may be called from any thread, for Items of
   --  their own.

   function Is_Empty (Item : Decoded) return Boolean;

   function Width (Item : Decoded) return Positive
     with Pre => not Is_Empty (Item);
   function Height (Item : Decoded) return Positive
     with Pre => not Is_Empty (Item);

   function Pixels (Item : Decoded) return System.Address
     with Pre => not Is_Empty (Item);
   function Pitch (Item : Decoded) return Positive
     with Pre => not Is_Empty (Item);
   --  Where the rows are, and how many bytes from one to the next.

   procedure Release (Item : in out Decoded)
     with Post => Is_Empty (Item);

private

   type Decoded is new Ada.Finalization.Limited_Controlled with record
      Surface : Thin.Surface_Access;  --  RGBA32
   end record;

   overriding procedure Finalize (Item : in out Decoded);

end SDL3.Pictures;
