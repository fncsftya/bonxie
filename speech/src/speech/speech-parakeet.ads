--  The Parakeet TDT 0.6b v3 speech model on Core ML (so, the Neural
--  Engine): Ada's side of parakeet/ (libBonxieParakeet, built by
--  native/build.sh). It makes text of audio given whole, with where each
--  word ends; Speech.Streams makes a stream of that.
--
--  Both calls wait (the first loads the models, downloading them the first
--  time), so they are not for the main thread. The model runs one at a
--  time; they may be called from any task.
with Speech.Windows;

package Speech.Parakeet is

   Max_Words : constant := 2048;

   subtype Word_Count is Natural range 0 .. Max_Words;

   type Heard is record
      Count       : Word_Count := 0;
      --  Words, of which the first Count of each array are used.
      Text_Length : Natural := 0;
      Text        : String (1 .. Text_Capacity) := [others => ' '];
      --  The words with a space between each.
      Text_Ends   : Windows.Offsets (1 .. Max_Words) := [others => 0];
      --  Where each word ends in Text: the place of its last byte.
      Sample_Starts : Windows.Offsets (1 .. Max_Words) := [others => 0];
      Sample_Ends   : Windows.Offsets (1 .. Max_Words) := [others => 0];
      --  Where each word starts and ends in the audio, in samples from
      --  its start.
   end record;

   function Present (Directory : String) return Boolean;
   --  Whether the models are all in Directory (see Speech.Models).

   procedure Load
     (Directory : String;
      Ok        : out Boolean;
      Message   : out String;
      Last      : out Natural)
     with Pre => Message'First = 1 and then Directory /= "";
   --  Have the models ready, if they are not already: those in Directory.
   --  On failure Message (1 .. Last) says why (not downloaded, say).

   procedure Transcribe
     (Audio   : Windows.Samples;
      Into    : out Heard;
      Ok      : out Boolean;
      Message : out String;
      Last    : out Natural)
     with Pre => Message'First = 1 and then Audio'First = 1 and then Audio'Length <= Windows.Capacity;
   --  Make the text of the audio. What comes back is not taken on trust:
   --  where the words are in the sound is made to be as it must (see
   --  Windows.Repair), and a text that is not what the words say is a
   --  failure.

   procedure Unload;
   --  Let the models go.

end Speech.Parakeet;
