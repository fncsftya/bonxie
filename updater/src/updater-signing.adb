with Interfaces.C;
with System;

package body Updater.Signing is

   use type Interfaces.C.int;

   function Native_Verify
     (Key       : Interfaces.C.char_array;
      Message   : System.Address;
      Length    : Interfaces.C.size_t;
      Signature : Interfaces.C.char_array) return Interfaces.C.int
   with Import, Convention => C, External_Name => "upd_verify_ed25519";

   function Native_SHA_256 (Path : Interfaces.C.char_array; Hex : System.Address) return Interfaces.C.int
   with Import, Convention => C, External_Name => "upd_sha256_file";

   function Verify (Public_Key, Message, Signature : String) return Boolean is
      Empty : aliased constant String := "";
      Bytes : constant System.Address :=
        (if Message'Length = 0 then Empty'Address else Message (Message'First)'Address);
   begin
      return
        Native_Verify
          (Interfaces.C.To_C (Public_Key), Bytes, Interfaces.C.size_t (Message'Length), Interfaces.C.To_C (Signature))
        = 1;
   end Verify;

   function SHA_256 (File_Name : String) return String is
      Hex : aliased Interfaces.C.char_array (0 .. 64);
   begin
      if Native_SHA_256 (Interfaces.C.To_C (File_Name), Hex'Address) /= 1 then
         return "";
      end if;
      return Interfaces.C.To_Ada (Hex);
   end SHA_256;

end Updater.Signing;
