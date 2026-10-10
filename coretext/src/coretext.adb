package body CoreText is

   function UTF16_Length (Text : String) return Natural is
      Count : Natural := 0;
   begin
      for C of Text loop
         case Character'Pos (C) is
            when 16#80# .. 16#BF# => null;  --  continuation byte
            when 16#F0# .. 16#FF# => Count := Count + 2;  --  surrogate pair
            when others           => Count := Count + 1;
         end case;
      end loop;
      return Count;
   end UTF16_Length;

end CoreText;
