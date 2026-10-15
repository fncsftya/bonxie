with Ada.Characters.Handling;
with Interfaces.C;

package body Ebook is

   use type Interfaces.C.int;

   function EB_Info
     (Path        : Interfaces.C.char_array;
      Pages       : out Interfaces.C.int;
      Title       : out Interfaces.C.char_array;
      Title_Cap   : Interfaces.C.int;
      Message     : out Interfaces.C.char_array;
      Message_Cap : Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C, External_Name => "eb_info";

   function EB_Render
     (Path        : Interfaces.C.char_array;
      Page        : Interfaces.C.int;
      PNG         : Interfaces.C.char_array;
      Width       : Interfaces.C.int;
      Tallest     : Interfaces.C.int;
      Height      : out Interfaces.C.int;
      Message     : out Interfaces.C.char_array;
      Message_Cap : Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C, External_Name => "eb_render";

   function Extension_Of (URL : String) return String is
      Stop : Natural := URL'Last;
   begin
      for I in URL'Range loop
         if URL (I) in '?' | '#' then
            Stop := I - 1;
            exit;
         end if;
      end loop;
      for I in reverse URL'First .. Stop loop
         exit when URL (I) = '/';
         if URL (I) = '.' then
            return Ada.Characters.Handling.To_Lower (URL (I + 1 .. Stop));
         end if;
      end loop;
      return "";
   end Extension_Of;

   function Is_Document (URL : String) return Boolean is
     (Extension_Of (URL) in "pdf" | "epub" | "fb2" | "xps" | "oxps" | "cbz" | "mobi");

   function File_Extension (Path : String) return String is
   begin
      for I in reverse Path'Range loop
         exit when Path (I) = '/';
         if Path (I) = '.' then
            return Ada.Characters.Handling.To_Lower (Path (I + 1 .. Path'Last));
         end if;
      end loop;
      return "";
   end File_Extension;

   function Is_Text (URL : String) return Boolean is
     (Extension_Of (URL) in "txt" | "text" | "md" | "markdown");

   function Extensions return String is
     ("pdf;epub;fb2;xps;oxps;cbz;mobi;txt;text;md;markdown");

   procedure Say
     (Text : Interfaces.C.char_array; Into : out String; Last : out Natural)
   is
      Said : constant String := Interfaces.C.To_Ada (Text);
      Used : constant Natural := Natural'Min (Said'Length, Into'Length);
   begin
      Into (Into'First .. Into'First + Used - 1) :=
        Said (Said'First .. Said'First + Used - 1);
      Last := Into'First + Used - 1;
   end Say;

   procedure Open
     (File_Name : String;
      Found     : out Information;
      Message   : out String;
      Last      : out Natural)
   is
      Pages : Interfaces.C.int;
      Title : Interfaces.C.char_array (0 .. Max_Title);
      Why   : Interfaces.C.char_array (0 .. Max_Message);
   begin
      Found := (others => <>);
      Last := Message'First - 1;
      Title (0) := Interfaces.C.nul;
      Why (0) := Interfaces.C.nul;
      if EB_Info
           (Interfaces.C.To_C (File_Name), Pages, Title, Max_Title,
            Why, Max_Message) = 1
      then
         Found.Pages := Natural (Pages);
         declare
            Text : constant String := Interfaces.C.To_Ada (Title);
         begin
            Found.Last := Natural'Min (Text'Length, Max_Title);
            Found.Title (1 .. Found.Last) :=
              Text (Text'First .. Text'First + Found.Last - 1);
         end;
      else
         Say (Why, Message, Last);
      end if;
   end Open;

   procedure Render
     (File_Name : String;
      Page      : Positive;
      PNG_Name  : String;
      Height    : out Natural;
      Message   : out String;
      Last      : out Natural)
   is
      Tall : Interfaces.C.int;
      Why  : Interfaces.C.char_array (0 .. Max_Message);
   begin
      Last := Message'First - 1;
      Height := 0;
      Why (0) := Interfaces.C.nul;
      if EB_Render
           (Interfaces.C.To_C (File_Name), Interfaces.C.int (Page),
            Interfaces.C.To_C (PNG_Name), Page_Width, Max_Height,
            Tall, Why, Max_Message) = 1
      then
         Height := Natural (Tall);
      else
         Say (Why, Message, Last);
      end if;
   end Render;

end Ebook;
