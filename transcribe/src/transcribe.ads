--  Speech to text from a GGUF model, by transcribe.cpp (the submodule
--  `transcribe.cpp`, built by `native/build.sh`): the Ada side of its C
--  interface.
--
--  The model wants 16 kHz mono float samples (-1.0 .. 1.0); it does not
--  convert, so whoever has the audio does (see Speech.Capture). See
--  Transcribe.Sessions for streaming.
package Transcribe is

   Sample_Rate : constant := 16_000;
   --  Samples to the second that the models are fed.

   type Samples is array (Positive range <>) of Float
     with Convention => C;
   --  Mono audio at Sample_Rate.

   Text_Capacity : constant := 32_000;
   --  Bytes of text that can be read from a session: more is left out.

   Max_Message : constant := 160;
   --  Bytes of a message saying why a call failed: more is left out.

   function Version return String;
   --  Of the library.

end Transcribe;
