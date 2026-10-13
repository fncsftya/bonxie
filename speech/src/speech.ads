--  Speech to text (macOS 26 or later): Apple's SpeechAnalyzer listens to
--  the microphone, on-device, and says what was spoken, as text.
--
--  A session is one listening, begun by Begin_Listening and ended by
--  End_Listening; several may be open at once, told apart by number. Both
--  wait (for the microphone to be allowed, for the language's model to be
--  installed the first time, for the last of the speech to be made into
--  text), so they are not for the main thread: see Speech.Jobs.

package Speech is

   Max_Sessions : constant := 16;

   subtype Session is Positive range 1 .. Max_Sessions;

   Text_Capacity : constant := 32_000;
   --  Bytes of what is said in one session: more is left out.

   type Transcript is record
      Length    : Natural := 0;
      --  Text (1 .. Length) is what is used.
      Truncated : Boolean := False;
      Text      : String (1 .. Text_Capacity) := [others => ' '];
   end record
     with Dynamic_Predicate => Transcript.Length <= Text_Capacity;

   function Image (Of_Transcript : Transcript) return String
     is (Of_Transcript.Text (1 .. Of_Transcript.Length));

   procedure Begin_Listening
     (Which   : Session;
      Ok      : out Boolean;
      Message : out String;
      Last    : out Natural)
     with Pre => Message'First = 1;
   --  Start listening, in session Which, which is not open already. On
   --  failure Ok is False and Message (1 .. Last) says why: no
   --  microphone, no leave to use it, a language that is not supported.

   function Level (Which : Session) return Float
     with Post => Level'Result in 0.0 .. 1.0;
   --  How loud what is heard is now, from 0.0 (silence, or not
   --  listening) to 1.0: it falls away between sounds. Cheap, and may be
   --  called from any thread.

   procedure Peek (Which : Session; Into : in out Transcript);
   --  What has been heard so far in an open session, as text: the words
   --  that are settled, then those still being worked out, which a later
   --  Peek may change. Empty if the session is not open. Cheap enough to
   --  call every frame, and from any thread.

   procedure End_Listening
     (Which   : Session;
      Into    : in out Transcript;
      Ok      : out Boolean;
      Message : out String;
      Last    : out Natural)
     with Pre => Message'First = 1;
   --  Stop listening, in an open session, and wait for the rest of what
   --  was heard to be made text, which goes in Into (empty if nothing
   --  was said). The session is closed, however it ends.

end Speech;
