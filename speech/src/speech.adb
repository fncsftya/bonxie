with Interfaces.C;
with System;

package body Speech
  with SPARK_Mode => Off
is

   use type Interfaces.C.int;

   function SP_Begin
     (Number       : Interfaces.C.int;
      Message      : System.Address;
      Message_Room : Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C, External_Name => "sp_begin";

   function SP_End
     (Number       : Interfaces.C.int;
      Text         : System.Address;
      Text_Room    : Interfaces.C.int;
      Text_Length  : out Interfaces.C.int;
      Cut          : out Interfaces.C.int;
      Message      : System.Address;
      Message_Room : Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C, External_Name => "sp_end";

   function SP_Level (Number : Interfaces.C.int) return Interfaces.C.C_float
     with Import, Convention => C, External_Name => "sp_level";

   function SP_Peek
     (Number      : Interfaces.C.int;
      Text        : System.Address;
      Text_Room   : Interfaces.C.int;
      Text_Length : out Interfaces.C.int;
      Cut         : out Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C, External_Name => "sp_peek";

   function Level (Which : Session) return Float is
     (Float'Min
        (1.0, Float'Max (0.0, Float (SP_Level (Interfaces.C.int (Which))))));

   procedure Say
     (Raw     : Interfaces.C.char_array;
      Message : out String;
      Last    : out Natural);
   --  Copy what the shim said, as much as Message holds.

   procedure Say
     (Raw     : Interfaces.C.char_array;
      Message : out String;
      Last    : out Natural)
   is
      Said : constant String := Interfaces.C.To_Ada (Raw);
      Used : constant Natural := Natural'Min (Said'Length, Message'Length);
   begin
      Message := [others => ' '];
      Message (Message'First .. Message'First + Used - 1) :=
        Said (Said'First .. Said'First + Used - 1);
      Last := Message'First - 1 + Used;
   end Say;

   procedure Begin_Listening
     (Which   : Session;
      Ok      : out Boolean;
      Message : out String;
      Last    : out Natural)
   is
      Raw  : aliased Interfaces.C.char_array (0 .. 255) :=
        [others => Interfaces.C.nul];
      Done : constant Interfaces.C.int :=
        SP_Begin (Interfaces.C.int (Which), Raw'Address, Raw'Length);
   begin
      Ok := Done = 1;
      if Ok then
         Message := [others => ' '];
         Last := 0;
      else
         Say (Raw, Message, Last);
      end if;
   end Begin_Listening;

   procedure Peek (Which : Session; Into : in out Transcript) is
      Length : Interfaces.C.int;
      Cut    : Interfaces.C.int;
      Open   : constant Interfaces.C.int :=
        SP_Peek
          (Interfaces.C.int (Which),
           Into.Text'Address, Text_Capacity, Length, Cut);
   begin
      if Open = 1 and then Length in 0 .. Text_Capacity then
         Into.Length := Natural (Length);
         Into.Truncated := Cut /= 0;
      else
         Into.Length := 0;
         Into.Truncated := False;
      end if;
   end Peek;

   procedure End_Listening
     (Which   : Session;
      Into    : in out Transcript;
      Ok      : out Boolean;
      Message : out String;
      Last    : out Natural)
   is
      Raw    : aliased Interfaces.C.char_array (0 .. 255) :=
        [others => Interfaces.C.nul];
      Length : Interfaces.C.int;
      Cut    : Interfaces.C.int;
      Done   : Interfaces.C.int;
   begin
      Into.Length := 0;
      Into.Truncated := False;
      Done :=
        SP_End
          (Interfaces.C.int (Which),
           Into.Text'Address, Text_Capacity, Length, Cut,
           Raw'Address, Raw'Length);
      Ok := Done = 1;
      if Ok then
         pragma Assert (Length in 0 .. Text_Capacity);
         Into.Length := Natural (Length);
         Into.Truncated := Cut /= 0;
         Message := [others => ' '];
         Last := 0;
      else
         Say (Raw, Message, Last);
      end if;
   end End_Listening;

end Speech;
