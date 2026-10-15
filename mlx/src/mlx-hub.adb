with Ada.Calendar;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Text_IO;

package body MLX.Hub is

   package Dirs renames Ada.Directories;

   use type Dirs.File_Kind;
   use type Ada.Calendar.Time;

   Prefix : constant String := "models--";

   function Set (Name : String) return Boolean is
     (Ada.Environment_Variables.Exists (Name) and then Ada.Environment_Variables.Value (Name) /= "");

   function Cache_Directory return String is
   begin
      --  As Hugging Face's own tools choose it.
      if Set ("HF_HUB_CACHE") then
         return Ada.Environment_Variables.Value ("HF_HUB_CACHE");
      elsif Set ("HF_HOME") then
         return Ada.Environment_Variables.Value ("HF_HOME") & "/hub";
      else
         return (if Set ("HOME") then Ada.Environment_Variables.Value ("HOME") else "/var/empty")
           & "/.cache/huggingface/hub";
      end if;
   end Cache_Directory;

   function Is_Present return Boolean is
     (Dirs.Exists (Cache_Directory) and then Dirs.Kind (Cache_Directory) = Dirs.Directory);

   function Name_Of_Folder (Folder : String) return String is
   begin
      if Folder'Length <= Prefix'Length
        or else Folder (Folder'First .. Folder'First + Prefix'Length - 1) /= Prefix
      then
         return "";
      end if;
      declare
         Rest  : constant String := Folder (Folder'First + Prefix'Length .. Folder'Last);
         Split : constant Natural := Ada.Strings.Fixed.Index (Rest, "--");
      begin
         --  A provider and a name, neither empty: Hugging Face writes the
         --  slash between them as two hyphens.
         if Split <= Rest'First or else Split + 2 > Rest'Last
           or else Rest'Length > Max_Name
         then
            return "";
         end if;
         return Rest (Rest'First .. Split - 1) & "/" & Rest (Split + 2 .. Rest'Last);
      end;
   end Name_Of_Folder;

   function Folder_Of (Name : String) return String is
      Slash : constant Natural := Ada.Strings.Fixed.Index (Name, "/");
   begin
      if Slash = 0 then
         return "";
      end if;
      return Cache_Directory & "/" & Prefix & Name (Name'First .. Slash - 1) & "--"
        & Name (Slash + 1 .. Name'Last);
   end Folder_Of;

   procedure Scan (Found : out Models) is
      Search : Dirs.Search_Type;
      Each   : Dirs.Directory_Entry_Type;
   begin
      Found := (others => <>);
      if not Is_Present then
         return;
      end if;
      Dirs.Start_Search (Search, Cache_Directory, "", [Dirs.Directory => True, others => False]);
      while Dirs.More_Entries (Search) loop
         Dirs.Get_Next_Entry (Search, Each);
         declare
            Name : constant String := Name_Of_Folder (Dirs.Simple_Name (Each));
         begin
            if Name /= "" then
               if Found.Total = Max_Models then
                  Found.Overflow := True;
               else
                  --  Kept in order: insert before the first that is greater.
                  declare
                     Place : Positive := Found.Total + 1;
                  begin
                     for Index in 1 .. Found.Total loop
                        if Name < Found.Names (Index) (1 .. Found.Lengths (Index)) then
                           Place := Index;
                           exit;
                        end if;
                     end loop;
                     for Index in reverse Place .. Found.Total loop
                        Found.Names (Index + 1) := Found.Names (Index);
                        Found.Lengths (Index + 1) := Found.Lengths (Index);
                     end loop;
                     Found.Names (Place) (1 .. Name'Length) := Name;
                     Found.Lengths (Place) := Name'Length;
                     Found.Total := Found.Total + 1;
                  end;
               end if;
            end if;
         end;
      end loop;
      Dirs.End_Search (Search);
   exception
      when Dirs.Name_Error | Dirs.Use_Error =>
         null;  --  it changed as it was looked at: what was found stays
   end Scan;

   function Count (Found : Models) return Natural is (Found.Total);

   function Model_At (Found : Models; Which : Positive) return String is
     (Found.Names (Which) (1 .. Found.Lengths (Which)));

   function Left_Out (Found : Models) return Boolean is (Found.Overflow);

   function Snapshot (Name : String) return String is
      Folder    : constant String := Folder_Of (Name);
      Snapshots : constant String := Folder & "/snapshots";
   begin
      if Folder = "" or else not Dirs.Exists (Snapshots) then
         return "";
      end if;

      --  The revision that main is at.
      declare
         Ref : constant String := Folder & "/refs/main";
      begin
         if Dirs.Exists (Ref) and then Dirs.Kind (Ref) = Dirs.Ordinary_File then
            declare
               File : Ada.Text_IO.File_Type;
            begin
               Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Ref);
               declare
                  Hash : constant String := Ada.Text_IO.Get_Line (File);
               begin
                  Ada.Text_IO.Close (File);
                  if Hash /= "" and then Dirs.Exists (Snapshots & "/" & Hash) then
                     return Snapshots & "/" & Hash;
                  end if;
               end;
            exception
               when others =>
                  if Ada.Text_IO.Is_Open (File) then
                     Ada.Text_IO.Close (File);
                  end if;
            end;
         end if;
      end;

      --  Or the newest.
      declare
         Search : Dirs.Search_Type;
         Each   : Dirs.Directory_Entry_Type;
         Best   : String (1 .. Max_Path) := [others => ' '];
         Length : Natural := 0;
         Latest : Ada.Calendar.Time := Ada.Calendar.Time_Of (Ada.Calendar.Year_Number'First, 1, 1);
      begin
         Dirs.Start_Search (Search, Snapshots, "", [Dirs.Directory => True, others => False]);
         while Dirs.More_Entries (Search) loop
            Dirs.Get_Next_Entry (Search, Each);
            if Dirs.Simple_Name (Each) not in "." | ".."
              and then Dirs.Full_Name (Each)'Length <= Max_Path
              and then (Length = 0 or else Dirs.Modification_Time (Each) > Latest)
            then
               Length := Dirs.Full_Name (Each)'Length;
               Best (1 .. Length) := Dirs.Full_Name (Each);
               Latest := Dirs.Modification_Time (Each);
            end if;
         end loop;
         Dirs.End_Search (Search);
         return Best (1 .. Length);
      exception
         when Dirs.Name_Error | Dirs.Use_Error =>
            return "";
      end;
   end Snapshot;

end MLX.Hub;
