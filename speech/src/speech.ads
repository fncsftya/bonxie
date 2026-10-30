--  Speech to text (macOS 26 or later): Apple's SpeechAnalyzer listens to
--  the microphone, on-device, and says what was spoken, as text.
--
--  A session is one listening, begun by Begin_Listening and ended by
--  End_Listening; several may be open at once, told apart by number. Both
--  wait (for the microphone to be allowed, for the language's model to be
--  installed the first time, for the last of the speech to be made into
--  text), so they are not for the main thread: see Speech.Jobs.

package Speech
  with
    SPARK_Mode,
    Abstract_State => (Recognizer with Synchronous, External => (Async_Readers, Async_Writers)),
    Initializes    => null
is
   --  Recognizer is SpeechAnalyzer's (Swift's) side of listenings: it is
   --  shared by every thread, and changes of itself (as sound comes).
   --  Synchronous is a claim, not a proof: the Swift side is taken to
   --  serialize its own calls, and GNATprove does not look inside it.

   type Model_Kinds is (Parakeet_V3, Granite_5);
   --  The speech models that are fetched and run on this machine (see Speech.Models):
   --  Parakeet TDT 0.6b v3 on Core ML, and Granite Speech 5.0 2B (4-bit) on MLX.

   Max_Sessions : constant := 16;

   subtype Session is Positive range 1 .. Max_Sessions;

   Text_Capacity : constant := 32_000;
   --  Bytes of what is said in one session: more is left out.

   type Transcript is record
      Length    : Natural := 0;
      --  Text (1 .. Length) is what is used.
      Truncated : Boolean := False;
      Settled   : Natural := 0;
      --  Text (1 .. Settled) will not change; what follows may.
      Text      : String (1 .. Text_Capacity) := [others => ' '];
   end record
   with Dynamic_Predicate => Transcript.Length <= Text_Capacity and then Transcript.Settled <= Transcript.Length;

   function Image (Of_Transcript : Transcript) return String
   is (Of_Transcript.Text (1 .. Of_Transcript.Length))
   with Post => Image'Result'First = 1 and then Image'Result'Length = Of_Transcript.Length;

   procedure Begin_Listening (Which : Session; Ok : out Boolean; Message : out String; Last : out Natural)
   with
     Global => (In_Out => Recognizer),
     Pre    => Message'First = 1 and then Message'Length < Positive'Last / 2,
     Post   => Last <= Message'Length;
   --  Start listening, in session Which, which is not open already. On
   --  failure Ok is False and Message (1 .. Last) says why: no
   --  microphone, no leave to use it, a language that is not supported.

   function Level (Which : Session) return Float
   with Volatile_Function, Global => (Input => Recognizer), Post => Level'Result in 0.0 .. 1.0;
   --  How loud what is heard is now, from 0.0 (silence, or not
   --  listening) to 1.0: it falls away between sounds. Cheap, and may be
   --  called from any thread.

   procedure Peek (Which : Session; Into : in out Transcript)
   with Global => (Input => Recognizer);
   --  What has been heard so far in an open session, as text: the words
   --  that are settled, then those still being worked out, which a later
   --  Peek may change. Empty if the session is not open. Cheap enough to
   --  call every frame, and from any thread.

   procedure End_Listening
     (Which : Session; Into : in out Transcript; Ok : out Boolean; Message : out String; Last : out Natural)
   with
     Global => (In_Out => Recognizer),
     Pre    => Message'First = 1 and then Message'Length < Positive'Last / 2,
     Post   => Last <= Message'Length;
   --  Stop listening, in an open session, and wait for the rest of what
   --  was heard to be made text, which goes in Into (empty if nothing
   --  was said). The session is closed, however it ends.

end Speech;
