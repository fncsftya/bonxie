--  The arithmetic of a ring of samples that one thread writes to (the
--  microphone's) and another reads from (the program's), neither waiting
--  for the other: where in the ring a sample goes, how much room there is,
--  and how much to read, from two counts of all that was written and all
--  that was read; and copying in and out of the ring, round the end of it.
--  The sample's place in the ring is its count (from the first sample
--  there was) mod Capacity.
--
--  GNATprove checks the Ada code for run-time errors and proves the
--  contracts under their preconditions: Write puts the selected source
--  samples in the corresponding ring places and preserves other places;
--  Read copies the requested samples in order and preserves the rest of
--  its output. This does not prove that concurrent users publish valid,
--  mutually consistent counts. Speech.Capture handles that boundary with
--  atomic counts, and tests it.
--  The postconditions inspect the ring and are ignored at run time; the
--  preconditions remain enabled.
with Interfaces;

package Speech.Rings
  with SPARK_Mode
is

   use type Interfaces.Unsigned_32;

   Capacity : constant := 2 ** 21;
   --  A little over two minutes of sound at 16 kHz.

   type Counter is mod 2 ** 64;
   --  How many samples there have been (written, or read) since the
   --  first: it does not come round in this world.

   subtype Place is Natural range 0 .. Capacity - 1;

   type Store is array (Place) of Interfaces.Unsigned_32;
   --  The samples' bits (a thread that writes samples does not say that
   --  they are numbers).

   type Raw_Samples is array (Positive range <>) of Interfaces.Unsigned_32;

   function Slot (Count : Counter) return Place is (Place (Count mod Capacity))
     with Global => null;
   --  Where the sample that is the Count'th goes.

   function Available (Head, Tail : Counter) return Natural is
     (if Head - Tail > Capacity then 0 else Natural (Head - Tail))
     with Global => null;
   --  How much there is to read, when Head have been written, and Tail
   --  read. (None if it is not as it can be, which is that more has been
   --  read than written, or more is unread than the ring holds.)

   function Room (Head, Tail : Counter) return Natural is
     (if Head - Tail > Capacity then 0 else Capacity - Natural (Head - Tail))
     with Global => null,
          Post   => Room'Result <= Capacity
                    and then (if Head - Tail <= Capacity
                              then Room'Result + Available (Head, Tail) = Capacity);
   --  How much there is room for, when Head have been written, and Tail
   --  read.

   function Offset (Count : Counter; Where : Place) return Natural is
     (Natural ((Counter (Where) - Count) mod Capacity))
     with Global => null,
          Post   => Offset'Result < Capacity;
   --  How far on from the Count'th sample's place Where is, going round.

   procedure Slot_Is_Offset (Count : Counter; By : Natural)
     with Ghost,
          Global => null,
          Pre    => By < Capacity,
          Post   => Offset (Count, Slot (Count + Counter (By))) = By;
   --  The samples Count, Count + 1, ... Count + Capacity - 1 each go
   --  somewhere of their own.

   procedure Offset_Is_Slot (Count : Counter)
     with Ghost,
          Global => null,
          Post   => (for all Where in Place => Slot (Count + Counter (Offset (Count, Where))) = Where);
   --  And a place is only that far on from the Count'th sample's.

   procedure Write
     (Into   : in out Store;
      Head   : Counter;
      Source : Raw_Samples;
      Count  : Natural)
     with Global => null,
          Pre    => Count <= Source'Length
                    and then Count <= Capacity
                    and then Source'Last < Positive'Last,
          Post   => (for all Where in Place =>
                       (if Offset (Head, Where) < Count
                        then Into (Where) = Source (Source'First + Offset (Head, Where))
                        else Into (Where) = Into'Old (Where)));
   --  Put the first Count samples of Source in the ring, as the Head'th,
   --  Head + 1'th, ...: and nothing else is changed.

   procedure Read
     (From  : Store;
      Tail  : Counter;
      Into  : in out Raw_Samples;
      Count : Natural)
     with Global => null,
          Pre    => Count <= Into'Length
                    and then Count <= Capacity
                    and then Into'Last < Positive'Last,
          Post   => (for all K in 0 .. Count - 1 =>
                       Into (Into'First + K) = From (Slot (Tail + Counter (K))))
                    and then
                      (for all K in Count .. Into'Length - 1 =>
                         Into (Into'First + K) = Into'Old (Into'First + K));
   --  Take Count samples from the ring, the Tail'th, Tail + 1'th, ...,
   --  into the first of Into.

   ---------------------------------------------------------------------
   --  A sample that is not a number is not heard.

   function Finite_Bits (Bits : Interfaces.Unsigned_32) return Boolean is
     (Interfaces.Shift_Right (Bits, 23) mod 256 /= 255)
     with Global => null;
   --  Whether the bits are those of a 32-bit float that is a number (that
   --  is not, by its exponent, an infinity or a NaN).

end Speech.Rings;
