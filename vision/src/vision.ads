--  Text in pictures (macOS only): Apple's Vision finds the words in a PNG
--  file, at the size it is, and where each is in it.

with Pomarine.Words;

package Vision is

   subtype Word is Pomarine.Words.Word;
   subtype Word_Array is Pomarine.Words.Word_Array;
   subtype Result is Pomarine.Words.Result;
   subtype Result_Access is Pomarine.Words.Result_Access;
   --  The widgets' own, so that they need not know of Vision.

   function Image (Of_Word : Word; In_Result : Result) return String renames Pomarine.Words.Image;
   --  The word's text.

   procedure Recognize
     (File_Name : String; Into : in out Result; Ok : out Boolean; Message : out String; Last : out Natural)
   with Pre => Message'First = 1;
   --  Into has room made for as many words as are found.
   --  Read the PNG file and find its text, now, on this thread, which
   --  Vision permits of any. On failure Ok is False and Message
   --  (1 .. Last) says why, and Into is empty. See Vision.Jobs to do it
   --  in the background.

end Vision;
