with Ada.Text_IO;
with Dotenv;

package body Premium is

   function Available return Boolean is (Dotenv.Value ("ENV") = "dev");

   function Backend return String is
      Given : constant String := Dotenv.Value ("BACKEND", Default_Backend);
      Last  : Natural := Given'Last;
   begin
      while Last >= Given'First and then Given (Last) in '/' | ' ' loop
         Last := Last - 1;
      end loop;
      return (if Last < Given'First then Default_Backend else Given (Given'First .. Last));
   end Backend;

   procedure Log (Words : String) is
   begin
      if Available then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "[premium] " & Words);
      end if;
   end Log;

end Premium;
