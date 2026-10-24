with Speech.Parakeet.Native;
with Speech.Words;

package body Speech.Parakeet
  with SPARK_Mode,
       Refined_State => (Model => null)
is

   function Present (Directory : String) return Boolean is (Native.Models_Present (Directory));

   procedure Load
     (Directory : String;
      Ok        : out Boolean;
      Message   : in out String;
      Last      : out Natural) is
   begin
      Native.Load_Models (Directory, Ok, Message, Last);
   end Load;

   procedure Unload is
   begin
      Native.Unload_Models;
   end Unload;

   procedure Say (Said : String; Message : out String; Last : out Natural)
     with Pre  => Message'First = 1 and then Message'Length < Positive'Last / 2
                  and then Said'First = 1 and then Said'Length < Positive'Last / 2,
          Post => Last <= Message'Length;
   --  Put Said in Message, as much as fits.

   procedure Say (Said : String; Message : out String; Last : out Natural) is
      Used : constant Natural := Natural'Min (Said'Length, Message'Length);
   begin
      Message := [others => ' '];
      Message (1 .. Used) := Said (1 .. Used);
      Last := Used;
   end Say;

   procedure Transcribe
     (Audio   : Windows.Samples;
      Into    : in out Heard;
      Ok      : out Boolean;
      Message : in out String;
      Last    : out Natural)
   is
      Token_Text   : String (1 .. Native.Token_Text_Capacity) := [others => ' '];
      Token_Length : Natural;
      Token_Ends   : Windows.Offsets (1 .. Native.Max_Tokens) := [others => 0];
      Token_Starts : Windows.Offsets (1 .. Native.Max_Tokens) := [others => 0];
      Token_Stops  : Windows.Offsets (1 .. Native.Max_Tokens) := [others => 0];
      Found        : Natural;
      Made         : Natural;
   begin
      Into.Count := 0;
      Into.Text_Length := 0;
      Native.Raw_Tokens
        (Audio, Token_Text, Token_Length, Token_Ends, Token_Starts, Token_Stops, Found,
         Ok, Message, Last);
      if not Ok then
         return;
      end if;
      if not Words.Tokens_Plausible (Token_Ends (1 .. Found), Token_Length) then
         Ok := False;
         Say ("The speech model's tokens could not be made sense of", Message, Last);
         return;
      end if;
      Words.Group
        (Token_Text (1 .. Token_Length), Token_Ends (1 .. Found),
         Token_Starts (1 .. Found), Token_Stops (1 .. Found),
         Into.Text, Into.Text_Length, Into.Text_Ends, Into.Sample_Starts, Into.Sample_Ends,
         Made);
      Into.Count := Made;
      Windows.Repair
        (Into.Sample_Starts (1 .. Into.Count), Into.Sample_Ends (1 .. Into.Count), Audio'Length);
   end Transcribe;

end Speech.Parakeet;
