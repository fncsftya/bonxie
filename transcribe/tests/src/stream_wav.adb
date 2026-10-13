--  Stream a 16 kHz mono 16-bit WAV through a model in 500 ms chunks, as
--  the microphone would give it, and show the text after each:
--  `stream_wav model.gguf audio.wav`.
with Ada.Command_Line;
with Ada.Direct_IO;
with Ada.Text_IO;
with Transcribe.Sessions;

procedure Stream_Wav is
   use Ada.Text_IO;

   package Bytes_IO is new Ada.Direct_IO (Character);

   Chunk : constant := 1365;

   Item    : Transcribe.Sessions.Session;
   Ok      : Boolean;
   Message : String (1 .. Transcribe.Max_Message);
   Last    : Natural;
   Heard   : String (1 .. Transcribe.Text_Capacity);
   Cut     : Boolean;
   Changed : Boolean;
begin
   Transcribe.Sessions.Open
     (Item, Ada.Command_Line.Argument (1), Ok, Message, Last);
   if not Ok then
      Put_Line ("open: " & Message (1 .. Last));
      return;
   end if;
   Transcribe.Sessions.Begin_Stream (Item, Ok, Message, Last);
   if not Ok then
      Put_Line ("begin: " & Message (1 .. Last));
      return;
   end if;
   declare
      File : Bytes_IO.File_Type;
   begin
      Bytes_IO.Open (File, Bytes_IO.In_File, Ada.Command_Line.Argument (2));
      declare
         Size   : constant Natural := Natural (Bytes_IO.Size (File));
         Raw    : String (1 .. Size);
         Count  : constant Natural := (Size - 44) / 2;
         Audio  : Transcribe.Samples (1 .. Count);
      begin
         for Index in Raw'Range loop
            Bytes_IO.Read (File, Raw (Index));
         end loop;
         for Index in Audio'Range loop
            declare
               Low  : constant Integer := Character'Pos (Raw (45 + 2 * (Index - 1)));
               High : constant Integer := Character'Pos (Raw (46 + 2 * (Index - 1)));
               Word : constant Integer :=
                 (if High >= 128 then Low + 256 * (High - 256) else Low + 256 * High);
            begin
               Audio (Index) := Float (Word) / 32768.0;
            end;
         end loop;
         Put_Line (Count'Image & " samples");
         declare
            At_Sample : Natural := 1;
         begin
            while At_Sample <= Count loop
               declare
                  Stop : constant Natural := Natural'Min (At_Sample + Chunk - 1, Count);
               begin
                  Transcribe.Sessions.Feed
                    (Item, Audio (At_Sample .. Stop), Changed, Ok, Message, Last);
                  if not Ok then
                     Put_Line ("feed: " & Message (1 .. Last));
                     return;
                  end if;
                  if Changed then
                     Transcribe.Sessions.Text (Item, Heard, Last, Cut);
                     Put_Line ("  " & Heard (1 .. Last));
                  end if;
                  At_Sample := Stop + 1;
               end;
            end loop;
         end;
      end;
   end;
   Transcribe.Sessions.Finalize_Stream (Item, Ok, Message, Last);
   Put_Line ("finalize ok=" & Ok'Image);
   Transcribe.Sessions.Text (Item, Heard, Last, Cut);
   Put_Line ("FINAL: " & Heard (1 .. Last));
end Stream_Wav;
