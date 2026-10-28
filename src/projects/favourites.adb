with Ada.Directories;
with Ada.IO_Exceptions;
with Ada.Strings.Fixed;
with Files;

package body Favourites is

   package Strings renames Ada.Strings.Unbounded;

   Tab : constant Character := ASCII.HT;

   function Plain (Text : String) return String;
   --  A line's own: with no tab or line end in it.

   function Plain (Text : String) return String is
      Result : String := Text;
   begin
      for Each of Result loop
         if Each in ASCII.HT | ASCII.LF | ASCII.CR then
            Each := ' ';
         end if;
      end loop;
      return Result;
   end Plain;

   function Hex (Value : Natural) return String is
      Digits_Of : constant String := "0123456789abcdef";
      Result    : String (1 .. 6);
      Rest      : Natural := Value;
   begin
      for I in reverse Result'Range loop
         Result (I) := Digits_Of (Rest mod 16 + 1);
         Rest := Rest / 16;
      end loop;
      return Result;
   end Hex;

   function Colour_From (Text : String) return Integer is
      Value : Natural := 0;
   begin
      if Text'Length /= 6 then
         return -1;
      end if;
      for Each of Text loop
         Value :=
           Value
           * 16
           + (case Each is
                when '0' .. '9' => Character'Pos (Each) - Character'Pos ('0'),
                when 'a' .. 'f' => Character'Pos (Each) - Character'Pos ('a') + 10,
                when others     => raise Constraint_Error);
      end loop;
      return Value;
   exception
      when Constraint_Error =>
         return -1;
   end Colour_From;

   procedure Add_Line (Into : in out Lists.List; Line : String);
   --  Hold the favourite a line of the file is, if it is one.

   procedure Add_Line (Into : in out Lists.List; Line : String) is
      Cut   : constant Natural := Ada.Strings.Fixed.Index (Line, String'(1 => Tab));
      Cut_2 : constant Natural :=
        (if Cut = 0 then 0 else Ada.Strings.Fixed.Index (Line (Cut + 1 .. Line'Last), String'(1 => Tab)));
   begin
      if Cut_2 > 0 then
         Lists.Append
           (Into,
            (Colour  => Colour_From (Line (Line'First .. Cut - 1)),
             Address => Strings.To_Unbounded_String (Line (Cut + 1 .. Cut_2 - 1)),
             Title   => Strings.To_Unbounded_String (Line (Cut_2 + 1 .. Line'Last))));
      end if;
   end Add_Line;

   procedure Load (Config : String; Into : in out Lists.List) is
   begin
      Lists.Clear (Into);
      declare
         Text  : constant String := Files.Read (File_Name (Config));
         First : Positive := Text'First;
         Last  : Natural;
      begin
         while First <= Text'Last loop
            Last := First;
            while Last <= Text'Last and then Text (Last) /= ASCII.LF loop
               Last := Last + 1;
            end loop;
            Add_Line (Into, Text (First .. Last - 1));
            First := Last + 1;
         end loop;
      end;
   exception
      when Ada.IO_Exceptions.Name_Error | Ada.IO_Exceptions.Use_Error | Ada.IO_Exceptions.End_Error =>
         null;
   end Load;

   procedure Save (Config : String; From : Lists.List) is
      Text : Strings.Unbounded_String;
   begin
      for Each of From loop
         Strings.Append
           (Text,
            (if Each.Colour in 0 .. 16#FFFFFF# then Hex (Each.Colour) else "-")
            & Tab
            & Plain (Strings.To_String (Each.Address))
            & Tab
            & Plain (Strings.To_String (Each.Title))
            & ASCII.LF);
      end loop;
      Ada.Directories.Create_Path (Config);
      Files.Write (File_Name (Config), Strings.To_String (Text));
   exception
      when Ada.IO_Exceptions.Use_Error | Ada.IO_Exceptions.Name_Error =>
         null;
   end Save;

   function Index_Of (From : Lists.List; Address : String) return Natural is
   begin
      for I in 1 .. From.Count loop
         if Strings.To_String (From (I).Address) = Address then
            return I;
         end if;
      end loop;
      return 0;
   end Index_Of;

   function Colour_Of (Address : String) return Natural is
      Start : Natural := Ada.Strings.Fixed.Index (Address, "://");
      Hash  : Natural := 5381;
   begin
      Start := (if Start > 0 then Start + 3 else Address'First);
      for I in Start .. Address'Last loop
         exit when Address (I) in '/' | '?' | '#';
         Hash := (Hash * 33 + Character'Pos (Address (I))) mod 2**24;
      end loop;
      return Hash;
   end Colour_Of;

end Favourites;
