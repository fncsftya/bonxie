with Ada.Streams.Stream_IO;

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

end Files;
