--  Finds sources for a text with the real model, search, pages and Vision.
--
--     finder_run <model folder> [text]
--        prints how it goes and what it finds;
--     finder_run --cancel <writing|searching|reading|judging> <model folder>
--        cancels when the work gets to that stage, and checks that it stops, keeps
--        nothing and leaves no pictures, and that work can be begun again.
--
--  Needs a network and a model in the Hugging Face cache.
with Ada.Calendar;
with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with MLX.Jobs;
with Source_Finder;
with Webshot;

procedure Finder_Run is
   use Ada.Text_IO;
   use type Source_Finder.States;
   use type Ada.Calendar.Time;

   Default_Text : constant String :=
     "The James Webb Space Telescope has revealed galaxies that formed only a few hundred million years "
     & "after the Big Bang, which is earlier than models of early galaxy formation predicted.";

   Folder  : constant String := "/tmp/bonxie-finder-run";
   Started : constant Ada.Calendar.Time := Ada.Calendar.Clock;
   Failures : Natural := 0;

   function Seconds (Since : Ada.Calendar.Time := Started) return String is
     (Integer'Image (Integer (Ada.Calendar.Clock - Since)) & "s");

   procedure Check (Ok : Boolean; What : String) is
   begin
      Put_Line ((if Ok then "ok    " else "FAIL  ") & What);
      if not Ok then
         Failures := Failures + 1;
      end if;
   end Check;

   function Starts (Text, Prefix : String) return Boolean is
     (Text'Length >= Prefix'Length and then Text (Text'First .. Text'First + Prefix'Length - 1) = Prefix);

   --  How many files of pages are left in the folder: pictures and PDFs of them,
   --  and the looks at their tops.
   function Pictures_Left return Natural is
      Count : Natural := 0;

      procedure Count_Of (Pattern : String) is
         Search : Ada.Directories.Search_Type;
         Found  : Ada.Directories.Directory_Entry_Type;
      begin
         Ada.Directories.Start_Search (Search, Folder, Pattern);
         while Ada.Directories.More_Entries (Search) loop
            Ada.Directories.Get_Next_Entry (Search, Found);
            Count := Count + 1;
         end loop;
         Ada.Directories.End_Search (Search);
      end Count_Of;
   begin
      if Ada.Directories.Exists (Folder) then
         Count_Of ("found-*");
         Count_Of ("look-*");
         Count_Of ("tile-*");
      end if;
      return Count;
   end Pictures_Left;

   procedure Run_And_Print (Model, Text : String) is
      Last        : String (1 .. 120) := [others => ' '];
      Last_Length : Natural := 0;
   begin
      Source_Finder.Start (Model, Text, Folder);
      while Source_Finder.State = Source_Finder.Running loop
         Source_Finder.Poll;
         Webshot.Pump (50);
         if Source_Finder.State = Source_Finder.Running then
            declare
               Now : constant String := Source_Finder.Status;
            begin
               if Now'Length /= Last_Length or else Now /= Last (1 .. Last_Length) then
                  Put_Line (Seconds & "  " & Now);
                  Last_Length := Natural'Min (Now'Length, Last'Length);
                  Last (1 .. Last_Length) := Now (Now'First .. Now'First + Last_Length - 1);
               end if;
            end;
         end if;
      end loop;
      case Source_Finder.State is
         when Source_Finder.Done =>
            Put_Line (Seconds & "  done:" & Source_Finder.Count'Image & " sources of"
                      & Source_Finder.Examined_Count'Image & " pages;" & Source_Finder.Documents_Taken'Image
                      & " PDFs;" & Source_Finder.Pressed_Count'Image & " buttons pressed (last: "
                      & Source_Finder.Last_Pressed & ")");
            if Source_Finder.Last_Reply /= "" then
               Put_Line ("last unusable reply: " & Source_Finder.Last_Reply);
            end if;
            for Each in 1 .. Source_Finder.Examined_Count loop
               Put_Line ("  looked at:" & Source_Finder.Examined_Percent (Each)'Image & "%  "
                         & Source_Finder.Examined_Title (Each));
               Put_Line ("      " & Source_Finder.Examined_Reason (Each));
            end loop;
            for Each in 1 .. Source_Finder.Count loop
               Put_Line (Source_Finder.Percent (Each)'Image & "%  " & Source_Finder.Title (Each));
               Put_Line ("      " & Source_Finder.Address (Each));
               Put_Line ("      " & Source_Finder.Reason (Each));
               Put_Line ("      " & Source_Finder.File (Each));
            end loop;
         when Source_Finder.Failed =>
            Put_Line (Seconds & "  failed: " & Source_Finder.Message);
            Put_Line ("last unusable reply: " & Source_Finder.Last_Reply);
            Failures := Failures + 1;
         when others =>
            Put_Line ("idle?");
      end case;
      Source_Finder.Reset;
   end Run_And_Print;

   --  Begin, go on until the work is at Stage (one of the words its status
   --  begins with), say stop, and see that it does, in good time.
   procedure Stop_At (Model, Name : String; Words : String) is
      Asked   : Ada.Calendar.Time;
      Waiting : constant Ada.Calendar.Time := Ada.Calendar.Clock;
      At_Stage : Boolean := False;
   begin
      Put_Line ("-- stop at " & Name);
      Source_Finder.Start (Model, Default_Text, Folder);
      while Source_Finder.State = Source_Finder.Running and then not At_Stage
        and then Ada.Calendar.Clock - Waiting < 300.0
      loop
         Source_Finder.Poll;
         Webshot.Pump (20);
         declare
            Status : constant String := (if Source_Finder.State = Source_Finder.Running then Source_Finder.Status else "");
         begin
            At_Stage := Ada.Strings.Fixed.Index (Words, "|" & (if Starts (Status, "Waiting") then "Waiting"
                                                               else Status (Status'First .. Status'First +
                                                                              Natural'Min (Status'Length, 7) - 1)))
                        > 0
                        and then Status /= "";
         end;
      end loop;
      Check (At_Stage, Name & ": the work got there (" & (if Source_Finder.State = Source_Finder.Running
                                                          then Source_Finder.Status else "it ended") & ")");
      if not At_Stage then
         Source_Finder.Reset;
         return;
      end if;
      Put_Line (Seconds & "  cancelling at: " & Source_Finder.Status);
      Source_Finder.Cancel;
      Asked := Ada.Calendar.Clock;
      Check (Source_Finder.State = Source_Finder.Running and then Source_Finder.Status = "Stopping",
             Name & ": it says it is stopping");
      while Source_Finder.State = Source_Finder.Running and then Ada.Calendar.Clock - Asked < 120.0 loop
         Source_Finder.Poll;
         Webshot.Pump (20);
      end loop;
      Put_Line (Seconds (Asked) & "  to stop");
      Check (Source_Finder.State = Source_Finder.Idle, Name & ": it is idle");
      Check (Source_Finder.Count = 0, Name & ": nothing is kept");
      Check (Pictures_Left = 0, Name & ": no pictures are left," & Pictures_Left'Image);
      Check (Ada.Calendar.Clock - Asked < 60.0, Name & ": it stopped in good time");
   end Stop_At;

   procedure Cancel_Mode (Stage, Model : String) is
   begin
      if Stage = "writing" then
         Stop_At (Model, "writing searches", "|Writing");
      elsif Stage = "searching" then
         Stop_At (Model, "searching", "|Searchi|Waiting");
      elsif Stage = "reading" then
         Stop_At (Model, "reading pages", "|Reading");
      elsif Stage = "judging" then
         Stop_At (Model, "judging pages", "|Judging");
      else
         Put_Line ("stage: writing, searching, reading or judging");
         Failures := Failures + 1;
         return;
      end if;
      --  Then again, as soon as it has begun: work can be begun again.
      Source_Finder.Start (Model, Default_Text, Folder);
      Check (Source_Finder.State = Source_Finder.Running, Stage & ": work begins again");
      declare
         Waiting : constant Ada.Calendar.Time := Ada.Calendar.Clock;
      begin
         while Ada.Calendar.Clock - Waiting < 3.0 loop
            Source_Finder.Poll;
            Webshot.Pump (20);
         end loop;
      end;
      Source_Finder.Cancel;
      declare
         Asked : constant Ada.Calendar.Time := Ada.Calendar.Clock;
      begin
         while Source_Finder.State = Source_Finder.Running and then Ada.Calendar.Clock - Asked < 120.0 loop
            Source_Finder.Poll;
            Webshot.Pump (20);
         end loop;
      end;
      Check (Source_Finder.State = Source_Finder.Idle and then Pictures_Left = 0, Stage & ": and stops again");
   end Cancel_Mode;

begin
   if Ada.Command_Line.Argument_Count >= 3 and then Ada.Command_Line.Argument (1) = "--cancel" then
      Cancel_Mode (Ada.Command_Line.Argument (2), Ada.Command_Line.Argument (3));
   elsif Ada.Command_Line.Argument_Count >= 1 then
      Run_And_Print
        (Ada.Command_Line.Argument (1),
         (if Ada.Command_Line.Argument_Count > 1 then Ada.Command_Line.Argument (2) else Default_Text));
   else
      Put_Line ("usage: finder_run <model folder> [text]");
      Put_Line ("       finder_run --cancel <writing|searching|reading|judging> <model folder>");
      Failures := 1;
   end if;
   MLX.Jobs.Shutdown;
   if Failures > 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Finder_Run;
