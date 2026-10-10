with Ada.Strings.Unbounded;

package body Typeset.Samples is

   type Generator is record
      State : Natural;
   end record;

   procedure Next
     (Gen : in out Generator; Limit : Positive; Value : out Natural)
   is
   begin
      Gen.State := (Gen.State * 1103 + 12345) mod 1_000_003;
      Value := (Gen.State / 3) mod Limit;
   end Next;

   type Bytes is array (Positive range <>) of Natural;

   function Text_Of (Item : Bytes) return String is
     (String'(for I in Item'Range => Character'Val (Item (I))));
   --  The string of these UTF-8 bytes.

   Foreign : constant array (0 .. 5) of access constant String :=
    [
     new String'
       (Text_Of
         ([
           227, 129, 147, 227, 130, 147, 227, 129, 171, 227, 129, 161,
           227, 129, 175])),
     new String'
       (Text_Of
         ([
           208, 159, 209, 128, 208, 184, 208, 178, 208, 181, 209, 130])),
     new String'
       (Text_Of
         ([
           240, 159, 152, 128])),
     new String'
       (Text_Of
         ([
           110, 97, 195, 175, 118, 101, 32, 99, 97, 102, 195, 169])),
     new String'
       (Text_Of
         ([
           217, 133, 216, 177, 216, 173, 216, 168, 216, 167])),
     new String'
       (Text_Of
         ([
           230, 151, 165, 230, 156, 172, 232, 170, 158, 227, 129, 174,
           227, 131, 134, 227, 130, 173, 227, 130, 185, 227, 131, 136]))];
   --  Hello in Japanese, Russian, an emoji, accents, Arabic, Japanese.

   function Document
     (Paragraphs : Positive; Seed : Natural := 1) return String
   is
      use Ada.Strings.Unbounded;
      Gen    : Generator := (State => Seed + 7);
      Result : Unbounded_String;
      Roll, Words, Size : Natural;

      procedure Word is
         Letters : Natural;
         Pick    : Natural;
      begin
         Next (Gen, 40, Pick);
         if Pick = 0 then
            Next (Gen, Foreign'Length, Pick);
            Append (Result, Foreign (Pick).all);
         else
            Next (Gen, 9, Letters);
            for K in 0 .. Letters + 1 loop
               Next (Gen, 26, Pick);
               Append (Result, Character'Val (97 + Pick));
            end loop;
         end if;
      end Word;
   begin
      for P in 1 .. Paragraphs loop
         Next (Gen, 100, Roll);
         Size := (if Roll < 5 then 1
                  elsif Roll < 95 then 20 + Roll
                  elsif Roll < 99 then 400
                  else 4000);
         Next (Gen, 40, Words);
         Words := Size + (if Size > 1 then Words else 0);
         for W in 1 .. Words loop
            if W > 1 then
               Append (Result, ' ');
            end if;
            Word;
         end loop;
         if P < Paragraphs then
            Append (Result, ASCII.LF);
         end if;
      end loop;
      return To_String (Result);
   end Document;

end Typeset.Samples;
