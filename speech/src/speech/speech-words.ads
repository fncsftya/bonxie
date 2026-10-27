--  Words out of the tokens a speech model says. A model speaks in pieces
--  of words (SentencePiece tokens), one of which, to begin a word, begins
--  with a mark (U+2581, or a space); the rest go on the word before. Here
--  they are made into the words, and the text of them, with a space
--  between: and where each word ends in the text, and in the sound.
--
--  GNATprove checks the Ada code for run-time errors and proves that Group
--  satisfies its contract under the preconditions. In particular, the
--  output word ends are plausible for the produced text and fit the output
--  arrays. This establishes the structural properties the caller relies
--  on; it does not prove that token grouping matches the intended spoken
--  words. The postcondition is ignored at run time; preconditions remain
--  enabled.
with Speech.Windows;

package Speech.Words
  with SPARK_Mode
is

   subtype Offsets is Windows.Offsets;

   function Tokens_Plausible (Token_Ends : Offsets; Token_Text_Length : Natural) return Boolean
   is (for all Token in Token_Ends'Range =>
         Token_Ends (Token) <= Token_Text_Length
         and then (if Token > Token_Ends'First then Token_Ends (Token - 1) <= Token_Ends (Token)))
   with Global => null;
   --  Whether Token_Ends, the place each token ends in a text
   --  Token_Text_Length long, in which they are one after the other, is
   --  as it must be: in the text, and in order. (A token may be empty.)

   procedure Group
     (Token_Text     : String;
      Token_Ends     : Offsets;
      Token_Starts   : Offsets;
      Token_Stops    : Offsets;
      Text           : in out String;
      Text_Length    : out Natural;
      Word_Text_Ends : in out Offsets;
      Word_Starts    : in out Offsets;
      Word_Stops     : in out Offsets;
      Word_Count     : out Natural)
   with
     Global => null,
     Pre    =>
       Token_Text'First = 1
       and then Token_Text'Length < Positive'Last / 2
       and then Token_Ends'First = 1
       and then Token_Starts'First = 1
       and then Token_Stops'First = 1
       and then Token_Starts'Last = Token_Ends'Last
       and then Token_Stops'Last = Token_Ends'Last
       and then Tokens_Plausible (Token_Ends, Token_Text'Length)
       and then Text'First = 1
       and then Text'Length < Positive'Last / 2
       and then Word_Text_Ends'First = 1
       and then Word_Starts'First = 1
       and then Word_Stops'First = 1
       and then Word_Starts'Last = Word_Text_Ends'Last
       and then Word_Stops'Last = Word_Text_Ends'Last,
     Post   =>
       Word_Count <= Word_Text_Ends'Length
       and then Text_Length <= Text'Length
       and then Windows.Text_Plausible (Word_Text_Ends (1 .. Word_Count), Text_Length);
   --  Make words of the tokens, whose text, one after the other, is
   --  Token_Text, and which end at Token_Ends in it; and which start and
   --  stop at Token_Starts and Token_Stops in the sound. The words'
   --  text, apart by a space, goes in Text (Text_Length bytes of it), and
   --  where each word ends in it in Word_Text_Ends; where each starts and
   --  stops in the sound, in Word_Starts and Word_Stops (those of the
   --  first and last of its tokens). The words that fit are made, and no
   --  more than Word_Text_Ends holds. When Text fills, the tokens from the
   --  first that does not fit are left out, so a word may lose its last
   --  pieces (never part of a piece, nor an empty word).

end Speech.Words;
