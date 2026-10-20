with Ada.Characters.Handling;
with Ebook;

package body Source_Links is

   function Lower (Text : String) return String is (Ada.Characters.Handling.To_Lower (Text));

   --  Where the host of an address begins and ends, and where its path begins
   --  (Path_First is Last + 1 if there is none).
   procedure Split (URL : String; Host_First, Host_Last, Path_First : out Natural) is
      Index : Natural := URL'First;
   begin
      Host_First := 0;
      Host_Last := 0;
      Path_First := URL'Last + 1;
      for Each in URL'First .. URL'Last - 2 loop
         if URL (Each .. Each + 2) = "://" then
            Index := Each + 3;
            exit;
         end if;
      end loop;
      Host_First := Index;
      Host_Last := Index - 1;
      while Host_Last < URL'Last and then URL (Host_Last + 1) not in '/' | '?' | '#' loop
         Host_Last := Host_Last + 1;
      end loop;
      Path_First := Host_Last + 1;
   end Split;

   --  The path of an address, less its query and fragment.
   function Path_Of (URL : String) return String is
      Host_First, Host_Last, Path_First : Natural;
      Stop : Natural := URL'Last;
   begin
      if URL'Length = 0 then
         return "";
      end if;
      Split (URL, Host_First, Host_Last, Path_First);
      for Each in Path_First .. URL'Last loop
         if URL (Each) in '?' | '#' then
            Stop := Each - 1;
            exit;
         end if;
      end loop;
      return URL (Path_First .. Stop);
   end Path_Of;

   function Host_Of (URL : String) return String is
      Host_First, Host_Last, Path_First : Natural;
   begin
      if URL'Length = 0 then
         return "";
      end if;
      Split (URL, Host_First, Host_Last, Path_First);
      return Lower (URL (Host_First .. Host_Last));
   end Host_Of;

   function Has_Host (URL, Name : String) return Boolean is
      Host : constant String := Host_Of (URL);
   begin
      return Host = Name
        or else (Host'Length > Name'Length and then Host (Host'Last - Name'Length .. Host'Last) = "." & Name);
   end Has_Host;

   --  The part of the path after a prefix, if it has it (the prefix has the slashes).
   function After (Path, Prefix : String) return String is
     (if Path'Length > Prefix'Length and then Path (Path'First .. Path'First + Prefix'Length - 1) = Prefix
      then Path (Path'First + Prefix'Length .. Path'Last) else "");

   function Without_Slashes (Text : String) return String is
      Last : Natural := Text'Last;
   begin
      while Last >= Text'First and then Text (Last) = '/' loop
         Last := Last - 1;
      end loop;
      return Text (Text'First .. Last);
   end Without_Slashes;

   --  Whether a segment of the path is Word (it has its slash after) with more after.
   function Has_Segment (Path, Word : String) return Boolean is
   begin
      for Each in Path'Range loop
         if Path (Each) = '/'
           and then Each + Word'Length + 1 < Path'Last
           and then Path (Each + 1 .. Each + Word'Length + 1) = Word & "/"
         then
            return True;
         end if;
      end loop;
      return False;
   end Has_Segment;

   function Is_Document (URL : String) return Boolean is
      Path : constant String := Lower (Path_Of (URL));
   begin
      return URL'Length > 0
        and then (Ebook.Extension_Of (URL) = "pdf"
                  or else Has_Segment (Path, "pdf") or else Has_Segment (Path, "epdf")
                  or else Has_Segment (Path, "pdfplus"));
   end Is_Document;

   function Direct_Document (URL : String) return String is
      Path : constant String := Path_Of (URL);
   begin
      if URL'Length = 0 then
         return "";
      end if;
      if Has_Host (URL, "arxiv.org") then
         declare
            Id : constant String :=
              (if After (Path, "/abs/") /= "" then After (Path, "/abs/")
               elsif After (Path, "/html/") /= "" then After (Path, "/html/")
               elsif After (Path, "/pdf/") /= "" then After (Path, "/pdf/")
               else "");
            Clean : constant String := Without_Slashes (Id);
            Bare  : constant String :=
              (if Clean'Length > 4 and then Lower (Clean (Clean'Last - 3 .. Clean'Last)) = ".pdf"
               then Clean (Clean'First .. Clean'Last - 4) else Clean);
         begin
            --  A paper's id has no slash but an old one has, as astro-ph/0601001.
            return (if Bare = "" then "" else "https://arxiv.org/pdf/" & Bare & ".pdf");
         end;
      elsif Has_Host (URL, "acm.org") and then Host_Of (URL) = "dl.acm.org" then
         declare
            Rest  : constant String := After (Path, "/doi/");
            Slash : Natural := 0;
         begin
            for Each in Rest'Range loop
               if Rest (Each) = '/' then
                  Slash := Each;
                  exit;
               end if;
            end loop;
            --  The DOI starts 10.: with or without a word before it.
            if Rest'Length > 3 and then Rest (Rest'First .. Rest'First + 2) = "10." then
               return "https://dl.acm.org/doi/pdf/" & Without_Slashes (Rest);
            elsif Slash > Rest'First and then Slash < Rest'Last
              and then Rest (Slash + 1 .. Natural'Min (Rest'Last, Slash + 3)) = "10."
              and then Lower (Rest (Rest'First .. Slash - 1))
                       in "abs" | "full" | "fullhtml" | "epdf" | "pdf" | "pdfplus"
            then
               return "https://dl.acm.org/doi/pdf/" & Without_Slashes (Rest (Slash + 1 .. Rest'Last));
            end if;
            return "";
         end;
      elsif Has_Host (URL, "tandfonline.com") then
         declare
            Rest : constant String :=
              (if After (Path, "/doi/abs/") /= "" then After (Path, "/doi/abs/")
               elsif After (Path, "/doi/full/") /= "" then After (Path, "/doi/full/")
               elsif After (Path, "/doi/epdf/") /= "" then After (Path, "/doi/epdf/")
               elsif After (Path, "/doi/figure/") /= "" then After (Path, "/doi/figure/")
               elsif After (Path, "/doi/pdf/") /= "" then After (Path, "/doi/pdf/")
               else "");
            Doi : constant String := Without_Slashes (Rest);
         begin
            return (if Doi = "" then "" else "https://www.tandfonline.com/doi/pdf/" & Doi);
         end;
      end if;
      return "";
   end Direct_Document;

   function Is_PDF_File (Start : String) return Boolean is
     (Start'Length >= 5 and then Start (Start'First .. Start'First + 4) = "%PDF-");

   function Name_Of (URL : String) return String is
      Path : constant String := Path_Of (URL);
      First : Natural := Path'First;
      Stop  : Natural := Path'Last;
   begin
      if Path = "" then
         return "";
      end if;
      Stop := Path'Last;
      while Stop >= Path'First and then Path (Stop) = '/' loop
         Stop := Stop - 1;
      end loop;
      for Each in Path'First .. Stop loop
         if Path (Each) = '/' then
            First := Each + 1;
         end if;
      end loop;
      if First > Stop then
         return "";
      end if;
      --  A DOI: from its segment (10.1145) to the end.
      for Each in Path'First .. Stop - 3 loop
         if (Each = Path'First or else Path (Each - 1) = '/') and then Path (Each .. Each + 2) = "10."
           and then (for some C of Path (Each .. Stop) => C = '/')
         then
            return Path (Each .. Stop);
         end if;
      end loop;
      declare
         Name : constant String := Path (First .. Stop);
         Dot  : Natural := 0;
      begin
         for Each in Name'Range loop
            if Name (Each) = '.' then
               Dot := Each;
            end if;
         end loop;
         --  What follows the last dot is an ending, unless it is a number (or a number and a
         --  version, v2, as the ids of arXiv have).
         return (if Dot > Name'First
                   and then not (for all C of Name (Dot + 1 .. Name'Last) => C in '0' .. '9' | 'v')
                 then Name (Name'First .. Dot - 1) else Name);
      end;
   end Name_Of;

end Source_Links;
