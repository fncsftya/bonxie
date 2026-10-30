with Ada.Strings.Fixed;
with Interfaces.C;

package body Updater.Locations is

   use type Interfaces.C.int;

   function Executable_Path
     (Buffer : out Interfaces.C.char_array; Size : in out Interfaces.C.unsigned) return Interfaces.C.int
   with Import, Convention => C, External_Name => "_NSGetExecutablePath";

   function Real_Path (Path : Interfaces.C.char_array; Resolved : out Interfaces.C.char_array) return Interfaces.C.int
   with Import, Convention => C, External_Name => "realpath";
   --  (Declared to return int, as it is only compared with zero: a null pointer is zero.)

   function Access_Path (Path : Interfaces.C.char_array; Mode : Interfaces.C.int) return Interfaces.C.int
   with Import, Convention => C, External_Name => "access";

   function Signal_Process (Process, Signal : Interfaces.C.int) return Interfaces.C.int
   with Import, Convention => C, External_Name => "kill";

   function Own_Process return Interfaces.C.int
   with Import, Convention => C, External_Name => "getpid";

   Write_Access : constant := 2;
   Path_Limit   : constant := 4096;
   --  PATH_MAX is 1024 on macOS: this is more than enough.

   Suffix : constant String := ".app/Contents/MacOS/";

   function Bundle return String is
      Buffer   : Interfaces.C.char_array (0 .. Path_Limit);
      Resolved : Interfaces.C.char_array (0 .. Path_Limit);
      Size     : Interfaces.C.unsigned := Path_Limit;
   begin
      if Executable_Path (Buffer, Size) /= 0 then
         return "";
      end if;
      --  The path the program was started by may go through links and `..`.
      declare
         Started : constant String := Interfaces.C.To_Ada (Buffer);
      begin
         if Real_Path (Interfaces.C.To_C (Started), Resolved) = 0 then
            return "";
         end if;
      end;
      declare
         Path  : constant String := Interfaces.C.To_Ada (Resolved);
         Where : constant Natural := Ada.Strings.Fixed.Index (Path, Suffix, Going => Ada.Strings.Backward);
      begin
         return (if Where = 0 then "" else Path (Path'First .. Where + 3));
      end;
   exception
      when others =>
         return "";
   end Bundle;

   function Is_Writable (Path : String) return Boolean
   is (Access_Path (Interfaces.C.To_C (Path), Write_Access) = 0);

   function Placement (Bundle_Path : String) return Placements is
      Slash : constant Natural := Ada.Strings.Fixed.Index (Bundle_Path, "/", Going => Ada.Strings.Backward);
   begin
      if Bundle_Path = "" or else Slash = 0 then
         return Not_Bundled;
      elsif Ada.Strings.Fixed.Index (Bundle_Path, "/AppTranslocation/") /= 0
        or else (Bundle_Path'Length > 9 and then Bundle_Path (Bundle_Path'First .. Bundle_Path'First + 8) = "/Volumes/")
      then
         return Running_From_Image;
      elsif not Is_Writable (Bundle_Path (Bundle_Path'First .. Slash)) or else not Is_Writable (Bundle_Path) then
         return Read_Only;
      else
         return Replaceable;
      end if;
   end Placement;

   function Is_Running (Process : Natural) return Boolean
   is (Process > 0 and then Signal_Process (Interfaces.C.int (Process), 0) = 0);
   --  (Signal 0 only asks. A process that is another person's answers "not permitted", which is not zero: a
   --  helper started by this program is this person's.)

   function Process_Number return Natural
   is (Natural (Own_Process));

end Updater.Locations;
