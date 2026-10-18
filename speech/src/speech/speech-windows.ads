--  The audio a model is run over again and again, as it grows: a window on
--  the sound that has come, which only ever slides forward. New samples are
--  added at its end; once the words in its first part are settled (they
--  will not change when more is heard) that part is dropped. Samples are
--  told apart by their place in everything heard, from 0, so a sample keeps
--  its number as the window slides.
--
--  Nothing here knows of the model or microphone. GNATprove checks the Ada
--  code for run-time errors and proves its contracts under their
--  preconditions (`gnatprove -P speech.gpr -u speech-windows.adb --level=2`).
--  Those contracts describe bounds and consistency; they do not prove every
--  intended behavior. Values passed through Clean are kept usable by the
--  model: in -1.0 .. 1.0, so no infinity or NaN is returned. GNATprove treats
--  every Float as a number, so the NaN case is checked by windows_test.
--  All operations have Global => null, so they access no package state.
--  Postconditions and invariants inspect whole windows and are ignored at
--  run time; preconditions remain enabled.
pragma Assertion_Policy
  (Post => Ignore, Postcondition => Ignore, Type_Invariant => Ignore,
   Loop_Invariant => Ignore, Assert => Ignore);

package Speech.Windows
  with SPARK_Mode
is

   Rate : constant := 16_000;
   --  Samples to the second.

   Capacity : constant := 15 * Rate;
   --  What the window holds: the longest the model takes in one go.

   Max_Index : constant := 2 ** 50;
   --  Far more than can be heard (a million years).

   type Sample_Index is range 0 .. Max_Index;

   type Samples is array (Positive range <>) of Float;
   --  Mono audio at Rate.

   function Usable (Value : Float) return Boolean is (Value in -1.0 .. 1.0)
     with Global => null;
   --  Whether a model can take the sample. (False for a NaN, as every
   --  comparison with one is.)

   function Clean (Audio : Samples; Index : Integer) return Float
     with Global => null,
          Pre    => Index in Audio'Range,
          Post   => Usable (Clean'Result)
                    and then (if Usable (Audio (Index)) then Clean'Result = Audio (Index));
   --  The sample at Index as it can be used: as it is, if it can; one that
   --  is too loud to be real, at the loudest there is; and one that is
   --  not a number at all (a NaN, an infinity), silence. It is looked at
   --  without being read, as reading one that is not a number is an error
   --  (the crate is built to say so), and what the sound card gives is not
   --  to be trusted with that. (GNATprove takes every number to be one, so
   --  the proof is of all but that: windows_test is of the rest.)

   type Window is private;

   function First (Of_Window : Window) return Sample_Index
     with Global => null;
   --  The place of the oldest sample the window holds.

   function Count (Of_Window : Window) return Natural
     with Global => null,
          Post   => Count'Result <= Capacity;
   --  How many samples it holds.

   function Next (Of_Window : Window) return Sample_Index
     with Global => null,
          Post   => Next'Result = First (Of_Window) + Sample_Index (Count (Of_Window));
   --  The place the next sample to come will have.

   function Decoded (Of_Window : Window) return Sample_Index
     with Global => null,
          Post   => Decoded'Result in First (Of_Window) .. Next (Of_Window);
   --  Next, when the model was last run (or First, if that is later).

   function Sample (Of_Window : Window; Place : Sample_Index) return Float
     with Global => null,
          Pre    => Place >= First (Of_Window) and then Place < Next (Of_Window),
          Post   => Usable (Sample'Result);

   procedure Clear (Of_Window : in out Window)
     with Global => null,
          Post   => Count (Of_Window) = 0
                    and then First (Of_Window) = 0
                    and then Decoded (Of_Window) = 0;
   --  Forget everything held, and start again from place 0. (The samples
   --  that were held are left as they are, to be written over.)

   procedure Append
     (Of_Window : in out Window;
      Audio     : Samples;
      Taken     : out Natural)
     with Global => null,
          Pre    => Audio'Last < Positive'Last
                    and then Next (Of_Window) <= Max_Index - Capacity,
          Post   => Taken = Natural'Min
                      (Audio'Length, Capacity - Count (Of_Window'Old))
                    and then First (Of_Window) = First (Of_Window'Old)
                    and then Decoded (Of_Window) = Decoded (Of_Window'Old)
                    and then Count (Of_Window) = Count (Of_Window'Old) + Taken
                    and then
                      (for all Place in First (Of_Window) .. Next (Of_Window'Old) - 1 =>
                         Sample (Of_Window, Place) = Sample (Of_Window'Old, Place))
                    and then
                      (for all K in 1 .. Taken =>
                         Sample (Of_Window, Next (Of_Window'Old) + Sample_Index (K) - 1)
                         = Clean (Audio, Audio'First + K - 1));
   --  Add samples at the end, as many as fit: Taken says how many (the
   --  first of Audio), each as Clean makes it.

   function Due (Of_Window : Window; Hop : Positive) return Boolean
     with Global => null,
          Post   => Due'Result = (Next (Of_Window) - Decoded (Of_Window) >= Sample_Index (Hop));
   --  Whether Hop samples or more have come since the model was last run.

   function Full (Of_Window : Window; Room : Positive) return Boolean
     with Global => null,
          Pre    => Room <= Capacity,
          Post   => Full'Result = (Capacity - Count (Of_Window) < Room);
   --  Whether there is not room for Room more samples.

   procedure Mark_Decoded (Of_Window : in out Window)
     with Global => null,
          Post   => Decoded (Of_Window) = Next (Of_Window)
                    and then First (Of_Window) = First (Of_Window'Old)
                    and then Count (Of_Window) = Count (Of_Window'Old)
                    and then
                      (for all Place in First (Of_Window) .. Next (Of_Window) - 1 =>
                         Sample (Of_Window, Place) = Sample (Of_Window'Old, Place));
   --  Say the model has just been run over everything held.

   procedure Drop_Before (Of_Window : in out Window; Place : Sample_Index)
     with Global => null,
          Pre    => Place >= First (Of_Window) and then Place <= Next (Of_Window),
          Post   => First (Of_Window) = Place
                    and then Next (Of_Window) = Next (Of_Window'Old)
                    and then Decoded (Of_Window) = Sample_Index'Max (Decoded (Of_Window'Old), Place)
                    and then
                      (for all Where in Place .. Next (Of_Window) - 1 =>
                         Sample (Of_Window, Where) = Sample (Of_Window'Old, Where));
   --  Forget the samples before Place: the window slides forward to it.

   procedure Make_Room (Of_Window : in out Window; Room : Positive)
     with Global => null,
          Pre    => Room <= Capacity,
          Post   => not Full (Of_Window, Room)
                    and then Next (Of_Window) = Next (Of_Window'Old)
                    and then
                      (if not Full (Of_Window'Old, Room)
                       then First (Of_Window) = First (Of_Window'Old)
                            and then Count (Of_Window) = Count (Of_Window'Old)
                       else Count (Of_Window) = 0);
   --  When the model has fallen behind, and the window is full, there is
   --  one thing to do that cannot go wrong: let the oldest sound go, all
   --  of it (it is what has not been settled, which is lost). What comes
   --  next is never held up, nor mistaken for what was there before: its
   --  places go on from where they were.

   ---------------------------------------------------------------------
   --  Which words are settled, and what the model said of them.

   type Offsets is array (Positive range <>) of Natural;
   --  Where words end, in samples from the start of the window, the
   --  first word first.

   function Ordered (Starts, Ends : Offsets; Total : Natural) return Boolean is
     (Starts'First = 1 and then Ends'First = 1 and then Starts'Last = Ends'Last
      and then
        (for all Word in Ends'Range =>
           Starts (Word) <= Ends (Word)
           and then Ends (Word) <= Total
           and then (if Word > 1 then Ends (Word - 1) <= Ends (Word))))
     with Global => null;
   --  Whether the words, which Starts and Ends say where they are in a
   --  sound Total samples long, are as words in a sound are: they begin
   --  before they end, are in the sound, and come in order.

   procedure Repair (Starts, Ends : in out Offsets; Total : Natural)
     with Global => null,
          Pre    => Starts'First = 1 and then Ends'First = 1 and then Starts'Last = Ends'Last,
          Post   => Ordered (Starts, Ends, Total);
   --  Make the words Ordered, by moving the one that is not: a model
   --  sometimes ends a word, at the end of the sound, before the word
   --  before it. (The words are not changed otherwise.)

   function Text_Plausible (Text_Ends : Offsets; Text_Length : Natural) return Boolean is
     (Text_Ends'First = 1
      and then
        (for all Word in Text_Ends'Range =>
           Text_Ends (Word) <= Text_Length
           and then Text_Ends (Word) >= (if Word = 1 then 1 else 2)
           and then (if Word > 1 then Text_Ends (Word) - 2 >= Text_Ends (Word - 1))
           and then (for all Before in Text_Ends'First .. Word =>
                       Text_Ends (Before) <= Text_Ends (Word))))
     with Global => null;
   --  Whether Text_Ends, the place each word ends in a text Text_Length
   --  long, in which the words are apart by a space, is as it must be:
   --  the words are in the text, in order, and each is some letters. That
   --  is for the code that made the text to see to, so it is not mended.

   function Text_From (Text_Ends : Offsets; Word : Positive) return Positive is
     (if Word = 1 then 1 else Text_Ends (Word - 1) + 2)
     with Global => null,
          Pre    => Text_Ends'First = 1
                    and then Word <= Text_Ends'Last
                    and then Text_Ends'Last < Positive'Last
                    and then (for all Index in Text_Ends'Range =>
                                Text_Ends (Index) <= Text_Capacity)
                    and then Text_Plausible (Text_Ends, Text_Capacity),
          Post   => Text_From'Result <= Text_Ends (Word);
   --  Where the Word'th word starts in a text, for which Text_Ends says
   --  where each ends (when Text_Plausible).

   function Is_Settled (Ends_At, Total, Guard : Natural) return Boolean is
     (Ends_At <= Total and then Total - Ends_At >= Guard)
     with Global => null;
   --  A word that ends Guard samples or more before the end of the sound
   --  heard (Total samples) is not likely to change when more is heard.

   function Settled
     (Ends : Offsets; From : Positive; Total, Guard : Natural) return Natural
     with Global => null,
          Pre    => Ends'First = 1
                    and then Ends'Last < Positive'Last
                    and then From <= Ends'Length + 1,
          Post   => Settled'Result in From - 1 .. Ends'Length
                    and then
                      (for all Word in From .. Settled'Result =>
                         Is_Settled (Ends (Word), Total, Guard))
                    and then
                      (Settled'Result = Ends'Length
                       or else not Is_Settled (Ends (Settled'Result + 1), Total, Guard));
   --  The last word that is settled, of those from From on, all the words
   --  from From up to it being settled: From - 1 if the first is not.

   function Passed (Starts, Ends : Offsets; Boundary : Natural) return Natural
     with Global => null,
          Pre    => Starts'First = 1 and then Ends'First = 1 and then Starts'Last = Ends'Last,
          Post   => Passed'Result <= Ends'Length
                    and then
                      (for all Word in 1 .. Passed'Result =>
                         Starts (Word) / 2 + Ends (Word) / 2 <= Boundary)
                    and then
                      (Passed'Result = Ends'Length
                       or else Starts (Passed'Result + 1) / 2 + Ends (Passed'Result + 1) / 2 > Boundary);
   --  How many words at the start are already behind Boundary, by their
   --  middles: they were heard before, and need no more.

   function Cut_Place
     (Of_Window : Window; Ends : Offsets; Word : Positive) return Sample_Index
     with Global => null,
          Pre    => Ends'First = 1
                    and then Word <= Ends'Length
                    and then Ends (Word) <= Count (Of_Window),
          Post   => Cut_Place'Result >= First (Of_Window)
                    and then Cut_Place'Result <= Next (Of_Window);
   --  Where the window may slide to when Word is the last that is
   --  settled: the end of that word.

   ---------------------------------------------------------------------
   --  The text so far.

   procedure Append_Text (Into : in out Transcript; Words : String)
     with Global => null,
          Pre    => Words'Last < Positive'Last
                    and then Words'Length <= Text_Capacity
                    and then Into.Length <= Text_Capacity,
          Post   => Into.Length <= Text_Capacity
                    and then Into.Length >= Into.Length'Old
                    and then Into.Length = Natural'Min (Text_Capacity, Into.Length'Old + Words'Length)
                    and then Into.Truncated =
                      (Into.Truncated'Old or else Into.Length'Old + Words'Length > Text_Capacity)
                    and then Into.Text (1 .. Into.Length'Old) = Into.Text'Old (1 .. Into.Length'Old);
   --  Add Words to the end of the text, as much as fits.

private

   type Window is record
      Start : Sample_Index := 0;
      Held  : Natural := 0;
      Last  : Sample_Index := 0;
      --  The place the model last ran to.
      Data  : Samples (1 .. Capacity) := [others => 0.0];
   end record
     with Type_Invariant =>
       Window.Held <= Capacity
       and then Sample_Index (Window.Held) <= Sample_Index'Last - Window.Start
       and then Window.Last >= Window.Start
       and then Window.Last - Window.Start <= Sample_Index (Window.Held)
       and then (for all Place in 1 .. Window.Held => Usable (Window.Data (Place)));

   function First (Of_Window : Window) return Sample_Index is (Of_Window.Start);

   function Count (Of_Window : Window) return Natural is (Of_Window.Held);

   function Next (Of_Window : Window) return Sample_Index is
     (Of_Window.Start + Sample_Index (Of_Window.Held));

   function Decoded (Of_Window : Window) return Sample_Index is (Of_Window.Last);

   function Sample (Of_Window : Window; Place : Sample_Index) return Float is
     (Of_Window.Data (Positive (Place - Of_Window.Start + 1)));

end Speech.Windows;
