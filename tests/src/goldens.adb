with Ada.Command_Line;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Text_IO;

package body Goldens is

   use type SDL3.Windows.Renderers.Color_Component;

   subtype Color is SDL3.Windows.Renderers.Color;

   Passes   : Natural := 0;
   Failures : Natural := 0;

   function Root return String is
     (Ada.Directories.Containing_Directory
        (Ada.Directories.Containing_Directory
           (Ada.Directories.Full_Name (Ada.Command_Line.Command_Name))));
   --  Of the tests: the program is in bin/ there.

   function Golden_Dir return String is (Root & "/golden");
   function Output_Dir return String is (Root & "/out");

   function Updating return Boolean is
     (Ada.Environment_Variables.Exists ("UPDATE_GOLDEN")
      and then Ada.Environment_Variables.Value ("UPDATE_GOLDEN") = "1");

   procedure Save (Item : Images.Image; Path : String) is
   begin
      Ada.Directories.Create_Path
        (Ada.Directories.Containing_Directory (Path));
      Images.Save_PNG (Item, Path);
   end Save;

   procedure Remove (Path : String) is
   begin
      if Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_File (Path);
      end if;
   end Remove;
   --  What an earlier run left.

   procedure Pass (Name : String; Note : String := "") is
   begin
      Passes := Passes + 1;
      Ada.Text_IO.Put_Line ("ok    " & Name & Note);
   end Pass;

   procedure Fail (Name : String; Why : String) is
   begin
      Failures := Failures + 1;
      Ada.Text_IO.Put_Line ("FAIL  " & Name & ": " & Why);
   end Fail;

   function Delta_Of (A, B : Color) return Natural is
     (Natural'Max
        (Natural'Max (Natural (abs (Integer (A.Red) - Integer (B.Red))),
                      Natural (abs (Integer (A.Green) - Integer (B.Green)))),
         Natural'Max (Natural (abs (Integer (A.Blue) - Integer (B.Blue))),
                      Natural (abs (Integer (A.Alpha) - Integer (B.Alpha))))));
   --  The most any channel differs by.

   function Same_Size (A, B : Images.Image) return Boolean is
     (Images.Width (A) = Images.Width (B)
      and then Images.Height (A) = Images.Height (B));

   function Size_Of (Item : Images.Image) return String is
     (Images.Width (Item)'Image & " x" & Images.Height (Item)'Image);

   procedure Compare
     (Expected, Actual : Images.Image;
      Tolerance        : Natural;
      Diff             : in out Images.Image;
      Differing        : out Natural;
      Max_Delta        : out Natural)
     with Pre => Same_Size (Expected, Actual);
   --  Count the pixels that differ by more than Tolerance, and make Diff:
   --  them in red, over Expected dimmed.

   procedure Compare
     (Expected, Actual : Images.Image;
      Tolerance        : Natural;
      Diff             : in out Images.Image;
      Differing        : out Natural;
      Max_Delta        : out Natural) is
   begin
      Images.Create (Diff, Images.Width (Expected), Images.Height (Expected));
      Differing := 0;
      Max_Delta := 0;
      for Y in 0 .. Images.Height (Expected) - 1 loop
         for X in 0 .. Images.Width (Expected) - 1 loop
            declare
               Was : constant Color := Images.Pixel (Expected, X, Y);
               Now : constant Color := Images.Pixel (Actual, X, Y);
               Off : constant Natural := Delta_Of (Was, Now);
            begin
               Max_Delta := Natural'Max (Max_Delta, Off);
               if Off > Tolerance then
                  Differing := Differing + 1;
                  Images.Set_Pixel (Diff, X, Y, (255, 0, 0, 255));
               else
                  Images.Set_Pixel
                    (Diff, X, Y,
                     (Was.Red / 4, Was.Green / 4, Was.Blue / 4, 255));
               end if;
            end;
         end loop;
      end loop;
   end Compare;

   procedure Judge
     (Name          : String;
      Expected      : Images.Image;
      Actual        : Images.Image;
      Tolerance     : Natural;
      Max_Differing : Natural;
      Against       : String;
      Keep_Expected : Boolean);
   --  Compare, and say how it went; on a mismatch write what was drawn,
   --  and the difference (and Expected, if Keep_Expected).

   procedure Judge
     (Name          : String;
      Expected      : Images.Image;
      Actual        : Images.Image;
      Tolerance     : Natural;
      Max_Differing : Natural;
      Against       : String;
      Keep_Expected : Boolean)
   is
      Actual_Path   : constant String :=
        Output_Dir & "/" & Name & "-actual.png";
      Diff_Path     : constant String := Output_Dir & "/" & Name & "-diff.png";
      Expected_Path : constant String :=
        Output_Dir & "/" & Name & "-expected.png";
      Diff          : Images.Image;
      Differing     : Natural;
      Max_Delta     : Natural;
   begin
      if not Same_Size (Expected, Actual) then
         Save (Actual, Actual_Path);
         Fail (Name, "size" & Size_Of (Actual) & ", " & Against
               & Size_Of (Expected) & "; see " & Actual_Path);
         return;
      end if;

      Compare (Expected, Actual, Tolerance, Diff, Differing, Max_Delta);
      if Differing <= Max_Differing then
         Remove (Actual_Path);
         Remove (Diff_Path);
         Remove (Expected_Path);
         Pass (Name, (if Differing > 0 or else Max_Delta > 0
                      then " (" & Differing'Image & " pixels differ, by up to"
                           & Max_Delta'Image & ")"
                      else ""));
      else
         Save (Actual, Actual_Path);
         Save (Diff, Diff_Path);
         if Keep_Expected then
            Save (Expected, Expected_Path);
         end if;
         Fail (Name, Differing'Image & " pixels differ from " & Against
               & " (by up to" & Max_Delta'Image & "); see " & Actual_Path
               & " and " & Diff_Path);
      end if;
   end Judge;

   procedure Check
     (Name          : String;
      Actual        : Images.Image;
      Tolerance     : Natural := 0;
      Max_Differing : Natural := 0)
   is
      Golden_Path : constant String := Golden_Dir & "/" & Name & ".png";
   begin
      if Updating then
         Save (Actual, Golden_Path);
         Pass (Name, " (golden written)");
      elsif not Ada.Directories.Exists (Golden_Path) then
         declare
            Actual_Path : constant String :=
              Output_Dir & "/" & Name & "-actual.png";
         begin
            Save (Actual, Actual_Path);
            Fail (Name, "no golden image " & Golden_Path & "; what is drawn "
                  & "is " & Actual_Path & ". If it looks right, run with "
                  & "UPDATE_GOLDEN=1.");
         end;
      else
         declare
            Golden : Images.Image;
         begin
            Images.Load_PNG (Golden, Golden_Path);
            Judge (Name, Golden, Actual, Tolerance, Max_Differing,
                   Against => "the golden", Keep_Expected => False);
         end;
      end if;
   end Check;

   procedure Check_Same
     (Name          : String;
      Expected      : Images.Image;
      Actual        : Images.Image;
      Tolerance     : Natural := 0;
      Max_Differing : Natural := 0) is
   begin
      Judge (Name, Expected, Actual, Tolerance, Max_Differing,
             Against => "what was expected", Keep_Expected => True);
   end Check_Same;

   procedure Check_Text (Name : String; Expected, Actual : String) is
   begin
      if Actual = Expected then
         Pass (Name);
      else
         Fail (Name, "expected """ & Expected & """, got """ & Actual & """");
      end if;
   end Check_Text;

   function Scratch (Name : String) return String is
   begin
      Ada.Directories.Create_Path (Output_Dir);
      return Output_Dir & "/" & Name;
   end Scratch;

   function Passed return Natural is (Passes);
   function Failed return Natural is (Failures);

end Goldens;
