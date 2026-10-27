with Pomarine.Pages;
with Pomarine.Words;

--  E-books (EPUB) set in pages. The whole book is read and set once, in
--  a page of a fixed size, a line at a time: the words that fall on each
--  page, where, and in what face. Pages are then made from that as they are
--  asked for (see Ebook.Build_Page). The last book set is kept, so that
--  asking for page after page does not set it again.
--
--  Only the book's text is set: its headings, paragraphs, lists, quotes and
--  preformatted text, in bold, italic and fixed faces. Its style sheets are
--  not read, and its pictures are not drawn.

package Ebook.Books is

   Sheet_Width  : constant := 432.0;
   Sheet_Height : constant := 648.0;
   --  Of every page, in points: six inches by nine.

   procedure Count_Pages
     (File_Name  : String;
      Pages      : out Natural;
      Title      : out String;
      Title_Last : out Natural;
      Message    : out String;
      Last       : out Natural)
   with
     Pre  => Message'Length >= Max_Message,
     Post => (if Pages > 0 then Last = Message'First - 1 else Last >= Message'First);
   --  Set the book and count its pages. Title (Title'First .. Title_Last)
   --  is its title, cut if it is longer than Title; empty if it has none.

   procedure Make_Page
     (File_Name : String;
      Number    : Positive;
      Content   : out Pomarine.Pages.Page_Access;
      Found     : in out Pomarine.Words.Result;
      Message   : out String;
      Last      : out Natural)
   with Pre => Message'Length >= Max_Message;
   --  The page, as Ebook.Build_Page says.

end Ebook.Books;
