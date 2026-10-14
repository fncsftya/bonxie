with Ada.IO_Exceptions;
with Ada.Streams.Stream_IO;
with Interfaces;
with Interfaces.C;
with Interfaces.C.Strings;
with SDL3.Errors;

package body SDL3.Pictures is

   use type Thin.Surface_Access;
   use type Interfaces.Unsigned_32;

   Signature : constant array (1 .. 8) of Interfaces.Unsigned_8 :=
     [137, 80, 78, 71, 13, 10, 26, 10];
   --  Where a PNG file begins; then the IHDR chunk, whose first fields
   --  are the width and height, four bytes each, most significant first.

   procedure Size (File_Name : String; Wide, High : out Natural) is
      use Ada.Streams;
      File   : Stream_IO.File_Type;
      Header : Stream_Element_Array (1 .. 24);
      Last   : Stream_Element_Offset;

      function Number (First : Stream_Element_Offset)
         return Interfaces.Unsigned_32
      is (Interfaces.Shift_Left (Interfaces.Unsigned_32 (Header (First)), 24)
          or Interfaces.Shift_Left
               (Interfaces.Unsigned_32 (Header (First + 1)), 16)
          or Interfaces.Shift_Left
               (Interfaces.Unsigned_32 (Header (First + 2)), 8)
          or Interfaces.Unsigned_32 (Header (First + 3)));
   begin
      Wide := 0;
      High := 0;
      Stream_IO.Open (File, Stream_IO.In_File, File_Name);
      Stream_IO.Read (File, Header, Last);
      Stream_IO.Close (File);
      if Last = Header'Last
        and then (for all I in Signature'Range =>
                    Header (Stream_Element_Offset (I))
                    = Stream_Element (Signature (I)))
        and then Header (13 .. 16) = [73, 72, 68, 82]  --  "IHDR"
        and then Number (17) in 1 .. 65_536
        and then Number (21) in 1 .. 65_536
      then
         Wide := Natural (Number (17));
         High := Natural (Number (21));
      end if;
   exception
      when Ada.IO_Exceptions.Name_Error | Ada.IO_Exceptions.Use_Error
         | Ada.IO_Exceptions.End_Error =>
         if Stream_IO.Is_Open (File) then
            Stream_IO.Close (File);
         end if;
         Wide := 0;
         High := 0;
   end Size;

   function Sampled_Dark (Surface : Thin.Surface_Access) return Boolean;
   --  Whether the RGBA32 surface is darker than not, by a sample of about
   --  64 x 64 of its pixels.

   function Sampled_Dark (Surface : Thin.Surface_Access) return Boolean is
      type Source_Bytes is array (Natural) of Interfaces.Unsigned_8;
      Source : Source_Bytes
        with Import, Address => Surface.Pixels;
      Columns : constant Positive := Positive (Surface.W);
      Rows    : constant Positive := Positive (Surface.H);
      Step_X  : constant Positive := Positive'Max (1, Columns / 64);
      Step_Y  : constant Positive := Positive'Max (1, Rows / 64);
      Total   : Natural := 0;
      Count   : Natural := 0;
   begin
      for Y in 0 .. (Rows - 1) / Step_Y loop
         for X in 0 .. (Columns - 1) / Step_X loop
            declare
               At_Pixel : constant Natural :=
                 Y * Step_Y * Natural (Surface.Pitch) + 4 * X * Step_X;
            begin
               Total := Total + Natural (Source (At_Pixel))
                        + Natural (Source (At_Pixel + 1))
                        + Natural (Source (At_Pixel + 2));
               Count := Count + 3;
            end;
         end loop;
      end loop;
      return Total / Count < 128;
   end Sampled_Dark;

   procedure Decode
     (Item : in out Decoded; File_Name : String; Dark : out Boolean)
   is
      use Interfaces.C.Strings;
      Name   : chars_ptr := New_String (File_Name);
      Loaded : constant Thin.Surface_Access := Thin.Load_PNG (Name);
      Plain  : Thin.Surface_Access;
   begin
      Free (Name);
      Release (Item);
      if Loaded = null then
         Errors.Raise_Last_Error ("SDL_LoadPNG " & File_Name);
      end if;
      Plain :=
        (if Loaded.Format = Thin.Pixel_Format_RGBA32 then Loaded
         else Thin.Convert_Surface (Loaded.all'Address,
                                    Thin.Pixel_Format_RGBA32));
      if Plain /= Loaded then
         Thin.Destroy_Surface (Loaded.all'Address);
      end if;
      if Plain = null then
         Errors.Raise_Last_Error ("SDL_ConvertSurface");
      end if;
      Item.Surface := Plain;
      Dark := Sampled_Dark (Plain);
   end Decode;

   function Is_Empty (Item : Decoded) return Boolean is
     (Item.Surface = null);

   function Width (Item : Decoded) return Positive is
     (Positive (Item.Surface.W));

   function Height (Item : Decoded) return Positive is
     (Positive (Item.Surface.H));

   function Pixels (Item : Decoded) return System.Address is
     (Item.Surface.Pixels);

   function Pitch (Item : Decoded) return Positive is
     (Positive (Item.Surface.Pitch));

   procedure Release (Item : in out Decoded) is
   begin
      if Item.Surface /= null then
         Thin.Destroy_Surface (Item.Surface.all'Address);
         Item.Surface := null;
      end if;
   end Release;

   overriding procedure Finalize (Item : in out Decoded) is
   begin
      Release (Item);
   end Finalize;

end SDL3.Pictures;
