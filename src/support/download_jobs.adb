with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Strings.Bounded;
with Ada.Strings.Unbounded;
with Ada.Strings.Fixed;
with Files;
with Interfaces.C;
with GNAT.OS_Lib;

package body Download_Jobs is

   use type GNAT.OS_Lib.Process_Id;
   use type Interfaces.C.int;
   use type GNAT.OS_Lib.String_Access;

   package Paths renames Ada.Strings.Unbounded;
   package Messages is new Ada.Strings.Bounded.Generic_Bounded_Length (Max_Message);

   subtype Count is Long_Long_Integer range 0 .. Long_Long_Integer'Last;

   --  What the task and the caller share.
   protected Job is
      procedure Begin_Job (From, To : Paths.Unbounded_String);
      procedure Finish (To : States; Why : String := "");
      procedure Set_Total (To : Count);
      procedure Set_Process (Pid : GNAT.OS_Lib.Process_Id; Stop : out Boolean);
      --  Stop: it was cancelled before it began, so is to be killed.
      procedure Cancel (Pid : out GNAT.OS_Lib.Process_Id);
      --  The process to kill, Invalid_Pid if none.
      procedure Forget;
      function Current return States;
      function Total return Count;
      function Source_URL return Paths.Unbounded_String;
      function Target_File return Paths.Unbounded_String;
      function Message return Messages.Bounded_String;
   private
      Now       : States := Idle;
      Source    : Paths.Unbounded_String;
      Target    : Paths.Unbounded_String;
      Size      : Count := 0;
      Reason    : Messages.Bounded_String;
      Process   : GNAT.OS_Lib.Process_Id := GNAT.OS_Lib.Invalid_Pid;
      Cancelled : Boolean := False;
   end Job;

   protected body Job is

      procedure Begin_Job (From, To : Paths.Unbounded_String) is
      begin
         Now := Running;
         Source := From;
         Target := To;
         Size := 0;
         Reason := Messages.Null_Bounded_String;
         Process := GNAT.OS_Lib.Invalid_Pid;
         Cancelled := False;
      end Begin_Job;

      procedure Finish (To : States; Why : String := "") is
      begin
         Now := To;
         Process := GNAT.OS_Lib.Invalid_Pid;
         Reason := Messages.To_Bounded_String (Why, Ada.Strings.Right);
      end Finish;

      procedure Set_Total (To : Count) is
      begin
         Size := To;
      end Set_Total;

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
         Reason := Messages.Null_Bounded_String;
         Size := 0;
      end Forget;

      function Current return States
      is (Now);
      function Total return Count
      is (Size);
      function Source_URL return Paths.Unbounded_String
      is (Source);
      function Target_File return Paths.Unbounded_String
      is (Target);
      function Message return Messages.Bounded_String
      is (Reason);

   end Job;

   function Content_Length (Headers : String) return Count;
   --  What the last response in the headers (there is one for each
   --  redirect) said the length of its body is; 0 if it did not.

   function Content_Length (Headers : String) return Count is
      Lower : constant String := Ada.Characters.Handling.To_Lower (Headers);
      Name  : constant String := "content-length:";
      From  : Natural := Lower'First;
      Found : Count := 0;
   begin
      loop
         declare
            At_Name : constant Natural := Ada.Strings.Fixed.Index (Lower, Name, From);
            First   : Natural;
            Last    : Natural;
         begin
            exit when At_Name = 0;
            First := At_Name + Name'Length;
            while First <= Lower'Last and then Lower (First) = ' ' loop
               First := First + 1;
            end loop;
            Last := First - 1;
            while Last < Lower'Last and then Lower (Last + 1) in '0' .. '9' and then Last - First < 17 loop
               Last := Last + 1;
            end loop;
            Found := (if Last >= First then Count'Value (Lower (First .. Last)) else 0);
            From := Natural'Max (Last + 1, At_Name + 1);
         end;
      end loop;
      return Found;
   end Content_Length;

   procedure Free_All (Args : in out GNAT.OS_Lib.Argument_List);
   --  Give back the strings (not the array).

   procedure Free_All (Args : in out GNAT.OS_Lib.Argument_List) is
   begin
      for Each of Args loop
         GNAT.OS_Lib.Free (Each);
      end loop;
   end Free_All;

   function Argument (Text : String) return GNAT.OS_Lib.String_Access
   is (new String'(Text));

   procedure Delete_If_There (File_Name : String);

   procedure Delete_If_There (File_Name : String) is
   begin
      if Ada.Directories.Exists (File_Name) then
         Ada.Directories.Delete_File (File_Name);
      end if;
   exception
      when Ada.Directories.Name_Error | Ada.Directories.Use_Error =>
         null;
   end Delete_If_There;

   function Wait_For
     (Pid : Interfaces.C.int; Status : out Interfaces.C.int; Flags : Interfaces.C.int) return Interfaces.C.int
   with Import, Convention => C, External_Name => "waitpid";
   --  Wait for that process, and no other (GNAT.OS_Lib.Wait_Process takes
   --  any child, which is not curl if something else has reaped it).

   Interrupted : constant := 4;
   --  EINTR.

   type Endings is (Exited_Well, Exited_Badly, Lost);
   --  How curl ended: with status 0, with another, or it is not known
   --  (the process was reaped by something else).

   procedure Await (Pid : GNAT.OS_Lib.Process_Id; How : out Endings; Code : out Natural);

   procedure Await (Pid : GNAT.OS_Lib.Process_Id; How : out Endings; Code : out Natural) is
      Status : Interfaces.C.int := 0;
      Result : Interfaces.C.int;
   begin
      Code := 0;
      loop
         Result := Wait_For (Interfaces.C.int (GNAT.OS_Lib.Pid_To_Integer (Pid)), Status, 0);
         exit when Result >= 0 or else GNAT.OS_Lib.Errno /= Interrupted;
      end loop;
      if Result < 0 then
         How := Lost;
      elsif Status = 0 then
         How := Exited_Well;
      else
         How := Exited_Badly;
         --  Its exit status, or 128 and the signal that ended it.
         Code := Natural ((Status / 256) mod 256);
         if Code = 0 then
            Code := 128 + Natural (Status mod 128);
         end if;
      end if;
   end Await;

   procedure Fetch;
   --  Do the job in Job, and say how it ended.

   procedure Fetch is
      URL    : constant String := Paths.To_String (Job.Source_URL);
      Target : constant String := Paths.To_String (Job.Target_File);
      Part   : constant String := Target & ".part";
      Head   : constant String := Target & ".head";
      Curl   : GNAT.OS_Lib.String_Access := GNAT.OS_Lib.Locate_Exec_On_Path ("curl");
      Ok     : Boolean;
      How    : Endings := Lost;
      Code   : Natural := 0;
   begin
      if Curl = null then
         Job.Finish (Failed, "curl was not found");
         return;
      end if;
      Ada.Directories.Create_Path (Ada.Directories.Containing_Directory (Target));
      Delete_If_There (Part);
      Delete_If_There (Head);

      --  How long it is, for the caller to say how far on it is.
      declare
         Args : GNAT.OS_Lib.Argument_List :=
           [Argument ("-fsIL"),
            Argument ("-o"),
            Argument ("/dev/null"),
            Argument ("-D"),
            Argument (Head),
            Argument (URL)];
      begin
         GNAT.OS_Lib.Spawn (Curl.all, Args, Ok);
         Free_All (Args);
      end;
      if Ok and then Ada.Directories.Exists (Head) then
         Job.Set_Total (Content_Length (Files.Read (Head)));
      end if;
      Delete_If_There (Head);

      --  The file, to the side until it is whole.
      declare
         Args : GNAT.OS_Lib.Argument_List := [Argument ("-fsL"), Argument ("-o"), Argument (Part), Argument (URL)];
         Pid  : GNAT.OS_Lib.Process_Id;
         Stop : Boolean;
      begin
         Pid := GNAT.OS_Lib.Non_Blocking_Spawn (Curl.all, Args);
         Free_All (Args);
         if Pid = GNAT.OS_Lib.Invalid_Pid then
            Job.Finish (Failed, "curl could not be started");
            GNAT.OS_Lib.Free (Curl);
            return;
         end if;
         Job.Set_Process (Pid, Stop);
         if Stop then
            GNAT.OS_Lib.Kill (Pid);
         end if;
         Await (Pid, How, Code);
         Ok := How = Exited_Well;
      end;
      GNAT.OS_Lib.Free (Curl);

      --  Not knowing how curl ended is not a failure, if the file is
      --  all that was said it would be.
      if (Ok or else (How = Lost and then Job.Total > 0))
        and then Ada.Directories.Exists (Part)
        and then (Job.Total = 0 or else Count (Ada.Directories.Size (Part)) = Job.Total)
      then
         Delete_If_There (Target);
         --  (Rename does not replace a file that is there.)
         Ada.Directories.Rename (Part, Target);
         Job.Finish (Done);
      else
         Delete_If_There (Part);
         Job.Finish
           (Failed,
            (if Messages.Length (Job.Message) = 0
             then
               (if How = Exited_Badly
                then "the transfer failed (curl exit" & Code'Image & ")"
                else "the transfer did not finish")
             else ""));
      end if;
   exception
      when Problem : others =>
         Delete_If_There (Part);
         Delete_If_There (Head);
         Job.Finish (Failed, "could not save the file (" & Ada.Exceptions.Exception_Message (Problem) & ")");
   end Fetch;

   task type Worker is
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
         Fetch;
      end loop;
   end Worker;

   type Worker_Ref is access Worker;

   Engine : Worker_Ref;
   --  Made by the first Start, so that a program that downloads nothing has no task. Start is the caller's, one
   --  at a time, as the one job is.

   procedure Start (URL, File_Name : String) is
   begin
      Job.Begin_Job (Paths.To_Unbounded_String (URL), Paths.To_Unbounded_String (File_Name));
      if Engine = null then
         Engine := new Worker;
      end if;
      Engine.Go;
   end Start;

   function State return States
   is (Job.Current);

   function Fraction return Float is
      Total : constant Count := Job.Total;
   begin
      case Job.Current is
         when Done          =>
            return 1.0;

         when Idle | Failed =>
            return 0.0;

         when Running       =>
            if Total = 0 then
               return 0.0;
            end if;
            declare
               Part : constant String := Paths.To_String (Job.Target_File) & ".part";
               Have : constant Count :=
                 (if Ada.Directories.Exists (Part) then Count (Ada.Directories.Size (Part)) else 0);
            begin
               return Float'Min (1.0, Float (Have) / Float (Total));
            end;
      end case;
   exception
      when Ada.Directories.Name_Error | Ada.Directories.Use_Error =>
         --  Moved into place just now.
         return 0.0;
   end Fraction;

   function Message return String
   is (Messages.To_String (Job.Message));

   procedure Reset is
   begin
      Job.Forget;
   end Reset;

   procedure Cancel is
      Pid : GNAT.OS_Lib.Process_Id;
   begin
      Job.Cancel (Pid);
      if Pid /= GNAT.OS_Lib.Invalid_Pid then
         GNAT.OS_Lib.Kill (Pid);
      end if;
   end Cancel;

end Download_Jobs;
