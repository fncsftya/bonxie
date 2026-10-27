with Interfaces;

package body Exports.Zips is

   use type Interfaces.Unsigned_32;

   subtype Word is Interfaces.Unsigned_32;

   function Table_Entry (Index : Natural) return Word is
      Value : Word := Word (Index);
   begin
      for Bit in 1 .. 8 loop
         Value :=
           (if (Value and 1) = 1
            then Interfaces.Shift_Right (Value, 1) xor 16#EDB8_8320#
            else Interfaces.Shift_Right (Value, 1));
      end loop;
      return Value;
   end Table_Entry;

   Table : constant array (Natural range 0 .. 255) of Word := [for Each in 0 .. 255 => Table_Entry (Each)];

   function Checksum (Data : String) return Word is
      Value : Word := 16#FFFF_FFFF#;
   begin
      for C of Data loop
         Value :=
           Table (Natural ((Value xor Word (Character'Pos (C))) and 16#FF#)) xor Interfaces.Shift_Right (Value, 8);
      end loop;
      return not Value;
   end Checksum;

   function Little (Value : Word; Bytes : Positive) return String is
   begin
      return
        [for Each in 1 .. Bytes => Character'Val (Natural (Interfaces.Shift_Right (Value, 8 * (Each - 1)) and 16#FF#))];
   end Little;

   Date_Of_Files : constant Word := (2026 - 1980) * 512 + 1 * 32 + 1;
   --  MS-DOS date: years since 1980, month, day.

   Needed      : constant := 20;
   Name_In_UTF : constant := 16#0800#;

   procedure Add (Into : in out Archive; Name : String; Data : String) is
   begin
      Into.Files.Append (File_Entry'(Unbounded.To_Unbounded_String (Name), Unbounded.To_Unbounded_String (Data)));
   end Add;

   function Count (Item : Archive) return Natural
   is (Natural (Item.Files.Length));

   function Image (Item : Archive) return String is
      Made      : Unbounded.Unbounded_String;
      Directory : Unbounded.Unbounded_String;
   begin
      for Each of Item.Files loop
         declare
            Name   : constant String := Unbounded.To_String (Each.Name);
            Data   : constant String := Unbounded.To_String (Each.Data);
            Sum    : constant Word := Checksum (Data);
            Where  : constant Word := Word (Unbounded.Length (Made));
            Shared : constant String :=
              Little (Needed, 2)
              & Little (Name_In_UTF, 2)
              & Little (0, 2)  --  stored
              & Little (0, 2)  --  time
              & Little (Date_Of_Files, 2)
              & Little (Sum, 4)
              & Little (Word (Data'Length), 4)
              & Little (Word (Data'Length), 4)
              & Little (Word (Name'Length), 2);
         begin
            Unbounded.Append (Made, "PK" & ASCII.ETX & ASCII.EOT & Shared & Little (0, 2) & Name & Data);
            Unbounded.Append
              (Directory,
               "PK"
               & ASCII.SOH
               & ASCII.STX
               & Little (Needed, 2)  --  made by
               & Shared
               & Little (0, 2)  --  extra
               & Little (0, 2)  --  comment
               & Little (0, 2)  --  disk
               & Little (0, 2)  --  internal attributes
               & Little (0, 4)  --  external attributes
               & Little (Where, 4)
               & Name);
         end;
      end loop;
      declare
         Start : constant Word := Word (Unbounded.Length (Made));
         Total : constant Word := Word (Item.Files.Length);
      begin
         Unbounded.Append (Made, Directory);
         Unbounded.Append
           (Made,
            "PK"
            & ASCII.ENQ
            & ASCII.ACK
            & Little (0, 2)  --  this disk
            & Little (0, 2)  --  disk of the directory
            & Little (Total, 2)
            & Little (Total, 2)
            & Little (Word (Unbounded.Length (Directory)), 4)
            & Little (Start, 4)
            & Little (0, 2));
      end;
      return Unbounded.To_String (Made);
   end Image;

end Exports.Zips;
