with Interfaces.C.Strings;

package body Transcribe is

   function C_Version return Interfaces.C.Strings.chars_ptr
     with Import, Convention => C, External_Name => "transcribe_version";

   function Version return String is
     (Interfaces.C.Strings.Value (C_Version));

end Transcribe;
