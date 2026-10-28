with Ada.Strings.Unbounded;
with Growing;

--  Which sites the browser may open, if the person says so: nothing is held back (Off), or the pages of the
--  sites in one list are (Use_Blocked), or all but the pages of the sites in the other are (Use_Allowed). Each
--  site is kept as its base address (`https://example.com`); a page is of a site if its host is the site's, or
--  a subdomain of it. The choice and both lists are kept in a file beside the projects (`<config>/site-filter`,
--  a line to each: `mode`, `blocked` or `allowed`, a tab, then the mode or the address). As many sites as are
--  entered.

package Site_Filters is

   type Modes is (Off, Use_Blocked, Use_Allowed);

   subtype Listed_Modes is Modes range Use_Blocked .. Use_Allowed;
   --  The ones that have a list of sites.

   package Lists is new Growing (Ada.Strings.Unbounded.Unbounded_String);

   type Rules is record
      Mode    : Modes := Off;
      Blocked : Lists.List;
      Allowed : Lists.List;
   end record;

   function Host_Of (Address : String) return String;
   --  The host of an address, in lower case; empty if it has none.

   function Base_Of (Text : String) return String
   with Post => Base_Of'Result = "" or else Host_Of (Base_Of'Result) /= "";
   --  The base address of what was typed: its scheme (https if none) and host, and its port, without the
   --  path, query, fragment or login, in lower case ("Google.com/search?q=a" is "https://google.com"). Empty if
   --  there is no host in it, or it is not one.

   function Is_Listed (From : Lists.List; Address : String) return Boolean;
   --  Whether the address's host is one of the sites', or a subdomain of one.

   function Permits (Using : Rules; Address : String) return Boolean;
   --  Whether a page at Address may be opened. Only web addresses (http and https) are held back.

   function List_Of (Using : Rules; Mode : Listed_Modes) return Lists.List
   is (case Mode is
         when Use_Blocked => Using.Blocked,
         when Use_Allowed => Using.Allowed);

   function Index_Of (From : Lists.List; Base : String) return Natural
   with Post => Index_Of'Result <= From.Count;
   --  Where the site of that base address is, 0 if it is not there.

   function Hosts_Of (Using : Rules) return String;
   --  The hosts of the list that is in use, one to a line, for what is to hold pages back; empty if none is
   --  (Off), or the list has none (in Use_Allowed, then, every page is held back).

   function File_Name (Config : String) return String
   is (Config & "/site-filter");

   procedure Load (Config : String; Into : in out Rules);
   --  Replace Into by what is kept: Off and no sites if nothing is kept or it cannot be read.

   procedure Save (Config : String; From : Rules);
   --  Keep these, making Config if need be. Not kept, without saying, if it cannot be.

end Site_Filters;
