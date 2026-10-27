with Interfaces.C;
with Vision.Layout;
with System;
with Pomarine.Strips;

package body Vision is

   use type Interfaces.C.int;
   use type Interfaces.C.double;

   First_Room_Words : constant := 4_096;
   First_Room_Bytes : constant := 48_000;
   --  What is made room for to begin with; more if there are more words.

   function VN_Recognize
     (Path         : Interfaces.C.char_array;
      Words        : System.Address;
      Max          : Interfaces.C.int;
      Text         : System.Address;
      Text_Room    : Interfaces.C.int;
      Word_Count   : out Interfaces.C.int;
      Text_Length  : out Interfaces.C.int;
      Cut          : out Interfaces.C.int;
      Aspect       : out Interfaces.C.double;
      Message      : System.Address;
      Message_Room : Interfaces.C.int) return Interfaces.C.int
   with Import, Convention => C, External_Name => "vn_recognize";

   procedure Recognize_Strip
     (File_Name : String;
      Into      : in out Result;
      Ok        : out Boolean;
      Message   : out String;
      Last      : out Natural;
      Aspect    : out Float)
   is
      Raw    : aliased Interfaces.C.char_array (0 .. 255) := [others => Interfaces.C.nul];
      Words  : Interfaces.C.int;
      Length : Interfaces.C.int;
      Cut    : Interfaces.C.int;
      Shape  : Interfaces.C.double;
      Done   : Interfaces.C.int;
   begin
      Aspect := 0.0;
      Pomarine.Words.Clear (Into);
      Pomarine.Words.Reserve (Into, First_Room_Words, First_Room_Bytes);
      loop
         Done :=
           VN_Recognize
             (Interfaces.C.To_C (File_Name),
              Into.Words.all'Address,
              Interfaces.C.int (Into.Words'Length),
              Into.Text.all'Address,
              Interfaces.C.int (Into.Text'Length),
              Words,
              Length,
              Cut,
              Shape,
              Raw'Address,
              Raw'Length);
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
            Aspect := Float (Shape);
            Layout.Reading_Order (Into, Aspect);
         end if;
      else
         declare
            Said : constant String := Interfaces.C.To_Ada (Raw);
            Used : constant Natural := Natural'Min (Said'Length, Message'Length);
         begin
            Message (Message'First .. Message'First + Used - 1) := Said (Said'First .. Said'First + Used - 1);
            Last := Message'First - 1 + Used;
         end;
      end if;
   end Recognize_Strip;

   procedure Recognize
     (File_Name : String; Into : in out Result; Ok : out Boolean; Message : out String; Last : out Natural)
   is
      Count  : constant Natural := Pomarine.Strips.Strip_Count (File_Name);
      Aspect : Float;
   begin
      if Count <= 1 then
         Recognize_Strip (File_Name, Into, Ok, Message, Last, Aspect);
         return;
      end if;

      --  A picture of strips, one under another: the words of each, with boxes
      --  as fractions of the whole, which is as tall as the strips together. Those
      --  are only known when every strip is read, so each is put where it belongs then.
      declare
         Shapes : array (1 .. Count) of Float := [others => 0.0];
         Ends   : array (1 .. Count) of Natural := [others => 0];
         --  How many words there are, with those of strip Each's.
         Total  : Float := 0.0;
         Above  : Float := 0.0;
         Lines  : Natural := 0;
      begin
         Pomarine.Words.Clear (Into);
         for Each in 1 .. Count loop
            declare
               Part  : Result;
               Wide  : Float;
               Start : constant Natural := Into.Count;
            begin
               Recognize_Strip (Pomarine.Strips.Strip_File (File_Name, Each), Part, Ok, Message, Last, Wide);
               if not Ok then
                  Pomarine.Words.Clear (Into);
                  return;
               end if;
               Pomarine.Words.Reserve (Into, Start + Part.Count, Into.Length + Part.Length);
               for Index in 1 .. Part.Count loop
                  declare
                     Found : Pomarine.Words.Word renames Into.Words (Start + Index);
                  begin
                     Found := Part.Words (Index);
                     Found.Line := Found.Line + Lines;
                     Found.First := Found.First + Into.Length;
                     Found.Last := Found.Last + Into.Length;
                     Lines := Natural'Max (Lines, Found.Line);
                  end;
               end loop;
               Into.Text (Into.Length + 1 .. Into.Length + Part.Length) := Part.Text (1 .. Part.Length);
               Into.Count := Start + Part.Count;
               Into.Length := Into.Length + Part.Length;
               Into.Truncated := Into.Truncated or else Part.Truncated;
               Shapes (Each) := Wide;
               Ends (Each) := Into.Count;
               Total := Total + Wide;
            end;
         end loop;
         Ok := True;
         Last := 0;
         if Total > 0.0 then
            for Each in 1 .. Count loop
               for Index in (if Each = 1 then 1 else Ends (Each - 1) + 1) .. Ends (Each) loop
                  declare
                     Found : Pomarine.Words.Word renames Into.Words (Index);
                  begin
                     Found.Top := (Above + Found.Top * Shapes (Each)) / Total;
                     Found.Height := Found.Height * Shapes (Each) / Total;
                  end;
               end loop;
               Above := Above + Shapes (Each);
            end loop;
         end if;
      end;
   end Recognize;

end Vision;
