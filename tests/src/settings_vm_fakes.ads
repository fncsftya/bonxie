with Ada.Strings.Unbounded;
with Preferences;
with Settings_VM;
with Speech.Models;

--  What the settings' view-model is given in a test in place of the disk and
--  the speech library: a store that writes down what it is told, and can be
--  made to fail, and a speech model that is as the test says.

package Settings_VM_Fakes is

   type Reactions is limited new Settings_VM.Effects with record
      Seed              : Natural := 1234;
      Requests, Notices : Natural := 0;
      Last              : Settings_VM.Command := Settings_VM.Open;
   end record;

   overriding
   function New_Picture_Seed (Self : in out Reactions) return Natural;
   overriding
   procedure Done (Self : in out Reactions; What : Settings_VM.Command);
   overriding
   procedure Ask_To_Delete (Self : in out Reactions; Size : String);

   type Notes is limited new Settings_VM.Store with record
      Said               : Ada.Strings.Unbounded.Unbounded_String;
      Failing            : Boolean := False;
      Background_Failing : Boolean := False;
   end record;

   overriding
   procedure Save_Speech_Model (Self : in out Notes; To : Preferences.Speech_Models);
   overriding
   procedure Save_Theme (Self : in out Notes; To : Preferences.Theme_Choices);
   overriding
   procedure Save_Background (Self : in out Notes; To : Preferences.Background_Modes);
   overriding
   procedure Save_VSync (Self : in out Notes; To : Boolean);
   overriding
   procedure Save_Seed (Self : in out Notes; To : Natural);

   function Told (Self : Notes) return String;
   --  Each save, in order, as "theme=DARK;".

   type Pretend is limited new Settings_VM.Model_Source with record
      Now     : Speech.Models.States := Speech.Models.Idle;
      Part    : Float := 0.0;
      Working : Boolean := False;
      --  Preparing.
      Bytes   : Long_Long_Integer := 0;
      Said    : Ada.Strings.Unbounded.Unbounded_String;
      Files   : Boolean := False;
      Size    : Long_Long_Integer := 0;
   end record;

   overriding
   function State (Self : Pretend) return Speech.Models.States;
   overriding
   function Fraction (Self : Pretend) return Float;
   overriding
   function Preparing (Self : Pretend) return Boolean;
   overriding
   function Total_Bytes (Self : Pretend) return Long_Long_Integer;
   overriding
   function Message (Self : Pretend) return String;
   overriding
   function Present (Self : Pretend) return Boolean;
   overriding
   function On_Disk (Self : Pretend) return Long_Long_Integer;
   overriding
   procedure Start (Self : in out Pretend);
   overriding
   procedure Delete (Self : in out Pretend);

end Settings_VM_Fakes;
