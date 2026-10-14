--  What the proofs of Speech.Rings cannot say: that the ring works between
--  two threads that do not wait for each other (the way the microphone's
--  thread and the reader are), with what the microphone's thread calls:
--  every sample comes out, in order, once; the newest are the ones lost
--  when the reader is too slow; and what is not a number is not heard.
with Ada.Text_IO;
with Interfaces;
with Interfaces.C;
with System;
with Speech.Capture;
with Speech.Windows;

procedure Capture_Test is
   use type Interfaces.C.int;

   procedure Push
     (Number  : Interfaces.C.int;
      Samples : System.Address;
      Count   : Interfaces.C.int;
      Loud    : Interfaces.Unsigned_32)
     with Import, Convention => C, External_Name => "sp_ring_push";

   Which  : constant Speech.Session := 1;
   Failed : Natural := 0;

   procedure Check (Name : String; Holds : Boolean) is
   begin
      Ada.Text_IO.Put_Line ((if Holds then "ok    " else "FAIL  ") & Name);
      if not Holds then
         Failed := Failed + 1;
      end if;
   end Check;

   Period : constant := 2 ** 20;
   --  Samples are numbered, in their size: sample N is N mod Period / Period.

   function Value_Of (N : Natural) return Float is (Float (N mod Period) / Float (Period));

   Total : constant := 20_000_000;

   protected Progress is
      procedure Took (Count : Natural);
      function Taken return Natural;
   private
      Count_Taken : Natural := 0;
   end Progress;

   protected body Progress is
      procedure Took (Count : Natural) is
      begin
         Count_Taken := Count_Taken + Count;
      end Took;

      function Taken return Natural is (Count_Taken);
   end Progress;

   task Producer;
   --  The microphone's thread: pushes Total samples, in chunks of 480.
   task body Producer is
      Chunk : Speech.Windows.Samples (1 .. 480);
      Next  : Natural := 0;
   begin
      while Next < Total loop
         for I in Chunk'Range loop
            Chunk (I) := Value_Of (Next + I - 1);
         end loop;
         Push (Interfaces.C.int (Which), Chunk'Address, Chunk'Length, 0);
         Next := Next + Chunk'Length;
         --  Not so far ahead that the ring is full (the test is of the
         --  order, not of the loss).
         while Next - Progress.Taken > 1_000_000 loop
            delay 0.0005;
         end loop;
      end loop;
   end Producer;

   Bits : aliased constant array (1 .. 5) of Interfaces.Unsigned_32 :=
     [16#7FC0_0000#,   --  a NaN
      16#7F80_0000#,   --  an infinity
      16#40400000#,    --  3.0
      16#BF00_0000#,   --  -0.5
      16#3F00_0000#];  --  0.5

   Heard : Speech.Windows.Samples (1 .. 4096);
   Last  : Natural;
   Next  : Natural := 0;
   Wrong : Natural := 0;
begin
   --  Two threads: in order, none lost, none twice.
   while Next < Total loop
      Speech.Capture.Read (Which, Heard, Last);
      for I in Heard'First .. Last loop
         if Heard (I) /= Value_Of (Next + I - Heard'First) then
            Wrong := Wrong + 1;
         end if;
      end loop;
      Next := Next + (Last - Heard'First + 1);
      Progress.Took (Last - Heard'First + 1);
      if Last < Heard'First then
         delay 0.0002;
      end if;
   end loop;
   Check ("all of them, in order", Wrong = 0 and then Next = Total);
   Check ("none lost", Speech.Capture.Dropped (Which) = 0);
   Speech.Capture.Read (Which, Heard, Last);
   Check ("none more", Last < Heard'First);

   --  What is not a number.
   Push (Interfaces.C.int (Which), Bits'Address, 5, 16#3F00_0000#);
   Speech.Capture.Read (Which, Heard, Last);
   Check ("five", Last = Heard'First + 4);
   Check ("a NaN is silence", Heard (1) = 0.0);
   Check ("an infinity is silence", Heard (2) = 0.0);
   Check ("too loud is the loudest", Heard (3) = 1.0);
   Check ("the rest as they are", Heard (4) = -0.5 and then Heard (5) = 0.5);
   Check ("loudness", Speech.Capture.Loudness (Which) = 0.5);
   Push (Interfaces.C.int (Which), Bits'Address, 1, 16#7FC0_0000#);
   Check ("loudness that is not a number is none", Speech.Capture.Loudness (Which) = 0.0);
   Push (Interfaces.C.int (Which), Bits'Address, 1, 16#4000_0000#);
   Check ("loudness is at most 1", Speech.Capture.Loudness (Which) = 1.0);
   Speech.Capture.Read (Which, Heard, Last);

   --  A reader that is too slow: the newest are lost.
   declare
      Many  : Speech.Windows.Samples (1 .. 1000);
      Count : constant := 2_200;
      --  1000 at a time, 2200 times: more than the ring holds, 2**21.
      Got   : Natural := 0;
      Right : Boolean := True;
      Big   : Speech.Windows.Samples (1 .. 100_000);
   begin
      for I in Many'Range loop
         Many (I) := Value_Of (I - 1);
      end loop;
      for Time in 1 .. Count loop
         Push (Interfaces.C.int (Which), Many'Address, Many'Length, 0);
      end loop;
      loop
         Speech.Capture.Read (Which, Big, Last);
         exit when Last < Big'First;
         for I in Big'First .. Last loop
            if Big (I) /= Value_Of ((Got + I - Big'First) mod 1000) then
               Right := False;
            end if;
         end loop;
         Got := Got + (Last - Big'First + 1);
      end loop;
      Check ("only what fits is kept", Got = 2 ** 21);
      Check ("what is kept is the oldest, in order", Right);
      Check ("the rest is counted", Speech.Capture.Dropped (Which) = Count * 1000 - 2 ** 21);
      Push (Interfaces.C.int (Which), Many'Address, Many'Length, 0);
      Speech.Capture.Read (Which, Big, Last);
      Check ("it goes on after", Last = Big'First + 999 and then Big (Big'First) = Value_Of (0));
   end;

   --  What is not meant for it.
   Push (0, Bits'Address, 5, 0);
   Push (99, Bits'Address, 5, 0);
   Push (Interfaces.C.int (Which), Bits'Address, 0, 0);
   Push (Interfaces.C.int (Which), Bits'Address, -3, 0);
   Speech.Capture.Read (Which, Heard, Last);
   Check ("a session or count that is not one is nothing", Last < Heard'First);

   Ada.Text_IO.Put_Line (if Failed = 0 then "all ok" else Failed'Image & " failed");
end Capture_Test;
