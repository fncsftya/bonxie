--  Stream a 16 kHz mono 16-bit WAV through the Core ML model in 500 ms
--  chunks, as the microphone would give it, and show the text after each
--  run of the model: `stream_wav model-folder audio.wav` (the model is
--  fetched into the folder if it is not there).
with Ada.Calendar;
with Ada.Command_Line;
with Ada.Direct_IO;
with Ada.Environment_Variables;
with Ada.Text_IO;
with Speech.Models;
with Speech.Parakeet;
with Speech.Streams;
with Speech.Windows;

procedure Stream_Wav is
   use Ada.Text_IO;
   use type Ada.Calendar.Time;
   use type Speech.Models.States;

   package Bytes_IO is new Ada.Direct_IO (Character);

   Chunk : constant := 1365;

   Item    : Speech.Streams.Stream;
   Heard   : Speech.Transcript;
   Ok      : Boolean;
   Message : String (1 .. 160);
   Last    : Natural;
   Changed : Boolean;
   Start   : Ada.Calendar.Time;
   Lap     : Ada.Calendar.Time;
   File    : Bytes_IO.File_Type;
begin
   declare
      Tuned : Speech.Streams.Tuning;

      procedure Take (Name : String; Into : in out Natural) is
      begin
         if Ada.Environment_Variables.Exists (Name) then
            Into := Natural'Value (Ada.Environment_Variables.Value (Name));
         end if;
      end Take;
   begin
      Take ("HOP", Natural (Tuned.Hop));
      Take ("GUARD", Tuned.Guard);
      Take ("TRIGGER", Natural (Tuned.Trigger));
      Take ("CONTEXT", Tuned.Context);
      Take ("SLACK", Tuned.Slack);
      Speech.Streams.Configure (Item, Tuned);
   end;
   Start := Ada.Calendar.Clock;
   if not Speech.Models.Present (Ada.Command_Line.Argument (1)) then
      Speech.Models.Start (Ada.Command_Line.Argument (1));
      while Speech.Models.State = Speech.Models.Running loop
         Put_Line ("fetching" & Natural (Speech.Models.Fraction * 100.0)'Image & "%");
         delay 2.0;
      end loop;
      if Speech.Models.State = Speech.Models.Failed then
         Put_Line ("fetch: " & Speech.Models.Message);
         return;
      end if;
   end if;
   Speech.Parakeet.Load (Ada.Command_Line.Argument (1), Ok, Message, Last);
   if not Ok then
      Put_Line ("load: " & Message (1 .. Last));
      return;
   end if;
   Put_Line ("loaded in" & Duration'Image (Ada.Calendar.Clock - Start) & " s");
   Bytes_IO.Open (File, Bytes_IO.In_File, Ada.Command_Line.Argument (2));
   declare
      Size  : constant Natural := Natural (Bytes_IO.Size (File));
      Raw   : String (1 .. Size);
      Count : constant Natural := (Size - 44) / 2;
      Audio : Speech.Windows.Samples (1 .. Count);
   begin
      for Index in Raw'Range loop
         Bytes_IO.Read (File, Raw (Index));
      end loop;
      for Index in Audio'Range loop
         declare
            Low  : constant Integer := Character'Pos (Raw (45 + 2 * (Index - 1)));
            High : constant Integer := Character'Pos (Raw (46 + 2 * (Index - 1)));
            Word : constant Integer := (if High >= 128 then Low + 256 * (High - 256) else Low + 256 * High);
         begin
            Audio (Index) := Float (Word) / 32768.0;
         end;
      end loop;
      Put_Line (Count'Image & " samples");
      Start := Ada.Calendar.Clock;
      declare
         At_Sample : Natural := 1;
      begin
         while At_Sample <= Count loop
            declare
               Stop : constant Natural := Natural'Min (At_Sample + Chunk - 1, Count);
            begin
               Lap := Ada.Calendar.Clock;
               Speech.Streams.Feed (Item, Audio (At_Sample .. Stop), Changed, Ok, Message, Last);
               if not Ok then
                  Put_Line ("feed: " & Message (1 .. Last));
                  return;
               end if;
               if Changed then
                  Speech.Streams.Text (Item, Heard);
                  Put_Line (Duration'Image (Ada.Calendar.Clock - Lap) & " s  " & Speech.Image (Heard));
               end if;
               At_Sample := Stop + 1;
            end;
         end loop;
      end;
      Speech.Streams.Finish (Item, Ok, Message, Last);
      Put_Line ("finish ok=" & Ok'Image & " " & Message (1 .. Last));
      Speech.Streams.Text (Item, Heard);
      Put_Line ("FINAL: " & Speech.Image (Heard));
      Put_Line ("took" & Duration'Image (Ada.Calendar.Clock - Start) & " s");
   end;
end Stream_Wav;
