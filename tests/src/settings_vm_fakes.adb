with Ada.Strings.Fixed;
with Ada.Text_IO;

package body Settings_VM_Fakes is

   overriding
   function Gallery_State_Of (Self : Gallery) return Settings_VM.Gallery_States
   is (Self.Now);
   overriding
   function Gallery_Fraction_Of (Self : Gallery) return Float
   is (Self.Part);
   overriding
   function Gallery_Message_Of (Self : Gallery) return String
   is (if Self.Files then "" else "unavailable");
   overriding
   function Gallery_Present (Self : Gallery) return Boolean
   is (Self.Files);
   overriding
   procedure Start_Gallery (Self : in out Gallery) is
   begin
      Self.Starts := @ + 1;
      Self.Now := Settings_VM.Running;
   end Start_Gallery;
   overriding
   procedure Poll_Gallery (Self : in out Gallery) is
      pragma Unreferenced (Self);
   begin
      null;
   end Poll_Gallery;

   overriding
   function New_Picture_Seed (Self : in out Reactions) return Natural is
   begin
      Self.Requests := Self.Requests + 1;
      return Self.Seed;
   end New_Picture_Seed;

   overriding
   procedure Done (Self : in out Reactions; What : Settings_VM.Command) is
   begin
      Self.Notices := Self.Notices + 1;
      Self.Last := What;
   end Done;

   overriding
   procedure Ask_To_Delete (Self : in out Reactions; Size : String) is
      pragma Unreferenced (Self, Size);
   begin
      null;
   end Ask_To_Delete;

   procedure Note (Self : in out Notes; What : String) is
   begin
      if Self.Failing then
         raise Ada.Text_IO.Use_Error with "the disk is full";
      end if;
      Ada.Strings.Unbounded.Append (Self.Said, What & ";");
   end Note;

   overriding
   procedure Save_Speech_Model (Self : in out Notes; To : Preferences.Speech_Models) is
   begin
      Note (Self, "speech=" & To'Image);
   end Save_Speech_Model;

   overriding
   procedure Save_Theme (Self : in out Notes; To : Preferences.Theme_Choices) is
   begin
      Note (Self, "theme=" & To'Image);
   end Save_Theme;

   overriding
   procedure Save_Background (Self : in out Notes; To : Preferences.Background_Modes) is
   begin
      if Self.Background_Failing then
         raise Ada.Text_IO.Use_Error with "cannot save background";
      end if;
      Note (Self, "background=" & To'Image);
   end Save_Background;

   overriding
   procedure Save_VSync (Self : in out Notes; To : Boolean) is
   begin
      Note (Self, "vsync=" & To'Image);
   end Save_VSync;

   overriding
   procedure Save_Seed (Self : in out Notes; To : Natural) is
   begin
      Note (Self, "seed=" & Ada.Strings.Fixed.Trim (To'Image, Ada.Strings.Left));
   end Save_Seed;

   function Told (Self : Notes) return String
   is (Ada.Strings.Unbounded.To_String (Self.Said));

   overriding
   function State (Self : Pretend) return Speech.Models.States
   is (Self.Now);

   overriding
   function Fraction (Self : Pretend) return Float
   is (Self.Part);

   overriding
   function Preparing (Self : Pretend) return Boolean
   is (Self.Working);

   overriding
   function Total_Bytes (Self : Pretend) return Long_Long_Integer
   is (Self.Bytes);

   overriding
   function Message (Self : Pretend) return String
   is (Ada.Strings.Unbounded.To_String (Self.Said));

   overriding
   function Present (Self : Pretend) return Boolean
   is (Self.Files);

   overriding
   function On_Disk (Self : Pretend) return Long_Long_Integer
   is (Self.Size);

   overriding
   procedure Start (Self : in out Pretend) is
   begin
      Self.Now := Speech.Models.Running;
   end Start;

   overriding
   procedure Delete (Self : in out Pretend) is
   begin
      Self.Files := False;
      Self.Size := 0;
      Self.Now := Speech.Models.Idle;
   end Delete;

end Settings_VM_Fakes;
