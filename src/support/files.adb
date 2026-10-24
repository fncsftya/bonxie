with Ada.Streams.Stream_IO;
with GNAT.OS_Lib;

package body Files is

   function Read (File_Name : String) return String is
      use Ada.Streams.Stream_IO;
      File : File_Type;
   begin
      Open (File, In_File, File_Name);
      declare
         Data : String (1 .. Natural (Size (File)));
      begin
         String'Read (Stream (File), Data);
         Close (File);
         return Data;
      end;
   end Read;

   procedure Write (File_Name : String; Contents : String) is
      use Ada.Streams.Stream_IO;
      Beside : constant String := File_Name & ".saving";
      File   : File_Type;
      Placed : Boolean;
   begin
      Create (File, Out_File, Beside);
      String'Write (Stream (File), Contents);
      Close (File);
      --  rename(2), which replaces what is there.
      GNAT.OS_Lib.Rename_File (Beside, File_Name, Placed);
      if not Placed then
         GNAT.OS_Lib.Delete_File (Beside, Placed);
         raise Ada.Streams.Stream_IO.Use_Error
           with "cannot replace " & File_Name;
      end if;
   end Write;

end Files;
