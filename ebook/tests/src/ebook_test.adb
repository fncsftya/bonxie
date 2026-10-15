with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with Ebook;

--  Usage: ebook_test FILE OUT_FOLDER. Draws the file's first page, and its
--  last, and checks what Ebook says of links.
procedure Ebook_Test is
   Found   : Ebook.Information;
   Message : String (1 .. Ebook.Max_Message);
   Last    : Natural;
   Height  : Natural;
   type Pair is array (1 .. 2) of Positive;
begin
   pragma Assert (Ebook.Extension_Of ("https://a.b/c/Book.PDF?x=1.epub#y") = "pdf");
   pragma Assert (Ebook.Extension_Of ("https://a.b/c.d/book") = "");
   pragma Assert (Ebook.Extension_Of ("https://a.b") = "b");
   pragma Assert (Ebook.Is_Document ("http://x.org/files/a.epub"));
   pragma Assert (not Ebook.Is_Document ("http://x.org/files/a.html"));
   pragma Assert (not Ebook.Is_Document ("http://x.org/a.pdf/index"));

   Ebook.Open ("/no/such.pdf", Found, Message, Last);
   pragma Assert (Found.Pages = 0 and then Last >= Message'First);
   Ada.Text_IO.Put_Line ("missing: " & Message (1 .. Last));

   declare
      File : constant String := Ada.Command_Line.Argument (1);
      Out_Folder : constant String := Ada.Command_Line.Argument (2);
   begin
      Ada.Directories.Create_Path (Out_Folder);
      Ebook.Open (File, Found, Message, Last);
      pragma Assert (Found.Pages > 0);
      Ada.Text_IO.Put_Line
        ("pages:" & Found.Pages'Image & " title: " & Found.Title (1 .. Found.Last));
      for Page of Pair'[1, Found.Pages] loop
         Ebook.Render
           (File, Page, Out_Folder & "/" & Ada.Strings.Fixed.Trim (Page'Image, Ada.Strings.Both) & ".png",
            Height, Message, Last);
         pragma Assert (Height > 0, Message (1 .. Last));
         Ada.Text_IO.Put_Line ("page" & Page'Image & " height" & Height'Image);
      end loop;
      Ebook.Render (File, Found.Pages + 1, Out_Folder & "/none.png", Height, Message, Last);
      pragma Assert (Height = 0 and then Last >= Message'First);
      Ada.Text_IO.Put_Line ("past the end: " & Message (1 .. Last));
   end;
end Ebook_Test;
