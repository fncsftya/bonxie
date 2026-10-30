package body View_Parts.Settings is
   overriding
   function Gallery_State_Of (Self : Gallery_Files) return Settings_VM.Gallery_States
   is (Settings_VM.Gallery_States'Val (Gallery_Pictures.States'Pos (Gallery_Pictures.State (Self.Pictures))));
   overriding
   function Gallery_Fraction_Of (Self : Gallery_Files) return Float
   is (Gallery_Pictures.Fraction (Self.Pictures));
   overriding
   function Gallery_Message_Of (Self : Gallery_Files) return String
   is (Gallery_Pictures.Message (Self.Pictures));
   overriding
   function Gallery_Present (Self : Gallery_Files) return Boolean
   is (Gallery_Pictures.Present (Self.Pictures));
   overriding
   procedure Start_Gallery (Self : in out Gallery_Files) is
   begin
      Gallery_Pictures.Start (Self.Pictures);
   end Start_Gallery;
   overriding
   procedure Poll_Gallery (Self : in out Gallery_Files) is
   begin
      Gallery_Pictures.Poll (Self.Pictures);
   end Poll_Gallery;
end View_Parts.Settings;
