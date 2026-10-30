with Ada.Strings.Fixed;
with JSON.Parsers;
with JSON.Types;

package body Updater.Releases is

   package Unbounded renames Ada.Strings.Unbounded;

   package Types is new JSON.Types (Long_Long_Integer, Long_Float);
   package Parsers is new JSON.Parsers (Types);

   use type Types.Value_Kind;

   Download_Prefix : constant String := "https://github.com/" & Repository & "/releases/download/";

   function Is_Download_URL (Text : String) return Boolean
   is (Text'Length > Download_Prefix'Length
       and then Text (Text'First .. Text'First + Download_Prefix'Length - 1) = Download_Prefix
       and then (for all Each of Text => Character'Pos (Each) in 33 .. 126));

   function Text_Of (Object : Types.JSON_Value; Key : String) return String;
   --  The string at Key, "" if there is none.

   function Text_Of (Object : Types.JSON_Value; Key : String) return String is
   begin
      if Object.Kind = Types.Object_Kind
        and then Object.Contains (Key)
        and then Object.Get (Key).Kind = Types.String_Kind
      then
         return Object.Get (Key).Value;
      end if;
      return "";
   end Text_Of;

   function Flag_Of (Object : Types.JSON_Value; Key : String) return Boolean;
   --  Whether Key is true; a missing or odd one is, to be safe, true.

   function Flag_Of (Object : Types.JSON_Value; Key : String) return Boolean is
   begin
      return
        not Object.Contains (Key) or else Object.Get (Key).Kind /= Types.Boolean_Kind or else Object.Get (Key).Value;
   end Flag_Of;

   function Parse (Text : String; Item : out Release) return Boolean is
      Image, Manifest, Signature : Boolean := False;
      --  Which of the assets have been found.
   begin
      Item := (Version => <>, others => Unbounded.Null_Unbounded_String);
      declare
         --  (In a block of its own: text that is not JSON fails here, and is not a release.)
         Source : Parsers.Parser := Parsers.Create (Text);
         Root   : constant Types.JSON_Value := Parsers.Parse (Source);
      begin
         if Root.Kind /= Types.Object_Kind
           or else Flag_Of (Root, "draft")
           or else Flag_Of (Root, "prerelease")
           or else not Versions.Parse (Text_Of (Root, "tag_name"), Item.Version)
           or else not Root.Contains ("assets")
           or else Root.Get ("assets").Kind /= Types.Array_Kind
         then
            return False;
         end if;
         Item.Notes := Unbounded.To_Unbounded_String (Text_Of (Root, "body"));
         Item.Page_URL := Unbounded.To_Unbounded_String (Text_Of (Root, "html_url"));
         for Index in 1 .. Root.Get ("assets").Length loop
            declare
               Asset : constant Types.JSON_Value := Root.Get ("assets").Get (Index);
               Name  : constant String := Text_Of (Asset, "name");
               URL   : constant String := Text_Of (Asset, "browser_download_url");
               Value : constant Unbounded.Unbounded_String := Unbounded.To_Unbounded_String (URL);
            begin
               if Is_Download_URL (URL) then
                  if Name = Disk_Image_Name then
                     Item.Disk_Image_URL := Value;
                     Image := True;
                  elsif Name = Manifest_Name then
                     Item.Manifest_URL := Value;
                     Manifest := True;
                  elsif Name = Signature_Name then
                     Item.Signature_URL := Value;
                     Signature := True;
                  end if;
               end if;
            end;
         end loop;
      end;
      return Image and then Manifest and then Signature;
   exception
      when others =>
         --  Not JSON, too deep, or not shaped as a release.
         return False;
   end Parse;

   function First_Line (Notes : String; Limit : Positive) return String is
      First : Natural := Notes'First;
   begin
      while First <= Notes'Last loop
         declare
            Last : Natural := First;
         begin
            while Last < Notes'Last and then Notes (Last + 1) not in ASCII.LF | ASCII.CR loop
               Last := Last + 1;
            end loop;
            declare
               Line : constant String := Ada.Strings.Fixed.Trim (Notes (First .. Last), Ada.Strings.Both);
               Skip : Natural := Line'First;
            begin
               while Skip <= Line'Last and then Line (Skip) in '#' | '-' | '*' | ' ' | ASCII.LF | ASCII.CR | ASCII.HT
               loop
                  Skip := Skip + 1;
               end loop;
               if Skip <= Line'Last then
                  return Line (Skip .. Natural'Min (Line'Last, Skip + Limit - 1));
               end if;
            end;
            First := Last + 1;
         end;
      end loop;
      return "";
   end First_Line;

end Updater.Releases;
