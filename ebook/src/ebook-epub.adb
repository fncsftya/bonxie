with Ada.Containers.Vectors;
with Ada.Strings.Fixed;
with Ebook.Markup;

package body Ebook.Epub is

   use type Markup.Kinds;

   use Ada.Strings.Unbounded;

   function Is_Open (Item : Book) return Boolean is (Item.Open);

   function Title (Item : Book) return String is (To_String (Item.Name));

   function Chapter_Count (Item : Book) return Natural is (Natural (Item.Spine.Length));

   procedure Close (Item : in out Book) is
   begin
      Zip.Close (Item.Files);
      Item.Spine.Clear;
      Item.Name := Null_Unbounded_String;
      Item.Open := False;
   end Close;

   function Chapter (Item : Book; Number : Positive) return String is
      Path : constant String := Item.Spine (Number);
   begin
      if not Zip.Contains (Item.Files, Path) then
         return "";
      end if;
      return Zip.Read (Item.Files, Path);
   exception
      when Zip.Damaged =>
         return "";
   end Chapter;

   --  Where the folder part of a path ends: the last slash, or 0.
   function Folder_End (Path : String) return Natural is
   begin
      for I in reverse Path'Range loop
         if Path (I) = '/' then
            return I;
         end if;
      end loop;
      return Path'First - 1;
   end Folder_End;

   --  The text with %20 and the like turned into the bytes they stand for.
   function Unescape (Text : String) return String is
      Result : String (1 .. Text'Length);
      Used   : Natural := 0;
      I      : Natural := Text'First;

      function Hex (C : Character) return Integer is
        (case C is
            when '0' .. '9' => Character'Pos (C) - Character'Pos ('0'),
            when 'a' .. 'f' => Character'Pos (C) - Character'Pos ('a') + 10,
            when 'A' .. 'F' => Character'Pos (C) - Character'Pos ('A') + 10,
            when others => -1);
   begin
      while I <= Text'Last loop
         if Text (I) = '%' and then I + 2 <= Text'Last and then Hex (Text (I + 1)) >= 0
           and then Hex (Text (I + 2)) >= 0
         then
            Used := Used + 1;
            Result (Used) := Character'Val (16 * Hex (Text (I + 1)) + Hex (Text (I + 2)));
            I := I + 3;
         else
            Used := Used + 1;
            Result (Used) := Text (I);
            I := I + 1;
         end if;
      end loop;
      return Result (1 .. Used);
   end Unescape;

   --  Where a link from a file in Folder (with its slash, or "") leads, as
   --  a path in the zip: no fragment, no . or .. parts.
   function Resolve (Folder : String; Link : String) return String is
      Cut : Natural := Link'Last;
   begin
      for I in Link'Range loop
         if Link (I) in '#' | '?' then
            Cut := I - 1;
            exit;
         end if;
      end loop;
      declare
         Target : constant String := Unescape (Link (Link'First .. Cut));
         Joined : constant String :=
           (if Target'Length > 0 and then Target (Target'First) = '/'
            then Target (Target'First + 1 .. Target'Last)
            else Folder & Target);
         Result : String (1 .. Joined'Length + 1) := [others => '/'];
         Used   : Natural := 0;   --  Result (Used) is the slash after a part
         Start  : Natural := Joined'First;
      begin
         while Start <= Joined'Last + 1 loop
            declare
               Stop : Natural := Start;
            begin
               while Stop <= Joined'Last and then Joined (Stop) /= '/' loop
                  Stop := Stop + 1;
               end loop;
               declare
                  Part : constant String := Joined (Start .. Stop - 1);
               begin
                  if Part = ".." then
                     if Used > 0 then
                        Used := Used - 1;   --  the slash
                        while Used > 0 and then Result (Used) /= '/' loop
                           Used := Used - 1;
                        end loop;
                     end if;
                  elsif Part /= "." and then Part /= "" then
                     Result (Used + 1 .. Used + Part'Length) := Part;
                     Used := Used + Part'Length + 1;
                     Result (Used) := '/';
                  end if;
               end;
               Start := Stop + 1;
            end;
         end loop;
         return (if Used > 0 then Result (1 .. Used - 1) else "");
      end;
   end Resolve;

   procedure Say (Text : String; Message : out String; Last : out Natural) is
   begin
      Message (Message'First .. Message'First + Text'Length - 1) := Text;
      Last := Message'First + Text'Length - 1;
   end Say;

   --  The book's title and chapters, from its package file.
   procedure Read_Package (Item : in out Book; Package_File : String; Ok : out Boolean) is
      Content : constant String := Zip.Read (Item.Files, Package_File);
      Folder  : constant String := Package_File (Package_File'First .. Folder_End (Package_File));

      type Entry_Record is record
         Id, Target, Kind : Unbounded_String;
      end record;
      package Entry_Vectors is new Ada.Containers.Vectors (Positive, Entry_Record);
      Manifest : Entry_Vectors.Vector;
      Cursor   : Positive := Content'First;
      Tag      : Markup.Token;
      In_Title : Boolean := False;

      procedure Add (Id : String) is
      begin
         for Each of Manifest loop
            if To_String (Each.Id) = Id then
               declare
                  Kind : constant String := To_String (Each.Kind);
                  Path : constant String := Resolve (Folder, To_String (Each.Target));
               begin
                  if (Kind = "" or else Ada.Strings.Fixed.Index (Kind, "html") > 0
                      or else Ada.Strings.Fixed.Index (Kind, "xml") > 0)
                    and then Path /= "" and then Zip.Contains (Item.Files, Path)
                  then
                     Item.Spine.Append (Path);
                  end if;
               end;
               return;
            end if;
         end loop;
      end Add;
   begin
      loop
         Markup.Next (Content, Cursor, Tag);
         exit when Tag.Kind = Markup.Finished;
         case Tag.Kind is
            when Markup.Start_Tag =>
               if Markup.Tag (Tag) = "item" then
                  Manifest.Append
                    (Entry_Record'(To_Unbounded_String (Markup.Attribute (Content, Tag, "id")),
                      To_Unbounded_String (Markup.Attribute (Content, Tag, "href")),
                      To_Unbounded_String (Markup.Attribute (Content, Tag, "media-type"))));
               elsif Markup.Tag (Tag) = "itemref" then
                  --  The manifest comes before the spine.
                  if Markup.Attribute (Content, Tag, "linear") /= "no" then
                     Add (Markup.Attribute (Content, Tag, "idref"));
                  end if;
               elsif Markup.Tag (Tag) = "title" and then Item.Name = Null_Unbounded_String then
                  In_Title := not Tag.Self_Closing;
               end if;
            when Markup.Text =>
               if In_Title then
                  Item.Name := To_Unbounded_String
                    (Ada.Strings.Fixed.Trim
                       (Markup.Decode (Content (Tag.First .. Tag.Last)), Ada.Strings.Both));
                  In_Title := False;
               end if;
            when Markup.End_Tag =>
               In_Title := False;
            when Markup.Finished =>
               null;
         end case;
      end loop;
      Ok := not Item.Spine.Is_Empty;
   end Read_Package;

   procedure Open
     (Item : in out Book; Path : String; Ok : out Boolean; Message : out String; Last : out Natural) is
   begin
      Close (Item);
      Ok := False;
      Zip.Open (Item.Files, Path, Ok, Message, Last);
      if not Ok then
         return;
      end if;
      Ok := False;
      if not Zip.Contains (Item.Files, "META-INF/container.xml") then
         Say ("the file is not an e-book (no container)", Message, Last);
         Close (Item);
         return;
      end if;
      declare
         Container : constant String := Zip.Read (Item.Files, "META-INF/container.xml");
         Cursor    : Positive := Container'First;
         Tag       : Markup.Token;
         Root      : Unbounded_String;
      begin
         loop
            Markup.Next (Container, Cursor, Tag);
            exit when Tag.Kind = Markup.Finished;
            if Tag.Kind = Markup.Start_Tag and then Markup.Tag (Tag) = "rootfile" then
               Root := To_Unbounded_String (Markup.Attribute (Container, Tag, "full-path"));
               exit;
            end if;
         end loop;
         if Root = Null_Unbounded_String or else not Zip.Contains (Item.Files, To_String (Root)) then
            Say ("the e-book has no package file", Message, Last);
            Close (Item);
            return;
         end if;
         Read_Package (Item, To_String (Root), Ok);
         if not Ok then
            Say ("the e-book has no chapters", Message, Last);
            Close (Item);
         else
            Item.Open := True;
         end if;
      end;
   exception
      when Zip.Damaged =>
         Close (Item);
         Say ("the e-book is damaged", Message, Last);
   end Open;

end Ebook.Epub;
