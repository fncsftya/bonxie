with Ada.Strings.Unbounded;

package Sidebar_VM.Disk is
   type File_Store is limited new Store with private;
   procedure Open (Self : in out File_Store; Config : String);
   overriding function Load (Self : File_Store) return Open_Sections;
   overriding procedure Save (Self : in out File_Store; Value : Open_Sections);
private
   type File_Store is limited new Store with record
      Config : Ada.Strings.Unbounded.Unbounded_String;
   end record;
end Sidebar_VM.Disk;
