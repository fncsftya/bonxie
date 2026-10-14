pragma Assertion_Policy
  (Post => Ignore, Postcondition => Ignore, Type_Invariant => Ignore,
   Loop_Invariant => Ignore, Assert => Ignore);

package body Speech.Words
  with SPARK_Mode
is

   --  U+2581, in UTF-8.
   Mark_1 : constant Character := Character'Val (16#E2#);
   Mark_2 : constant Character := Character'Val (16#96#);
   Mark_3 : constant Character := Character'Val (16#81#);

   function Mark_At (Token_Text : String; From, Stop : Natural) return Boolean is
     (From >= 1 and then Stop >= 3 and then From <= Stop - 2
      and then Token_Text (From) = Mark_1
      and then Token_Text (From + 1) = Mark_2
      and then Token_Text (From + 2) = Mark_3)
     with Pre => Token_Text'First = 1 and then Stop <= Token_Text'Length;
   --  Whether the mark is at From, of a token that ends at Stop.

   function Space_At (Token_Text : String; From, Stop : Natural) return Boolean is
     (From >= 1 and then From <= Stop and then Token_Text (From) = ' ')
     with Pre => Token_Text'First = 1 and then Stop <= Token_Text'Length;

   procedure Group
     (Token_Text     : String;
      Token_Ends     : Offsets;
      Token_Starts   : Offsets;
      Token_Stops    : Offsets;
      Text           : in out String;
      Text_Length    : out Natural;
      Word_Text_Ends : in out Offsets;
      Word_Starts    : in out Offsets;
      Word_Stops     : in out Offsets;
      Word_Count     : out Natural)
   is
      Used    : Natural := 0;
      --  How much of Text is made.
      Done    : Natural := 0;
      --  How many words are made.
      Spaced  : Boolean := True;
      --  Whether the next piece begins a word.
      Full    : Boolean := False;
      --  Whether a word did not fit.
   begin
      for Token in Token_Ends'Range loop
         pragma Loop_Invariant (Done <= Word_Text_Ends'Length);
         pragma Loop_Invariant (Used <= Text'Length);
         pragma Loop_Invariant (Windows.Text_Plausible (Word_Text_Ends (1 .. Done), Used));
         pragma Loop_Invariant (if Done > 0 then Word_Text_Ends (Done) = Used else Used = 0);
         exit when Full;
         declare
            Start : constant Positive := (if Token = 1 then 1 else Token_Ends (Token - 1) + 1);
            Stop  : constant Natural := Token_Ends (Token);
            From  : Positive := Start;
            Last  : Natural := Stop;
            Marks : Boolean := False;
         begin
            --  The mark, or spaces, that begin the token.
            while Mark_At (Token_Text, From, Stop) or else Space_At (Token_Text, From, Stop) loop
               pragma Loop_Invariant (From in Start .. Stop);
               pragma Loop_Variant (Increases => From);
               Marks := True;
               From := (if Space_At (Token_Text, From, Stop) then From + 1 else From + 3);
            end loop;
            --  The spaces that end it.
            while Last >= From and then Token_Text (Last) = ' ' loop
               pragma Loop_Invariant (Last in From - 1 .. Stop);
               pragma Loop_Variant (Decreases => Last);
               Last := Last - 1;
            end loop;
            if Marks then
               Spaced := True;
            end if;
            if Last >= From then
               declare
                  Length : constant Positive := Last - From + 1;
               begin
                  if Spaced or else Done = 0 then
                     --  A word of its own, after a space (if not the first).
                     declare
                        Space : constant Natural := (if Done = 0 then 0 else 1);
                     begin
                        if Done < Word_Text_Ends'Length
                          and then Length <= Text'Length - Used
                          and then Space <= Text'Length - Used - Length
                        then
                           if Space = 1 then
                              Text (Used + 1) := ' ';
                           end if;
                           Text (Used + Space + 1 .. Used + Space + Length) := Token_Text (From .. Last);
                           Used := Used + Space + Length;
                           Done := Done + 1;
                           Word_Text_Ends (Done) := Used;
                           Word_Starts (Done) := Token_Starts (Token);
                           Word_Stops (Done) := Token_Stops (Token);
                           Spaced := False;
                        else
                           Full := True;
                        end if;
                     end;
                  elsif Length <= Text'Length - Used then
                     --  On the word before.
                     Text (Used + 1 .. Used + Length) := Token_Text (From .. Last);
                     Used := Used + Length;
                     Word_Text_Ends (Done) := Used;
                     Word_Stops (Done) := Token_Stops (Token);
                  else
                     Full := True;
                  end if;
               end;
            end if;
         end;
      end loop;
      Text_Length := Used;
      Word_Count := Done;
   end Group;

end Speech.Words;
