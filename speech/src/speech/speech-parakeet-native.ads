--  The C interface of libBonxieParakeet (see parakeet/Sources), as it is:
--  nothing is made of what comes back here, and nothing is taken on trust
--  by what calls it (Speech.Parakeet), except the plain sizes, which the
--  body sees to.
with Speech.Windows;

private package Speech.Parakeet.Native
  with SPARK_Mode
is

   Max_Tokens          : constant := 4096;
   Token_Text_Capacity : constant := 65_536;

   function Models_Present (Directory : String) return Boolean
     with Volatile_Function,
          Global => (Input => Parakeet.Model);

   procedure Load_Models
     (Directory : String;
      Ok        : out Boolean;
      Message   : in out String;
      Last      : out Natural)
     with Global => (In_Out => Parakeet.Model),
          Pre    => Message'First = 1 and then Message'Length < Positive'Last / 2,
          Post   => Last <= Message'Length;

   procedure Unload_Models
     with Global => (In_Out => Parakeet.Model);

   procedure Raw_Tokens
     (Audio             : Windows.Samples;
      Token_Text        : in out String;
      Token_Text_Length : out Natural;
      Token_Ends        : in out Windows.Offsets;
      Token_Starts      : in out Windows.Offsets;
      Token_Stops       : in out Windows.Offsets;
      Token_Count       : out Natural;
      Ok                : out Boolean;
      Message           : in out String;
      Last              : out Natural)
     with Global => (Input => Parakeet.Model),
          Pre    => Audio'First = 1
                    and then Audio'Length <= Windows.Capacity
                    and then Message'First = 1
                    and then Message'Length < Positive'Last / 2
                    and then Token_Text'First = 1
                    and then Token_Text'Length <= Token_Text_Capacity
                    and then Token_Ends'First = 1
                    and then Token_Starts'First = 1
                    and then Token_Stops'First = 1
                    and then Token_Starts'Last = Token_Ends'Last
                    and then Token_Stops'Last = Token_Ends'Last
                    and then Token_Ends'Last <= Max_Tokens,
          Post   => Last <= Message'Length
                    and then Token_Text_Length <= Token_Text'Length
                    and then Token_Count <= Token_Ends'Length
                    and then (if not Ok then Token_Count = 0 and then Token_Text_Length = 0);
   --  The model's tokens of the audio: their text, one after the other,
   --  as the model has it (see pk_transcribe); where each ends in it; and
   --  where each starts and stops in the sound. As many as fit.

end Speech.Parakeet.Native;
