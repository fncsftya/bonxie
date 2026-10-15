--  Text in pictures (macOS only): Apple's Vision finds the words in a PNG
--  file, at the size it is, and where each is in it.

with Pomarine.Words;

package Vision is

   Max_Words : constant := Pomarine.Words.Max_Words;
   --  Of one picture: more are left out (Result.Truncated).

   Text_Capacity : constant := Pomarine.Words.Text_Capacity;
   --  Bytes of all the words together.

   subtype Word is Pomarine.Words.Word;
   subtype Word_Array is Pomarine.Words.Word_Array;
   subtype Result is Pomarine.Words.Result;
   subtype Result_Access is Pomarine.Words.Result_Access;
   --  The widgets' own, so that they need not know of Vision.

   function Image (Of_Word : Word; In_Result : Result) return String
     renames Pomarine.Words.Image;
   --  The word's text.

   procedure Recognize
     (File_Name : String;
      Into      : in out Result;
      Ok        : out Boolean;
      Message   : out String;
      Last      : out Natural)
     with Pre => Message'First = 1;
   --  Read the PNG file and find its text, now, on this thread, which
   --  Vision permits of any. On failure Ok is False and Message
   --  (1 .. Last) says why, and Into is empty. See Vision.Jobs to do it
   --  in the background.

end Vision;
