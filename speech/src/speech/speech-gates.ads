--  Which of the sound heard is speech, and which is the room: a noise
--  gate that listens to what is held, and not only to what comes. The
--  model, given a quiet room, will make words of it (the breath of a
--  fan, a chair), so the sound that is not speech is made silence before
--  the model is run.
--
--  The level of the room is learnt as the sound comes (Observe): it
--  falls to a quiet moment quickly, and rises, to a steady noise, slowly,
--  so it is not carried up by speech. Whether a stretch is speech is
--  judged over the whole window at once (Apply), by frames of 20 ms,
--  where the sound after is known as well as the sound before:
--   - a frame well above the room's level is speech;
--   - the Pre_Roll frames before it are kept, so that a word's start,
--     which is quiet, is not cut;
--   - and after it the sound is kept while it is above the room's level
--     (a voice trailing off), for up to Max_Trail frames, and for
--     Hangover frames more after it has fallen to the room's. (Lenient: a
--  word cut costs more than a noise let in.)
--  Nothing is taken out of the window itself: it is the copy that goes to
--  the model that is gated, so that a later look, with more sound to
--  judge by, may keep what an earlier one did not.
with Speech.Windows;

package Speech.Gates
  with SPARK_Mode
is

   Frame : constant := Windows.Rate / 50;
   --  Samples to a frame: 20 ms.

   Pre_Roll  : constant := 15;
   Hangover  : constant := 25;
   Max_Trail : constant := 75;
   --  In frames.

   Open_Margin  : constant Float := 2.0;
   Close_Margin : constant Float := 1.25;
   --  How many times the room's level a frame is to be to be speech, and
   --  to be kept after speech.

   Open_Least : constant Float := 0.0015;
   --  The quietest a frame can be, whatever the room, and be speech (about
   --  -56 dB, which is a long way below a voice).

   Floor_Least : constant Float := 0.0005;
   Floor_Most  : constant Float := 0.02;

   type Floor is private;
   --  What is known of the level of the room.

   Unknown : constant Floor;
   --  Nothing known yet: the room is taken to be quiet.

   function Level (Of_Floor : Floor) return Float
   with Global => null, Post => Level'Result in Floor_Least .. Floor_Most;
   --  The room's level now, as an amplitude.

   procedure Observe (Of_Floor : in out Floor; Audio : Windows.Samples)
   with Global => null, Pre => Audio'Last < Positive'Last;
   --  Learn from sound that has come (all of it, in order).

   procedure Apply (Of_Floor : Floor; Audio : in out Windows.Samples; Voiced : out Boolean)
   with Global => null, Pre => Audio'Last < Positive'Last and then Audio'Length <= Windows.Capacity;
   --  Make silence of the sound in Audio that is not speech. Voiced
   --  says if any is. (The end, less than a frame, goes as the frame
   --  before it does, or is kept if it is all there is.)

private

   type Floor is record
      Amplitude : Float := 0.003;
      Sum       : Float := 0.0;
      --  The squares of the samples of the frame that is coming.
      Seen      : Natural := 0;
      --  How many there are.
   end record
   with
     Type_Invariant =>
       Floor.Amplitude in Floor_Least .. Floor_Most and then Floor.Sum >= 0.0 and then Floor.Seen < Frame;

   Unknown : constant Floor := (others => <>);

   function Level (Of_Floor : Floor) return Float
   is (Of_Floor.Amplitude);

end Speech.Gates;
