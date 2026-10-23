with Ada.Directories;
with Ada.Exceptions;
with Ada.Strings.Bounded;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Files;
with GNAT.OS_Lib;
with Interfaces.C;
with JSON.Parsers;
with JSON.Types;
with Model_Replies;

package body Premium.Sources is

   use type GNAT.OS_Lib.Process_Id;
   use type GNAT.OS_Lib.String_Access;
   use type Interfaces.C.int;

   package JSON_Types is new JSON.Types (Long_Long_Integer, Long_Float);
   package JSON_Parsers is new JSON.Parsers (JSON_Types, Default_Maximum_Depth => 16);

   package Addresses is new Ada.Strings.Bounded.Generic_Bounded_Length (Max_Address);
   package Titles is new Ada.Strings.Bounded.Generic_Bounded_Length (Max_Title);
   package Guidances is new Ada.Strings.Bounded.Generic_Bounded_Length (Max_Guidance);
   package Messages is new Ada.Strings.Bounded.Generic_Bounded_Length (Max_Message);
   package Paths is new Ada.Strings.Bounded.Generic_Bounded_Length (1_024);

   Max_Description : constant := 20_000;
   --  Bytes of the project's description that are sent; the backend takes 4 MB of a request.

   Try_Again : constant String := "Premium could not find sources, try again";

   type Found_Page is record
      Address : Addresses.Bounded_String;
      Title   : Titles.Bounded_String;
   end record;

   type Result_Array is array (1 .. Max_Results) of Found_Page;

   --  What the task and the caller share.
   protected Job is
      procedure Begin_Job;
      procedure Finish_Done (Found : Result_Array; Total : Natural; Said : Guidances.Bounded_String);
      procedure Finish_Failed (Why : String);
      procedure Set_Process (Pid : GNAT.OS_Lib.Process_Id; Stop : out Boolean);
      --  Stop: it was cancelled before the process began, so is to be killed.
      procedure Cancel (Pid : out GNAT.OS_Lib.Process_Id);
      --  The process to kill, Invalid_Pid if none.
      procedure Forget;
      function Current return States;
      function Result_Count return Natural;
      function Found_At (Item : Positive) return Found_Page;
      function Advice_Text return Guidances.Bounded_String;
      function Reason_Text return Messages.Bounded_String;
      function Was_Cancelled return Boolean;
   private
      Now       : States := Idle;
      Held      : Result_Array;
      Held_Total : Natural := 0;
      Advice    : Guidances.Bounded_String;
      Reason    : Messages.Bounded_String;
      Process   : GNAT.OS_Lib.Process_Id := GNAT.OS_Lib.Invalid_Pid;
      Cancelled : Boolean := False;
   end Job;

   protected body Job is

      procedure Begin_Job is
      begin
         Now := Running;
         Held_Total := 0;
         Advice := Guidances.Null_Bounded_String;
         Reason := Messages.Null_Bounded_String;
         Process := GNAT.OS_Lib.Invalid_Pid;
         Cancelled := False;
      end Begin_Job;

      procedure Finish_Done (Found : Result_Array; Total : Natural; Said : Guidances.Bounded_String) is
      begin
         Held := Found;
         Held_Total := Total;
         Advice := Said;
         Process := GNAT.OS_Lib.Invalid_Pid;
         Now := Done;
      end Finish_Done;

      procedure Finish_Failed (Why : String) is
      begin
         Held_Total := 0;
         Reason := Messages.To_Bounded_String (Why, Ada.Strings.Right);
         Process := GNAT.OS_Lib.Invalid_Pid;
         Now := Failed;
      end Finish_Failed;

      procedure Set_Process (Pid : GNAT.OS_Lib.Process_Id; Stop : out Boolean) is
      begin
         Process := Pid;
         Stop := Cancelled;
      end Set_Process;

      procedure Cancel (Pid : out GNAT.OS_Lib.Process_Id) is
      begin
         Cancelled := Now = Running;
         Pid := Process;
      end Cancel;

      procedure Forget is
      begin
         Now := Idle;
         Held_Total := 0;
         Advice := Guidances.Null_Bounded_String;
         Reason := Messages.Null_Bounded_String;
      end Forget;

      function Current return States is (Now);
      function Result_Count return Natural is (Held_Total);
      function Found_At (Item : Positive) return Found_Page is (Held (Item));
      function Advice_Text return Guidances.Bounded_String is (Advice);
      function Reason_Text return Messages.Bounded_String is (Reason);
      function Was_Cancelled return Boolean is (Cancelled);

   end Job;

   --  The request

   function Escaped (Text : String) return String is
      Hex    : constant String := "0123456789abcdef";
      Buffer : String (1 .. 6 * Text'Length);
      Last   : Natural := 0;

      procedure Put (Words : String) is
      begin
         Buffer (Last + 1 .. Last + Words'Length) := Words;
         Last := Last + Words'Length;
      end Put;
   begin
      for C of Text loop
         case C is
            when '"'            => Put ("\""");
            when '\'            => Put ("\\");
            when ASCII.LF       => Put ("\n");
            when ASCII.CR       => Put ("\r");
            when ASCII.HT       => Put ("\t");
            when Character'Val (0) .. Character'Val (8) | Character'Val (11) | Character'Val (12)
               | Character'Val (14) .. Character'Val (31) =>
               Put ("\u00" & Hex (Character'Pos (C) / 16 + 1) & Hex (Character'Pos (C) mod 16 + 1));
            when others         => Put ([C]);
         end case;
      end loop;
      return Buffer (1 .. Last);
   end Escaped;

   function Request_Body
     (Project_Title, Project_Description, Section_Title, Document_Title : String) return String
   is
      Description : constant String := Model_Replies.Cut (Project_Description, Max_Description);
   begin
      return
        "{""section_title"":""" & Escaped (Section_Title) & """,""document_title"":""" & Escaped (Document_Title)
        & """,""context"":{""project_title"":""" & Escaped (Project_Title) & """"
        & (if Description = "" then "" else ",""project_description"":""" & Escaped (Description) & """")
        & "}}";
   end Request_Body;

   --  The reply

   procedure Read_Results
     (Reply : String; Found : out Result_Array; Total : out Natural; Said : out Guidances.Bounded_String;
      Valid : out Boolean)
   is
      use JSON_Types;

      function Is_Web_Address (Text : String) return Boolean is
        ((Text'Length > 8 and then Text (Text'First .. Text'First + 7) = "https://")
         or else (Text'Length > 7 and then Text (Text'First .. Text'First + 6) = "http://"));

      procedure Add (One : JSON_Value) is
      begin
         if One.Kind /= Object_Kind or else not One.Contains ("url") or else One ("url").Kind /= String_Kind then
            raise JSON_Parsers.Parse_Error;
         end if;
         declare
            Link : constant String := One ("url").Value;
            Name : constant String :=
              (if One.Contains ("title") and then One ("title").Kind = String_Kind
               then Model_Replies.Tidy (One ("title").Value, Max_Title) else "");
         begin
            --  Not a page to open: left out.
            if Total < Max_Results and then Link'Length <= Max_Address and then Is_Web_Address (Link) then
               Total := Total + 1;
               Found (Total) := (Addresses.To_Bounded_String (Link), Titles.To_Bounded_String (Name));
            end if;
         end;
      end Add;

   begin
      Found := [others => (others => <>)];
      Total := 0;
      Said := Guidances.Null_Bounded_String;
      Valid := False;
      declare
         Parser : JSON_Parsers.Parser := JSON_Parsers.Create (Reply, Maximum_Depth => 16);
         Root   : constant JSON_Value := Parser.Parse;
      begin
         if Root.Kind /= Object_Kind or else not Root.Contains ("results")
           or else Root ("results").Kind /= Array_Kind
         then
            return;
         end if;
         for Each of Root ("results") loop
            Add (Each);
         end loop;
         if Root.Contains ("guidance") and then Root ("guidance").Kind = String_Kind then
            Said := Guidances.To_Bounded_String (Model_Replies.Tidy (Root ("guidance").Value, Max_Guidance));
         end if;
         Valid := True;
      end;
   exception
      when Problem : JSON_Parsers.Parse_Error | JSON_Types.Invalid_Type_Error | Constraint_Error | Program_Error =>
         Log ("the reply is not what was expected: " & Ada.Exceptions.Exception_Information (Problem));
         Total := 0;
         Valid := False;
   end Read_Results;

   procedure Take_Reply (Status : Natural; Reply : String) is
      Found : Result_Array;
      Total : Natural;
      Said  : Guidances.Bounded_String;
      Valid : Boolean;
   begin
      Log ("find_sources replied" & Status'Image & ": " & Model_Replies.Cut (Reply, 2_000));
      if Status /= 200 then
         --  A developer is told what the backend said (its {"error": ...}); a person, only to try again.
         Job.Finish_Failed
           (if Available
            then Model_Replies.Cut
                   ("Premium HTTP" & Status'Image & ": " & Model_Replies.Tidy (Reply, 80), Max_Message)
            else Try_Again);
         return;
      end if;
      Read_Results (Reply, Found, Total, Said, Valid);
      if not Valid then
         Log ("the reply could not be read");
         Job.Finish_Failed (if Available then "Premium sent a reply that could not be read" else Try_Again);
      else
         Log (Total'Image & " results" & (if Total = 0 then ", guidance: " & Guidances.To_String (Said) else ""));
         --  Guidance goes with no results only.
         Job.Finish_Done (Found, Total, (if Total = 0 then Said else Guidances.Null_Bounded_String));
      end if;
   end Take_Reply;

   procedure Read_Reply (Status : Natural; Reply : String) is
   begin
      Job.Begin_Job;
      Take_Reply (Status, Reply);
   end Read_Reply;

   --  The status of the last response in the headers curl dumped (there is one to each redirect and
   --  to a "100 Continue"); 0 if there is none.
   function Status_Of (Headers : String) return Natural;

   function Status_Of (Headers : String) return Natural is
      Found : Natural := 0;
      From  : Natural := Headers'First;
   begin
      loop
         declare
            At_Line : constant Natural := Ada.Strings.Fixed.Index (Headers, "HTTP/", From);
            Space   : Natural;
         begin
            exit when At_Line = 0;
            Space := Ada.Strings.Fixed.Index (Headers, " ", At_Line);
            if Space /= 0 and then Space + 3 <= Headers'Last
              and then (for all C of Headers (Space + 1 .. Space + 3) => C in '0' .. '9')
            then
               Found := Natural'Value (Headers (Space + 1 .. Space + 3));
            end if;
            From := At_Line + 5;
         end;
      end loop;
      return Found;
   end Status_Of;

   --  The task

   function Wait_For
     (Pid    : Interfaces.C.int;
      Status : out Interfaces.C.int;
      Flags  : Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C, External_Name => "waitpid";
   --  Wait for that process, and no other (see Downloads).

   Interrupted : constant := 4;
   --  EINTR.

   function Argument (Text : String) return GNAT.OS_Lib.String_Access is (new String'(Text));

   procedure Delete_If_There (File_Name : String) is
   begin
      if Ada.Directories.Exists (File_Name) then
         Ada.Directories.Delete_File (File_Name);
      end if;
   exception
      when Ada.Directories.Name_Error | Ada.Directories.Use_Error =>
         null;
   end Delete_If_There;

   Request_Path : Paths.Bounded_String;
   Reply_Path   : Paths.Bounded_String;
   Head_Path    : Paths.Bounded_String;
   --  The files of the request being made: set before the task is told to go.

   procedure Ask is
      Request : constant String := Paths.To_String (Request_Path);
      Reply   : constant String := Paths.To_String (Reply_Path);
      Head    : constant String := Paths.To_String (Head_Path);
      Curl    : GNAT.OS_Lib.String_Access := GNAT.OS_Lib.Locate_Exec_On_Path ("curl");
      Args    : GNAT.OS_Lib.Argument_List :=
        [Argument ("-sS"), Argument ("--max-time"), Argument (Ada.Strings.Fixed.Trim (Timeout'Image, Ada.Strings.Left)),
         Argument ("-X"), Argument ("POST"), Argument ("-H"), Argument ("Content-Type: application/json"),
         Argument ("--data-binary"), Argument ("@" & Request), Argument ("-o"), Argument (Reply),
         Argument ("-D"), Argument (Head), Argument (Backend & "/api/v1/find_sources")];
      Pid     : GNAT.OS_Lib.Process_Id;
      Stop    : Boolean;
      Status  : Interfaces.C.int := 0;
      Waited  : Interfaces.C.int;
   begin
      if Curl = null then
         Job.Finish_Failed ("curl was not found");
         for Each of Args loop
            GNAT.OS_Lib.Free (Each);
         end loop;
         return;
      end if;
      Pid := GNAT.OS_Lib.Non_Blocking_Spawn (Curl.all, Args);
      GNAT.OS_Lib.Free (Curl);
      for Each of Args loop
         GNAT.OS_Lib.Free (Each);
      end loop;
      if Pid = GNAT.OS_Lib.Invalid_Pid then
         Job.Finish_Failed ("curl could not be started");
         return;
      end if;
      Job.Set_Process (Pid, Stop);
      if Stop then
         GNAT.OS_Lib.Kill (Pid);
      end if;
      loop
         Waited := Wait_For (Interfaces.C.int (GNAT.OS_Lib.Pid_To_Integer (Pid)), Status, 0);
         exit when Waited >= 0 or else GNAT.OS_Lib.Errno /= Interrupted;
      end loop;
      if Job.Was_Cancelled then
         Job.Finish_Failed (Stopped);
      elsif Waited < 0 or else Status /= 0 or else not Ada.Directories.Exists (Reply)
        or else not Ada.Directories.Exists (Head)
      then
         Log ("curl failed: wait" & Waited'Image & ", exit status" & Status'Image & " (no reply: the backend is not "
              & "reachable at " & Backend & "?)");
         Job.Finish_Failed (if Available then "Premium could not be reached at " & Backend else Try_Again);
      else
         Take_Reply (Status_Of (Files.Read (Head)), Files.Read (Reply));
      end if;
   end Ask;

   procedure Run is
   begin
      Ask;
      Delete_If_There (Paths.To_String (Request_Path));
      Delete_If_There (Paths.To_String (Reply_Path));
      Delete_If_There (Paths.To_String (Head_Path));
   exception
      when Problem : others =>
         Delete_If_There (Paths.To_String (Request_Path));
         Delete_If_There (Paths.To_String (Reply_Path));
         Delete_If_There (Paths.To_String (Head_Path));
         Log ("failed: " & Ada.Exceptions.Exception_Information (Problem));
         Job.Finish_Failed (Try_Again & " (" & Ada.Exceptions.Exception_Name (Problem) & ")");
   end Run;

   task Worker is
      entry Go;
   end Worker;

   task body Worker is
   begin
      loop
         select
            accept Go;
         or
            terminate;
         end select;
         Run;
      end loop;
   end Worker;

   procedure Start
     (Project_Title, Project_Description, Section_Title, Document_Title, Work_Directory : String)
   is
   begin
      Job.Begin_Job;
      Log ("POST " & Backend & "/api/v1/find_sources "
           & Request_Body (Project_Title, Project_Description, Section_Title, Document_Title));
      begin
         Ada.Directories.Create_Path (Work_Directory);
         Request_Path := Paths.To_Bounded_String (Work_Directory & "/premium-request.json");
         Reply_Path := Paths.To_Bounded_String (Work_Directory & "/premium-reply.json");
         Head_Path := Paths.To_Bounded_String (Work_Directory & "/premium-reply.head");
         Delete_If_There (Paths.To_String (Reply_Path));
         Delete_If_There (Paths.To_String (Head_Path));
         Files.Write
           (Paths.To_String (Request_Path),
            Request_Body (Project_Title, Project_Description, Section_Title, Document_Title));
      exception
         when Ada.Directories.Name_Error | Ada.Directories.Use_Error | Ada.Strings.Length_Error
            | Ada.Streams.Stream_IO.Use_Error | Ada.Streams.Stream_IO.Name_Error =>
            Job.Finish_Failed ("The request could not be made");
            return;
      end;
      Worker.Go;
   end Start;

   function State return States is (Job.Current);

   procedure Cancel is
      Pid : GNAT.OS_Lib.Process_Id;
   begin
      Job.Cancel (Pid);
      if Pid /= GNAT.OS_Lib.Invalid_Pid then
         GNAT.OS_Lib.Kill (Pid);
      end if;
   end Cancel;

   procedure Reset is
   begin
      Job.Forget;
   end Reset;

   function Count return Natural is (Job.Result_Count);
   function Address (Item : Positive) return String is (Addresses.To_String (Job.Found_At (Item).Address));
   function Title (Item : Positive) return String is (Titles.To_String (Job.Found_At (Item).Title));
   function Guidance return String is (Guidances.To_String (Job.Advice_Text));
   function Message return String is (Messages.To_String (Job.Reason_Text));

end Premium.Sources;
