--  Speech.Words on tokens as a model says them (the proof is of what
--  cannot go wrong; this is of what is meant).
with Ada.Text_IO;
with Speech.Windows;
with Speech.Words;

procedure Words_Test is
   Mark        : constant String := Character'Val (16#E2#) & Character'Val (16#96#) & Character'Val (16#81#);
   function Token_Of (Which : Positive) return String
   is (case Which is
         when 1      => Mark & "And",
         when 2      => Mark & "so",
         when 3      => ",",
         when 4      => Mark & "form",
         when 5      => Mark,
         when 6      => "3",
         when 7      => "5",
         when 8      => " years",
         when others => "!");
   Token_Count : constant := 9;
   use type Speech.Windows.Offsets;
   Failed      : Natural := 0;

   procedure Check (Name : String; Holds : Boolean) is
   begin
      Ada.Text_IO.Put_Line ((if Holds then "ok    " else "FAIL  ") & Name);
      if not Holds then
         Failed := Failed + 1;
      end if;
   end Check;

   Raw    : String (1 .. 64);
   Used   : Natural := 0;
   Ends   : Speech.Windows.Offsets (1 .. Token_Count);
   Starts : Speech.Windows.Offsets (1 .. Token_Count);
   Stops  : Speech.Windows.Offsets (1 .. Token_Count);
begin
   for T in 1 .. Token_Count loop
      Raw (Used + 1 .. Used + Token_Of (T)'Length) := Token_Of (T);
      Used := Used + Token_Of (T)'Length;
      Ends (T) := Used;
      Starts (T) := (T - 1) * 100;
      Stops (T) := T * 100;
   end loop;
   declare
      Text    : String (1 .. 100) := [others => '.'];
      Length  : Natural;
      Text_At : Speech.Windows.Offsets (1 .. 8) := [others => 0];
      From    : Speech.Windows.Offsets (1 .. 8) := [others => 0];
      To      : Speech.Windows.Offsets (1 .. 8) := [others => 0];
      Count   : Natural;
   begin
      Speech.Words.Group (Raw (1 .. Used), Ends, Starts, Stops, Text, Length, Text_At, From, To, Count);
      Ada.Text_IO.Put_Line (Text (1 .. Length));
      Check ("words", Text (1 .. Length) = "And so, form 35 years!");
      Check ("five words", Count = 5);
      Check ("where they end", Text_At (1 .. Count) = [3, 7, 12, 15, 22]);
      Check ("starts", From (1 .. Count) = [0, 100, 300, 500, 700]);
      Check ("stops", To (1 .. Count) = [100, 300, 400, 700, 900]);
      Check ("as it must be", Speech.Windows.Text_Plausible (Text_At (1 .. Count), Length));
   end;
   declare
      Text    : String (1 .. 10) := [others => '.'];
      Length  : Natural;
      Text_At : Speech.Windows.Offsets (1 .. 8) := [others => 0];
      From    : Speech.Windows.Offsets (1 .. 8) := [others => 0];
      To      : Speech.Windows.Offsets (1 .. 8) := [others => 0];
      Count   : Natural;
   begin
      Speech.Words.Group (Raw (1 .. Used), Ends, Starts, Stops, Text, Length, Text_At, From, To, Count);
      Check ("only what fits, no word cut", Text (1 .. Length) = "And so, 35" or else Length <= 10);
      Check ("still as it must be", Speech.Windows.Text_Plausible (Text_At (1 .. Count), Length));
   end;
   Ada.Text_IO.Put_Line (if Failed = 0 then "all ok" else Failed'Image & " failed");
end Words_Test;
