package body Model_Replies is

   procedure Find_Object (Reply : String; First, Last : out Natural) is
   begin
      if Reply'Length = 0 then
         First := 0;
         Last := 0;
      else
         Find_Object (Reply, Reply'First, First, Last);
      end if;
   end Find_Object;

   procedure Find_Object (Reply : String; From : Positive; First, Last : out Natural) is
      Depth : Natural := 0;
      Quoted, Escaped : Boolean := False;
   begin
      First := 0;
      Last := 0;
      for Index in From .. Reply'Last loop
         declare
            C : constant Character := Reply (Index);
         begin
            if First = 0 then
               if C = '{' then
                  First := Index;
                  Depth := 1;
               end if;
            elsif Quoted then
               if Escaped then
                  Escaped := False;
               elsif C = '\' then
                  Escaped := True;
               elsif C = '"' then
                  Quoted := False;
               end if;
            elsif C = '"' then
               Quoted := True;
            elsif C = '{' then
               Depth := Depth + 1;
            elsif C = '}' then
               Depth := Depth - 1;
               if Depth = 0 then
                  Last := Index;
                  return;
               end if;
            end if;
         end;
      end loop;
      --  An opening brace that is never closed is not an object: look past it.
      if First /= 0 and then First < Reply'Last then
         declare
            Start : constant Positive := First + 1;
         begin
            Find_Object (Reply, Start, First, Last);
         end;
      else
         First := 0;
      end if;
   end Find_Object;

   function Cut (Text : String; Limit : Natural) return String is
      Last : Natural := Text'First - 1 + Natural'Min (Limit, Text'Length);
   begin
      --  Not in the middle of a UTF-8 character: back to before its first byte.
      if Last < Text'Last then
         while Last >= Text'First and then Character'Pos (Text (Last + 1)) in 16#80# .. 16#BF# loop
            Last := Last - 1;
         end loop;
      end if;
      return Text (Text'First .. Last);
   end Cut;

   function Tidy (Text : String; Limit : Natural) return String is
      Result : String (1 .. Text'Length);
      Length : Natural := 0;
      Gap    : Boolean := False;
   begin
      for C of Text loop
         if C <= ' ' or else C = Character'Val (127) then
            Gap := Length > 0;
         else
            if Gap then
               Length := Length + 1;
               Result (Length) := ' ';
               Gap := False;
            end if;
            Length := Length + 1;
            Result (Length) := C;
         end if;
      end loop;
      return Cut (Result (1 .. Length), Limit);
   end Tidy;

end Model_Replies;
