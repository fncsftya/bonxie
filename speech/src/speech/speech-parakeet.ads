--  The speech models that run on this machine: Parakeet TDT 0.6b v3 on Core
--  ML (so, the Neural Engine), Ada's side of parakeet/ (libBonxieParakeet),
--  and Granite Speech 5.0 2B on MLX, of granite/ (libBonxieGranite): both
--  built by native/build.sh. The one that was loaded last is the one that
--  hears. It makes text of audio given whole, with where each word ends;
--  Speech.Streams makes a stream of that.
--
--  Both calls wait (the first loads the models, downloading them the first
--  time), so they are not for the main thread. The model runs one at a
--  time; they may be called from any task.
--  GNATprove proves the Ada-side contracts under their preconditions. The
--  imported native implementation is not proved to satisfy them, so its
--  outputs must be checked or repaired by the Ada caller. Postconditions
--  are ignored at run time; preconditions remain enabled.
with Speech.Windows;

package Speech.Parakeet
  with SPARK_Mode, Abstract_State => (Model with Synchronous, External => (Async_Readers, Async_Writers))
is
   --  Model is the model, as libBonxieParakeet has it: loaded, or not, and
   --  being fetched, by whoever asks (see Speech.Models).
   --  Synchronous is a claim, not a proof: every slot's task may call
   --  Transcribe at once, and the native library is taken to run them one
   --  at a time. Nothing in the Ada code does that, nor can GNATprove see it.

   Max_Words : constant := 2048;

   subtype Word_Count is Natural range 0 .. Max_Words;

   type Heard is record
      Count         : Word_Count := 0;
      --  Words, of which the first Count of each array are used.
      Text_Length   : Natural := 0;
      Text          : String (1 .. Text_Capacity) := [others => ' '];
      --  The words with a space between each.
      Text_Ends     : Windows.Offsets (1 .. Max_Words) := [others => 0];
      --  Where each word ends in Text: the place of its last byte.
      Sample_Starts : Windows.Offsets (1 .. Max_Words) := [others => 0];
      Sample_Ends   : Windows.Offsets (1 .. Max_Words) := [others => 0];
      --  Where each word starts and ends in the audio, in samples from
      --  its start.
   end record;

   function Present (Kind : Model_Kinds; Directory : String) return Boolean
   with Volatile_Function, Global => (Input => Model);
   --  Whether the model's files are all in Directory (see Speech.Models).

   procedure Load
     (Kind : Model_Kinds; Directory : String; Ok : out Boolean; Message : in out String; Last : out Natural)
   with
     Global => (In_Out => Model),
     Pre    => Message'First = 1 and then Message'Length < Positive'Last / 2 and then Directory /= "",
     Post   => Last <= Message'Length;
   --  Have the model ready, if it is not already: that in Directory. Another
   --  that was loaded is let go.
   --  On failure Message (1 .. Last) says why (not downloaded, say).

   procedure Transcribe
     (Audio : Windows.Samples; Into : in out Heard; Ok : out Boolean; Message : in out String; Last : out Natural)
   with
     Global => (Input => Model),
     Pre    =>
       Message'First = 1
       and then Message'Length < Positive'Last / 2
       and then Audio'First = 1
       and then Audio'Length <= Windows.Capacity,
     Post   =>
       Last <= Message'Length
       and then Into.Count <= Max_Words
       and then Into.Text_Length <= Text_Capacity
       and then (if Ok
                 then
                   Windows.Text_Plausible (Into.Text_Ends (1 .. Into.Count), Into.Text_Length)
                   and then Windows.Ordered
                              (Into.Sample_Starts (1 .. Into.Count), Into.Sample_Ends (1 .. Into.Count), Audio'Length)
                 else Into.Count = 0 and then Into.Text_Length = 0);
   --  Make the text of the audio, and where each word of it is in the
   --  sound. The model's tokens are made into words (Speech.Words), whose
   --  places are made to be as they must (Windows.Repair), so what is
   --  here is as the rest of the program counts on, as it is proved.

   procedure Unload
   with Global => (In_Out => Model);
   --  Let the models go.

end Speech.Parakeet;
