with Interfaces.C;
with Vision.Layout;
with System;

package body Vision is

   use type Interfaces.C.int;
   use type Interfaces.C.double;

   First_Room_Words : constant := 4_096;
   First_Room_Bytes : constant := 48_000;
   --  What is made room for to begin with; more if there are more words.

   function VN_Recognize
     (Path           : Interfaces.C.char_array;
      Words          : System.Address;
      Max            : Interfaces.C.int;
      Text           : System.Address;
      Text_Room      : Interfaces.C.int;
      Word_Count     : out Interfaces.C.int;
      Text_Length    : out Interfaces.C.int;
      Cut            : out Interfaces.C.int;
      Aspect         : out Interfaces.C.double;
      Message        : System.Address;
      Message_Room   : Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C, External_Name => "vn_recognize";

   procedure Recognize
     (File_Name : String;
      Into      : in out Result;
      Ok        : out Boolean;
      Message   : out String;
      Last      : out Natural)
   is
      Raw     : aliased Interfaces.C.char_array (0 .. 255) :=
        [others => Interfaces.C.nul];
      Words   : Interfaces.C.int;
      Length  : Interfaces.C.int;
      Cut     : Interfaces.C.int;
      Shape   : Interfaces.C.double;
      Done    : Interfaces.C.int;
   begin
      Pomarine.Words.Clear (Into);
      Pomarine.Words.Reserve (Into, First_Room_Words, First_Room_Bytes);
      loop
         Done :=
           VN_Recognize
             (Interfaces.C.To_C (File_Name),
              Into.Words.all'Address, Interfaces.C.int (Into.Words'Length),
              Into.Text.all'Address, Interfaces.C.int (Into.Text'Length),
              Words, Length, Cut, Shape,
              Raw'Address, Raw'Length);
         --  If it was cut short for room, it is done again with more.
         exit when Done /= 1 or else Cut = 0;
         Pomarine.Words.Reserve (Into, 2 * Into.Words'Length, 2 * Into.Text'Length);
      end loop;
      Ok := Done = 1;
      Last := 0;
      if Ok then
         Into.Count := Natural (Words);
         Into.Length := Natural (Length);
         Into.Truncated := False;
         if Shape > 0.0 then
            Layout.Reading_Order (Into, Float (Shape));
         end if;
      else
         declare
            Said : constant String := Interfaces.C.To_Ada (Raw);
            Used : constant Natural :=
              Natural'Min (Said'Length, Message'Length);
         begin
            Message (Message'First .. Message'First + Used - 1) :=
              Said (Said'First .. Said'First + Used - 1);
            Last := Message'First - 1 + Used;
         end;
      end if;
   end Recognize;

end Vision;
