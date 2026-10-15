with Ada.Characters.Handling;
with Interfaces.C;
with System;

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

   function EB_Page_Build
     (Path        : Interfaces.C.char_array;
      Page        : Interfaces.C.int;
      Message     : out Interfaces.C.char_array;
      Message_Cap : Interfaces.C.int) return System.Address
     with Import, Convention => C, External_Name => "eb_page_build";

   procedure EB_Page_Sizes
     (Handle  : System.Address;
      Ops, Points, Chars, Faces, Clips, Images, Bytes : out Interfaces.C.int;
      Width, Height : out Interfaces.C.C_float)
     with Import, Convention => C, External_Name => "eb_page_sizes";

   procedure EB_Page_Fill
     (Handle : System.Address;
      Ops, Points, Chars, Faces, Clips, Images, Pixels : System.Address)
     with Import, Convention => C, External_Name => "eb_page_fill";

   procedure EB_Page_Words
     (Handle      : System.Address;
      Words       : System.Address;
      Max_Words   : Interfaces.C.int;
      Text        : System.Address;
      Text_Cap    : Interfaces.C.int;
      Word_Count, Text_Length, Truncated : out Interfaces.C.int)
     with Import, Convention => C, External_Name => "eb_page_words";

   function EB_Document_Sizes
     (Path        : Interfaces.C.char_array;
      Count       : Interfaces.C.int;
      Sizes       : System.Address;
      Message     : out Interfaces.C.char_array;
      Message_Cap : Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C, External_Name => "eb_document_sizes";

   procedure EB_Page_Free (Handle : System.Address)
     with Import, Convention => C, External_Name => "eb_page_free";

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
     (Extension_Of (URL) = "pdf");

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
     ("pdf;txt;text;md;markdown");

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

   procedure Build_Page
     (File_Name : String;
      Page      : Positive;
      Content   : out Pomarine.Pages.Page_Access;
      Found     : in out Pomarine.Words.Result;
      Message   : out String;
      Last      : out Natural)
   is
      use type System.Address;
      Why    : Interfaces.C.char_array (0 .. Max_Message);
      Handle : System.Address;
   begin
      Content := null;
      Last := Message'First - 1;
      Handle :=
        EB_Page_Build
          (Interfaces.C.To_C (File_Name), Interfaces.C.int (Page), Why, Max_Message);
      if Handle = System.Null_Address then
         Say (Why, Message, Last);
         return;
      end if;
      declare
         Ops, Points, Chars, Faces, Clips, Images, Bytes : Interfaces.C.int;
         Width, Height : Interfaces.C.C_float;
         Words, Length, Cut : Interfaces.C.int;
      begin
         EB_Page_Sizes (Handle, Ops, Points, Chars, Faces, Clips, Images, Bytes, Width, Height);
         Content := new Pomarine.Pages.Page
           (Operations => Natural (Ops), Points => Natural (Points),
            Characters => Natural (Chars), Faces => Natural (Faces),
            Clips => Natural (Clips), Images => Natural (Images),
            Bytes => Natural (Bytes));
         Content.Width := Float (Width);
         Content.Height := Float (Height);
         EB_Page_Fill
           (Handle,
            Content.Op'Address, Content.Corner'Address, Content.Letters'Address,
            Content.Fonts'Address, Content.Clip'Address, Content.Pictures'Address,
            Content.Pixels'Address);
         EB_Page_Words
           (Handle, Found.Words'Address, Pomarine.Words.Max_Words,
            Found.Text'Address, Pomarine.Words.Text_Capacity, Words, Length, Cut);
         Found.Count := Natural (Words);
         Found.Length := Natural (Length);
         Found.Truncated := Cut /= 0;
         EB_Page_Free (Handle);
      end;
   end Build_Page;

   procedure Document_Sizes
     (File_Name : String;
      Count     : Natural;
      Sizes     : out Pomarine.Pages.Size_Array_Access;
      Message   : out String;
      Last      : out Natural)
   is
      Why : Interfaces.C.char_array (0 .. Max_Message);
   begin
      Last := Message'First - 1;
      Sizes := new Pomarine.Pages.Size_Array (1 .. Count);
      Why (0) := Interfaces.C.nul;
      if EB_Document_Sizes
           (Interfaces.C.To_C (File_Name), Interfaces.C.int (Count),
            Sizes.all'Address, Why, Max_Message) /= 1
      then
         Pomarine.Pages.Free (Sizes);
         Say (Why, Message, Last);
      end if;
   end Document_Sizes;

end Ebook;
