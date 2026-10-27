with Ada.Containers.Indefinite_Vectors;
with Ada.Strings.Unbounded;
with Ebook.Zip;

--  An EPUB: a zip of XHTML chapters, with a package file that names them in
--  reading order and gives the book's title. Only what is needed to read
--  it through is taken.

package Ebook.Epub is

   type Book is limited private;

   procedure Open (Item : in out Book; Path : String; Ok : out Boolean; Message : out String; Last : out Natural)
   with Pre => Message'Length >= Max_Message;
   --  Read the book's package. If it cannot be, Message
   --  (Message'First .. Last) says why.

   function Is_Open (Item : Book) return Boolean;

   function Title (Item : Book) return String
   with Pre => Is_Open (Item);
   --  "" if it has none.

   function Chapter_Count (Item : Book) return Natural
   with Pre => Is_Open (Item);
   --  How many files are read, one after another.

   function Chapter (Item : Book; Number : Positive) return String
   with Pre => Is_Open (Item) and then Number <= Chapter_Count (Item);
   --  The XHTML of a chapter; "" if it cannot be read.

   procedure Close (Item : in out Book)
   with Post => not Is_Open (Item);

private

   package String_Vectors is new Ada.Containers.Indefinite_Vectors (Positive, String);

   type Book is limited record
      Files : Zip.Archive;
      Open  : Boolean := False;
      Name  : Ada.Strings.Unbounded.Unbounded_String;
      Spine : String_Vectors.Vector;
      --  The path in the zip of each chapter.
   end record;

end Ebook.Epub;
