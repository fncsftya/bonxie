--  Fetches the file an address is of, as a browser would download it: fetch_probe <address>;
--  says how it ended, and the first bytes of the file (/tmp/fetch-probe.pdf).
with Ada.Command_Line;
with Ada.Directories;
with Ada.Streams.Stream_IO;
with Ada.Text_IO;
with Webshot;

procedure Fetch_Probe is
   use Ada.Text_IO;
   use type Webshot.States;
   Waited : Natural := 0;
   File   : Ada.Streams.Stream_IO.File_Type;
   Head   : String (1 .. 8) := [others => ' '];
begin
   if Ada.Directories.Exists ("/tmp/fetch-probe.pdf") then
      Ada.Directories.Delete_File ("/tmp/fetch-probe.pdf");
   end if;
   Webshot.Start_Download (1, Ada.Command_Line.Argument (1), "/tmp/fetch-probe.pdf");
   while Webshot.State (1) = Webshot.Working and then Waited < 120_000 loop
      Webshot.Pump (50);
      Waited := Waited + 50;
   end loop;
   Put_Line ("state " & Webshot.State (1)'Image & " after" & Natural'Image (Waited / 1000) & " s"
             & (if Webshot.State (1) = Webshot.Failed then ": " & Webshot.Message (1) else ""));
   if Ada.Directories.Exists ("/tmp/fetch-probe.pdf") then
      Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, "/tmp/fetch-probe.pdf");
      for Each in Head'Range loop
         exit when Ada.Streams.Stream_IO.End_Of_File (File);
         Character'Read (Ada.Streams.Stream_IO.Stream (File), Head (Each));
      end loop;
      Ada.Streams.Stream_IO.Close (File);
      Put_Line ("file of" & Ada.Directories.Size ("/tmp/fetch-probe.pdf")'Image & " bytes, begins " & Head);
   end if;
end Fetch_Probe;
