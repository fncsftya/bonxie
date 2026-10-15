with Ada.Strings.Fixed;
with Ada.Strings.Maps;
with Interfaces.C;
with System;

package body MLX is

   use type Interfaces.C.int;

   function MX_Check
     (Directory    : System.Address;
      Message      : System.Address;
      Message_Room : Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C, External_Name => "mx_check";

   procedure MX_Unload
     with Import, Convention => C, External_Name => "mx_unload";

   function MX_Loaded return Interfaces.C.int
     with Import, Convention => C, External_Name => "mx_loaded";

   procedure MX_Cancel_All
     with Import, Convention => C, External_Name => "mx_cancel_all";

   function Problem (Directory : String) return String is
      Where : aliased constant Interfaces.C.char_array := Interfaces.C.To_C (Directory);
      Raw   : aliased Interfaces.C.char_array (0 .. Max_Message) := [others => Interfaces.C.nul];
   begin
      if MX_Check (Where'Address, Raw'Address, Raw'Length) = 1 then
         return "";
      end if;
      declare
         Said : constant String := Interfaces.C.To_Ada (Raw);
      begin
         return (if Said = "" then "The model cannot be used" else Said);
      end;
   end Problem;

   procedure Unload is
   begin
      MX_Unload;
   end Unload;

   function Is_Loaded return Boolean is (MX_Loaded = 1);

   procedure Cancel_All is
   begin
      MX_Cancel_All;
   end Cancel_All;

   Spaces : constant Ada.Strings.Maps.Character_Set :=
     Ada.Strings.Maps.To_Set (" " & ASCII.LF & ASCII.CR & ASCII.HT);

   function Trimmed (Text : String) return String is
     (Ada.Strings.Fixed.Trim (Text, Left => Spaces, Right => Spaces));

   function Without_Thinking (Raw : String) return String is
      Open  : constant String := "<think>";
      Close : constant String := "</think>";
      Kept  : String (1 .. Raw'Length) := Raw;
      Last  : Natural := Kept'Last;

      procedure Remove (From, To : Positive) is
      begin
         Kept (From .. Last - (To - From + 1)) := Kept (To + 1 .. Last);
         Last := Last - (To - From + 1);
      end Remove;
   begin
      --  Whole thoughts, and one that is not closed, which goes to the end.
      loop
         declare
            Start : constant Natural := Ada.Strings.Fixed.Index (Kept (1 .. Last), Open);
         begin
            exit when Start = 0;
            declare
               Stop : constant Natural :=
                 Ada.Strings.Fixed.Index (Kept (Start + Open'Length .. Last), Close);
            begin
               if Stop = 0 then
                  Last := Start - 1;
               else
                  Remove (Start, Stop + Close'Length - 1);
               end if;
            end;
         end;
      end loop;
      --  A thought whose start was not said: all before its end.
      declare
         Stop : constant Natural := Ada.Strings.Fixed.Index (Kept (1 .. Last), Close);
      begin
         if Stop /= 0 then
            Remove (1, Stop + Close'Length - 1);
         end if;
      end;
      declare
         Said : constant String := Trimmed (Kept (1 .. Last));
      begin
         return (if Said /= "" then Said else Trimmed (Raw));
      end;
   end Without_Thinking;

end MLX;
