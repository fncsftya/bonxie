with Ada.Directories;
with Ada.Numerics.Elementary_Functions;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ebook;
with Interfaces.C;
with Interfaces.C.Strings;
with GNAT.OS_Lib;
with Files;
with Items.Marks;
with Items.Words;
with Repository.Item;

package body Items.Sources is

   use type Interfaces.C.int;
   use type Interfaces.C.Strings.chars_ptr;

   function Image_To_PNG
     (From, To : Interfaces.C.Strings.chars_ptr) return Interfaces.C.int
     with Import, Convention => C, External_Name => "pn_image_to_png";

   function Percent (Zoom : Float) return String is
     (Ada.Strings.Fixed.Trim
        (Integer'Image (Integer (Float'Rounding (Zoom * 100.0))),
         Ada.Strings.Both) & "%");

   function To_Slider (Zoom : Float) return Float is
     (Float'Min
        (1.0,
         Float'Max
           (0.0,
            Ada.Numerics.Elementary_Functions.Log (Zoom / Min_Zoom)
            / Ada.Numerics.Elementary_Functions.Log (Max_Zoom / Min_Zoom))));

   function From_Slider (Along : Float) return Float is
     (Float'Min
        (Max_Zoom,
         Float'Max
           (Min_Zoom,
            Float'Rounding
              (100.0 * Min_Zoom
               * Ada.Numerics.Elementary_Functions."**"
                   (Max_Zoom / Min_Zoom, Along)) / 100.0)));

   procedure Set_Zoom
     (Store : in out Projects.Store; Key : Id; Zoom : Zoom_Level) is
   begin
      Repository.Item.Set_Zoom (Store, Key, Zoom);
   end Set_Zoom;

   procedure Set_Captured
     (Store : in out Projects.Store; Key : Id; At_Time : Projects.Seconds) is
   begin
      Repository.Item.Set_Captured (Store, Key, At_Time);
      Words.Clear_Words (Store, Key);
      Marks.Clear_Marks (Store, Key);
   end Set_Captured;

   procedure Set_Origin
     (Store : in out Projects.Store; Key : Id; Origin : Origins) is
   begin
      Repository.Item.Set_Origin (Store, Key, Origin);
   end Set_Origin;

   function Is_Text (Document : String) return Boolean is
     (Ebook.Is_Text ("." & Document));

   function Is_Vector (Document : String) return Boolean is
     (Ebook.Is_Document ("." & Document));

   function Read_Text (File_Name : String) return String is
      Raw  : constant String := Files.Read (File_Name);
      Last : constant Natural := Natural'Min (Raw'Length, Max_Text);
      Text : String (1 .. 3 * Last);
      Used : Natural := 0;
      BOM  : constant String := [Character'Val (16#EF#), Character'Val (16#BB#), Character'Val (16#BF#)];
      --  A byte order mark is skipped: CoreFoundation drops it.
      Next : Natural :=
        Raw'First + (if Raw'Length >= 3 and then Raw (Raw'First .. Raw'First + 2) = BOM then 3 else 0);
      Stop : constant Natural := Raw'First + Last - 1;

      procedure Put (C : Character) is
      begin
         Used := Used + 1;
         Text (Used) := C;
      end Put;

      function Continuation (At_Index : Natural) return Boolean is
        (At_Index <= Stop and then Character'Pos (Raw (At_Index)) in 16#80# .. 16#BF#);

      --  No overlong forms, surrogates or code points past U+10FFFF: the
      --  second byte is limited for these leads.
      function Well_Formed (At_Index, Lead, Size : Natural) return Boolean is
         Second : constant Natural :=
           (if Size > 1 then Character'Pos (Raw (At_Index + 1)) else 0);
      begin
         return (case Lead is
                    when 16#E0# => Second >= 16#A0#,
                    when 16#ED# => Second <= 16#9F#,
                    when 16#F0# => Second >= 16#90#,
                    when 16#F4# => Second <= 16#8F#,
                    when others => True);
      end Well_Formed;
   begin
      while Next <= Stop loop
         declare
            C    : constant Character := Raw (Next);
            Code : constant Natural := Character'Pos (C);
            Size : constant Natural :=
              (if Code < 16#80# then 1
               elsif Code in 16#C2# .. 16#DF# then 2
               elsif Code in 16#E0# .. 16#EF# then 3
               elsif Code in 16#F0# .. 16#F4# then 4 else 0);
            Whole : constant Boolean :=
              Size > 0 and then Next + Size - 1 <= Stop
              and then (for all Offset in 1 .. Size - 1 => Continuation (Next + Offset))
              and then Well_Formed (Next, Code, Size);
         begin
            if C = ASCII.CR then
               Put (ASCII.LF);
               Next := Next + (if Next < Stop and then Raw (Next + 1) = ASCII.LF then 2 else 1);
            elsif Code = 0 then
               Put (' ');
               Next := Next + 1;
            elsif Size = 1 then
               Put (C);
               Next := Next + 1;
            elsif Whole then
               for Offset in 0 .. Size - 1 loop
                  Put (Raw (Next + Offset));
               end loop;
               Next := Next + Size;
            else
               --  U+FFFD.
               Put (Character'Val (16#EF#));
               Put (Character'Val (16#BF#));
               Put (Character'Val (16#BD#));
               Next := Next + 1;
            end if;
         end;
      end loop;
      return Text (1 .. Used);
   end Read_Text;

   procedure Copy_File (From, To : String) is
      Part    : constant String := To & ".part";
      Success : Boolean;
   begin
      GNAT.OS_Lib.Copy_File
        (From, Part, Success, Mode => GNAT.OS_Lib.Overwrite, Preserve => GNAT.OS_Lib.None);
      if not Success then
         raise Ada.Directories.Use_Error with "could not copy " & From;
      end if;
      if Ada.Directories.Exists (To) then
         Ada.Directories.Delete_File (To);
      end if;
      Ada.Directories.Rename (Part, To);
   end Copy_File;

   procedure Convert_Image (From, To : String) is
      Input  : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.New_String (From);
      Output : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.New_String (To);
   begin
      if Image_To_PNG (Input, Output) = 0 then
         raise Ada.Directories.Use_Error with "could not convert image " & From;
      end if;
      Interfaces.C.Strings.Free (Input);
      Interfaces.C.Strings.Free (Output);
   exception
      when others =>
         if Input /= Interfaces.C.Strings.Null_Ptr then
            Interfaces.C.Strings.Free (Input);
         end if;
         if Output /= Interfaces.C.Strings.Null_Ptr then
            Interfaces.C.Strings.Free (Output);
         end if;
         raise;
   end Convert_Image;

   function Image_Folder
     (Store : Projects.Store; Project : Projects.Id) return String is
     (Projects.Folder (Store, Project) & "/sources");

   function Image_File
     (Store : Projects.Store; Project : Projects.Id; Key : Id) return String
   is
     (Image_Folder (Store, Project) & "/"
      & Ada.Strings.Fixed.Trim (Key'Image, Ada.Strings.Both) & ".png");

   procedure Set_Document
     (Store      : in out Projects.Store;
      Key        : Id;
      Document   : String;
      Page_Count : Natural) is
   begin
      Repository.Item.Set_Document (Store, Key, Document, Page_Count);
   end Set_Document;

   procedure Set_Page (Store : in out Projects.Store; Key : Id; Page : Positive) is
   begin
      Repository.Item.Set_Page (Store, Key, Page);
   end Set_Page;

   function Document_File
     (Store    : Projects.Store;
      Project  : Projects.Id;
      Key      : Id;
      Document : String) return String is
     (Image_Folder (Store, Project) & "/"
      & Ada.Strings.Fixed.Trim (Key'Image, Ada.Strings.Both) & "." & Document);

   function Shown_File
     (Store : Projects.Store; Project : Projects.Id; Of_Item : Info) return String is
     (if Of_Item.Origin /= Unchosen
         and then (Is_Text (Extensions.To_String (Of_Item.Document))
                   or else (Is_Vector (Extensions.To_String (Of_Item.Document))
                            and then Of_Item.Page > 0))
      then Document_File (Store, Project, Of_Item.Key, Extensions.To_String (Of_Item.Document))
      else Image_File (Store, Project, Of_Item.Key));

   procedure Delete_Files
     (Store : Projects.Store; Project : Projects.Id; Key : Id)
   is
      Folder : constant String := Image_Folder (Store, Project);
      Name   : constant String :=
        Ada.Strings.Fixed.Trim (Key'Image, Ada.Strings.Both);
   begin
      if not Ada.Directories.Exists (Folder) then
         return;
      end if;
      --  The picture, and a document with any ending (and what a
      --  download that was cut short left: see Downloads).
      loop
         declare
            Search : Ada.Directories.Search_Type;
            Found  : Ada.Directories.Directory_Entry_Type;
         begin
            Ada.Directories.Start_Search
              (Search, Folder, Name & ".*",
               [Ada.Directories.Ordinary_File => True, others => False]);
            if not Ada.Directories.More_Entries (Search) then
               Ada.Directories.End_Search (Search);
               return;
            end if;
            Ada.Directories.Get_Next_Entry (Search, Found);
            Ada.Directories.End_Search (Search);
            Ada.Directories.Delete_File (Ada.Directories.Full_Name (Found));
         end;
      end loop;
   end Delete_Files;

   procedure Make_Image_Folder
     (Store : Projects.Store; Project : Projects.Id) is
   begin
      Ada.Directories.Create_Path (Image_Folder (Store, Project));
   end Make_Image_Folder;

end Items.Sources;
