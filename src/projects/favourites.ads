with Ada.Strings.Unbounded;
with Growing;

--  The pages a person has marked as favourites in the browser: not of any project, kept in a file beside the
--  projects (`<config>/favourites`, a line to each: the colour as six hex digits or `-`, the address and the title,
--  with a tab between). As many as are made.

package Favourites is

   type Favourite is record
      Title   : Ada.Strings.Unbounded.Unbounded_String;
      Address : Ada.Strings.Unbounded.Unbounded_String;
      Colour  : Integer := -1;
      --  The page's own colour as 16#RRGGBB#, or -1 if it gave none.
   end record;

   package Lists is new Growing (Favourite);

   function File_Name (Config : String) return String
   is (Config & "/favourites");

   procedure Load (Config : String; Into : in out Lists.List)
   with Post => Into.Count >= 0;
   --  Replace what Into holds by the favourites kept: none if there are none or they cannot be read.

   procedure Save (Config : String; From : Lists.List);
   --  Keep these, making Config if need be. Not kept, without saying, if it cannot be.

   function Index_Of (From : Lists.List; Address : String) return Natural
   with Post => Index_Of'Result <= From.Count;
   --  Where the favourite of that address is, 0 if there is none.

   function Colour_Of (Address : String) return Natural
   with Post => Colour_Of'Result <= 16#FFFFFF#;
   --  A colour for a page that gave none, the same for the same site: of its host's letters.

end Favourites;
