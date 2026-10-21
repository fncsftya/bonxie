with Ada.Numerics.Elementary_Functions;

package body Speech.Gates
  with SPARK_Mode
is

   Fall  : constant Float := 0.1;
   --  To a quieter moment: quickly.
   Settle : constant Float := 0.01;
   --  To a louder one that is not speech: a few seconds.
   Creep : constant Float := 0.0002;
   --  To one that is: so slowly that speech does not carry it up, but
   --  a noise that has come to stay is in time not mistaken for speech.

   function Root_Mean_Square (Sum : Float) return Float is
     (Ada.Numerics.Elementary_Functions.Sqrt (Float'Max (0.0, Sum) / Float (Frame)));

   procedure Observe (Of_Floor : in out Floor; Audio : Windows.Samples) is
   begin
      for Index in Audio'Range loop
         declare
            Value : constant Float := Windows.Clean (Audio, Index);
         begin
            Of_Floor.Sum := Of_Floor.Sum + Value * Value;
            Of_Floor.Seen := Of_Floor.Seen + 1;
            if Of_Floor.Seen = Frame then
               declare
                  Loud : constant Float := Root_Mean_Square (Of_Floor.Sum);
                  Now  : Float renames Of_Floor.Amplitude;
                  Rate : constant Float :=
                    (if Loud < Now then Fall
                     elsif Loud < Now * Open_Margin then Settle
                     else Creep);
               begin
                  Now := Float'Max (Floor_Least, Float'Min (Floor_Most, Now + (Loud - Now) * Rate));
               end;
               Of_Floor.Sum := 0.0;
               Of_Floor.Seen := 0;
            end if;
         end;
      end loop;
   end Observe;

   procedure Apply
     (Of_Floor : Floor;
      Audio    : in out Windows.Samples;
      Voiced   : out Boolean)
   is
      Frames : constant Natural := Audio'Length / Frame;
      Open   : constant Float := Float'Max (Open_Least, Of_Floor.Amplitude * Open_Margin);
      Close  : constant Float := Of_Floor.Amplitude * Close_Margin;
      Loud   : array (1 .. Windows.Capacity / Frame + 1) of Float := [others => 0.0];
      Strong : array (1 .. Windows.Capacity / Frame + 1) of Boolean := [others => False];
      Keep   : array (1 .. Windows.Capacity / Frame + 1) of Boolean := [others => False];
      Active : Boolean := False;
      Since  : Natural := 0;
      Quiet  : Natural := 0;
   begin
      Voiced := False;
      for Each in 1 .. Frames loop
         declare
            Sum : Float := 0.0;
         begin
            for K in 0 .. Frame - 1 loop
               declare
                  Value : constant Float := Windows.Clean (Audio, Audio'First + (Each - 1) * Frame + K);
               begin
                  Sum := Sum + Value * Value;
               end;
            end loop;
            Loud (Each) := Root_Mean_Square (Sum);
         end;
      end loop;
      --  Forward: speech, and what trails after it.
      for Each in 1 .. Frames loop
         if Loud (Each) > Open then
            Strong (Each) := True;
            Keep (Each) := True;
            Active := True;
            Since := 0;
            Quiet := 0;
         elsif Active then
            Since := Since + 1;
            Quiet := (if Loud (Each) > Close then 0 else Quiet + 1);
            if Quiet <= Hangover and then Since <= Max_Trail then
               Keep (Each) := True;
            else
               Active := False;
            end if;
         end if;
      end loop;
      --  Back: what comes before speech.
      for Each in 1 .. Frames loop
         if Strong (Each) then
            for Before in Integer'Max (1, Each - Pre_Roll) .. Each - 1 loop
               Keep (Before) := True;
            end loop;
         end if;
      end loop;
      for Each in 1 .. Frames loop
         if Keep (Each) then
            Voiced := True;
         else
            for K in 0 .. Frame - 1 loop
               Audio (Audio'First + (Each - 1) * Frame + K) := 0.0;
            end loop;
         end if;
      end loop;
      if Frames = 0 then
         Voiced := Audio'Length > 0;
      elsif not Keep (Frames) then
         for Index in Audio'First + Frames * Frame .. Audio'Last loop
            Audio (Index) := 0.0;
         end loop;
      else
         null;  --  what is left of a frame goes as the one before it
      end if;
   end Apply;

end Speech.Gates;
