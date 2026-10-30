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

   function PK_Fetch_Preparing return Interfaces.C.int
   with Import, Convention => C, External_Name => "pk_fetch_preparing";

   procedure PK_Preload (Directory : System.Address)
   with Import, Convention => C, External_Name => "pk_preload";

   function PK_Fetch_Total return Interfaces.C.long
   with Import, Convention => C, External_Name => "pk_fetch_total";

   procedure PK_Fetch_Message (Into : System.Address; Room : Interfaces.C.int)
   with Import, Convention => C, External_Name => "pk_fetch_message";

   procedure PK_Fetch_Reset
   with Import, Convention => C, External_Name => "pk_fetch_reset";

   procedure PK_Fetch_Cancel
   with Import, Convention => C, External_Name => "pk_fetch_cancel";

   function GR_Fetch_Begin (Directory : System.Address) return Interfaces.C.int
   with Import, Convention => C, External_Name => "gr_fetch_begin";

   function GR_Fetch_State return Interfaces.C.int
   with Import, Convention => C, External_Name => "gr_fetch_state";

   function GR_Fetch_Fraction return Interfaces.C.C_float
   with Import, Convention => C, External_Name => "gr_fetch_fraction";

   function GR_Fetch_Preparing return Interfaces.C.int
   with Import, Convention => C, External_Name => "gr_fetch_preparing";

   procedure GR_Preload (Directory : System.Address)
   with Import, Convention => C, External_Name => "gr_preload";

   function GR_Fetch_Total return Interfaces.C.long
   with Import, Convention => C, External_Name => "gr_fetch_total";

   procedure GR_Fetch_Message (Into : System.Address; Room : Interfaces.C.int)
   with Import, Convention => C, External_Name => "gr_fetch_message";

   procedure GR_Fetch_Reset
   with Import, Convention => C, External_Name => "gr_fetch_reset";

   procedure GR_Fetch_Cancel
   with Import, Convention => C, External_Name => "gr_fetch_cancel";

   Speaking : Model_Kinds := Parakeet_V3
   with Atomic;
   --  The kind that State and the rest speak of.

   function Present (Kind : Model_Kinds; Directory : String) return Boolean
   is (Parakeet.Present (Kind, Directory));

   procedure Focus (Kind : Model_Kinds) is
   begin
      Reset;
      Speaking := Kind;
   end Focus;

   procedure Start (Kind : Model_Kinds; Directory : String) is
      Where : aliased constant Interfaces.C.char_array := Interfaces.C.To_C (Directory);
      Began : Interfaces.C.int;
   begin
      Reset;
      Speaking := Kind;
      case Kind is
         when Parakeet_V3 =>
            Began := PK_Fetch_Begin (Where'Address);

         when Granite_5   =>
            Began := GR_Fetch_Begin (Where'Address);
      end case;
      pragma Assert (Began = 1);
   end Start;

   function Raw_State return Interfaces.C.int
   is (case Speaking is
         when Parakeet_V3 => PK_Fetch_State,
         when Granite_5   => GR_Fetch_State);

   function State return States
   is (case Raw_State is
         when 1      => Running,
         when 2      => Done,
         when 3      => Failed,
         when others => Idle);

   function Fraction return Float
   is (Float'Min
         (1.0,
          Float'Max
            (0.0,
             Float
               (case Speaking is
                  when Parakeet_V3 => PK_Fetch_Fraction,
                  when Granite_5   => GR_Fetch_Fraction))));

   function Preparing return Boolean
   is (Raw_State = 1
       and then (case Speaking is
                   when Parakeet_V3 => PK_Fetch_Preparing = 1,
                   when Granite_5   => GR_Fetch_Preparing = 1));

   procedure Preload (Kind : Model_Kinds; Directory : String) is
      Where : aliased constant Interfaces.C.char_array := Interfaces.C.To_C (Directory);
   begin
      case Kind is
         when Parakeet_V3 =>
            PK_Preload (Where'Address);

         when Granite_5   =>
            GR_Preload (Where'Address);
      end case;
   end Preload;

   function Total_Bytes return Long_Long_Integer
   is (Long_Long_Integer'Max
         (0,
          Long_Long_Integer
            (case Speaking is
               when Parakeet_V3 => PK_Fetch_Total,
               when Granite_5   => GR_Fetch_Total)));

   function Size_On_Disk (Directory : String) return Long_Long_Integer is
      package Dirs renames Ada.Directories;
      use type Dirs.File_Kind;
      Sum   : Long_Long_Integer := 0;
      Found : Dirs.Search_Type;
      Each  : Dirs.Directory_Entry_Type;
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

   procedure Delete (Kind : Model_Kinds; Directory : String) is
      pragma Unreferenced (Kind);
   begin
      Parakeet.Unload;
      if Ada.Directories.Exists (Directory) then
         Ada.Directories.Delete_Tree (Directory);
      end if;
   end Delete;

   function Message return String is
      Raw : aliased Interfaces.C.char_array (0 .. Max_Message) := [others => Interfaces.C.nul];
   begin
      case Speaking is
         when Parakeet_V3 =>
            PK_Fetch_Message (Raw'Address, Raw'Length);

         when Granite_5   =>
            GR_Fetch_Message (Raw'Address, Raw'Length);
      end case;
      declare
         Said : constant String := Interfaces.C.To_Ada (Raw);
      begin
         return Said (Said'First .. Said'First - 1 + Natural'Min (Said'Length, Max_Message));
      end;
   end Message;

   procedure Reset is
   begin
      PK_Fetch_Reset;
      GR_Fetch_Reset;
   end Reset;

   procedure Cancel is
   begin
      PK_Fetch_Cancel;
      GR_Fetch_Cancel;
   end Cancel;

end Speech.Models;
