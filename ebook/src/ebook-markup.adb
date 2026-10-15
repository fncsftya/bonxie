with Ada.Characters.Handling;

package body Ebook.Markup is

   function Is_Space (C : Character) return Boolean is
     (C in ' ' | ASCII.HT | ASCII.LF | ASCII.CR | ASCII.FF);

   function Is_Name_Character (C : Character) return Boolean is
     (C in 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '-' | '_' | ':' | '.');

   function Local (Name : String) return String is
   begin
      for I in reverse Name'Range loop
         if Name (I) = ':' then
            return Name (I + 1 .. Name'Last);
         end if;
      end loop;
      return Name;
   end Local;

   function Find (Source : String; Pattern : String; From : Positive) return Natural is
   begin
      if Source'Last < Pattern'Length then
         return 0;
      end if;
      for I in From .. Source'Last - Pattern'Length + 1 loop
         if Source (I .. I + Pattern'Length - 1) = Pattern then
            return I;
         end if;
      end loop;
      return 0;
   end Find;

   procedure Next (Source : String; Cursor : in out Positive; Item : out Token) is
   begin
      Item := (others => <>);
      loop
         if Cursor > Source'Last then
            Item.Kind := Finished;
            return;
         end if;
         if Source (Cursor) /= '<' then
            Item.Kind := Text;
            Item.First := Cursor;
            while Cursor <= Source'Last and then Source (Cursor) /= '<' loop
               Cursor := Cursor + 1;
            end loop;
            Item.Last := Cursor - 1;
            return;
         end if;
         --  A tag, comment, CDATA section, declaration or instruction.
         if Source'Last >= Cursor + 3 and then Source (Cursor .. Cursor + 3) = "<!--" then
            declare
               Stop : constant Natural := Find (Source, "-->", Cursor + 4);
            begin
               Cursor := (if Stop = 0 then Source'Last + 1 else Stop + 3);
            end;
         elsif Source'Last >= Cursor + 8 and then Source (Cursor .. Cursor + 8) = "<![CDATA[" then
            declare
               Stop : constant Natural := Find (Source, "]]>", Cursor + 9);
            begin
               Item.Kind := Text;
               Item.First := Cursor + 9;
               Item.Last := (if Stop = 0 then Source'Last else Stop - 1);
               Cursor := (if Stop = 0 then Source'Last + 1 else Stop + 3);
               return;
            end;
         elsif Cursor < Source'Last and then Source (Cursor + 1) in '!' | '?' then
            while Cursor <= Source'Last and then Source (Cursor) /= '>' loop
               Cursor := Cursor + 1;
            end loop;
            Cursor := Cursor + 1;
         elsif Cursor < Source'Last
           and then (Is_Name_Character (Source (Cursor + 1)) or else Source (Cursor + 1) = '/')
         then
            declare
               Closing : constant Boolean := Source (Cursor + 1) = '/';
               Name_At : constant Positive := Cursor + (if Closing then 2 else 1);
               Stop    : Natural := Name_At;
               Quote   : Character := ' ';
            begin
               while Stop <= Source'Last and then Is_Name_Character (Source (Stop)) loop
                  Stop := Stop + 1;
               end loop;
               declare
                  Name : constant String :=
                    Ada.Characters.Handling.To_Lower (Local (Source (Name_At .. Stop - 1)));
                  Used : constant Natural := Natural'Min (Name'Length, Max_Name);
               begin
                  Item.Kind := (if Closing then End_Tag else Start_Tag);
                  Item.Name (1 .. Used) := Name (Name'First .. Name'First + Used - 1);
                  Item.Name_Length := Used;
               end;
               Item.First := Stop;
               --  To the closing >, which a quoted value may contain.
               while Stop <= Source'Last loop
                  if Quote /= ' ' then
                     if Source (Stop) = Quote then
                        Quote := ' ';
                     end if;
                  elsif Source (Stop) in '"' | ''' then
                     Quote := Source (Stop);
                  elsif Source (Stop) = '>' then
                     exit;
                  end if;
                  Stop := Stop + 1;
               end loop;
               Item.Last := Stop - 1;
               Item.Self_Closing := Item.Kind = Start_Tag and then Stop > Item.First
                 and then Source (Stop - 1) = '/';
               Cursor := Stop + 1;
               return;
            end;
         else
            --  A < that is only text.
            Item.Kind := Text;
            Item.First := Cursor;
            Cursor := Cursor + 1;
            while Cursor <= Source'Last and then Source (Cursor) /= '<' loop
               Cursor := Cursor + 1;
            end loop;
            Item.Last := Cursor - 1;
            return;
         end if;
      end loop;
   end Next;

   --  The attribute's value as written, and whether it is there.
   procedure Locate
     (Source : String; Item : Token; Name : String; Found : out Boolean; First, Last : out Natural)
   is
      At_Index : Natural := Item.First;
   begin
      Found := False;
      First := 1;
      Last := 0;
      while At_Index <= Item.Last loop
         while At_Index <= Item.Last and then (Is_Space (Source (At_Index)) or else Source (At_Index) = '/') loop
            At_Index := At_Index + 1;
         end loop;
         exit when At_Index > Item.Last;
         declare
            Name_At : constant Natural := At_Index;
         begin
            while At_Index <= Item.Last and then Is_Name_Character (Source (At_Index)) loop
               At_Index := At_Index + 1;
            end loop;
            if At_Index = Name_At then
               At_Index := At_Index + 1;   --  not a name: skip it
            else
               declare
                  Mine : constant String :=
                    Ada.Characters.Handling.To_Lower (Local (Source (Name_At .. At_Index - 1)));
                  V_First : Natural := 1;
                  V_Last  : Natural := 0;
               begin
                  while At_Index <= Item.Last and then Is_Space (Source (At_Index)) loop
                     At_Index := At_Index + 1;
                  end loop;
                  if At_Index <= Item.Last and then Source (At_Index) = '=' then
                     At_Index := At_Index + 1;
                     while At_Index <= Item.Last and then Is_Space (Source (At_Index)) loop
                        At_Index := At_Index + 1;
                     end loop;
                     if At_Index <= Item.Last and then Source (At_Index) in '"' | ''' then
                        declare
                           Quote : constant Character := Source (At_Index);
                        begin
                           At_Index := At_Index + 1;
                           V_First := At_Index;
                           while At_Index <= Item.Last and then Source (At_Index) /= Quote loop
                              At_Index := At_Index + 1;
                           end loop;
                           V_Last := At_Index - 1;
                           At_Index := At_Index + 1;
                        end;
                     else
                        V_First := At_Index;
                        while At_Index <= Item.Last and then not Is_Space (Source (At_Index)) loop
                           At_Index := At_Index + 1;
                        end loop;
                        V_Last := At_Index - 1;
                     end if;
                  end if;
                  if Mine = Name then
                     Found := True;
                     First := V_First;
                     Last := V_Last;
                     return;
                  end if;
               end;
            end if;
         end;
      end loop;
   end Locate;

   function Attribute (Source : String; Item : Token; Name : String) return String is
      Found       : Boolean;
      First, Last : Natural;
   begin
      Locate (Source, Item, Name, Found, First, Last);
      return (if Found then Decode (Source (First .. Last)) else "");
   end Attribute;

   function Has_Attribute (Source : String; Item : Token; Name : String) return Boolean is
      Found       : Boolean;
      First, Last : Natural;
   begin
      Locate (Source, Item, Name, Found, First, Last);
      return Found;
   end Has_Attribute;

   function UTF8 (Code : Natural) return String is
   begin
      if Code < 16#80# then
         return [1 => Character'Val (Code)];
      elsif Code < 16#800# then
         return [Character'Val (16#C0# + Code / 64), Character'Val (16#80# + Code mod 64)];
      elsif Code < 16#10000# then
         return [Character'Val (16#E0# + Code / 4096), Character'Val (16#80# + (Code / 64) mod 64),
                 Character'Val (16#80# + Code mod 64)];
      elsif Code < 16#110000# then
         return [Character'Val (16#F0# + Code / 262_144), Character'Val (16#80# + (Code / 4096) mod 64),
                 Character'Val (16#80# + (Code / 64) mod 64), Character'Val (16#80# + Code mod 64)];
      else
         return "?";
      end if;
   end UTF8;

   type Entity is record
      Name : String (1 .. 6);   --  padded with spaces
      Code : Natural;
   end record;

   Entities : constant array (Positive range <>) of Entity :=
     [("amp   ", 38),
      ("lt    ", 60),
      ("gt    ", 62),
      ("quot  ", 34),
      ("apos  ", 39),
      ("nbsp  ", 160),
      ("ndash ", 8211),
      ("mdash ", 8212),
      ("hellip", 8230),
      ("lsquo ", 8216),
      ("rsquo ", 8217),
      ("ldquo ", 8220),
      ("rdquo ", 8221),
      ("bull  ", 8226),
      ("middot", 183),
      ("copy  ", 169),
      ("reg   ", 174),
      ("trade ", 8482),
      ("deg   ", 176),
      ("times ", 215),
      ("divide", 247),
      ("laquo ", 171),
      ("raquo ", 187),
      ("sect  ", 167),
      ("para  ", 182),
      ("dagger", 8224),
      ("euro  ", 8364),
      ("pound ", 163),
      ("cent  ", 162),
      ("yen   ", 165),
      ("shy   ", 173),
      ("ensp  ", 8194),
      ("emsp  ", 8195),
      ("thinsp", 8201),
      ("aacute", 225),
      ("eacute", 233),
      ("iacute", 237),
      ("oacute", 243),
      ("uacute", 250),
      ("ntilde", 241),
      ("agrave", 224),
      ("egrave", 232),
      ("ccedil", 231),
      ("uuml  ", 252),
      ("ouml  ", 246),
      ("auml  ", 228),
      ("iexcl ", 161),
      ("iquest", 191)];

   function Named (Name : String) return Natural is
   begin
      --  0 if it is not known.
      if Name'Length > 6 then
         return 0;
      end if;
      declare
         Padded : constant String (1 .. 6) := Name & [1 .. 6 - Name'Length => ' '];
      begin
         for Each of Entities loop
            if Each.Name = Padded then
               return Each.Code;
            end if;
         end loop;
      end;
      return 0;
   end Named;

   function Decode (Raw : String) return String is
      Result : String (1 .. 4 * Raw'Length);
      Used   : Natural := 0;
      I      : Natural := Raw'First;

      procedure Put (Piece : String) is
      begin
         Result (Used + 1 .. Used + Piece'Length) := Piece;
         Used := Used + Piece'Length;
      end Put;
   begin
      while I <= Raw'Last loop
         if Raw (I) = '&' then
            declare
               Stop : Natural := I + 1;
               Code : Natural := 0;
            begin
               while Stop <= Raw'Last and then Stop - I <= 10 and then Raw (Stop) /= ';'
                 and then Raw (Stop) /= '&' and then not Is_Space (Raw (Stop))
               loop
                  Stop := Stop + 1;
               end loop;
               if Stop <= Raw'Last and then Raw (Stop) = ';' and then Stop > I + 1 then
                  declare
                     Name : constant String := Raw (I + 1 .. Stop - 1);
                  begin
                     if Name (Name'First) = '#' and then Name'Length > 1 then
                        declare
                           Hex : constant Boolean := Name (Name'First + 1) in 'x' | 'X';
                           Digits_At : constant Positive := Name'First + (if Hex then 2 else 1);
                        begin
                           Code := 0;
                           for K in Digits_At .. Name'Last loop
                              declare
                                 C : constant Character := Name (K);
                                 D : Integer := -1;
                              begin
                                 if C in '0' .. '9' then
                                    D := Character'Pos (C) - Character'Pos ('0');
                                 elsif Hex and then C in 'a' .. 'f' then
                                    D := Character'Pos (C) - Character'Pos ('a') + 10;
                                 elsif Hex and then C in 'A' .. 'F' then
                                    D := Character'Pos (C) - Character'Pos ('A') + 10;
                                 end if;
                                 if D < 0 or else Code > 16#10FFFF# then
                                    Code := 0;
                                    exit;
                                 end if;
                                 Code := Code * (if Hex then 16 else 10) + D;
                              end;
                           end loop;
                        end;
                     else
                        Code := Named (Name);
                     end if;
                  end;
               end if;
               if Code /= 0 then
                  Put (UTF8 (Code));
                  I := Stop + 1;
               else
                  Put ("&");
                  I := I + 1;
               end if;
            end;
         else
            Used := Used + 1;
            Result (Used) := Raw (I);
            I := I + 1;
         end if;
      end loop;
      return Result (1 .. Used);
   end Decode;

end Ebook.Markup;
