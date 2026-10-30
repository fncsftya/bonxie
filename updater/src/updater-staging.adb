with Ada.Directories;
with Ada.Exceptions;
with Ada.Streams.Stream_IO;
with Ada.Strings.Bounded;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with GNAT.OS_Lib;
with Updater.Manifests;
with Updater.Signing;

package body Updater.Staging is

   use type GNAT.OS_Lib.Process_Id;

   package Unbounded renames Ada.Strings.Unbounded;
   package Messages is new Ada.Strings.Bounded.Generic_Bounded_Length (Max_Message);

   Application_Name : constant String := "Bonxie.app";
   Result_Name      : constant String := "result";
   Failure_Prefix   : constant String := "failed: ";

   type Work is record
      Directory, Disk_Image, Manifest, Signature, Key : Unbounded.Unbounded_String;
      Expected                                        : Versions.Version;
   end record;

   protected Job is
      procedure Begin_Job (What : Work);
      procedure Finish (To : States; Why : String := "");
      function Current return States;
      function Task_Work return Work;
      function Reason return Messages.Bounded_String;
      procedure Forget;
   private
      Now   : States := Idle;
      Given : Work;
      Why   : Messages.Bounded_String;
   end Job;

   protected body Job is

      procedure Begin_Job (What : Work) is
      begin
         Now := Running;
         Given := What;
         Why := Messages.Null_Bounded_String;
      end Begin_Job;

      procedure Finish (To : States; Why : String := "") is
      begin
         Now := To;
         Job.Why := Messages.To_Bounded_String (Why, Ada.Strings.Right);
      end Finish;

      function Current return States
      is (Now);
      function Task_Work return Work
      is (Given);
      function Reason return Messages.Bounded_String
      is (Why);

      procedure Forget is
      begin
         Now := Idle;
         Why := Messages.Null_Bounded_String;
      end Forget;

   end Job;

   function Read_All (File_Name : String) return String;

   function Read_All (File_Name : String) return String is
      File : Ada.Streams.Stream_IO.File_Type;
   begin
      Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, File_Name);
      declare
         Text : String (1 .. Natural (Ada.Streams.Stream_IO.Size (File)));
      begin
         String'Read (Ada.Streams.Stream_IO.Stream (File), Text);
         Ada.Streams.Stream_IO.Close (File);
         return Text;
      end;
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;
         return "";
   end Read_All;

   procedure Delete_Tree (Path : String);

   procedure Delete_Tree (Path : String) is
   begin
      if Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_Tree (Path);
      end if;
   exception
      when Ada.Directories.Use_Error | Ada.Directories.Name_Error =>
         null;
   end Delete_Tree;

   type Text_List is array (Positive range <>) of Unbounded.Unbounded_String;

   function "+" (Text : String) return Unbounded.Unbounded_String renames Unbounded.To_Unbounded_String;

   function Run (Program : String; Arguments : Text_List; Log : String) return Boolean;
   --  Whether the program, started by this path with those arguments, ended well; what it said is put in Log.

   function Run (Program : String; Arguments : Text_List; Log : String) return Boolean is
      List : GNAT.OS_Lib.Argument_List (Arguments'Range);
      Ok   : Boolean;
      Code : Integer;
   begin
      for Index in List'Range loop
         List (Index) := new String'(Unbounded.To_String (Arguments (Index)));
      end loop;
      GNAT.OS_Lib.Spawn (Program, List, Log, Ok, Code);
      for Each of List loop
         GNAT.OS_Lib.Free (Each);
      end loop;
      return Ok and then Code = 0;
   end Run;

   function Last_Line (Log : String) return String;
   --  The last line a tool said: a reason, or near one.

   function Last_Line (Log : String) return String is
      Text : constant String := Read_All (Log);
      Last : Natural := Text'Last;
      From : Natural;
   begin
      while Last >= Text'First and then Text (Last) in ASCII.LF | ASCII.CR | ' ' loop
         Last := Last - 1;
      end loop;
      From := Last;
      while From > Text'First and then Text (From - 1) not in ASCII.LF | ASCII.CR loop
         From := From - 1;
      end loop;
      return (if Last < Text'First then "" else Text (From .. Last));
   end Last_Line;

   function Shorter (Text : String) return String
   is (Text (Text'First .. Text'First + Natural'Min (Text'Length, Max_Message - 60) - 1));
   --  (Leaving room for what the message adds.)

   procedure Stage;
   --  Do the job in Job, and say how it ended.

   procedure Stage is
      What      : constant Work := Job.Task_Work;
      Directory : constant String := Unbounded.To_String (What.Directory);
      Image     : constant String := Unbounded.To_String (What.Disk_Image);
      Mount     : constant String := Directory & "/mount";
      Log       : constant String := Directory & "/log";
      Staged    : constant String := Directory & "/" & Application_Name;
      Hdiutil   : constant String := "/usr/bin/hdiutil";
      Manifest  : Manifests.Manifest;
      Failure   : Unbounded.Unbounded_String;

      procedure Fail (Why : String);
      procedure Fail (Why : String) is
      begin
         Failure := Unbounded.To_Unbounded_String (Why);
      end Fail;

      function Failed_Already return Boolean
      is (Unbounded.Length (Failure) > 0);

      procedure Verify;
      --  The signature first: nothing else is believed until it holds.

      procedure Verify is
         Text      : constant String := Read_All (Unbounded.To_String (What.Manifest));
         Signature : constant String := Read_All (Unbounded.To_String (What.Signature));
      begin
         if Text = "" or else Signature = "" then
            Fail ("the update's manifest or signature is missing");
         elsif not Signing.Verify (Unbounded.To_String (What.Key), Text, Signature) then
            Fail ("the update is not signed by its author");
         elsif not Manifests.Parse (Text, Manifest) then
            Fail ("the update's manifest is not readable");
         elsif Versions.Compare (Manifest.Version, What.Expected) /= 0 then
            Fail ("the update is for version " & Versions.Image (Manifest.Version) & ", not the one offered");
         elsif Long_Long_Integer (Ada.Directories.Size (Image)) /= Manifest.Size then
            Fail ("the download is not the size the author signed");
         elsif Signing.SHA_256 (Image) /= Manifest.Digest then
            Fail ("the download is not the file the author signed");
         end if;
      end Verify;

      procedure Extract;
      --  Take the application out of the image.

      procedure Extract is
         Mounted  : Boolean := False;
         Detached : Boolean;
         pragma Unreferenced (Detached);
      begin
         Ada.Directories.Create_Path (Mount);
         if Run
              (Hdiutil,
               [+"attach", +"-nobrowse", +"-readonly", +"-noverify", +"-noautoopen", +"-mountpoint", +Mount, +Image],
               Log)
         then
            Mounted := True;
            if not Ada.Directories.Exists (Mount & "/" & Application_Name) then
               Fail ("the disk image has no " & Application_Name);
            elsif not Run ("/usr/bin/ditto", [+(Mount & "/" & Application_Name), +Staged], Log) then
               Fail ("the application could not be copied from the disk image");
            end if;
         else
            Fail ("the disk image could not be opened");
         end if;
         if Mounted then
            --  (If it will not let go, it is gone with the next restart: not the update's fault.)
            Detached := Run (Hdiutil, [+"detach", +Mount, +"-force"], Log);
         end if;
         Delete_Tree (Mount);
      end Extract;

      procedure Inspect;
      --  The copy is as it was signed, and is the version that was promised.

      procedure Inspect is
         Plist : constant String := Staged & "/Contents/Info.plist";
      begin
         if not Run ("/usr/bin/xattr", [+"-dr", +"com.apple.quarantine", +Staged], Log) then
            Fail ("the application could not be cleared of its quarantine");
         elsif not Run ("/usr/bin/codesign", [+"--verify", +"--deep", +"--strict", +Staged], Log) then
            Fail ("the application's signature is not intact");
         elsif not Run ("/usr/libexec/PlistBuddy", [+"-c", +"Print :CFBundleShortVersionString", +Plist], Log)
           or else Last_Line (Log) /= Versions.Image (What.Expected)
         then
            Fail ("the application is not version " & Versions.Image (What.Expected));
         end if;
      end Inspect;

   begin
      Delete_Tree (Staged);
      Delete_Tree (Mount);
      Verify;
      if not Failed_Already then
         Extract;
      end if;
      if not Failed_Already then
         Inspect;
      end if;
      if Failed_Already then
         Delete_Tree (Staged);
         Job.Finish (Failed, Shorter (Unbounded.To_String (Failure)));
      else
         Job.Finish (Done);
      end if;
   exception
      when Problem : others =>
         Delete_Tree (Staged);
         Delete_Tree (Mount);
         Job.Finish (Failed, Shorter (Ada.Exceptions.Exception_Message (Problem)));
   end Stage;

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
         Stage;
      end loop;
   end Worker;

   type Worker_Ref is access Worker;

   Engine : Worker_Ref;
   --  Made by the first Start, so that a program that updates nothing has no task.

   procedure Start (Directory, Disk_Image, Manifest, Signature, Public_Key : String; Expected : Versions.Version) is
   begin
      Job.Begin_Job
        ((Directory  => +Directory,
          Disk_Image => +Disk_Image,
          Manifest   => +Manifest,
          Signature  => +Signature,
          Key        => +Public_Key,
          Expected   => Expected));
      if Engine = null then
         Engine := new Worker;
      end if;
      Engine.Go;
   end Start;

   function State return States
   is (Job.Current);

   function Message return String
   is (Messages.To_String (Job.Reason));

   function Application return String
   is (Unbounded.To_String (Job.Task_Work.Directory) & "/" & Application_Name);

   procedure Reset is
   begin
      Job.Forget;
   end Reset;

   procedure Hand_Over (Script, Staged, Target, Directory : String; Process : Natural; Started : out Boolean) is
      Copy : constant String := Directory & "/update-helper.sh";
      Args : GNAT.OS_Lib.Argument_List :=
        [new String'(Copy),
         new String'(Ada.Strings.Fixed.Trim (Process'Image, Ada.Strings.Left)),
         new String'(Staged),
         new String'(Target),
         new String'(Directory & "/" & Result_Name)];
      Pid  : GNAT.OS_Lib.Process_Id;
   begin
      Started := False;
      if Ada.Directories.Exists (Copy) then
         Ada.Directories.Delete_File (Copy);
      end if;
      Ada.Directories.Copy_File (Script, Copy);
      if Ada.Directories.Exists (Directory & "/" & Result_Name) then
         Ada.Directories.Delete_File (Directory & "/" & Result_Name);
      end if;
      Pid := GNAT.OS_Lib.Non_Blocking_Spawn ("/bin/sh", Args);
      Started := Pid /= GNAT.OS_Lib.Invalid_Pid;
      for Each of Args loop
         GNAT.OS_Lib.Free (Each);
      end loop;
   exception
      when Ada.Directories.Name_Error | Ada.Directories.Use_Error =>
         for Each of Args loop
            GNAT.OS_Lib.Free (Each);
         end loop;
         Started := False;
   end Hand_Over;

   function Last_Failure (Directory : String) return String is
      Text : constant String := Read_All (Directory & "/" & Result_Name);
      Line : constant Natural := Ada.Strings.Fixed.Index (Text, String'[1 => ASCII.LF]);
      Last : constant Natural := (if Line = 0 then Text'Last else Line - 1);
   begin
      if Text'Length > Failure_Prefix'Length
        and then Text (Text'First .. Text'First + Failure_Prefix'Length - 1) = Failure_Prefix
      then
         return Shorter (Text (Text'First + Failure_Prefix'Length .. Last));
      end if;
      return "";
   end Last_Failure;

   procedure Forget_Failure (Directory : String) is
   begin
      if Ada.Directories.Exists (Directory & "/" & Result_Name) then
         Ada.Directories.Delete_File (Directory & "/" & Result_Name);
      end if;
   exception
      when Ada.Directories.Use_Error | Ada.Directories.Name_Error =>
         null;
   end Forget_Failure;

end Updater.Staging;
