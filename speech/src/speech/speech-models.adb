with Ada.Directories;
with Interfaces.C;
with Speech.Parakeet;
with System;

package body Speech.Models is

   use type Interfaces.C.int;

   function PK_Fetch_Begin (Directory : System.Address) return Interfaces.C.int
     with Import, Convention => C, External_Name => "pk_fetch_begin";

   function PK_Fetch_State return Interfaces.C.int
     with Import, Convention => C, External_Name => "pk_fetch_state";

   function PK_Fetch_Fraction return Interfaces.C.C_float
     with Import, Convention => C, External_Name => "pk_fetch_fraction";

   function PK_Fetch_Total return Interfaces.C.long
     with Import, Convention => C, External_Name => "pk_fetch_total";

   procedure PK_Fetch_Message (Into : System.Address; Room : Interfaces.C.int)
     with Import, Convention => C, External_Name => "pk_fetch_message";

   procedure PK_Fetch_Reset
     with Import, Convention => C, External_Name => "pk_fetch_reset";

   procedure PK_Fetch_Cancel
     with Import, Convention => C, External_Name => "pk_fetch_cancel";

   function Present (Directory : String) return Boolean is
     (Parakeet.Present (Directory));

   procedure Start (Directory : String) is
      Where : aliased constant Interfaces.C.char_array := Interfaces.C.To_C (Directory);
      Began : constant Interfaces.C.int := PK_Fetch_Begin (Where'Address);
   begin
      pragma Assert (Began = 1);
   end Start;

   function State return States is
     (case PK_Fetch_State is
         when 1      => Running,
         when 2      => Done,
         when 3      => Failed,
         when others => Idle);

   function Fraction return Float is
     (Float'Min (1.0, Float'Max (0.0, Float (PK_Fetch_Fraction))));

   function Total_Bytes return Long_Long_Integer is
     (Long_Long_Integer'Max (0, Long_Long_Integer (PK_Fetch_Total)));

   function Size_On_Disk (Directory : String) return Long_Long_Integer is
      package Dirs renames Ada.Directories;
      use type Dirs.File_Kind;
      Sum    : Long_Long_Integer := 0;
      Found  : Dirs.Search_Type;
      Each   : Dirs.Directory_Entry_Type;
   begin
      if not Dirs.Exists (Directory) or else Dirs.Kind (Directory) /= Dirs.Directory then
         return 0;
      end if;
      Dirs.Start_Search (Found, Directory, "", [Dirs.Ordinary_File | Dirs.Directory => True, others => False]);
      while Dirs.More_Entries (Found) loop
         Dirs.Get_Next_Entry (Found, Each);
         if Dirs.Simple_Name (Each) in "." | ".." then
            null;
         elsif Dirs.Kind (Each) = Dirs.Directory then
            Sum := Sum + Size_On_Disk (Dirs.Full_Name (Each));
         else
            Sum := Sum + Long_Long_Integer (Dirs.Size (Each));
         end if;
      end loop;
      Dirs.End_Search (Found);
      return Sum;
   exception
      when Dirs.Name_Error | Dirs.Use_Error =>
         return Sum;  --  it changed as it was looked at
   end Size_On_Disk;

   procedure Delete (Directory : String) is
   begin
      Parakeet.Unload;
      if Ada.Directories.Exists (Directory) then
         Ada.Directories.Delete_Tree (Directory);
      end if;
   end Delete;

   function Message return String is
      Raw  : aliased Interfaces.C.char_array (0 .. Max_Message) := [others => Interfaces.C.nul];
   begin
      PK_Fetch_Message (Raw'Address, Raw'Length);
      declare
         Said : constant String := Interfaces.C.To_Ada (Raw);
      begin
         return Said (Said'First .. Said'First - 1 + Natural'Min (Said'Length, Max_Message));
      end;
   end Message;

   procedure Reset is
   begin
      PK_Fetch_Reset;
   end Reset;

   procedure Cancel is
   begin
      PK_Fetch_Cancel;
   end Cancel;

end Speech.Models;
