--  Versions as the project writes them: `0.2.0`, `0.1.0-alpha`, with a `v` before them in a tag. They are
--  ordered as semantic versioning orders them: by major, minor and patch, and a prerelease (`-alpha`) before the
--  version it leads up to. Build metadata (`+...`) is ignored.

package Updater.Versions is

   type Version is private;

   Max_Prerelease : constant := 40;

   function Parse (Text : String; Item : out Version) return Boolean;
   --  Whether Text is a version (a leading `v` is allowed); Item is it if so. A part of more than nine digits, or
   --  a prerelease of more than Max_Prerelease characters, is not one.

   function Image (Item : Version) return String;
   --  `0.2.0` or `0.1.0-alpha`: no `v`, no metadata.

   function Is_Prerelease (Item : Version) return Boolean;

   function Compare (Left, Right : Version) return Integer
   with Post => Compare'Result in -1 | 0 | 1;
   --  -1 if Left comes first, 1 if Right does, else 0.

   function Is_Newer (Candidate, Current : Version) return Boolean
   is (Compare (Candidate, Current) > 0);

private

   subtype Digits_Count is Natural range 0 .. 999_999_999;

   type Version is record
      Major, Minor, Patch : Digits_Count := 0;
      Pre_Length          : Natural range 0 .. Max_Prerelease := 0;
      Pre                 : String (1 .. Max_Prerelease) := [others => ' '];
   end record;

end Updater.Versions;
