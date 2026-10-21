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
with Speech.Gates;
with Speech.Parakeet;
with Speech.Windows;

package Speech.Streams
  with SPARK_Mode
is

   use type Windows.Sample_Index;

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

   function Consistent (Item : Stream) return Boolean
     with Global => null;
   --  What holds of a stream between calls: the place up to which words
   --  are settled is not past the sound that is heard.

   type Tuning is record
      Hop     : Positive range 1 .. Windows.Capacity := Streams.Hop;
      Guard   : Natural range 0 .. Windows.Capacity := Streams.Guard;
      Trigger : Positive range 1 .. Windows.Capacity := Streams.Trigger;
      Context : Natural range 0 .. Windows.Capacity := Streams.Context;
      Slack   : Natural range 0 .. Windows.Capacity := Streams.Slack;
      Gate    : Boolean := True;
      --  Whether the sound that is not speech is made silence before the
      --  model hears it (see Speech.Gates).
   end record;
   --  The constants above, which are what a stream starts with.

   procedure Configure (Item : in out Stream; With_Tuning : Tuning)
     with Global => null,
          Pre    => Consistent (Item),
          Post   => Consistent (Item);
   --  Use other values than the constants (for finding better ones).

   procedure Reset (Item : in out Stream)
     with Global => null,
          Post   => Consistent (Item);
   --  Forget all that was heard.

   procedure Feed
     (Item    : in out Stream;
      Audio   : Windows.Samples;
      Changed : out Boolean;
      Ok      : out Boolean;
      Message : out String;
      Last    : out Natural)
     with Global => (Input => Parakeet.Model),
          Pre    => Consistent (Item)
                    and then Message'First = 1
                    and then Message'Length < Positive'Last / 2
                    and then Audio'First >= 1
                    and then Audio'Last < Positive'Last,
          Post   => Consistent (Item) and then Last <= Message'Length;
   --  Give the stream more audio. Changed says the model was run, so the
   --  text may not be as it was.

   procedure Finish
     (Item    : in out Stream;
      Ok      : out Boolean;
      Message : out String;
      Last    : out Natural)
     with Global => (Input => Parakeet.Model),
          Pre    => Consistent (Item)
                    and then Message'First = 1
                    and then Message'Length < Positive'Last / 2,
          Post   => Consistent (Item) and then Last <= Message'Length;
   --  There is no more audio: the text is all settled.

   function Room_Level (Item : Stream) return Float
     with Global => null,
          Post   => Room_Level'Result in 0.0 .. 1.0;
   --  How loud the room is, as an amplitude (see Speech.Gates).

   procedure Text (Item : Stream; Into : in out Transcript)
     with Global => null;
   --  What has been heard: the settled words, then those that may yet
   --  change.

private

   type Stream is limited record
      Held       : Windows.Window;
      Settled_To : Windows.Sample_Index := 0;
      --  The place in the sound up to which words are settled.
      Tuned      : Tuning;
      Room       : Gates.Floor;
      --  What is known of the level of the room.
      Settled    : Transcript;
      Tentative  : Transcript;
   end record;

   function Room_Level (Item : Stream) return Float is (Gates.Level (Item.Room));

   function Consistent (Item : Stream) return Boolean is
     (Item.Settled_To <= Windows.Next (Item.Held));

end Speech.Streams;
