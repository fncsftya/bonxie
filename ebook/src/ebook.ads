--  Pages of PDFs, drawn with PDFium, and of EPUB e-books, which are read and
--  set here (see Ebook.Books).
--
--  What is called here does its work before it returns, in the caller's
--  thread: a page takes a moment. Nothing is kept open between calls.
with Pomarine.Pages;
with Pomarine.Words;

package Ebook is

   use type Pomarine.Pages.Page_Access;
   use type Pomarine.Pages.Size_Array_Access;

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

   function Is_Supported (URL : String) return Boolean
   is (Is_Document (URL) or else Is_Text (URL));

   function Extensions return String;
   --  The endings of the files this can show, as "pdf;txt", for a
   --  dialog to choose among.

   type Information is record
      Pages : Natural := 0;
      Title : String (1 .. Max_Title) := [others => ' '];
      Last  : Natural := 0;
      --  The title is Title (1 .. Last); Last = 0 if the file has none.
   end record;

   procedure Open (File_Name : String; Found : out Information; Message : out String; Last : out Natural)
   with Pre => Message'Length >= Max_Message, Post => (if Found.Pages > 0 then Last = Message'First - 1);
   --  Count the pages of the file. If it cannot be read, Pages is 0 and
   --  Message (Message'First .. Last) says why.

   procedure Render
     (File_Name : String;
      Page      : Positive;
      PNG_Name  : String;
      Height    : out Natural;
      Message   : out String;
      Last      : out Natural)
   with Pre => Message'Length >= Max_Message, Post => (if Height > 0 then Last = Message'First - 1);
   --  Draw the page (counted from 1) as a PNG file, Page_Width pixels
   --  wide (less if it is tall). If it cannot be, Height is 0 and
   --  Message (Message'First .. Last) says why.

   procedure Build_Page
     (File_Name : String;
      Page      : Positive;
      Content   : out Pomarine.Pages.Page_Access;
      Found     : in out Pomarine.Words.Result;
      Message   : out String;
      Last      : out Natural)
   with Pre => Message'Length >= Max_Message, Post => (if Content /= null then Last = Message'First - 1);
   --  Make the page (counted from 1) as what is drawn on it (see
   --  Pomarine.Pages): shapes, characters and pictures, to be drawn at any
   --  size. Found is given the words of its text, as boxes over the page.
   --  A page that cannot be drawn as shapes (it has shading, say) is one
   --  picture, drawn by PDFium. If it cannot be made, Content is null and
   --  Message says why. The document stays open for the next page.

   function Page_Text (File_Name : String; Page : Positive; Most : Positive := 8_000) return String
   with Post => Page_Text'Result'Length <= Most;
   --  The text of the page (counted from 1) of a PDF, as it is in the file, with no drawing of
   --  the page: its lines are broken by the PDF's own breaks (a CR and LF, or one of them), and
   --  it is cut off at Most bytes. Empty if the page has no text (a picture of one has none), or
   --  cannot be had.

   procedure Document_Sizes
     (File_Name : String;
      Count     : Natural;
      Sizes     : out Pomarine.Pages.Size_Array_Access;
      Message   : out String;
      Last      : out Natural)
   with Pre => Message'Length >= Max_Message, Post => (if Sizes /= null then Sizes'Length = Count);
   --  How big, in points, each of the first Count pages is. Sizes is null,
   --  and Message says why, if it cannot be known.

end Ebook;
