with Ada.Characters.Handling;
with Ada.Directories;
with Ada.IO_Exceptions;
with Ada.Streams.Stream_IO;
with Ada.Unchecked_Deallocation;
with Ebook.Inflate;

package body Ebook.Zip is

   use type Ada.Directories.File_Kind;
   use type Ada.Directories.File_Size;

   use Ada.Strings.Unbounded;

   procedure Release is new Ada.Unchecked_Deallocation (String, Data_Access);

   Max_Archive : constant := 512 * 1024 * 1024;
   Max_File    : constant := 256 * 1024 * 1024;

   function Is_Open (Item : Archive) return Boolean
   is (Item.Data /= null);

   procedure Say (Text : String; Message : out String; Last : out Natural) is
   begin
      Message (Message'First .. Message'First + Text'Length - 1) := Text;
      Last := Message'First + Text'Length - 1;
   end Say;

   procedure Close (Item : in out Archive) is
   begin
      Release (Item.Data);
      Item.Entries.Clear;
   end Close;

   function Lower (Text : String) return String
   is (Ada.Characters.Handling.To_Lower (Text));

   procedure Open (Item : in out Archive; Path : String; Ok : out Boolean; Message : out String; Last : out Natural) is
      use Ada.Streams;
      File : Stream_IO.File_Type;
   begin
      Close (Item);
      Ok := False;
      Last := Message'First - 1;
      if not Ada.Directories.Exists (Path) or else Ada.Directories.Kind (Path) /= Ada.Directories.Ordinary_File then
         Say ("the file cannot be read", Message, Last);
         return;
      end if;
      declare
         Size : constant Ada.Directories.File_Size := Ada.Directories.Size (Path);
      begin
         if Size < 22 or else Size > Max_Archive then
            Say ("the file is not an e-book", Message, Last);
            return;
         end if;
         Stream_IO.Open (File, Stream_IO.In_File, Path);
         Item.Data := new String (1 .. Natural (Size));
         declare
            Bytes : Stream_Element_Array (1 .. Stream_Element_Offset (Size))
            with Import, Address => Item.Data.all'Address;
            Done  : Stream_Element_Offset;
         begin
            Stream_IO.Read (File, Bytes, Done);
            Stream_IO.Close (File);
            if Done /= Bytes'Last then
               Say ("the file cannot be read", Message, Last);
               Close (Item);
               return;
            end if;
         end;
      exception
         when
           Ada.IO_Exceptions.Name_Error
           | Ada.IO_Exceptions.Use_Error
           | Ada.IO_Exceptions.Device_Error
           | Ada.IO_Exceptions.End_Error
         =>
            if Stream_IO.Is_Open (File) then
               Stream_IO.Close (File);
            end if;
            Close (Item);
            Say ("the file cannot be read", Message, Last);
            return;
      end;

      declare
         Data : String renames Item.Data.all;

         function U16 (At_Index : Natural) return Natural
         is (Character'Pos (Data (At_Index + 1)) + 256 * Character'Pos (Data (At_Index + 2)));
         --  At_Index counts from 0, as the format does.

         function U32 (At_Index : Natural) return Natural
         is (U16 (At_Index) + 65_536 * U16 (At_Index + 2));

         End_At : Integer := -1;
         Count  : Natural;
         Cursor : Natural;
      begin
         --  The end record is the last 22 bytes, or before a comment.
         for Start in reverse Natural'Max (0, Data'Length - 22 - 65_535) .. Data'Length - 22 loop
            if U32 (Start) = 16#06054B50# then
               End_At := Start;
               exit;
            end if;
         end loop;
         if End_At < 0 then
            Close (Item);
            Say ("the file is not an e-book (not a zip)", Message, Last);
            return;
         end if;
         Count := U16 (End_At + 10);
         Cursor := U32 (End_At + 16);
         for Each in 1 .. Count loop
            if Cursor + 46 > Data'Length or else U32 (Cursor) /= 16#02014B50# then
               Close (Item);
               Say ("the zip is damaged", Message, Last);
               return;
            end if;
            declare
               Name_Length : constant Natural := U16 (Cursor + 28);
               Extra       : constant Natural := U16 (Cursor + 30);
               Comment     : constant Natural := U16 (Cursor + 32);
            begin
               if Cursor + 46 + Name_Length > Data'Length then
                  Close (Item);
                  Say ("the zip is damaged", Message, Last);
                  return;
               end if;
               Item.Entries.Append
                 (Entry_Record'
                    (Name   => To_Unbounded_String (Data (Cursor + 47 .. Cursor + 46 + Name_Length)),
                     Method => U16 (Cursor + 10),
                     Packed => U32 (Cursor + 20),
                     Size   => U32 (Cursor + 24),
                     Local  => U32 (Cursor + 42)));
               Cursor := Cursor + 46 + Name_Length + Extra + Comment;
            end;
         end loop;
      end;
      Ok := True;
   end Open;

   function Find (Item : Archive; Name : String) return Natural is
      Wanted : constant String := Lower (Name);
   begin
      for Index in 1 .. Natural (Item.Entries.Length) loop
         if Lower (To_String (Item.Entries (Index).Name)) = Wanted then
            return Index;
         end if;
      end loop;
      return 0;
   end Find;

   function Contains (Item : Archive; Name : String) return Boolean
   is (Find (Item, Name) /= 0);

   function Read (Item : Archive; Name : String) return String is
      Data  : String renames Item.Data.all;
      Found : constant Entry_Record := Item.Entries (Find (Item, Name));
      function U16 (At_Index : Natural) return Natural
      is (Character'Pos (Data (At_Index + 1)) + 256 * Character'Pos (Data (At_Index + 2)));
   begin
      if Found.Size > Max_File
        or else Found.Local + 30 > Data'Length
        or else U16 (Found.Local) /= 16#4B50#
        or else U16 (Found.Local + 2) /= 16#0403#
      then
         raise Damaged;
      end if;
      declare
         Start : constant Natural := Found.Local + 30 + U16 (Found.Local + 26) + U16 (Found.Local + 28);
      begin
         if Start + Found.Packed > Data'Length then
            raise Damaged;
         end if;
         case Found.Method is
            when 0      =>
               if Found.Packed /= Found.Size then
                  raise Damaged;
               end if;
               return Data (Start + 1 .. Start + Found.Size);

            when 8      =>
               return Result : String (1 .. Found.Size) do
                  declare
                     Ok : Boolean;
                  begin
                     Inflate.Run (Data (Start + 1 .. Start + Found.Packed), Found.Size, Result, Ok);
                     if not Ok then
                        raise Damaged;
                     end if;
                  end;
               end return;

            when others =>
               raise Damaged;
         end case;
      end;
   end Read;

end Ebook.Zip;
