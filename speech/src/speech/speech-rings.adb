pragma Assertion_Policy
  (Post => Ignore, Postcondition => Ignore, Type_Invariant => Ignore,
   Loop_Invariant => Ignore, Assert => Ignore);

package body Speech.Rings
  with SPARK_Mode
is

   --  The lemmas are proved by the provers alone: there is nothing to
   --  do but say so.
   procedure Slot_Is_Offset (Count : Counter; By : Natural) is
   begin
      pragma Assert (Offset (Count, Slot (Count + Counter (By))) = By);
   end Slot_Is_Offset;

   procedure Offset_Is_Slot (Count : Counter) is
   begin
      pragma Assert
        (for all Where in Place => Slot (Count + Counter (Offset (Count, Where))) = Where);
   end Offset_Is_Slot;

   procedure Write
     (Into   : in out Store;
      Head   : Counter;
      Source : Raw_Samples;
      Count  : Natural) is
   begin
      for K in 0 .. Count - 1 loop
         pragma Loop_Invariant
           (for all Where in Place =>
              (if Offset (Head, Where) < K
               then Into (Where) = Source (Source'First + Offset (Head, Where))
               else Into (Where) = Into'Loop_Entry (Where)));
         Slot_Is_Offset (Head, K);
         Offset_Is_Slot (Head);
         Into (Slot (Head + Counter (K))) := Source (Source'First + K);
      end loop;
   end Write;

   procedure Read
     (From  : Store;
      Tail  : Counter;
      Into  : in out Raw_Samples;
      Count : Natural) is
   begin
      for K in 0 .. Count - 1 loop
         pragma Loop_Invariant
           (for all J in 0 .. K - 1 => Into (Into'First + J) = From (Slot (Tail + Counter (J))));
         pragma Loop_Invariant
           (for all J in K .. Into'Length - 1 => Into (Into'First + J) = Into'Loop_Entry (Into'First + J));
         Into (Into'First + K) := From (Slot (Tail + Counter (K)));
      end loop;
   end Read;

end Speech.Rings;
