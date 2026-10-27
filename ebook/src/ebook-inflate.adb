package body Ebook.Inflate is

   Max_Bits : constant := 15;

   type Count_Array is array (0 .. Max_Bits) of Natural;
   type Symbol_Array is array (Natural range <>) of Natural;

   --  A canonical Huffman code: how many codes there are of each length,
   --  and the symbols in the order of their codes.
   type Code (Symbols : Natural) is record
      Count  : Count_Array := [others => 0];
      Symbol : Symbol_Array (0 .. Symbols) := [others => 0];
   end record;

   type Length_Array is array (Natural range <>) of Natural;

   procedure Build (Item : out Code; Lengths : Length_Array; Complete : out Boolean) is
      Offset : array (0 .. Max_Bits + 1) of Natural := [others => 0];
      Left   : Integer := 1;
   begin
      Item.Count := [others => 0];
      for L of Lengths loop
         Item.Count (L) := Item.Count (L) + 1;
      end loop;
      Complete := True;
      for Bits in 1 .. Max_Bits loop
         Left := 2 * Left - Item.Count (Bits);
         if Left < 0 then
            Complete := False;   --  over-subscribed
            return;
         end if;
      end loop;
      for Bits in 1 .. Max_Bits loop
         Offset (Bits + 1) := Offset (Bits) + Item.Count (Bits);
      end loop;
      for Index in Lengths'Range loop
         if Lengths (Index) /= 0 then
            Item.Symbol (Offset (Lengths (Index))) := Index - Lengths'First;
            Offset (Lengths (Index)) := Offset (Lengths (Index)) + 1;
         end if;
      end loop;
   end Build;

   Length_Base    : constant array (0 .. 28) of Natural :=
     [3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      13,
      15,
      17,
      19,
      23,
      27,
      31,
      35,
      43,
      51,
      59,
      67,
      83,
      99,
      115,
      131,
      163,
      195,
      227,
      258];
   Length_Extra   : constant array (0 .. 28) of Natural :=
     [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0];
   Distance_Base  : constant array (0 .. 29) of Natural :=
     [1,
      2,
      3,
      4,
      5,
      7,
      9,
      13,
      17,
      25,
      33,
      49,
      65,
      97,
      129,
      193,
      257,
      385,
      513,
      769,
      1025,
      1537,
      2049,
      3073,
      4097,
      6145,
      8193,
      12289,
      16385,
      24577];
   Distance_Extra : constant array (0 .. 29) of Natural :=
     [0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13];
   Order          : constant array (0 .. 18) of Natural :=
     [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15];

   procedure Run (Packed : String; Size : Natural; Result : out String; Ok : out Boolean) is
      Next   : Natural := Packed'First;   --  the next byte to read
      Buffer : Natural := 0;
      Held   : Natural := 0;              --  bits in Buffer
      Used   : Natural := 0;              --  bytes of Result made
      Bad    : exception;

      function Bits (Count : Natural) return Natural is
         Value : Natural;
      begin
         while Held < Count loop
            if Next > Packed'Last then
               raise Bad;
            end if;
            Buffer := Buffer + Character'Pos (Packed (Next)) * 2**Held;
            Next := Next + 1;
            Held := Held + 8;
         end loop;
         Value := Buffer mod 2**Count;
         Buffer := Buffer / 2**Count;
         Held := Held - Count;
         return Value;
      end Bits;

      function Decode (Using : Code) return Natural is
         First : Integer := 0;
         Index : Integer := 0;
         Value : Integer := 0;
      begin
         for Length in 1 .. Max_Bits loop
            Value := Value + Bits (1);
            declare
               Count : constant Integer := Using.Count (Length);
            begin
               if Value - Count < First then
                  return Using.Symbol (Index + (Value - First));
               end if;
               Index := Index + Count;
               First := (First + Count) * 2;
               Value := Value * 2;
            end;
         end loop;
         raise Bad;
      end Decode;

      procedure Put (Byte : Natural) is
      begin
         if Used >= Size then
            raise Bad;
         end if;
         Used := Used + 1;
         Result (Result'First + Used - 1) := Character'Val (Byte);
      end Put;

      procedure Codes (Literals : Code; Distances : Code) is
      begin
         loop
            declare
               Symbol : constant Natural := Decode (Literals);
            begin
               if Symbol < 256 then
                  Put (Symbol);
               elsif Symbol = 256 then
                  return;
               else
                  declare
                     Index    : constant Natural := Symbol - 257;
                     Length   : Natural;
                     Distance : Natural;
                  begin
                     if Index > 28 then
                        raise Bad;
                     end if;
                     Length := Length_Base (Index) + Bits (Length_Extra (Index));
                     Index_Check :
                     declare
                        Slot : constant Natural := Decode (Distances);
                     begin
                        if Slot > 29 then
                           raise Bad;
                        end if;
                        Distance := Distance_Base (Slot) + Bits (Distance_Extra (Slot));
                     end Index_Check;
                     if Distance > Used or else Used + Length > Size then
                        raise Bad;
                     end if;
                     for Each in 1 .. Length loop
                        Result (Result'First + Used) := Result (Result'First + Used - Distance);
                        Used := Used + 1;
                     end loop;
                  end;
               end if;
            end;
         end loop;
      end Codes;

      Fixed_Literals  : Code (287);
      Fixed_Distances : Code (29);

      procedure Fixed is
         Lengths : Length_Array (0 .. 287);
         Short   : constant Length_Array (0 .. 29) := [others => 5];
         Done    : Boolean;
      begin
         for Index in Lengths'Range loop
            Lengths (Index) := (if Index < 144 then 8 elsif Index < 256 then 9 elsif Index < 280 then 7 else 8);
         end loop;
         Build (Fixed_Literals, Lengths, Done);
         Build (Fixed_Distances, Short, Done);
         Codes (Fixed_Literals, Fixed_Distances);
      end Fixed;

      procedure Dynamic is
         Literal_Count  : constant Natural := Bits (5) + 257;
         Distance_Count : constant Natural := Bits (5) + 1;
         Length_Count   : constant Natural := Bits (4) + 4;
         Lengths        : Length_Array (0 .. 318) := [others => 0];
         Header         : Length_Array (0 .. 18) := [others => 0];
         Header_Code    : Code (18);
         Literals       : Code (287);
         Distances      : Code (29);
         Index          : Natural := 0;
         Done           : Boolean;
      begin
         if Literal_Count > 286 or else Distance_Count > 30 then
            raise Bad;
         end if;
         for Each in 0 .. Length_Count - 1 loop
            Header (Order (Each)) := Bits (3);
         end loop;
         Build (Header_Code, Header, Done);
         if not Done then
            raise Bad;
         end if;
         while Index < Literal_Count + Distance_Count loop
            declare
               Symbol : constant Natural := Decode (Header_Code);
               Value  : Natural := 0;
               Repeat : Natural;
            begin
               if Symbol < 16 then
                  Lengths (Index) := Symbol;
                  Index := Index + 1;
               else
                  if Symbol = 16 then
                     if Index = 0 then
                        raise Bad;
                     end if;
                     Value := Lengths (Index - 1);
                     Repeat := 3 + Bits (2);
                  elsif Symbol = 17 then
                     Repeat := 3 + Bits (3);
                  else
                     Repeat := 11 + Bits (7);
                  end if;
                  if Index + Repeat > Literal_Count + Distance_Count then
                     raise Bad;
                  end if;
                  for Each in 1 .. Repeat loop
                     Lengths (Index) := Value;
                     Index := Index + 1;
                  end loop;
               end if;
            end;
         end loop;
         if Lengths (256) = 0 then
            raise Bad;
         end if;
         Build (Literals, Lengths (0 .. Literal_Count - 1), Done);
         if not Done then
            raise Bad;
         end if;
         Build (Distances, Lengths (Literal_Count .. Literal_Count + Distance_Count - 1), Done);
         if not Done then
            raise Bad;
         end if;
         Codes (Literals, Distances);
      end Dynamic;

      procedure Stored is
         Length, Inverse : Natural;
      begin
         Buffer := 0;
         Held := 0;   --  to a byte boundary
         if Next + 3 > Packed'Last then
            raise Bad;
         end if;
         Length := Character'Pos (Packed (Next)) + 256 * Character'Pos (Packed (Next + 1));
         Inverse := Character'Pos (Packed (Next + 2)) + 256 * Character'Pos (Packed (Next + 3));
         Next := Next + 4;
         if Length + Inverse /= 65_535 or else Next + Length - 1 > Packed'Last or else Used + Length > Size then
            raise Bad;
         end if;
         Result (Result'First + Used .. Result'First + Used + Length - 1) := Packed (Next .. Next + Length - 1);
         Used := Used + Length;
         Next := Next + Length;
      end Stored;

      Last_Block : Boolean;
   begin
      Ok := False;
      loop
         Last_Block := Bits (1) = 1;
         case Bits (2) is
            when 0      =>
               Stored;

            when 1      =>
               Fixed;

            when 2      =>
               Dynamic;

            when others =>
               raise Bad;
         end case;
         exit when Last_Block;
      end loop;
      Ok := Used = Size;
   exception
      when Bad =>
         Ok := False;
   end Run;

end Ebook.Inflate;
