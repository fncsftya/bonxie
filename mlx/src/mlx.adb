with Interfaces.C;
with System;

package body MLX is

   use type Interfaces.C.int;

   function MX_Check
     (Directory    : System.Address;
      Message      : System.Address;
      Message_Room : Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C, External_Name => "mx_check";

   function MX_Test_Begin (Directory : System.Address) return Interfaces.C.int
     with Import, Convention => C, External_Name => "mx_test_begin";

   function MX_Test_State return Interfaces.C.int
     with Import, Convention => C, External_Name => "mx_test_state";

   procedure MX_Test_Text (Into : System.Address; Room : Interfaces.C.int)
     with Import, Convention => C, External_Name => "mx_test_text";

   procedure MX_Test_Reset
     with Import, Convention => C, External_Name => "mx_test_reset";

   function Problem (Directory : String) return String is
      Where : aliased constant Interfaces.C.char_array := Interfaces.C.To_C (Directory);
      Raw   : aliased Interfaces.C.char_array (0 .. Max_Message) := [others => Interfaces.C.nul];
   begin
      if MX_Check (Where'Address, Raw'Address, Raw'Length) = 1 then
         return "";
      end if;
      declare
         Said : constant String := Interfaces.C.To_Ada (Raw);
      begin
         return (if Said = "" then "The model cannot be used" else Said);
      end;
   end Problem;

   procedure Start_Test (Directory : String) is
      Where : aliased constant Interfaces.C.char_array := Interfaces.C.To_C (Directory);
      Began : constant Interfaces.C.int := MX_Test_Begin (Where'Address);
   begin
      pragma Assert (Began = 1);
   end Start_Test;

   function State return States is
     (case MX_Test_State is
         when 1      => Running,
         when 2      => Done,
         when 3      => Failed,
         when others => Idle);

   function Text return String is
      Raw : aliased Interfaces.C.char_array (0 .. Max_Reply) := [others => Interfaces.C.nul];
   begin
      MX_Test_Text (Raw'Address, Raw'Length);
      declare
         Said : constant String := Interfaces.C.To_Ada (Raw);
      begin
         return Said (Said'First .. Said'First - 1 + Natural'Min (Said'Length, Max_Reply));
      end;
   end Text;

   procedure Reset is
   begin
      MX_Test_Reset;
   end Reset;

end MLX;
