--  What the proofs of Speech.Windows cannot say: that it does the right
--  thing with a NaN or an infinity actually read from memory, as the
--  microphone's samples are (with the checks the crate is built with).
with Ada.Text_IO;
with Interfaces;
with Speech.Windows;

procedure Windows_Test is
   use type Speech.Windows.Sample_Index;
   use Speech.Windows;

   --  Sound as it comes from the sound card: bits, which may be anything.
   Raw   : aliased constant array (1 .. 6) of Interfaces.Unsigned_32 :=
     [16#3F00_0000#,   --  0.5
      16#7FC0_0000#,   --  a NaN
      16#7F80_0000#,   --  an infinity
      16#FF80_0000#,   --  minus an infinity
      16#40E0_0000#,   --  7.0
      16#BE80_0000#];  --  -0.25
   Heard : constant Samples (1 .. 6)
     with Import, Address => Raw'Address;

   Held   : Window;
   Taken  : Natural;
   Failed : Natural := 0;

   procedure Check (Name : String; Holds : Boolean) is
   begin
      Ada.Text_IO.Put_Line ((if Holds then "ok    " else "FAIL  ") & Name);
      if not Holds then
         Failed := Failed + 1;
      end if;
   end Check;
begin
   Append (Held, Heard, Taken);
   Check ("all taken", Taken = 6 and then Count (Held) = 6);
   Check ("kept as it was", Sample (Held, 0) = 0.5 and then Sample (Held, 5) = -0.25);
   Check ("NaN is silence", Sample (Held, 1) = 0.0);
   Check ("infinities are silence", Sample (Held, 2) = 0.0 and then Sample (Held, 3) = 0.0);
   Check ("too loud is loudest", Sample (Held, 4) = 1.0);
   Drop_Before (Held, 3);
   Check ("slid", First (Held) = 3 and then Count (Held) = 3 and then Next (Held) = 6);
   Check ("places kept", Sample (Held, 3) = 0.0 and then Sample (Held, 5) = -0.25);
   Mark_Decoded (Held);
   Check ("decoded", Decoded (Held) = 6 and then not Due (Held, 1) and then Due (Held, 1) = False);

   declare
      Many : constant Samples (1 .. Capacity + 10) := [others => 0.1];
   begin
      Append (Held, Many, Taken);
      Check ("fills to capacity", Taken = Capacity - 3 and then Count (Held) = Capacity);
      Check ("is full", Full (Held, 1));
      Make_Room (Held, Speech.Windows.Rate / 2);
      Check ("room made", not Full (Held, Speech.Windows.Rate / 2) and then Count (Held) = 0);
      Check ("places go on", First (Held) = Next (Held) and then First (Held) = Sample_Index (Capacity) + 3);
   end;

   declare
      Starts : Offsets := [0, 8, 9];
      Ends   : Offsets := [7, 15, 5];
   begin
      --  What the model gave for the end of a sound 12 samples long: a
      --  last word ending before the one before it, and one past the end.
      Check ("not ordered", not Ordered (Starts, Ends, 12));
      Repair (Starts, Ends, 12);
      Check ("repaired", Ordered (Starts, Ends, 12));
      Check ("repaired as asked", Ends = [7, 12, 12] and then Starts = [0, 8, 9]);
   end;
   declare
      Starts : Offsets := [1 .. 0 => 0];
      Ends   : Offsets := [1 .. 0 => 0];
   begin
      Repair (Starts, Ends, 0);
      Check ("no words are ordered", Ordered (Starts, Ends, 0));
   end;
   Check ("text fits", Text_Plausible ([3, 9], 9));
   Check ("no text fits", Text_Plausible ([1 .. 0 => 0], 0));
   Check ("past the text", not Text_Plausible ([10], 9));
   Check ("out of order", not Text_Plausible ([9, 3], 9));
   Check ("no word between", not Text_Plausible ([3, 4], 9));
   Check ("empty word", not Text_Plausible ([0], 9));

   Ada.Text_IO.Put_Line (if Failed = 0 then "all ok" else Failed'Image & " failed");
end Windows_Test;
