package body Updater.Versions is

   function Number (Text : String; Value : out Digits_Count) return Boolean;
   --  Whether Text is one to nine digits: its value.

   function Number (Text : String; Value : out Digits_Count) return Boolean is
   begin
      Value := 0;
      if Text'Length not in 1 .. 9 then
         return False;
      end if;
      for Each of Text loop
         if Each not in '0' .. '9' then
            return False;
         end if;
         Value := Value * 10 + (Character'Pos (Each) - Character'Pos ('0'));
      end loop;
      return True;
   end Number;

   function Parse (Text : String; Item : out Version) return Boolean is
      First : Natural := Text'First;
      Last  : Natural := Text'Last;
      Dots  : array (1 .. 2) of Natural := [others => 0];
      Found : Natural := 0;
      Dash  : Natural := 0;
   begin
      Item := (others => <>);
      if First <= Last and then Text (First) = 'v' then
         First := First + 1;
      end if;
      for At_Plus in First .. Last loop
         if Text (At_Plus) = '+' then
            Last := At_Plus - 1;
            exit;
         end if;
      end loop;
      if First > Last then
         return False;
      end if;
      for At_Mark in First .. Last loop
         if Text (At_Mark) = '-' then
            Dash := At_Mark;
            exit;
         end if;
      end loop;
      declare
         Core_Last : constant Natural := (if Dash = 0 then Last else Dash - 1);
      begin
         for At_Dot in First .. Core_Last loop
            if Text (At_Dot) = '.' then
               Found := Found + 1;
               if Found > 2 then
                  return False;
               end if;
               Dots (Found) := At_Dot;
            end if;
         end loop;
         if Found /= 2 then
            return False;
         end if;
         if not Number (Text (First .. Dots (1) - 1), Item.Major)
           or else not Number (Text (Dots (1) + 1 .. Dots (2) - 1), Item.Minor)
           or else not Number (Text (Dots (2) + 1 .. Core_Last), Item.Patch)
         then
            return False;
         end if;
      end;
      if Dash /= 0 then
         declare
            Pre : constant String := Text (Dash + 1 .. Last);
         begin
            if Pre'Length not in 1 .. Max_Prerelease then
               return False;
            end if;
            for Each of Pre loop
               if Each not in '0' .. '9' | 'a' .. 'z' | 'A' .. 'Z' | '-' | '.' then
                  return False;
               end if;
            end loop;
            Item.Pre_Length := Pre'Length;
            Item.Pre (1 .. Pre'Length) := Pre;
         end;
      end if;
      return True;
   end Parse;

   function Image (Item : Version) return String is
      function Part (Value : Digits_Count) return String is
         Text : constant String := Value'Image;
      begin
         return Text (Text'First + 1 .. Text'Last);
      end Part;

      Core : constant String := Part (Item.Major) & "." & Part (Item.Minor) & "." & Part (Item.Patch);
   begin
      return (if Item.Pre_Length = 0 then Core else Core & "-" & Item.Pre (1 .. Item.Pre_Length));
   end Image;

   function Is_Prerelease (Item : Version) return Boolean
   is (Item.Pre_Length > 0);

   function Sign (Left, Right : Natural) return Integer
   is (if Left < Right then -1 elsif Left > Right then 1 else 0);

   function Is_Numeric (Text : String) return Boolean
   is (Text'Length > 0 and then (for all Each of Text => Each in '0' .. '9'));

   function Compare_Identifier (Left, Right : String) return Integer;
   --  One dot-separated part of a prerelease: numbers by value and before words, words by their letters.

   function Compare_Identifier (Left, Right : String) return Integer is
      Left_Number  : constant Boolean := Is_Numeric (Left);
      Right_Number : constant Boolean := Is_Numeric (Right);
   begin
      if Left_Number and then Right_Number then
         if Left'Length /= Right'Length then
            --  (Without leading zeros, which semantic versioning does not allow, the longer is the larger.)
            return Sign (Left'Length, Right'Length);
         end if;
      elsif Left_Number then
         return -1;
      elsif Right_Number then
         return 1;
      end if;
      return (if Left < Right then -1 elsif Left > Right then 1 else 0);
   end Compare_Identifier;

   function Compare_Prerelease (Left, Right : String) return Integer;

   function Compare_Prerelease (Left, Right : String) return Integer is
      Left_At  : Natural := Left'First;
      Right_At : Natural := Right'First;
   begin
      while Left_At <= Left'Last and then Right_At <= Right'Last loop
         declare
            Left_End  : Natural := Left_At;
            Right_End : Natural := Right_At;
         begin
            while Left_End < Left'Last and then Left (Left_End + 1) /= '.' loop
               Left_End := Left_End + 1;
            end loop;
            while Right_End < Right'Last and then Right (Right_End + 1) /= '.' loop
               Right_End := Right_End + 1;
            end loop;
            declare
               Result : constant Integer :=
                 Compare_Identifier (Left (Left_At .. Left_End), Right (Right_At .. Right_End));
            begin
               if Result /= 0 then
                  return Result;
               end if;
            end;
            Left_At := Left_End + 2;
            Right_At := Right_End + 2;
         end;
      end loop;
      --  The one with more parts to it is the later.
      return Sign (Boolean'Pos (Left_At <= Left'Last), Boolean'Pos (Right_At <= Right'Last));
   end Compare_Prerelease;

   function Compare (Left, Right : Version) return Integer is
   begin
      if Left.Major /= Right.Major then
         return Sign (Left.Major, Right.Major);
      elsif Left.Minor /= Right.Minor then
         return Sign (Left.Minor, Right.Minor);
      elsif Left.Patch /= Right.Patch then
         return Sign (Left.Patch, Right.Patch);
      elsif Left.Pre_Length = 0 or else Right.Pre_Length = 0 then
         --  A prerelease comes before the version it leads up to.
         return Sign (Boolean'Pos (Left.Pre_Length = 0), Boolean'Pos (Right.Pre_Length = 0));
      else
         return Compare_Prerelease (Left.Pre (1 .. Left.Pre_Length), Right.Pre (1 .. Right.Pre_Length));
      end if;
   end Compare;

end Updater.Versions;
