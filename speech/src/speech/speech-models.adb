with Interfaces.C;
with Speech.Parakeet;
with System;

package body Speech.Models is

   use type Interfaces.C.int;

   function PK_Fetch_Begin (Directory : System.Address) return Interfaces.C.int
     with Import, Convention => C, External_Name => "pk_fetch_begin";

   function PK_Fetch_State return Interfaces.C.int
     with Import, Convention => C, External_Name => "pk_fetch_state";

   function PK_Fetch_Fraction return Interfaces.C.C_float
     with Import, Convention => C, External_Name => "pk_fetch_fraction";

   procedure PK_Fetch_Message (Into : System.Address; Room : Interfaces.C.int)
     with Import, Convention => C, External_Name => "pk_fetch_message";

   procedure PK_Fetch_Reset
     with Import, Convention => C, External_Name => "pk_fetch_reset";

   procedure PK_Fetch_Cancel
     with Import, Convention => C, External_Name => "pk_fetch_cancel";

   function Present (Directory : String) return Boolean is
     (Parakeet.Present (Directory));

   procedure Start (Directory : String) is
      Where : aliased constant Interfaces.C.char_array := Interfaces.C.To_C (Directory);
      Began : constant Interfaces.C.int := PK_Fetch_Begin (Where'Address);
   begin
      pragma Assert (Began = 1);
   end Start;

   function State return States is
     (case PK_Fetch_State is
         when 1      => Running,
         when 2      => Done,
         when 3      => Failed,
         when others => Idle);

   function Fraction return Float is
     (Float'Min (1.0, Float'Max (0.0, Float (PK_Fetch_Fraction))));

   function Message return String is
      Raw  : aliased Interfaces.C.char_array (0 .. Max_Message) := [others => Interfaces.C.nul];
   begin
      PK_Fetch_Message (Raw'Address, Raw'Length);
      declare
         Said : constant String := Interfaces.C.To_Ada (Raw);
      begin
         return Said (Said'First .. Said'First - 1 + Natural'Min (Said'Length, Max_Message));
      end;
   end Message;

   procedure Reset is
   begin
      PK_Fetch_Reset;
   end Reset;

   procedure Cancel is
   begin
      PK_Fetch_Cancel;
   end Cancel;

end Speech.Models;
