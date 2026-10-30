package body Updater.Manifests is

   function Parse (Text : String; Item : out Manifest) return Boolean is
      At_Line : Natural := Text'First;

      function Next_Line return String;
      --  The line from At_Line on, without its line feed; At_Line moves past it.

      function Next_Line return String is
         First : constant Natural := At_Line;
      begin
         while At_Line <= Text'Last and then Text (At_Line) /= ASCII.LF loop
            At_Line := At_Line + 1;
         end loop;
         if At_Line > Text'Last then
            --  A line must end.
            At_Line := Text'Last + 2;
            return "";
         end if;
         At_Line := At_Line + 1;
         return Text (First .. At_Line - 2);
      end Next_Line;

      function Field (Line, Name : String) return String
      is (if Line'Length > Name'Length + 1 and then Line (Line'First .. Line'First + Name'Length) = Name & ' '
          then Line (Line'First + Name'Length + 1 .. Line'Last)
          else "");

   begin
      Item := (others => <>);
      if Next_Line /= Format_Line then
         return False;
      end if;
      if not Versions.Parse (Field (Next_Line, "version"), Item.Version) then
         return False;
      end if;
      if Field (Next_Line, "file") /= Disk_Image_Name then
         return False;
      end if;
      declare
         Size : constant String := Field (Next_Line, "size");
      begin
         if Size'Length not in 1 .. 12 or else not (for all Each of Size => Each in '0' .. '9') then
            return False;
         end if;
         Item.Size := Long_Long_Integer'Value (Size);
      end;
      declare
         Digest : constant String := Field (Next_Line, "sha256");
      begin
         if Digest'Length /= Hex_Digest'Length or else not (for all Each of Digest => Each in '0' .. '9' | 'a' .. 'f')
         then
            return False;
         end if;
         Item.Digest := Digest;
      end;
      return At_Line = Text'Last + 1;
   end Parse;

   function Image (Item : Manifest) return String is
      Size : constant String := Item.Size'Image;
   begin
      return
        Format_Line
        & ASCII.LF
        & "version "
        & Versions.Image (Item.Version)
        & ASCII.LF
        & "file "
        & Disk_Image_Name
        & ASCII.LF
        & "size "
        & Size (Size'First + 1 .. Size'Last)
        & ASCII.LF
        & "sha256 "
        & Item.Digest
        & ASCII.LF;
   end Image;

end Updater.Manifests;
