--  The noise gate: a room's hiss is silenced, speech is kept with what
--  comes before and trails after it, and a steady new noise is in time
--  not taken for speech.
with Ada.Numerics.Elementary_Functions;
with Ada.Text_IO;
with Speech.Gates;
with Speech.Windows;

procedure Gates_Test is
   use Speech.Windows;

   Failed : Natural := 0;

   procedure Check (Name : String; Holds : Boolean) is
   begin
      Ada.Text_IO.Put_Line ((if Holds then "ok    " else "FAIL  ") & Name);
      if not Holds then
         Failed := Failed + 1;
      end if;
   end Check;

   Second : constant := Rate;

   --  A tone of the given amplitude, from sample From to To of Audio; the rest is
   --  a hiss of 0.001.
   function Sound (Length : Positive; Speech_From, Speech_To : Natural; Loud : Float;
                   Fade_To : Natural := 0) return Samples is
      Result : Samples (1 .. Length);
   begin
      for I in Result'Range loop
         declare
            Wave : constant Float :=
              Ada.Numerics.Elementary_Functions.Sin (Float (I) * 0.3);
            Amp  : Float := 0.001;
         begin
            if I in Speech_From .. Speech_To then
               Amp := Loud;
            elsif I > Speech_To and then I <= Speech_To + Fade_To then
               Amp := 0.01;   --  trailing off: quiet, but well above the room
            end if;
            Result (I) := Amp * Wave * 1.4;
         end;
      end loop;
      return Result;
   end Sound;

   Room   : Speech.Gates.Floor;
   Voiced : Boolean;
begin
   --  A quiet room alone.
   declare
      Audio : Samples := Sound (4 * Second, 1, 0, 0.0);
   begin
      Speech.Gates.Observe (Room, Audio);
      Speech.Gates.Apply (Room, Audio, Voiced);
      Check ("room is not speech", not Voiced);
      Check ("room is silence", (for all S of Audio => S = 0.0));
   end;

   --  Speech from 2 s to 3 s, trailing off for half a second.
   declare
      Audio : Samples := Sound (5 * Second, 2 * Second, 3 * Second, 0.2, Fade_To => Second / 2);
      Copy  : constant Samples := Audio;
   begin
      Speech.Gates.Apply (Room, Audio, Voiced);
      Check ("speech is voiced", Voiced);
      Check ("speech kept", (for all I in 2 * Second + 1 .. 3 * Second => Audio (I) = Copy (I)));
      Check ("start is not cut", (for all I in 2 * Second - 100 .. 2 * Second => Audio (I) = Copy (I)));
      Check ("trailing off kept",
             (for all I in 3 * Second + 1 .. 3 * Second + Second / 2 - 400 => Audio (I) = Copy (I)));
      Check ("before is silent", (for all I in 1 .. Second => Audio (I) = 0.0));
      Check ("long after is silent", (for all I in 4 * Second + Second / 4 .. 5 * Second => Audio (I) = 0.0));
   end;

   --  A noise that stays (a fan turned on) is, in time, the room.
   declare
      Fan : constant Samples := Sound (30 * Second, 1, 30 * Second, 0.008);
      Before : constant Float := Speech.Gates.Level (Room);
   begin
      for Round in 1 .. 3 loop
         Speech.Gates.Observe (Room, Fan);
      end loop;
      Check ("room level rose", Speech.Gates.Level (Room) > Before * 3.0);
   end;

   Ada.Text_IO.Put_Line (Natural'Image (Failed) & " failed");
   if Failed > 0 then
      raise Program_Error;
   end if;
end Gates_Test;
