with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

--  A zip archive (which an e-book is), read whole into memory: the names of
--  its files and their contents, stored or deflated.
package Ebook.Zip is

   type Archive is limited private;

   procedure Open
     (Item : in out Archive; Path : String; Ok : out Boolean; Message : out String; Last : out Natural)
     with Pre => Message'Length >= Max_Message;
   --  Read the archive at Path. If it cannot be read, Message
   --  (Message'First .. Last) says why.

   function Is_Open (Item : Archive) return Boolean;

   function Contains (Item : Archive; Name : String) return Boolean
     with Pre => Is_Open (Item);
   --  Whether there is a file called Name (compared without regard to case,
   --  as e-books are made carelessly).

   function Read (Item : Archive; Name : String) return String
     with Pre => Is_Open (Item) and then Contains (Item, Name);
   --  What the file holds. Raises Damaged if it cannot be read.

   Damaged : exception;

   procedure Close (Item : in out Archive)
     with Post => not Is_Open (Item);

private

   type Data_Access is access String;

   type Entry_Record is record
      Name       : Ada.Strings.Unbounded.Unbounded_String;
      Method     : Natural;
      Packed     : Natural;
      Size       : Natural;
      Local      : Natural;   --  where its local header is, from 0
   end record;

   package Entry_Vectors is new Ada.Containers.Vectors (Positive, Entry_Record);

   type Archive is limited record
      Data    : Data_Access;
      Entries : Entry_Vectors.Vector;
   end record;

end Ebook.Zip;
