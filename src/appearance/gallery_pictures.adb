with Ada.Directories;
with Ada.Exceptions;
with Ada.Numerics.Discrete_Random;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with Backgrounds;
with Download_Jobs;
with Interfaces.C;
with Painting_Colours;
with SDL3.Pictures;

package body Gallery_Pictures is
   package Strings renames Ada.Strings.Unbounded;
   package Transfer is new Download_Jobs;
   package Random_Numbers is new Ada.Numerics.Discrete_Random (Natural);
   use type Transfer.States;
   use type Interfaces.C.int;

   function Rename (Old_Name, New_Name : Interfaces.C.char_array) return Interfaces.C.int
   with Import, Convention => C, External_Name => "rename";

   function File_Name (Item : Source) return String
   is (Strings.To_String (Item.Directory) & "/gallery-background.png");

   function Candidate (Item : Source) return String
   is (Strings.To_String (Item.Directory) & "/gallery-candidate.png");

   function State (Item : Source) return States
   is (Item.Current);
   function Message (Item : Source) return String
   is (Strings.To_String (Item.Reason));
   function Present (Item : Source) return Boolean
   is (Ada.Directories.Exists (File_Name (Item)));
   function Version (Item : Source) return Natural
   is (Item.Serial);
   function Hue (Item : Source) return Float
   is (Item.Colour_Hue);
   function Strength (Item : Source) return Float
   is (Item.Colour_Strength);
   function Fraction (Item : Source) return Float
   is (if Item.Current = Running then Transfer.Fraction else (if Item.Current = Done then 1.0 else 0.0));

   procedure Open
     (Item : in out Source; Catalogue, Directory : String; Image_Base : String := "https://api.nga.gov/iiif/") is
   begin
      Item.Catalogue := Strings.To_Unbounded_String (Catalogue);
      Item.Directory := Strings.To_Unbounded_String (Directory);
      Item.Image_Base := Strings.To_Unbounded_String (Image_Base);
      if Present (Item) then
         declare
            Picture : SDL3.Pictures.Decoded;
            Dark    : Boolean;
         begin
            SDL3.Pictures.Decode (Picture, File_Name (Item), Dark);
            Painting_Colours.Sample (Picture, Item.Colour_Hue, Item.Colour_Strength);
         exception
            when others =>
               Item.Colour_Hue := 0.0;
               Item.Colour_Strength := 0.0;
         end;
      end if;
   end Open;

   procedure Start (Item : in out Source) is
      File      : Ada.Text_IO.File_Type;
      Count     : Natural := 0;
      Pick      : Strings.Unbounded_String;
      Fallback  : Strings.Unbounded_String;
      Seed      : constant Natural := Backgrounds.New_Seed;
      Generator : Random_Numbers.Generator;
   begin
      Random_Numbers.Reset (Generator, Seed);
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Strings.To_String (Item.Catalogue));
      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line : constant String := Ada.Text_IO.Get_Line (File);
            Tab  : constant Natural := Ada.Strings.Fixed.Index (Line, String'(1 => ASCII.HT));
         begin
            if Tab > 0 and then Tab < Line'Last then
               declare
                  Image_Id : constant Strings.Unbounded_String :=
                    Strings.To_Unbounded_String (Line (Tab + 1 .. Line'Last));
               begin
                  if Strings."=" (Image_Id, Item.Last) then
                     Fallback := Image_Id;
                  else
                     Count := Count + 1;
                     if Count = 1 or else Random_Numbers.Random (Generator) mod Count = 0 then
                        Pick := Image_Id;
                     end if;
                  end if;
               end;
            end if;
         end;
      end loop;
      Ada.Text_IO.Close (File);
      if Count = 0 then
         if Strings.Length (Fallback) = 0 then
            raise Constraint_Error with "the gallery catalogue is empty";
         end if;
         Pick := Fallback;
      end if;
      Transfer.Start
        (Strings.To_String (Item.Image_Base) & Strings.To_String (Pick) & "/full/!2560,2560/0/default.png",
         Candidate (Item));
      Item.Last := Pick;
      Item.Current := Running;
      Item.Reason := Strings.Null_Unbounded_String;
   exception
      when Problem : others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         Item.Current := Failed;
         Item.Reason := Strings.To_Unbounded_String (Ada.Exceptions.Exception_Message (Problem));
   end Start;

   procedure Poll (Item : in out Source) is
      Picture                     : SDL3.Pictures.Decoded;
      Dark                        : Boolean;
      Sample_Hue, Sample_Strength : Float;
   begin
      if Item.Current /= Running then
         return;
      elsif Transfer.State = Transfer.Failed then
         Item.Current := Failed;
         Item.Reason := Strings.To_Unbounded_String (Transfer.Message);
      elsif Transfer.State = Transfer.Done then
         SDL3.Pictures.Decode (Picture, Candidate (Item), Dark);
         Painting_Colours.Sample (Picture, Sample_Hue, Sample_Strength);
         if Rename (Interfaces.C.To_C (Candidate (Item)), Interfaces.C.To_C (File_Name (Item))) /= 0 then
            raise Ada.Directories.Use_Error with "could not replace the cached image";
         end if;
         Item.Colour_Hue := Sample_Hue;
         Item.Colour_Strength := Sample_Strength;
         Item.Current := Done;
         Item.Serial := @ + 1;
      end if;
   exception
      when Problem : others =>
         Item.Current := Failed;
         Item.Reason := Strings.To_Unbounded_String (Ada.Exceptions.Exception_Message (Problem));
   end Poll;
end Gallery_Pictures;
