with Ada.Unchecked_Conversion;
with Interfaces;
with Interfaces.C;
with Speech.Rings;
with System;

package body Speech.Capture
  with SPARK_Mode => Off
is

   use type Interfaces.C.int;
   use type Interfaces.Unsigned_32;
   use type Rings.Counter;

   function CAP_Begin
     (Number       : Interfaces.C.int;
      Message      : System.Address;
      Message_Room : Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C, External_Name => "sp_cap_begin";

   procedure CAP_Stop (Number : Interfaces.C.int)
     with Import, Convention => C, External_Name => "sp_cap_stop";

   procedure CAP_Close (Number : Interfaces.C.int)
     with Import, Convention => C, External_Name => "sp_cap_close";

   ---------------------------------------------------------------------
   --  What is shared between the microphone's thread, which writes
   --  (Heads, the level, Dropped_Count), and the reader, which reads
   --  (Tails). Each count has one writer, and is atomic, so that what the
   --  other reads of it is a whole count, and, as it is written after
   --  what it counts, is that much of the ring that is there to be seen.

   type Atomic_Counter is new Rings.Counter
     with Atomic;

   type Atomic_Bits is new Interfaces.Unsigned_32
     with Atomic;

   Stores : array (Session) of Rings.Store;
   --  Not given a first value: it is as large as can be, and the
   --  microphone's thread is not to be waited for to make it.

   Heads : array (Session) of Atomic_Counter := [others => 0]
     with Atomic_Components;
   --  How many samples have been written, by the microphone's thread.

   Tails : array (Session) of Atomic_Counter := [others => 0]
     with Atomic_Components;
   --  How many have been read, by the reader.

   Lost : array (Session) of Atomic_Counter := [others => 0]
     with Atomic_Components;

   Levels : array (Session) of Atomic_Bits := [others => 0]
     with Atomic_Components;
   --  The bits of how loud it is, a float.

   Rooms : array (Session) of Atomic_Bits := [others => 0]
     with Atomic_Components;
   --  The bits of how loud the room is, as an amplitude, a float.

   function To_Float is new Ada.Unchecked_Conversion (Interfaces.Unsigned_32, Float);
   function To_Bits is new Ada.Unchecked_Conversion (Float, Interfaces.Unsigned_32);

   function To_Sample (Bits : Interfaces.Unsigned_32) return Float is
     (if not Rings.Finite_Bits (Bits) then 0.0
      else Float'Max (-1.0, Float'Min (1.0, To_Float (Bits))));

   --  Called by the microphone's thread, which is not Ada's: nothing
   --  here can wait, allocate or raise.
   procedure Push
     (Number  : Interfaces.C.int;
      Samples : System.Address;
      Count   : Interfaces.C.int;
      Loud    : Interfaces.Unsigned_32)
     with Export, Convention => C, External_Name => "sp_ring_push";

   procedure Push
     (Number  : Interfaces.C.int;
      Samples : System.Address;
      Count   : Interfaces.C.int;
      Loud    : Interfaces.Unsigned_32) is
   begin
      if Number not in 1 .. Max_Sessions or else Count <= 0 then
         return;
      end if;
      declare
         Which : constant Session := Session (Number);
         Given : constant Natural := Natural (Count);
         Raw   : Rings.Raw_Samples (1 .. Given)
           with Import, Address => Samples;
         Head  : constant Rings.Counter := Rings.Counter (Heads (Which));
         Tail  : constant Rings.Counter := Rings.Counter (Tails (Which));
         Taken : constant Natural := Natural'Min (Given, Rings.Room (Head, Tail));
      begin
         Rings.Write (Stores (Which), Head, Raw, Taken);
         if Taken < Given then
            Lost (Which) := Lost (Which) + Atomic_Counter (Given - Taken);
         end if;
         Levels (Which) := Atomic_Bits (Loud);
         Heads (Which) := Atomic_Counter (Head + Rings.Counter (Taken));
      end;
   exception
      when others =>
         null;  --  there is no one to tell, and nothing that can be done
   end Push;

   procedure Begin_Capture
     (Which   : Session;
      Ok      : out Boolean;
      Message : out String;
      Last    : out Natural)
   is
      Raw  : aliased Interfaces.C.char_array (0 .. 255) :=
        [others => Interfaces.C.nul];
   begin
      --  Nothing is writing (the capture is not begun), so, what was left
      --  unread is forgotten.
      Tails (Which) := Heads (Which);
      Lost (Which) := 0;
      Levels (Which) := 0;
      Rooms (Which) := 0;
      declare
         Done : constant Interfaces.C.int :=
           CAP_Begin (Interfaces.C.int (Which), Raw'Address, Raw'Length);
         Said : constant String :=
           (if Done = 1 then "" else Interfaces.C.To_Ada (Raw));
      begin
         Ok := Done = 1;
         Last := Natural'Min (Said'Length, Message'Length);
         Message := [others => ' '];
         Message (1 .. Last) := Said (Said'First .. Said'First + Last - 1);
      end;
   end Begin_Capture;

   procedure Read
     (Which : Session;
      Into  : out Windows.Samples;
      Last  : out Natural)
   is
      Tail : constant Rings.Counter := Rings.Counter (Tails (Which));
      Head : constant Rings.Counter := Rings.Counter (Heads (Which));
      Take : constant Natural :=
        (if Into'Length = 0 or else Into'Last = Positive'Last then 0
         else Natural'Min (Into'Length, Rings.Available (Head, Tail)));
   begin
      Last := Into'First - 1;
      if Take = 0 then
         return;
      end if;
      declare
         Raw : Rings.Raw_Samples (1 .. Take);
      begin
         Rings.Read (Stores (Which), Tail, Raw, Take);
         for Index in 1 .. Take loop
            Into (Into'First + Index - 1) := To_Sample (Raw (Index));
         end loop;
      end;
      Tails (Which) := Atomic_Counter (Tail + Rings.Counter (Take));
      Last := Into'First - 1 + Take;
   end Read;

   function Dropped (Which : Session) return Natural is
     (Natural (Rings.Counter'Min (Rings.Counter (Lost (Which)), Rings.Counter (Natural'Last))));

   procedure Set_Room (Which : Session; Amplitude : Float) is
   begin
      Rooms (Which) := Atomic_Bits (To_Bits (Amplitude));
   end Set_Room;

   Full : constant := 0.5;
   --  How loud, as the microphone's thread says it (twelve times the
   --  amplitude), is as loud as the meter shows.

   function Loudness (Which : Session) return Float is
      Bits : constant Interfaces.Unsigned_32 := Interfaces.Unsigned_32 (Levels (Which));
      Room : constant Interfaces.Unsigned_32 := Interfaces.Unsigned_32 (Rooms (Which));
      Now  : constant Float :=
        (if Rings.Finite_Bits (Bits) then Float'Max (0.0, Float'Min (1.0, To_Float (Bits))) else 0.0);
      Hush : constant Float :=
        (if Rings.Finite_Bits (Room)
         then Float'Max (0.0, Float'Min (0.02, To_Float (Room))) * 12.0
         else 0.0);
   begin
      return Float'Max (0.0, Float'Min (1.0, (Now - Hush) / (Full - Hush)));
   end Loudness;

   procedure Stop (Which : Session) is
   begin
      CAP_Stop (Interfaces.C.int (Which));
   end Stop;

   procedure Close (Which : Session) is
   begin
      CAP_Close (Interfaces.C.int (Which));
      --  (The microphone has stopped, so nothing writes.)
      Tails (Which) := Heads (Which);
   end Close;

end Speech.Capture;
