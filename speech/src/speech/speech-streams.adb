package body Speech.Streams
  with SPARK_Mode
is

   procedure Configure (Item : in out Stream; With_Tuning : Tuning) is
   begin
      Item.Tuned := With_Tuning;
   end Configure;

   procedure Reset (Item : in out Stream) is
   begin
      Windows.Clear (Item.Held);
      Item.Room := Gates.Unknown;
      Item.Settled_To := 0;
      Item.Settled.Length := 0;
      Item.Settled.Truncated := False;
      Item.Tentative.Length := 0;
      Item.Tentative.Truncated := False;
   end Reset;

   procedure Decode
     (Item     : in out Stream;
      Is_Final : Boolean;
      Ok       : out Boolean;
      Message  : out String;
      Last     : out Natural)
     with Global => (Input => Parakeet.Model),
          Pre    => Consistent (Item)
                    and then Message'First = 1
                    and then Message'Length < Positive'Last / 2,
          Post   => Consistent (Item) and then Last <= Message'Length;
   --  Run the model over the window; keep as settled the words that are
   --  (all of them if Is_Final, or if the window is full), and slide the
   --  window past them. The rest are the tentative text.

   procedure Decode
     (Item     : in out Stream;
      Is_Final : Boolean;
      Ok       : out Boolean;
      Message  : out String;
      Last     : out Natural)
   is
      Heard : Parakeet.Heard;
      Used  : constant Natural := Windows.Count (Item.Held);
      Voiced : Boolean := True;
      --  Whether any of what is held is speech.
      Skip  : Natural;
      --  Words at the start that are settled already.
      Done  : Natural;
      --  The last word that is settled now.
   begin
      Message := [others => ' '];
      Last := 0;
      Ok := True;
      Item.Tentative.Length := 0;
      Item.Tentative.Truncated := False;
      if Used = 0 then
         Windows.Mark_Decoded (Item.Held);
         return;
      end if;
      declare
         Audio : Windows.Samples (1 .. Used) := [others => 0.0];
      begin
         for Index in 1 .. Used loop
            Audio (Index) :=
              Windows.Sample (Item.Held, Windows.First (Item.Held) + Windows.Sample_Index (Index - 1));
         end loop;
         if Item.Tuned.Gate then
            Gates.Apply (Item.Room, Audio, Voiced);
         end if;
         if Voiced then
            Parakeet.Transcribe (Audio, Heard, Ok, Message, Last);
         end if;
         --  (What is all room is not given to the model, which would make
         --  words of it: nothing was said.)
      end;
      if not Ok then
         return;
      end if;
      Windows.Mark_Decoded (Item.Held);
      Skip := Windows.Passed
        (Heard.Sample_Starts (1 .. Heard.Count), Heard.Sample_Ends (1 .. Heard.Count),
         (if Item.Settled_To > Windows.First (Item.Held)
          then Natural (Item.Settled_To - Windows.First (Item.Held)) + Item.Tuned.Slack else 0));
      declare
         Everything : constant Boolean :=
           Is_Final or else Windows.Full (Item.Held, Item.Tuned.Hop);
      begin
         Done := (if Everything then Heard.Count
                  elsif Used >= Item.Tuned.Trigger
                  then Windows.Settled
                         (Heard.Sample_Ends (1 .. Heard.Count), Skip + 1, Used, Item.Tuned.Guard)
                  else Skip);
         if Done > Skip then
            if Item.Settled.Length > 0 then
               Windows.Append_Text (Item.Settled, " ");
            end if;
            Windows.Append_Text
              (Item.Settled,
               Heard.Text
                 (Windows.Text_From (Heard.Text_Ends (1 .. Heard.Count), Skip + 1)
                  .. Heard.Text_Ends (Done)));
         end if;
         if Everything then
            Item.Settled_To := Windows.Next (Item.Held);
            Windows.Drop_Before (Item.Held, Windows.Next (Item.Held));
         elsif Done > Skip then
            Item.Settled_To :=
              Windows.Cut_Place (Item.Held, Heard.Sample_Ends (1 .. Heard.Count), Done);
            Windows.Drop_Before
              (Item.Held,
               (if Item.Settled_To - Windows.First (Item.Held) > Windows.Sample_Index (Item.Tuned.Context)
                then Item.Settled_To - Windows.Sample_Index (Item.Tuned.Context)
                else Windows.First (Item.Held)));
         end if;
      end;
      if Done < Heard.Count then
         Windows.Append_Text
           (Item.Tentative,
            Heard.Text
              (Windows.Text_From (Heard.Text_Ends (1 .. Heard.Count), Done + 1)
               .. Heard.Text_Length));
      end if;
   end Decode;

   procedure Feed
     (Item    : in out Stream;
      Audio   : Windows.Samples;
      Changed : out Boolean;
      Ok      : out Boolean;
      Message : out String;
      Last    : out Natural)
   is
      Place : Natural := Audio'First;
      Taken : Natural;
   begin
      Changed := False;
      Ok := True;
      Message := [others => ' '];
      Last := 0;
      while Place <= Audio'Last loop
         pragma Loop_Invariant (Consistent (Item));
         pragma Loop_Invariant (Place in Audio'First .. Audio'Last);
         pragma Loop_Invariant (Last <= Message'Length);
         pragma Loop_Variant (Increases => Place);
         if Windows.Full (Item.Held, Item.Tuned.Hop) then
            Decode (Item, True, Ok, Message, Last);
            Changed := True;
            if not Ok then
               return;
            end if;
            Windows.Make_Room (Item.Held, Item.Tuned.Hop);
            --  Whatever the model made of it, the sound goes on being heard.
         end if;
         if Windows.Next (Item.Held) > Windows.Max_Index - Windows.Capacity then
            --  (It does not come to this in this world: the places are
            --  counted from the start, and there are more of them than
            --  seconds in a million years.)
            Windows.Clear (Item.Held);
            Item.Settled_To := 0;
         end if;
         Windows.Append (Item.Held, Audio (Place .. Audio'Last), Taken);
         Gates.Observe (Item.Room, Audio (Place .. Place + Taken - 1));
         Place := Place + Taken;
         if Windows.Due (Item.Held, Item.Tuned.Hop) then
            Decode (Item, False, Ok, Message, Last);
            Changed := True;
            if not Ok then
               return;
            end if;
         end if;
      end loop;
   end Feed;

   procedure Finish
     (Item    : in out Stream;
      Ok      : out Boolean;
      Message : out String;
      Last    : out Natural) is
   begin
      Decode (Item, True, Ok, Message, Last);
   end Finish;

   procedure Text (Item : Stream; Into : in out Transcript) is
   begin
      Into.Length := 0;
      Into.Truncated := Item.Settled.Truncated or else Item.Tentative.Truncated;
      Windows.Append_Text (Into, Item.Settled.Text (1 .. Item.Settled.Length));
      if Item.Settled.Length > 0 and then Item.Tentative.Length > 0 then
         Windows.Append_Text (Into, " ");
      end if;
      Into.Settled := Into.Length;
      Windows.Append_Text (Into, Item.Tentative.Text (1 .. Item.Tentative.Length));
   end Text;

end Speech.Streams;
