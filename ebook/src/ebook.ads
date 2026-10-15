--  Pages of PDFs and e-books (EPUB, FB2, XPS, comic book archives...),
--  drawn as PNG files with MuPDF, as SDLBook does to show them.
--
--  What is called here does its work before it returns, in the caller's
--  thread: a page takes a moment. Nothing is kept open between calls.
package Ebook is

   Max_Message : constant := 160;
   Max_Title   : constant := 160;

   Page_Width : constant := 2048;
   --  Pixels wide a page is drawn, as a page of a source is as wide as
   --  a web page's picture (see Webshot).

   Max_Height : constant := 16_384;
   --  Pixels tall a page is at most, which a GPU texture can be: a page
   --  taller for its width is drawn smaller.

   function Extension_Of (URL : String) return String;
   --  The lower case ending of the link's path, without its dot, as
   --  "pdf"; empty if it has none. A query or fragment is not part of it.

   function File_Extension (Path : String) return String;
   --  The lower case ending of a file's name, without its dot, as "pdf";
   --  empty if it has none. Unlike Extension_Of, a ? or # in it is part
   --  of the name.

   function Is_Document (URL : String) return Boolean;
   --  Whether the link is of a file this can draw, by its ending.

   function Is_Text (URL : String) return Boolean;
   --  Whether the link is of a file of plain text, by its ending: what is
   --  shown as it is, not drawn.

   function Is_Supported (URL : String) return Boolean is
     (Is_Document (URL) or else Is_Text (URL));

   function Extensions return String;
   --  The endings of the files this can show, as "pdf;epub;txt", for a
   --  dialog to choose among.

   type Information is record
      Pages  : Natural := 0;
      Title  : String (1 .. Max_Title) := [others => ' '];
      Last   : Natural := 0;
      --  The title is Title (1 .. Last); Last = 0 if the file has none.
   end record;

   procedure Open
     (File_Name : String;
      Found     : out Information;
      Message   : out String;
      Last      : out Natural)
     with Pre  => Message'Length >= Max_Message,
          Post => (if Found.Pages > 0 then Last = Message'First - 1);
   --  Count the pages of the file. If it cannot be read, Pages is 0 and
   --  Message (Message'First .. Last) says why.

   procedure Render
     (File_Name : String;
      Page      : Positive;
      PNG_Name  : String;
      Height    : out Natural;
      Message   : out String;
      Last      : out Natural)
     with Pre  => Message'Length >= Max_Message,
          Post => (if Height > 0 then Last = Message'First - 1);
   --  Draw the page (counted from 1) as a PNG file, Page_Width pixels
   --  wide (less if it is tall). If it cannot be, Height is 0 and
   --  Message (Message'First .. Last) says why.

end Ebook;
