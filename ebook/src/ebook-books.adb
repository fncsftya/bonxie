with Ada.Calendar;
with Ada.Exceptions;
with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Vectors;
with Ada.Directories;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded;
with Ada.Unchecked_Deallocation;
with CoreText.Fonts;
with CoreText.Lines;
with Ebook.Epub;
with Ebook.Markup;
with Interfaces;

package body Ebook.Books is

   use type Ada.Calendar.Time;
   use type Ada.Directories.File_Size;
   use type Markup.Kinds;

   ---------------------------------------------------------------------
   --  Faces
   ---------------------------------------------------------------------

   type Size_Classes is (Body_Size, Heading_1, Heading_2, Heading_3);

   Point_Size : constant array (Size_Classes) of Float := [12.0, 22.0, 18.0, 15.0];

   Fixed_Scale : constant := 0.88;
   --  A fixed face is a little smaller than a proportional one of the same size.

   Line_Factor : constant := 1.4;
   --  A line is this many times the font's size from the one above.

   subtype Style_Id is Positive range 1 .. 8 * (Size_Classes'Pos (Size_Classes'Last) + 1);

   function Style_Of (Bold, Italic, Fixed : Boolean; Class : Size_Classes) return Style_Id is
     (1 + Boolean'Pos (Bold) + 2 * Boolean'Pos (Italic) + 4 * Boolean'Pos (Fixed)
      + 8 * Size_Classes'Pos (Class));

   function Is_Bold (Style : Style_Id) return Boolean is ((Style - 1) mod 2 = 1);
   function Is_Italic (Style : Style_Id) return Boolean is (((Style - 1) / 2) mod 2 = 1);
   function Is_Fixed (Style : Style_Id) return Boolean is (((Style - 1) / 4) mod 2 = 1);
   function Class_Of (Style : Style_Id) return Size_Classes is
     (Size_Classes'Val ((Style - 1) / 8));

   function Size_Of (Style : Style_Id) return Float is
     (Point_Size (Class_Of (Style)) * (if Is_Fixed (Style) then Fixed_Scale else 1.0));

   function Face_Name (Style : Style_Id) return String is
     (if Is_Fixed (Style) then
        (if Is_Bold (Style) and then Is_Italic (Style) then "Menlo-BoldItalic"
         elsif Is_Bold (Style) then "Menlo-Bold"
         elsif Is_Italic (Style) then "Menlo-Italic"
         else "Menlo-Regular")
      else
        (if Is_Bold (Style) and then Is_Italic (Style) then "Georgia-BoldItalic"
         elsif Is_Bold (Style) then "Georgia-Bold"
         elsif Is_Italic (Style) then "Georgia-Italic"
         else "Georgia"));

   Fonts : array (Style_Id) of CoreText.Fonts.Font;

   procedure Ensure_Font (Style : Style_Id) is
   begin
      if not CoreText.Fonts.Is_Open (Fonts (Style)) then
         CoreText.Fonts.Open (Fonts (Style), Face_Name (Style), Size_Of (Style));
      end if;
   end Ensure_Font;

   Scratch : CoreText.Lines.Line;

   package Width_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (String, Float, Ada.Strings.Hash, "=");

   Widths : Width_Maps.Map;
   --  How wide each word is in each style: the style, then the word.

   function Measure (Style : Style_Id; Text : String) return Float is
      Key   : constant String := Character'Val (Style) & Text;
      Place : constant Width_Maps.Cursor := Widths.Find (Key);
   begin
      if Width_Maps.Has_Element (Place) then
         return Width_Maps.Element (Place);
      end if;
      Ensure_Font (Style);
      CoreText.Lines.Make (Scratch, Fonts (Style), Text);
      declare
         Wide : constant Float := CoreText.Lines.Width (Scratch);
      begin
         if Natural (Widths.Length) > 200_000 then
            Widths.Clear;
         end if;
         Widths.Insert (Key, Wide);
         return Wide;
      end;
   end Measure;

   ---------------------------------------------------------------------
   --  The set book
   ---------------------------------------------------------------------

   type Data_Access is access String;
   procedure Release is new Ada.Unchecked_Deallocation (String, Data_Access);

   type Placed_Word is record
      First, Last : Natural;   --  in Store
      Style       : Style_Id;
      X, Y        : Float;     --  Y is the baseline; both in points
      Width       : Float;
      Line        : Positive;  --  on its page
   end record;

   package Word_Vectors is new Ada.Containers.Vectors (Positive, Placed_Word);
   package Index_Vectors is new Ada.Containers.Vectors (Positive, Positive);

   Margin_Left   : constant := 48.0;
   Margin_Right  : constant := 48.0;
   Margin_Top    : constant := 54.0;
   Margin_Bottom : constant := 54.0;
   Right_Edge    : constant Float := Sheet_Width - Margin_Right;
   Bottom_Edge   : constant Float := Sheet_Height - Margin_Bottom;

   Max_Words_In_Line : constant := 1_024;

   type Pending_Word is record
      First, Last : Natural;
      Style       : Style_Id;
      Width       : Float;
      Spaced      : Boolean;   --  a space comes before it
   end record;

   type Pending_Array is array (1 .. Max_Words_In_Line) of Pending_Word;

   type Kept_Book is record
      Name     : Ada.Strings.Unbounded.Unbounded_String;
      Size     : Ada.Directories.File_Size := 0;
      Time     : Ada.Calendar.Time := Ada.Calendar.Time_Of (1970, 1, 1);
      Loaded   : Boolean := False;
      Title    : Ada.Strings.Unbounded.Unbounded_String;
      Words    : Word_Vectors.Vector;
      Starts   : Index_Vectors.Vector;   --  the first word of each page
      Store    : Data_Access;
      Used     : Natural := 0;           --  of Store
   end record;

   Book : Kept_Book;

   --  The state of setting
   Pending       : Pending_Array;
   Pending_Count : Natural := 0;
   Indent        : Float := 0.0;      --  of the lines being set
   Cursor_Y      : Float := Margin_Top;
   Page_Fresh    : Boolean := True;   --  nothing is on the page yet
   Page_Wanted   : Boolean := True;   --  the next word starts a page
   Line_On_Page  : Natural := 0;
   Gap           : Float := 0.0;      --  to leave before the next line
   Keep_Next     : Boolean := False;  --  the lines being set are a heading

   procedure Append_Text (Text : String; First, Last : out Natural) is
   begin
      if Book.Store = null or else Book.Used + Text'Length > Book.Store'Length then
         declare
            Wanted : constant Natural :=
              Natural'Max (2 * (if Book.Store = null then 0 else Book.Store'Length),
                           Book.Used + Text'Length + 65_536);
            Grown  : constant Data_Access := new String (1 .. Wanted);
         begin
            if Book.Store /= null then
               Grown (1 .. Book.Used) := Book.Store (1 .. Book.Used);
               Release (Book.Store);
            end if;
            Book.Store := Grown;
         end;
      end if;
      First := Book.Used + 1;
      Last := Book.Used + Text'Length;
      Book.Store (First .. Last) := Text;
      Book.Used := Last;
   end Append_Text;

   procedure Start_Page is
   begin
      Cursor_Y := Margin_Top;
      Page_Fresh := True;
      Page_Wanted := True;
      Line_On_Page := 0;
      Gap := 0.0;
   end Start_Page;

   --  Put the pending words on the page, as a line.
   procedure Flush_Line is
      Tallest : Style_Id := Style_Id'First;
      Height  : Float := 0.0;
      Body_H  : constant Float := Point_Size (Body_Size) * Line_Factor;
      Spare   : Float;
      Across  : Float := Margin_Left + Indent;
      Baseline : Float;
   begin
      if Pending_Count = 0 then
         return;
      end if;
      for Each in 1 .. Pending_Count loop
         declare
            H : constant Float := Size_Of (Pending (Each).Style) * Line_Factor;
         begin
            if H > Height then
               Height := H;
               Tallest := Pending (Each).Style;
            end if;
         end;
      end loop;
      Spare := (if Page_Fresh then 0.0 else Gap);
      if not Page_Fresh
        and then Cursor_Y + Spare + Height + (if Keep_Next then 2.0 * Body_H else 0.0) > Bottom_Edge
      then
         Start_Page;
         Spare := 0.0;
      end if;
      Cursor_Y := Cursor_Y + Spare;
      Gap := 0.0;
      if Page_Wanted then
         Book.Starts.Append (Book.Words.Last_Index + 1);
         Page_Wanted := False;
      end if;
      Page_Fresh := False;
      Line_On_Page := Line_On_Page + 1;
      Ensure_Font (Tallest);
      Baseline :=
        Cursor_Y + (Height - (CoreText.Fonts.Ascent (Fonts (Tallest)) + CoreText.Fonts.Descent (Fonts (Tallest))))
        / 2.0 + CoreText.Fonts.Ascent (Fonts (Tallest));
      for Each in 1 .. Pending_Count loop
         declare
            Word : Pending_Word renames Pending (Each);
         begin
            if Each > 1 and then Word.Spaced then
               Across := Across + Measure (Word.Style, " ");
            end if;
            Book.Words.Append
              (Placed_Word'(First => Word.First, Last => Word.Last, Style => Word.Style, X => Across,
                Y => Baseline, Width => Word.Width, Line => Line_On_Page));
            Across := Across + Word.Width;
         end;
      end loop;
      Pending_Count := 0;
      Cursor_Y := Cursor_Y + Height;
   end Flush_Line;

   --  How far across the line the pending words reach.
   function Reach return Float is
      Across : Float := Margin_Left + Indent;
   begin
      for Each in 1 .. Pending_Count loop
         if Each > 1 and then Pending (Each).Spaced then
            Across := Across + Measure (Pending (Each).Style, " ");
         end if;
         Across := Across + Pending (Each).Width;
      end loop;
      return Across;
   end Reach;

   --  Add a word to the line, which is flushed first if it does not fit.
   procedure Add_Word (Style : Style_Id; Text : String; Spaced : Boolean) is
      Wide : constant Float := Measure (Style, Text);
      Room : constant Float := Right_Edge - (Margin_Left + Indent);
   begin
      if Text = "" then
         return;
      end if;
      if Wide > Room and then Text'Length > 1 then
         --  A word longer than a line: cut where it fills one.
         declare
            Cut : Natural := Natural'Max (1, Natural (Float (Text'Length) * Room / Wide) - 1);
         begin
            Cut := Natural'Min (Cut, Text'Length - 1);
            while Cut > 1 and then Character'Pos (Text (Text'First + Cut)) in 16#80# .. 16#BF# loop
               Cut := Cut - 1;
            end loop;
            Add_Word (Style, Text (Text'First .. Text'First + Cut - 1), Spaced);
            Flush_Line;
            Add_Word (Style, Text (Text'First + Cut .. Text'Last), False);
            return;
         end;
      end if;
      if Pending_Count > 0
        and then (Pending_Count = Max_Words_In_Line
                  or else Reach + (if Spaced then Measure (Style, " ") else 0.0) + Wide > Right_Edge)
      then
         Flush_Line;
      end if;
      declare
         First, Last : Natural;
      begin
         Append_Text (Text, First, Last);
         Pending_Count := Pending_Count + 1;
         Pending (Pending_Count) :=
           (First => First, Last => Last, Style => Style, Width => Wide,
            Spaced => Spaced and then Pending_Count > 1);
      end;
   end Add_Word;

   ---------------------------------------------------------------------
   --  A chapter
   ---------------------------------------------------------------------

   Bullet : constant String := [Character'Val (16#E2#), Character'Val (16#80#), Character'Val (16#A2#)];

   function Is_Space (C : Character) return Boolean is
     (C in ' ' | ASCII.HT | ASCII.LF | ASCII.CR | ASCII.FF);

   function Is_Skipped (Name : String) return Boolean is
     (Name in "head" | "style" | "script" | "title" | "svg" | "math" | "template" | "noscript");

   function Heading_Level (Name : String) return Natural is
     (if Name'Length = 2 and then Name (Name'First) = 'h' and then Name (Name'Last) in '1' .. '6'
      then Character'Pos (Name (Name'Last)) - Character'Pos ('0') else 0);

   procedure Set_Chapter (Source : String) is
      Position : Positive := Source'First;
      Token    : Markup.Token;
      Skip     : Natural := 0;
      Skipping : String (1 .. Markup.Max_Name) := [others => ' '];
      Skip_Len : Natural := 0;
      Bold, Italic, Fixed : Natural := 0;
      Heading  : Natural := 0;
      Quotes   : Natural := 0;
      Lists    : Natural := 0;
      Preformatted : Boolean := False;
      Space    : Boolean := False;   --  white space has come since the last word
      Numbers  : array (1 .. 16) of Natural := [others => 0];
      Ordered  : array (1 .. 16) of Boolean := [others => False];

      function Class return Size_Classes is
        (case Heading is
            when 1 => Heading_1,
            when 2 => Heading_2,
            when 3 => Heading_3,
            when others => Body_Size);

      function Style return Style_Id is
        (Style_Of (Bold > 0 or else Heading > 0, Italic > 0, Fixed > 0, Class));

      procedure Set_Indent is
      begin
         Indent := 24.0 * Float (Quotes) + 22.0 * Float (Lists);
      end Set_Indent;

      --  A new block: what is set so far ends, and the space between is at
      --  least Before points.
      procedure Break_Block (Before : Float) is
      begin
         Flush_Line;
         Gap := Float'Max (Gap, Before);
         Space := False;
      end Break_Block;

      procedure Break_Line is
      begin
         Flush_Line;
         Space := False;
      end Break_Line;

      procedure Words_Of (Text : String) is
         Start : Natural := Text'First;
      begin
         if Preformatted then
            for Index in Text'Range loop
               if Text (Index) = ASCII.LF or else Index = Text'Last then
                  declare
                     Stop : constant Natural := (if Text (Index) = ASCII.LF then Index - 1 else Index);
                     Line : constant String := Text (Start .. Stop);
                     Clean : String := Line;
                  begin
                     for C of Clean loop
                        if C in ASCII.CR | ASCII.HT then
                           C := ' ';
                        end if;
                     end loop;
                     if Clean'Length > 0 then
                        Add_Word (Style, Clean, False);
                     end if;
                     if Text (Index) = ASCII.LF then
                        Flush_Line;
                        --  A blank line in the text is a blank line on the page.
                        if Clean'Length = 0 then
                           Gap := Gap + Size_Of (Style) * Line_Factor;
                        end if;
                     end if;
                     Start := Index + 1;
                  end;
               end if;
            end loop;
            return;
         end if;
         Start := Text'First;
         while Start <= Text'Last loop
            if Is_Space (Text (Start)) then
               Space := True;
               Start := Start + 1;
            else
               declare
                  Stop : Natural := Start;
               begin
                  while Stop < Text'Last and then not Is_Space (Text (Stop + 1)) loop
                     Stop := Stop + 1;
                  end loop;
                  Add_Word (Style, Text (Start .. Stop), Space);
                  Space := False;
                  Start := Stop + 1;
               end;
            end if;
         end loop;
      end Words_Of;

      procedure Open_Tag (Name : String) is
      begin
         if Name in "b" | "strong" | "th" then
            Bold := Bold + 1;
         elsif Name in "i" | "em" | "cite" | "dfn" | "var" then
            Italic := Italic + 1;
         elsif Name in "code" | "tt" | "kbd" | "samp" then
            Fixed := Fixed + 1;
         end if;
         if Heading_Level (Name) > 0 then
            Break_Block (Point_Size (Body_Size) * (if Heading_Level (Name) <= 2 then 1.6 else 1.1));
            Heading := (if Heading_Level (Name) <= 3 then Heading_Level (Name) else 0);
            if Heading_Level (Name) > 3 then
               Bold := Bold + 1;
            end if;
            Keep_Next := True;
         elsif Name = "p" or else Name = "div" or else Name = "section" or else Name = "article"
           or else Name = "figure" or else Name = "figcaption" or else Name = "dt" or else Name = "dd"
           or else Name = "table" or else Name = "caption" or else Name = "aside" or else Name = "header"
           or else Name = "footer" or else Name = "nav" or else Name = "main" or else Name = "address"
         then
            Break_Block (0.0);
         elsif Name = "blockquote" then
            Break_Block (Point_Size (Body_Size) * 0.5);
            Quotes := Quotes + 1;
            Set_Indent;
         elsif Name = "ul" or else Name = "ol" then
            Break_Block (Point_Size (Body_Size) * 0.3);
            Lists := Lists + 1;
            if Lists <= Numbers'Last then
               Numbers (Lists) := 0;
               Ordered (Lists) := Name = "ol";
            end if;
            Set_Indent;
         elsif Name = "li" then
            Break_Block (Point_Size (Body_Size) * 0.2);
            if Lists = 0 then
               Lists := 1;   --  an item with no list round it
               Set_Indent;
            end if;
            if Lists <= Numbers'Last then
               Numbers (Lists) := Numbers (Lists) + 1;
               declare
                  Count : constant String := Natural'Image (Numbers (Lists));
               begin
                  Add_Word
                    (Style_Of (False, False, False, Body_Size),
                     (if Ordered (Lists) then Count (Count'First + 1 .. Count'Last) & "." else Bullet),
                     False);
               end;
            end if;
            Space := True;
         elsif Name = "pre" then
            Break_Block (Point_Size (Body_Size) * 0.6);
            Preformatted := True;
            Fixed := Fixed + 1;
         elsif Name = "tr" then
            Break_Block (0.0);
         elsif Name = "td" then
            Space := True;
         elsif Name = "br" then
            Break_Line;
         elsif Name = "hr" then
            Break_Block (Point_Size (Body_Size) * 0.8);
            Gap := Gap + Point_Size (Body_Size) * 0.8;
         end if;
      end Open_Tag;

      procedure Close_Tag (Name : String) is
      begin
         if Name in "b" | "strong" | "th" then
            Bold := Natural'Max (0, Bold - 1);
         elsif Name in "i" | "em" | "cite" | "dfn" | "var" then
            Italic := Natural'Max (0, Italic - 1);
         elsif Name in "code" | "tt" | "kbd" | "samp" then
            Fixed := Natural'Max (0, Fixed - 1);
         end if;
         if Heading_Level (Name) > 0 then
            Break_Block (0.0);
            Keep_Next := False;
            Gap := Gap + Point_Size (Body_Size) * 0.6;
            if Heading_Level (Name) > 3 then
               Bold := Natural'Max (0, Bold - 1);
            end if;
            Heading := 0;
         elsif Name = "p" or else Name = "div" or else Name = "section" or else Name = "figure"
           or else Name = "figcaption" or else Name = "dd" or else Name = "dt" or else Name = "table"
           or else Name = "article" or else Name = "caption" or else Name = "tr"
         then
            Break_Block (if Name = "p" then Point_Size (Body_Size) * 0.6 else 0.0);
         elsif Name = "blockquote" then
            Break_Block (Point_Size (Body_Size) * 0.5);
            Quotes := Natural'Max (0, Quotes - 1);
            Set_Indent;
         elsif Name = "ul" or else Name = "ol" then
            Break_Block (Point_Size (Body_Size) * 0.4);
            Lists := Natural'Max (0, Lists - 1);
            Set_Indent;
         elsif Name = "li" then
            Break_Block (Point_Size (Body_Size) * 0.2);
         elsif Name = "pre" then
            Break_Block (Point_Size (Body_Size) * 0.6);
            Preformatted := False;
            Fixed := Natural'Max (0, Fixed - 1);
         end if;
      end Close_Tag;

   begin
      Pending_Count := 0;
      Indent := 0.0;
      Keep_Next := False;
      loop
         Markup.Next (Source, Position, Token);
         exit when Token.Kind = Markup.Finished;
         if Skip > 0 then
            --  Inside something that is not shown: only its end matters.
            if Token.Kind = Markup.Start_Tag and then not Token.Self_Closing
              and then Markup.Tag (Token) = Skipping (1 .. Skip_Len)
            then
               Skip := Skip + 1;
            elsif Token.Kind = Markup.End_Tag and then Markup.Tag (Token) = Skipping (1 .. Skip_Len) then
               Skip := Skip - 1;
            end if;
         else
            case Token.Kind is
               when Markup.Text =>
                  Words_Of (Markup.Decode (Source (Token.First .. Token.Last)));
               when Markup.Start_Tag =>
                  if Is_Skipped (Markup.Tag (Token)) then
                     if not Token.Self_Closing then
                        Skip := 1;
                        Skip_Len := Token.Name_Length;
                        Skipping (1 .. Skip_Len) := Markup.Tag (Token);
                     end if;
                  elsif Markup.Tag (Token) = "img" then
                     declare
                        Alt : constant String := Markup.Attribute (Source, Token, "alt");
                     begin
                        if Alt /= "" then
                           Words_Of ("[" & Alt & "]");
                        end if;
                     end;
                  else
                     Open_Tag (Markup.Tag (Token));
                     if Token.Self_Closing then
                        Close_Tag (Markup.Tag (Token));
                     end if;
                  end if;
               when Markup.End_Tag =>
                  Close_Tag (Markup.Tag (Token));
               when Markup.Finished =>
                  null;
            end case;
         end if;
      end loop;
      Flush_Line;
      Gap := 0.0;
      Keep_Next := False;
   end Set_Chapter;

   ---------------------------------------------------------------------
   --  Setting a book
   ---------------------------------------------------------------------

   protected Gate is
      entry Seize;
      procedure Release;
   private
      Busy : Boolean := False;
   end Gate;

   protected body Gate is
      entry Seize when not Busy is
      begin
         Busy := True;
      end Seize;

      procedure Release is
      begin
         Busy := False;
      end Release;
   end Gate;

   procedure Forget is
   begin
      Book.Words.Clear;
      Book.Starts.Clear;
      Release (Book.Store);
      Book.Used := 0;
      Book.Loaded := False;
      Book.Name := Ada.Strings.Unbounded.Null_Unbounded_String;
      Book.Title := Ada.Strings.Unbounded.Null_Unbounded_String;
   end Forget;

   procedure Say (Text : String; Message : out String; Last : out Natural) is
      Used : constant Natural := Natural'Min (Text'Length, Message'Length);
   begin
      Message (Message'First .. Message'First + Used - 1) := Text (Text'First .. Text'First + Used - 1);
      Last := Message'First + Used - 1;
   end Say;

   --  Set the book, if the one kept is not it. Loaded says whether it is.
   procedure Load (File_Name : String; Message : out String; Last : out Natural) is
      use Ada.Strings.Unbounded;
      Size : Ada.Directories.File_Size := 0;
      Time : Ada.Calendar.Time := Book.Time;
   begin
      Last := Message'First - 1;
      if Ada.Directories.Exists (File_Name) then
         Size := Ada.Directories.Size (File_Name);
         Time := Ada.Directories.Modification_Time (File_Name);
      end if;
      if Book.Loaded and then To_String (Book.Name) = File_Name and then Book.Size = Size
        and then Book.Time = Time
      then
         return;
      end if;
      Forget;
      declare
         Source : Epub.Book;
         Ok     : Boolean;
      begin
         Epub.Open (Source, File_Name, Ok, Message, Last);
         if not Ok then
            return;
         end if;
         Start_Page;
         Page_Wanted := True;
         for Number in 1 .. Epub.Chapter_Count (Source) loop
            Set_Chapter (Epub.Chapter (Source, Number));
            --  A chapter begins a page.
            if not Page_Fresh then
               Start_Page;
            end if;
         end loop;
         if Book.Starts.Is_Empty then
            Say ("the e-book has no text", Message, Last);
            Forget;
            Epub.Close (Source);
            return;
         end if;
         Book.Title := To_Unbounded_String (Epub.Title (Source));
         Epub.Close (Source);
      end;
      Book.Name := To_Unbounded_String (File_Name);
      Book.Size := Size;
      Book.Time := Time;
      Book.Loaded := True;
   end Load;

   procedure Count_Pages
     (File_Name  : String;
      Pages      : out Natural;
      Title      : out String;
      Title_Last : out Natural;
      Message    : out String;
      Last       : out Natural) is
   begin
      Pages := 0;
      Title_Last := Title'First - 1;
      Gate.Seize;
      begin
         Load (File_Name, Message, Last);
         if Book.Loaded then
            Pages := Natural (Book.Starts.Length);
            declare
               Name : constant String := Ada.Strings.Unbounded.To_String (Book.Title);
               Used : constant Natural := Natural'Min (Name'Length, Title'Length);
            begin
               Title (Title'First .. Title'First + Used - 1) := Name (Name'First .. Name'First + Used - 1);
               Title_Last := Title'First + Used - 1;
            end;
         end if;
      exception
         when Problem : others =>
            Gate.Release;
            Pages := 0;
            Say ("the e-book could not be read " & Ada.Exceptions.Exception_Information (Problem),
                 Message, Last);
            return;
      end;
      Gate.Release;
   end Count_Pages;

   ---------------------------------------------------------------------
   --  A page
   ---------------------------------------------------------------------

   --  The code points of UTF-8 text, and where each is in UTF-16 units.
   procedure Next_Code
     (Text : String; At_Index : in out Positive; Code : out Interfaces.Unsigned_32; Units : out Positive)
   is
      use Interfaces;
      Lead : constant Unsigned_32 := Unsigned_32 (Character'Pos (Text (At_Index)));
      More : Natural;

      function Tail (Offset : Natural) return Unsigned_32 is
        (Unsigned_32 (Character'Pos (Text (At_Index + Offset))) and 16#3F#);
   begin
      if Lead < 16#80# then
         More := 0;
         Code := Lead;
      elsif Lead in 16#C0# .. 16#DF# then
         More := 1;
         Code := Lead and 16#1F#;
      elsif Lead in 16#E0# .. 16#EF# then
         More := 2;
         Code := Lead and 16#0F#;
      elsif Lead in 16#F0# .. 16#F7# then
         More := 3;
         Code := Lead and 16#07#;
      else
         More := 0;
         Code := Lead;
      end if;
      if At_Index + More > Text'Last then
         More := 0;
         Code := Lead;
      end if;
      for Offset in 1 .. More loop
         Code := Shift_Left (Code, 6) or Tail (Offset);
      end loop;
      At_Index := At_Index + More + 1;
      Units := (if Code > 16#FFFF# then 2 else 1);
   end Next_Code;

   procedure Make_Page
     (File_Name : String;
      Number    : Positive;
      Content   : out Pomarine.Pages.Page_Access;
      Found     : in out Pomarine.Words.Result;
      Message   : out String;
      Last      : out Natural)
   is
   begin
      Content := null;
      Last := Message'First - 1;
      Gate.Seize;
      begin
         Load (File_Name, Message, Last);
         if not Book.Loaded then
            Gate.Release;
            return;
         end if;
         if Number > Natural (Book.Starts.Length) then
            Say ("the e-book has fewer pages", Message, Last);
            Gate.Release;
            return;
         end if;
         declare
            First : constant Positive := Book.Starts (Number);
            Stop  : constant Natural :=
              (if Number < Natural (Book.Starts.Length) then Book.Starts (Number + 1) - 1
               else Book.Words.Last_Index);
            Letters : Natural := 0;
            Runs    : Natural := 0;
            Faces   : Natural := 0;
            Slot    : array (Style_Id) of Natural := [others => 0];
            Previous : Natural := 0;
         begin
            for Index in First .. Stop loop
               declare
                  Word : Placed_Word renames Book.Words (Index);
                  At_Index : Positive := Word.First;
                  Code : Interfaces.Unsigned_32;
                  Units : Positive;
               begin
                  while At_Index <= Word.Last loop
                     Next_Code (Book.Store.all (Word.First .. Word.Last), At_Index, Code, Units);
                     Letters := Letters + 1;
                  end loop;
                  if Slot (Word.Style) = 0 then
                     Faces := Faces + 1;
                     Slot (Word.Style) := Faces;
                  end if;
                  if Slot (Word.Style) /= Previous then
                     Runs := Runs + 1;
                     Previous := Slot (Word.Style);
                  end if;
               end;
            end loop;
            Content := new Pomarine.Pages.Page
              (Operations => Runs, Points => 0, Characters => Letters, Faces => Faces,
               Clips => 0, Images => 0, Bytes => 0);
            Content.Width := Sheet_Width;
            Content.Height := Sheet_Height;
            Found.Count := 0;
            Found.Length := 0;
            Found.Truncated := False;
            for Style in Style_Id loop
               if Slot (Style) /= 0 then
                  declare
                     Name : constant String := Face_Name (Style);
                  begin
                     Content.Fonts (Slot (Style)).Name (1 .. Name'Length) := Name;
                     Content.Fonts (Slot (Style)).Last := Name'Length;
                  end;
               end if;
            end loop;
            declare
               Next_Letter : Natural := 0;
               Next_Run    : Natural := 0;
               Run_Slot    : Natural := 0;
            begin
               for Index in First .. Stop loop
                  declare
                     Word  : Placed_Word renames Book.Words (Index);
                     Text  : constant String := Book.Store.all (Word.First .. Word.Last);
                     Points : constant Float := Size_Of (Word.Style);
                     Top   : Float;
                     Tall  : Float;
                     At_Index : Positive := Text'First;
                     Unit  : Natural := 0;
                     Code  : Interfaces.Unsigned_32;
                     Units : Positive;
                  begin
                     Ensure_Font (Word.Style);
                     CoreText.Lines.Make (Scratch, Fonts (Word.Style), Text);
                     if Slot (Word.Style) /= Run_Slot then
                        Next_Run := Next_Run + 1;
                        Run_Slot := Slot (Word.Style);
                        Content.Op (Next_Run) :=
                          (Kind => Pomarine.Pages.Text, Clip => 0, First => Next_Letter + 1, Count => 0,
                           Color => (0, 0, 0, 255), Width => 0.0, Face => Run_Slot,
                           Box => (Word.X, Word.Y - Points, Word.X + Word.Width, Word.Y + Points * 0.3));
                     end if;
                     Top := Word.Y - CoreText.Fonts.Ascent (Fonts (Word.Style));
                     Tall := CoreText.Fonts.Ascent (Fonts (Word.Style)) + CoreText.Fonts.Descent (Fonts (Word.Style));
                     while At_Index <= Text'Last loop
                        declare
                           Before : constant Natural := Unit;
                        begin
                           Next_Code (Text, At_Index, Code, Units);
                           Unit := Unit + Units;
                           Next_Letter := Next_Letter + 1;
                           Content.Letters (Next_Letter) :=
                             (Code => Code,
                              X => Word.X + CoreText.Lines.Offset_For_Index (Scratch, Before),
                              Y => Word.Y, Size => Points);
                        end;
                     end loop;
                     declare
                        Op : Pomarine.Pages.Operation renames Content.Op (Next_Run);
                     begin
                        Op.Count := Next_Letter - Op.First + 1;
                        Op.Box.Left := Float'Min (Op.Box.Left, Word.X);
                        Op.Box.Right := Float'Max (Op.Box.Right, Word.X + Word.Width);
                        Op.Box.Top := Float'Min (Op.Box.Top, Top);
                        Op.Box.Bottom := Float'Max (Op.Box.Bottom, Top + Tall);
                     end;
                     begin
                        Pomarine.Words.Reserve (Found, Found.Count + 1, Found.Length + Text'Length);
                        Found.Count := Found.Count + 1;
                        Found.Text (Found.Length + 1 .. Found.Length + Text'Length) := Text;
                        Found.Words (Found.Count) :=
                          (Line => Word.Line,
                           First => Found.Length + 1, Last => Found.Length + Text'Length,
                           Left => Word.X / Sheet_Width, Top => Top / Sheet_Height,
                           Width => Word.Width / Sheet_Width, Height => Tall / Sheet_Height);
                        Found.Length := Found.Length + Text'Length;
                     end;
                  end;
               end loop;
            end;
         end;
      exception
         when others =>
            Gate.Release;
            Pomarine.Pages.Free (Content);
            Say ("the page could not be made", Message, Last);
            return;
      end;
      Gate.Release;
   end Make_Page;

end Ebook.Books;
