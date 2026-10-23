with Ada.Environment_Variables;
with Ada.IO_Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Files;
with Growing;

package body Dotenv is

   use Ada.Strings.Unbounded;

   type Setting is record
      Key   : Unbounded_String;
      Value : Unbounded_String;
   end record;

   package Settings is new Growing (Setting);

   Held : Settings.List;

   LF : constant Character := Character'Val (10);
   CR : constant Character := Character'Val (13);
   HT : constant Character := Character'Val (9);

   function Is_Blank (C : Character) return Boolean is (C in ' ' | HT | CR);

   function Trim (Text : String) return String is
      First : Positive := Text'First;
      Last  : Natural  := Text'Last;
   begin
      while First <= Last and then Is_Blank (Text (First)) loop
         First := First + 1;
      end loop;
      while Last >= First and then Is_Blank (Text (Last)) loop
         Last := Last - 1;
      end loop;
      return Text (First .. Last);
   end Trim;

   function Find (Key : String) return Natural is
   begin
      for I in reverse 1 .. Held.Count loop
         if Held (I).Key = Key then
            return I;
         end if;
      end loop;
      return 0;
   end Find;

   procedure Put (Key, Setting_Value : String) is
      Place : constant Natural := Find (Key);
   begin
      if Place = 0 then
         Held.Append ((To_Unbounded_String (Key), To_Unbounded_String (Setting_Value)));
      else
         Held (Place).Value := To_Unbounded_String (Setting_Value);
      end if;
   end Put;

   function Unescape (Text : String) return String is
      Result : String (1 .. Text'Length);
      Last   : Natural := 0;
      I      : Positive := Text'First;
   begin
      while I <= Text'Last loop
         Last := Last + 1;
         if Text (I) = '\' and then I < Text'Last then
            I := I + 1;
            Result (Last) :=
              (case Text (I) is
                 when 'n'    => LF,
                 when 't'    => HT,
                 when 'r'    => CR,
                 when others => Text (I));
         else
            Result (Last) := Text (I);
         end if;
         I := I + 1;
      end loop;
      return Result (1 .. Last);
   end Unescape;

   function Quoted_Value (Text : String) return String is
      --  Text starts with a quote; the value is up to the matching one.
      Quote : constant Character := Text (Text'First);
      I     : Positive := Text'First + 1;
   begin
      while I <= Text'Last and then Text (I) /= Quote loop
         if Quote = '"' and then Text (I) = '\' then
            I := I + 1;
         end if;
         I := I + 1;
      end loop;
      if I > Text'Last then
         --  Never closed: the rest of the line, as written.
         return Trim (Text (Text'First + 1 .. Text'Last));
      end if;
      declare
         Inside : constant String := Text (Text'First + 1 .. I - 1);
      begin
         return (if Quote = '"' then Unescape (Inside) else Inside);
      end;
   end Quoted_Value;

   function Plain_Value (Text : String) return String is
   begin
      for I in Text'Range loop
         if Text (I) = '#' and then I > Text'First and then Is_Blank (Text (I - 1)) then
            return Trim (Text (Text'First .. I - 1));
         end if;
      end loop;
      return Trim (Text);
   end Plain_Value;

   procedure Parse_Line (Raw : String) is
      Line : constant String := Trim (Raw);
      Skip : constant Natural :=
        (if Line'Length > 7 and then Line (Line'First .. Line'First + 6) = "export " then 7 else 0);
      Body_Text : constant String := Trim (Line (Line'First + Skip .. Line'Last));
      Equals    : constant Natural := Ada.Strings.Fixed.Index (Body_Text, "=");
   begin
      if Body_Text'Length = 0 or else Body_Text (Body_Text'First) = '#' or else Equals = 0 then
         return;
      end if;
      declare
         Key  : constant String := Trim (Body_Text (Body_Text'First .. Equals - 1));
         Rest : constant String := Trim (Body_Text (Equals + 1 .. Body_Text'Last));
      begin
         if Key'Length = 0 then
            return;
         end if;
         if Rest'Length > 0 and then Rest (Rest'First) in '"' | ''' then
            Put (Key, Quoted_Value (Rest));
         else
            Put (Key, Plain_Value (Rest));
         end if;
      end;
   end Parse_Line;

   procedure Parse (Text : String) is
      Start : Positive := Text'First;
   begin
      for I in Text'Range loop
         if Text (I) = LF then
            Parse_Line (Text (Start .. I - 1));
            Start := I + 1;
         end if;
      end loop;
      if Start <= Text'Last then
         Parse_Line (Text (Start .. Text'Last));
      end if;
   end Parse;

   function Load (File_Name : String := Default_File) return Boolean is
   begin
      Parse (Files.Read (File_Name));
      return True;
   exception
      when Ada.IO_Exceptions.Name_Error =>
         return False;
   end Load;

   procedure Clear is
   begin
      Held.Clear;
   end Clear;

   function Count return Natural is (Held.Count);

   function Has (Key : String) return Boolean is
     (Ada.Environment_Variables.Exists (Key) or else Find (Key) /= 0);

   function Value (Key : String; Default : String := "") return String is
      Place : Natural;
   begin
      if Ada.Environment_Variables.Exists (Key) then
         return Ada.Environment_Variables.Value (Key);
      end if;
      Place := Find (Key);
      return (if Place = 0 then Default else To_String (Held (Place).Value));
   end Value;

end Dotenv;
