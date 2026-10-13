with Interfaces.C;
with Vision.Layout;
with System;

package body Vision is

   use type Interfaces.C.int;
   use type Interfaces.C.double;

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
      Into.Count := 0;
      Into.Length := 0;
      Into.Truncated := False;
      Done :=
        VN_Recognize
          (Interfaces.C.To_C (File_Name),
           Into.Words'Address, Max_Words,
           Into.Text'Address, Text_Capacity,
           Words, Length, Cut, Shape,
           Raw'Address, Raw'Length);
      Ok := Done = 1;
      Last := 0;
      if Ok then
         pragma Assert (Words in 0 .. Max_Words);
         pragma Assert (Length in 0 .. Text_Capacity);
         Into.Count := Natural (Words);
         Into.Length := Natural (Length);
         Into.Truncated := Cut /= 0;
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
