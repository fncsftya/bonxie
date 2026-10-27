--  Inflate: the decompression of the deflate format (RFC 1951) that zip
--  files, and so e-books, use. Written here so that reading an e-book needs
--  no library.

package Ebook.Inflate is

   procedure Run (Packed : String; Size : Natural; Result : out String; Ok : out Boolean)
   with Pre => Result'Length = Size;
   --  Decompress the deflate stream Packed into Result, which is exactly
   --  Size bytes long. Not Ok if the stream is damaged or does not make
   --  exactly Size bytes.

end Ebook.Inflate;
