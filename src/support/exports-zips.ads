private with Ada.Containers.Vectors;

--  A zip archive built in memory, for the formats that are one (EPUB, DOCX, ODT). Files are stored, not deflated:
--  these formats' readers take them so, and a document's XML is small. Names are UTF-8, and each file is dated
--  1 January 2026, so the same files make the same archive.

package Exports.Zips is

   type Archive is limited private;

   procedure Add (Into : in out Archive; Name : String; Data : String)
   with Pre => Name'Length > 0 and then Name (Name'First) /= '/';
   --  Add a file; the first added is the first in the archive (an EPUB's and an ODT's mimetype must be).

   function Count (Item : Archive) return Natural;

   function Image (Item : Archive) return String
   with Post => Image'Result'Length >= 22;
   --  The bytes of the archive: the files with their headers, then the directory that lists them.

private

   type File_Entry is record
      Name : Unbounded.Unbounded_String;
      Data : Unbounded.Unbounded_String;
   end record;

   package File_Vectors is new Ada.Containers.Vectors (Positive, File_Entry);

   type Archive is limited record
      Files : File_Vectors.Vector;
   end record;

end Exports.Zips;
