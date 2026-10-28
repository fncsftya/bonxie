with Ada.Characters.Handling;
with Ada.Directories;
with Ada.IO_Exceptions;
with Ada.Strings.Fixed;
with Files;

package body Site_Filters is

   package Strings renames Ada.Strings.Unbounded;

   Tab : constant Character := ASCII.HT;

   function Begins (Text, Prefix : String) return Boolean
   is (Text'Length >= Prefix'Length and then Text (Text'First .. Text'First + Prefix'Length - 1) = Prefix);

   function Lower (Text : String) return String
   is (Ada.Characters.Handling.To_Lower (Text));

   function Is_Host_Letter (Each : Character) return Boolean
   is (Each in 'a' .. 'z' | '0' .. '9' | '-' | '.');

   function Is_Host (Text : String) return Boolean
   is (Text'Length > 0
       and then Text (Text'First) not in '.' | '-'
       and then Text (Text'Last) not in '.' | '-'
       and then (for all Each of Text => Is_Host_Letter (Each))
       and then Ada.Strings.Fixed.Index (Text, "..") = 0);

   --  Where the scheme ends (after "://"), 0 if there is none.
   function After_Scheme (Text : String) return Natural is
      Cut : constant Natural := Ada.Strings.Fixed.Index (Text, "://");
   begin
      return (if Cut = 0 then 0 else Cut + 3);
   end After_Scheme;

   --  The part of an address before its path, query or fragment, with no scheme: login, host and port.
   function Authority_Of (Text : String) return String is
      First : constant Positive := (if After_Scheme (Text) > 0 then After_Scheme (Text) else Text'First);
      Stop  : Natural := Text'Last + 1;
   begin
      for I in First .. Text'Last loop
         if Text (I) in '/' | '?' | '#' then
            Stop := I;
            exit;
         end if;
      end loop;
      declare
         Whole : constant String := Text (First .. Stop - 1);
         Login : constant Natural := Ada.Strings.Fixed.Index (Whole, "@", Ada.Strings.Backward);
      begin
         return (if Login > 0 then Whole (Login + 1 .. Whole'Last) else Whole);
      end;
   end Authority_Of;

   --  The host in an authority: what comes before its port.
   function Without_Port (Authority : String) return String is
      Colon : constant Natural := Ada.Strings.Fixed.Index (Authority, ":");
   begin
      return (if Colon = 0 then Authority else Authority (Authority'First .. Colon - 1));
   end Without_Port;

   function Host_Of (Address : String) return String is
      Host : constant String := Lower (Without_Port (Authority_Of (Address)));
   begin
      return (if Is_Host (Host) then Host else "");
   end Host_Of;

   --  A port as it follows a host: a colon and digits.
   function Is_Port (Text : String) return Boolean
   is (Text'Length > 1
       and then Text (Text'First) = ':'
       and then (for all I in Text'First + 1 .. Text'Last => Text (I) in '0' .. '9'));

   function Is_Web (Address : String) return Boolean
   is (Begins (Lower (Address), "http://") or else Begins (Lower (Address), "https://"));

   function Base_Of (Text : String) return String is
      Trimmed   : constant String := Ada.Strings.Fixed.Trim (Text, Ada.Strings.Both);
      Scheme    : constant String := (if Begins (Lower (Trimmed), "http://") then "http" else "https");
      Has_Other : constant Boolean := After_Scheme (Trimmed) > 0 and then not Is_Web (Trimmed);
      Authority : constant String := Lower (Authority_Of (Trimmed));
      Colon     : constant Natural := Ada.Strings.Fixed.Index (Authority, ":");
      Port      : constant String := (if Colon = 0 then "" else Authority (Colon .. Authority'Last));
   begin
      if Has_Other
        or else Ada.Strings.Fixed.Index (Trimmed, " ") > 0
        or else Host_Of (Trimmed) = ""
        or else (Port /= "" and then not Is_Port (Port))
      then
         return "";
      end if;
      return Scheme & "://" & Host_Of (Trimmed) & Port;
   end Base_Of;

   function Is_Listed (From : Lists.List; Address : String) return Boolean is
      Host : constant String := Host_Of (Address);
   begin
      if Host = "" then
         return False;
      end if;
      for Each of From loop
         declare
            Site : constant String := Host_Of (Strings.To_String (Each));
         begin
            if Site /= ""
              and then (Host = Site
                        or else (Host'Length > Site'Length
                                 and then Host (Host'Last - Site'Length .. Host'Last) = "." & Site))
            then
               return True;
            end if;
         end;
      end loop;
      return False;
   end Is_Listed;

   function Permits (Using : Rules; Address : String) return Boolean
   is (not Is_Web (Address)
       or else (case Using.Mode is
                  when Off         => True,
                  when Use_Blocked => not Is_Listed (Using.Blocked, Address),
                  when Use_Allowed => Is_Listed (Using.Allowed, Address)));

   function Index_Of (From : Lists.List; Base : String) return Natural is
   begin
      for I in 1 .. From.Count loop
         if Strings.To_String (From (I)) = Base then
            return I;
         end if;
      end loop;
      return 0;
   end Index_Of;

   function Hosts_Of (Using : Rules) return String is
      Text : Strings.Unbounded_String;
   begin
      if Using.Mode = Off then
         return "";
      end if;
      for Each of List_Of (Using, Using.Mode) loop
         Strings.Append (Text, Host_Of (Strings.To_String (Each)) & ASCII.LF);
      end loop;
      return Strings.To_String (Text);
   end Hosts_Of;

   procedure Add_Line (Into : in out Rules; Line : String);
   --  Take what a line of the file says, if it says something.

   procedure Add_Line (Into : in out Rules; Line : String) is
      Cut   : constant Natural := Ada.Strings.Fixed.Index (Line, String'(1 => Tab));
      Key   : constant String := (if Cut = 0 then "" else Line (Line'First .. Cut - 1));
      Value : constant String := (if Cut = 0 then "" else Line (Cut + 1 .. Line'Last));
   begin
      if Key = "mode" then
         for Each in Modes loop
            if Value = Lower (Each'Image) then
               Into.Mode := Each;
            end if;
         end loop;
      elsif Key = "blocked" and then Base_Of (Value) = Value then
         Lists.Append (Into.Blocked, Strings.To_Unbounded_String (Value));
      elsif Key = "allowed" and then Base_Of (Value) = Value then
         Lists.Append (Into.Allowed, Strings.To_Unbounded_String (Value));
      end if;
   end Add_Line;

   procedure Load (Config : String; Into : in out Rules) is
   begin
      Into.Mode := Off;
      Lists.Clear (Into.Blocked);
      Lists.Clear (Into.Allowed);
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

   procedure Save (Config : String; From : Rules) is
      Text : Strings.Unbounded_String;
   begin
      Strings.Append (Text, "mode" & Tab & Lower (From.Mode'Image) & ASCII.LF);
      for Each of From.Blocked loop
         Strings.Append (Text, "blocked" & Tab & Strings.To_String (Each) & ASCII.LF);
      end loop;
      for Each of From.Allowed loop
         Strings.Append (Text, "allowed" & Tab & Strings.To_String (Each) & ASCII.LF);
      end loop;
      Ada.Directories.Create_Path (Config);
      Files.Write (File_Name (Config), Strings.To_String (Text));
   exception
      when Ada.IO_Exceptions.Use_Error | Ada.IO_Exceptions.Name_Error =>
         null;
   end Save;

end Site_Filters;
