--  The microphone as 16 kHz mono samples, for a model that wants nothing
--  else (see Speech.Parakeet): converted as the sound comes in, and kept until
--  it is read. A capture is told apart by its session number, as
--  Speech's listenings are (the two do not share a number's state). Begin
--  waits for leave to
--  use the microphone, so it is not for the main thread; the rest are
--  cheap and may be called from any thread.
with Speech.Windows;

package Speech.Capture is

   procedure Begin_Capture
     (Which   : Session;
      Ok      : out Boolean;
      Message : out String;
      Last    : out Natural)
     with Pre => Message'First = 1;
   --  Start hearing, in session Which, which is not open already. On
   --  failure Ok is False and Message (1 .. Last) says why.

   procedure Read
     (Which : Session;
      Into  : out Windows.Samples;
      Last  : out Natural)
     with Post => Last in Into'First - 1 .. Into'Last;
   --  Take the samples that have come, as many as Into holds: Into
   --  (Into'First .. Last), the oldest first. None if nothing has come,
   --  or the session is not open. Only the last two minutes are kept.

   function Loudness (Which : Session) return Float
     with Post => Loudness'Result in 0.0 .. 1.0;
   --  How loud it is now, falling away between sounds.

   procedure Stop (Which : Session);
   --  Stop hearing; what came can still be Read.

   procedure Close (Which : Session);
   --  Stop, and forget the session and the samples not read.

end Speech.Capture;
