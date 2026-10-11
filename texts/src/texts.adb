package body Texts is

   function End_After (From : Position; Added : String) return Position is
      Result : Position := From;
   begin
      for C of Added loop
         if C = ASCII.LF then
            Result := (Result.Paragraph + 1, 1);
         else
            Result.Index := Result.Index + 1;
         end if;
      end loop;
      return Result;
   end End_After;

   function UTF16_Length (Text : String) return Natural is
      Result : Natural := 0;
   begin
      for C of Text loop
         Result := Result + Units_Of (C);
      end loop;
      return Result;
   end UTF16_Length;

end Texts;
