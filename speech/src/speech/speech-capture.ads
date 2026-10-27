--  The microphone as 16 kHz mono samples, for a model that wants nothing
--  else (see Speech.Parakeet): converted as the sound comes in, and kept
--  until it is read. A capture is told apart by its session number, as
--  Speech's listenings are (the two do not share a number's state). Begin
--  waits for leave to use the microphone, so it is not for the main
--  thread; the rest are cheap and may be called from any thread.
--
--  The sound goes from the microphone's thread to the reader's through a
--  ring (Speech.Rings, whose arithmetic is proved) that neither waits for
--  the other to use: the microphone's thread does no more than copy the
--  samples in, and say how loud they were, and cannot be held up by a
--  reader that is slow, or has stopped.
with Speech.Windows;

package Speech.Capture
  with
    SPARK_Mode,
    Abstract_State => (Ring with Synchronous, External => (Async_Readers, Async_Writers)),
    Initializes    => null
is
   --  Ring is the sound that has come and not been read, and how loud it
   --  is: the microphone's thread writes it, and the reader reads, with
   --  no other lock than that of each count being whole (see the body).
   --  Synchronous is a claim, not a proof: the body is not SPARK, so that
   --  the samples are written before the count that publishes them (and
   --  read after it) is for the tests, and the atomic counts, to bear out.

   procedure Begin_Capture (Which : Session; Ok : out Boolean; Message : out String; Last : out Natural)
   with
     Global => (In_Out => Ring),
     Pre    => Message'First = 1 and then Message'Length < Positive'Last / 2,
     Post   => Last <= Message'Length;
   --  Start hearing, in session Which, which is not open already. On
   --  failure Ok is False and Message (1 .. Last) says why.

   procedure Read (Which : Session; Into : out Windows.Samples; Last : out Natural)
   with Global => (In_Out => Ring), Post => Last in Into'First - 1 .. Into'Last;
   --  Take the samples that have come, as many as Into holds: Into
   --  (Into'First .. Last), the oldest first. None if nothing has come,
   --  or the session is not open. A sample that is not a number (which a
   --  sound card should not give) is silence, and one too loud to be
   --  real is as loud as can be.

   function Dropped (Which : Session) return Natural
   with Volatile_Function, Global => (Input => Ring);
   --  How many samples have been lost, since the capture began, because
   --  more than the ring holds (a little over two minutes) were waiting
   --  to be read: the newest are the ones lost.

   procedure Set_Room (Which : Session; Amplitude : Float)
   with Global => (In_Out => Ring), Pre => Amplitude in 0.0 .. 1.0;
   --  Say how loud the room is, as an amplitude (see Speech.Gates), which
   --  the reader finds, from what it hears, as it reads.

   function Loudness (Which : Session) return Float
   with Volatile_Function, Global => (Input => Ring), Post => Loudness'Result in 0.0 .. 1.0;
   --  How loud it is now, falling away between sounds, above that of the
   --  room: a quiet room is silence, and speech, as it is to the gate,
   --  fills the more of it the louder it is.

   procedure Stop (Which : Session)
   with Global => (In_Out => Ring);
   --  Stop hearing; what came can still be Read.

   procedure Close (Which : Session)
   with Global => (In_Out => Ring);
   --  Stop, and forget the session and the samples not read.

end Speech.Capture;
