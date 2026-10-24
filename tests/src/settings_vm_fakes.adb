with Ada.Strings.Fixed;
with Ada.Text_IO;

package body Settings_VM_Fakes is

   procedure Note (Self : in out Notes; What : String) is
   begin
      if Self.Failing then
         raise Ada.Text_IO.Use_Error with "the disk is full";
      end if;
      Ada.Strings.Unbounded.Append (Self.Said, What & ";");
   end Note;

   overriding procedure Save_Speech_Model (Self : in out Notes; To : Preferences.Speech_Models) is
   begin
      Note (Self, "speech=" & To'Image);
   end Save_Speech_Model;

   overriding procedure Save_Theme (Self : in out Notes; To : Preferences.Theme_Choices) is
   begin
      Note (Self, "theme=" & To'Image);
   end Save_Theme;

   overriding procedure Save_Background (Self : in out Notes; To : Preferences.Background_Modes) is
   begin
      Note (Self, "background=" & To'Image);
   end Save_Background;

   overriding procedure Save_VSync (Self : in out Notes; To : Boolean) is
   begin
      Note (Self, "vsync=" & To'Image);
   end Save_VSync;

   overriding procedure Save_Seed (Self : in out Notes; To : Natural) is
   begin
      Note (Self, "seed=" & Ada.Strings.Fixed.Trim (To'Image, Ada.Strings.Left));
   end Save_Seed;

   function Told (Self : Notes) return String is (Ada.Strings.Unbounded.To_String (Self.Said));

   overriding function State (Self : Pretend) return Speech.Models.States is (Self.Now);

   overriding function Fraction (Self : Pretend) return Float is (Self.Part);

   overriding function Preparing (Self : Pretend) return Boolean is (Self.Working);

   overriding function Total_Bytes (Self : Pretend) return Long_Long_Integer is (Self.Bytes);

   overriding function Message (Self : Pretend) return String is (Ada.Strings.Unbounded.To_String (Self.Said));

   overriding function Present (Self : Pretend) return Boolean is (Self.Files);

   overriding function On_Disk (Self : Pretend) return Long_Long_Integer is (Self.Size);

   overriding procedure Start (Self : in out Pretend) is
   begin
      Self.Now := Speech.Models.Running;
   end Start;

   overriding procedure Delete (Self : in out Pretend) is
   begin
      Self.Files := False;
      Self.Size := 0;
      Self.Now := Speech.Models.Idle;
   end Delete;

end Settings_VM_Fakes;
