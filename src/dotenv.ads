--  Settings kept in a `.env` file in the working directory, available from anywhere:
--  Dotenv.Value ("KEY"). Lines are KEY=VALUE; blank lines and lines starting with `#`
--  are skipped, as is a leading `export `. A value may be in "double quotes" (with \n,
--  \t, \" and \\ escapes) or 'single quotes' (as written); an unquoted value ends at
--  a ` #` comment and is trimmed. A key given twice has its last value.
package Dotenv is

   Default_File : constant String := ".env";

   function Load (File_Name : String := Default_File) return Boolean;
   --  Read the file, relative to the working directory, adding its keys to those held.
   --  False, with nothing added, if there is no such file.

   procedure Parse (Text : String);
   --  Add the keys of Text, as the contents of a file, to those held.

   procedure Clear
     with Post => Count = 0;
   --  Hold no keys.

   function Count return Natural;
   --  How many keys are held.

   function Has (Key : String) return Boolean;
   --  Whether Key is set, in the process's environment or in what was loaded.

   function Value (Key : String; Default : String := "") return String;
   --  The value of Key; Default if it is not set. The process's environment
   --  comes first, so a variable set outside overrides the file.

end Dotenv;
