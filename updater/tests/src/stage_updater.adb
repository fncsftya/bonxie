with Ada.Command_Line;
with Ada.Text_IO;
with Updater.Staging;
with Updater.Versions;

--  Stage an update as the program does and say how it went; stage_test.sh makes the files and judges the answer.
--
--     bin/stage_updater <public-key> <directory> <disk-image> <manifest> <signature> <version>
--
--  Prints "staged <path>" or "failed <why>".

procedure Stage_Updater is
   package Staging renames Updater.Staging;
   use type Staging.States;
   Version : Updater.Versions.Version;
begin
   if Ada.Command_Line.Argument_Count /= 6 or else not Updater.Versions.Parse (Ada.Command_Line.Argument (6), Version)
   then
      Ada.Text_IO.Put_Line ("usage: stage_updater KEY DIRECTORY DMG MANIFEST SIGNATURE VERSION");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;
   Staging.Start
     (Directory  => Ada.Command_Line.Argument (2),
      Disk_Image => Ada.Command_Line.Argument (3),
      Manifest   => Ada.Command_Line.Argument (4),
      Signature  => Ada.Command_Line.Argument (5),
      Public_Key => Ada.Command_Line.Argument (1),
      Expected   => Version);
   while Staging.State = Staging.Running loop
      delay 0.05;
   end loop;
   if Staging.State = Staging.Done then
      Ada.Text_IO.Put_Line ("staged " & Staging.Application);
   else
      Ada.Text_IO.Put_Line ("failed " & Staging.Message);
   end if;
end Stage_Updater;
