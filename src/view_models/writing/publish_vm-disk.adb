with Files;

package body Publish_VM.Disk is
   overriding
   procedure Save (Self : in out File_Store; Path, Words : String) is
      pragma Unreferenced (Self);
   begin
      Files.Write (Path, Words);
   end Save;
end Publish_VM.Disk;
