package Publish_VM.Disk is
   type File_Store is limited new Store with null record;
   overriding
   procedure Save (Self : in out File_Store; Path, Words : String);
end Publish_VM.Disk;
