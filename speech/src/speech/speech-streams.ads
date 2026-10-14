--  Speech from a stream of audio, as the microphone gives it, made of the
--  batch model (Speech.Parakeet) run again and again over a window on the
--  sound (Speech.Windows): every Hop of new audio, the model is run over
--  the whole window, and what it hears is the text so far. The words
--  in the first part of the window, that more sound will not change, are
--  settled: they are kept as text, and the window slides past them, so that
--  the model's work does not grow without end.
--
--  Feed and Finish run the model, so they take a while and are not for the
--  main thread. A stream is for one task at a time.
with Speech.Windows;

package Speech.Streams is

   Hop : constant := Windows.Rate / 2;
   --  How much new audio there is to be before the model is run again.

   Guard : constant := Windows.Rate;
   --  A word is settled when it ends this long before the end of the
   --  audio: the model changes its mind about the last words as it hears
   --  what follows them.

   Trigger : constant := 8 * Windows.Rate;
   --  Settled words are not let go of until the window holds this much:
   --  the model does best with several seconds to go on (less, and the
   --  seams show; more, and it sometimes loses its way).

   Context : constant := Windows.Rate;
   --  How much of the sound before the last settled word the window keeps,
   --  so that the model starts at a word's beginning and not the middle
   --  of one. (The words in it are not taken twice.)

   Slack : constant := Windows.Rate / 10;
   --  How far past the place where words are settled a word's middle may
   --  be and the word still be taken as one that was settled: the model
   --  does not say where a word is to the sample, and not the same twice.

   type Stream is limited private;

   type Tuning is record
      Hop     : Positive range 1 .. Windows.Capacity := Streams.Hop;
      Guard   : Natural := Streams.Guard;
      Trigger : Positive := Streams.Trigger;
      Context : Natural := Streams.Context;
      Slack   : Natural := Streams.Slack;
   end record;
   --  The constants above, which are what a stream starts with.

   procedure Configure (Item : in out Stream; With_Tuning : Tuning);
   --  Use other values than the constants (for finding better ones).

   procedure Reset (Item : in out Stream);
   --  Forget all that was heard.

   procedure Feed
     (Item    : in out Stream;
      Audio   : Windows.Samples;
      Changed : out Boolean;
      Ok      : out Boolean;
      Message : out String;
      Last    : out Natural)
     with Pre => Message'First = 1 and then Audio'Last < Positive'Last;
   --  Give the stream more audio. Changed says the model was run, so the
   --  text may not be as it was.

   procedure Finish
     (Item    : in out Stream;
      Ok      : out Boolean;
      Message : out String;
      Last    : out Natural)
     with Pre => Message'First = 1;
   --  There is no more audio: the text is all settled.

   procedure Text (Item : Stream; Into : in out Transcript);
   --  What has been heard: the settled words, then those that may yet
   --  change.

private

   type Stream is limited record
      Held      : Windows.Window;
      Settled_To : Windows.Sample_Index := 0;
      Tuned      : Tuning;
      --  The place in the sound up to which words are settled.
      Settled   : Transcript;
      Tentative : Transcript;
   end record;

end Speech.Streams;
