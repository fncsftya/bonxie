package Files is

   function Read (File_Name : String) return String;
   --  The whole contents of the file.

   procedure Write (File_Name : String; Contents : String);
   --  Make Contents the whole of the file: written beside it, then put
   --  in its place, so that a failure leaves it as it was.

end Files;
