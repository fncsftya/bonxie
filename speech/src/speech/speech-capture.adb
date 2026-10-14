with Interfaces.C;
with System;

package body Speech.Capture is

   use type Interfaces.C.int;

   function CAP_Begin
     (Number       : Interfaces.C.int;
      Message      : System.Address;
      Message_Room : Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C, External_Name => "sp_cap_begin";

   function CAP_Read
     (Number : Interfaces.C.int;
      Out_To : System.Address;
      Room   : Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C, External_Name => "sp_cap_read";

   function CAP_Level (Number : Interfaces.C.int) return Interfaces.C.C_float
     with Import, Convention => C, External_Name => "sp_cap_level";

   procedure CAP_Stop (Number : Interfaces.C.int)
     with Import, Convention => C, External_Name => "sp_cap_stop";

   procedure CAP_Close (Number : Interfaces.C.int)
     with Import, Convention => C, External_Name => "sp_cap_close";

   procedure Begin_Capture
     (Which   : Session;
      Ok      : out Boolean;
      Message : out String;
      Last    : out Natural)
   is
      Raw  : aliased Interfaces.C.char_array (0 .. 255) :=
        [others => Interfaces.C.nul];
      Done : constant Interfaces.C.int :=
        CAP_Begin (Interfaces.C.int (Which), Raw'Address, Raw'Length);
      Said : constant String :=
        (if Done = 1 then "" else Interfaces.C.To_Ada (Raw));
   begin
      Ok := Done = 1;
      Last := Natural'Min (Said'Length, Message'Length);
      Message := [others => ' '];
      Message (1 .. Last) := Said (Said'First .. Said'First + Last - 1);
   end Begin_Capture;

   procedure Read
     (Which : Session;
      Into  : out Windows.Samples;
      Last  : out Natural) is
   begin
      Last := Into'First - 1;
      if Into'Length = 0 then
         return;
      end if;
      Last :=
        Into'First - 1
        + Natural
            (CAP_Read
               (Interfaces.C.int (Which), Into (Into'First)'Address,
                Interfaces.C.int (Natural'Min (Into'Length, 1_000_000))));
   end Read;

   function Loudness (Which : Session) return Float is
     (Float'Min
        (1.0,
         Float'Max (0.0, Float (CAP_Level (Interfaces.C.int (Which))))));

   procedure Stop (Which : Session) is
   begin
      CAP_Stop (Interfaces.C.int (Which));
   end Stop;

   procedure Close (Which : Session) is
   begin
      CAP_Close (Interfaces.C.int (Which));
   end Close;

end Speech.Capture;
