with Ada.Unchecked_Deallocation;

package body Typeset.Documents is

   use CoreText.Wrapping;

   procedure Free is new Ada.Unchecked_Deallocation (String, Text_Access);
   procedure Free is new Ada.Unchecked_Deallocation
     (Paragraph, Paragraph_Access);

   Sample_Doubling : constant := 8;
   --  The estimate of how much a line holds is made again each time the
   --  paragraphs laid out double from this many.

   Initial_Per_Line : constant := 0.5;
   --  How wide a character is to start with, as a fraction of the font's
   --  size.

   --  Heights

   function Estimate (Item : Document; Units : Natural) return Long_Float;
   --  The height of a paragraph of Units not yet laid out.

   function Estimate (Item : Document; Units : Natural) return Long_Float is
      Lines : constant Long_Float :=
        Long_Float'Max
          (1.0, Long_Float'Ceiling (Long_Float (Units) / Item.Per_Line));
   begin
      return Lines * Long_Float (CoreText.Fonts.Line_Height (Item.Font))
        + Long_Float (Item.Gap);
   end Estimate;

   function Laid_Height (Item : Document; Lines : Natural) return Long_Float
   is (Long_Float (Lines) * Long_Float (CoreText.Fonts.Line_Height (Item.Font))
       + Long_Float (Item.Gap));

   function Is_Laid_Out
     (Item : Document; Para : Paragraph_Number) return Boolean is
     (not Item.Paragraphs (Para).Lines.Is_Empty
      and then not Item.Paragraphs (Para).Dirty);

   procedure Reset_Heights (Item : in out Document);
   --  Work out every height again, from the estimate and what is laid
   --  out, and forget all tops.

   procedure Reset_Heights (Item : in out Document) is
   begin
      Item.Heights.Clear;
      Item.Tops.Clear;
      for P of Item.Paragraphs loop
         Item.Heights.Append
           (if P.Lines.Is_Empty
            then Estimate (Item, P.Units)
            else Laid_Height (Item, Natural (P.Lines.Length)));
         Item.Tops.Append (0.0);
      end loop;
      Item.Tops.Append (0.0);
      Item.Known := 1;
   end Reset_Heights;

   procedure Forget_Tops (Item : in out Document; From : Positive) is
   begin
      Item.Known := Natural'Min (Item.Known, From);
   end Forget_Tops;
   --  Tops after paragraph From are no longer right.

   procedure Know_Tops (Item : in out Document; Up_To : Positive);
   --  Make the tops of paragraphs up to Up_To right.

   procedure Know_Tops (Item : in out Document; Up_To : Positive) is
   begin
      while Item.Known < Up_To loop
         Item.Tops (Item.Known + 1) :=
           Item.Tops (Item.Known) + Item.Heights (Item.Known);
         Item.Known := Item.Known + 1;
      end loop;
   end Know_Tops;

   --  Paragraphs

   function New_Paragraph (Content : String) return Paragraph_Access is
     (new Paragraph'(Body_Text => new String'(Content),
                     Units     => CoreText.UTF16_Length (Content),
                     others    => <>));

   procedure Clear (Item : in out Document) is
   begin
      for P of Item.Paragraphs loop
         Free (P.Body_Text);
         Free (P);
      end loop;
      Item.Paragraphs.Clear;
   end Clear;

   procedure Configure
     (Item    : in out Document;
      Family  : String;
      Size    : Float;
      Page_Width : Float;
      Spacing : Float := 0.0) is
   begin
      CoreText.Fonts.Open (Item.Font, Family, Size);
      Item.Wide := Page_Width;
      Item.Gap := Spacing;
      Item.Per_Line :=
        Long_Float'Max
          (1.0, Long_Float (Page_Width / (Initial_Per_Line * Size)));
      Item.Units_Seen := 0.0;
      Item.Lines_Seen := 0.0;
      Item.Laid_Out := 0;
      Item.Next_Sample := Sample_Doubling;
      for P of Item.Paragraphs loop
         P.Lines.Clear;
         P.Dirty := False;
         CoreText.Strings.Clear (P.Held);
      end loop;
      Reset_Heights (Item);
   end Configure;

   function Is_Configured (Item : Document) return Boolean is
     (CoreText.Fonts.Is_Open (Item.Font));

   procedure Load (Item : in out Document; Content : String) is
      Start : Positive := Content'First;
   begin
      Clear (Item);
      for I in Content'Range loop
         if Content (I) = ASCII.LF then
            Item.Paragraphs.Append
              (New_Paragraph
                 (Content (Start
                        .. (if I > Start and then Content (I - 1) = ASCII.CR
                            then I - 2 else I - 1))));
            Start := I + 1;
         end if;
      end loop;
      Item.Paragraphs.Append
        (New_Paragraph (Content (Start .. Content'Last)));
      if Is_Configured (Item) then
         Reset_Heights (Item);
      end if;
   end Load;

   function Count (Item : Document) return Positive is
     (Positive (Item.Paragraphs.Length));

   function Text (Item : Document; Para : Paragraph_Number) return String is
     (Item.Paragraphs (Para).Body_Text.all);

   function Byte_Length
     (Item : Document; Para : Paragraph_Number) return Natural is
     (Item.Paragraphs (Para).Body_Text'Length);

   function Length (Item : Document; Para : Paragraph_Number) return Natural
   is (Item.Paragraphs (Para).Units);

   --  Editing

   function Is_Boundary
     (Item : Document; Para : Paragraph_Number; Index : Positive)
      return Boolean
   is
      Content : constant Text_Access := Item.Paragraphs (Para).Body_Text;
   begin
      return Index > Content'Length
        or else Character'Pos (Content (Content'First + Index - 1))
                not in 16#80# .. 16#BF#;  --  not a continuation byte
   end Is_Boundary;

   procedure Changed
     (Item : in out Document;
      Para : Paragraph_Number;
      Edit_At, Old_Stop, New_Stop : Natural);
   --  Note that the paragraph's UTF-16 range [Edit_At, Old_Stop) was
   --  replaced by what is now [Edit_At, New_Stop), so that its lines
   --  can be made again from there.

   procedure Changed
     (Item : in out Document;
      Para : Paragraph_Number;
      Edit_At, Old_Stop, New_Stop : Natural)
   is
      P : constant Paragraph_Access := Item.Paragraphs (Para);
   begin
      CoreText.Strings.Clear (P.Held);
      if not P.Lines.Is_Empty then
         if not P.Dirty then
            P.Dirty := True;
            P.Edit_At := Edit_At;
            P.Edit_Stop := New_Stop;
         else
            --  An edit on an edit: the two, as one.
            P.Edit_Stop :=
              (if Old_Stop <= P.Edit_Stop
               then Natural'Max
                      (New_Stop, P.Edit_Stop + New_Stop - Old_Stop)
               else New_Stop);
            P.Edit_At := Natural'Min (P.Edit_At, Edit_At);
         end if;
      end if;
   end Changed;

   procedure Replace
     (Item : in out Document;
      Para : Paragraph_Number;
      First, Last : Integer;
      By   : String)
   is
      P     : constant Paragraph_Access := Item.Paragraphs (Para);
      Old   : Text_Access := P.Body_Text;
      Edit_At  : constant Natural :=
        CoreText.UTF16_Length (Old (Old'First .. Old'First + First - 2));
      Old_Stop : constant Natural :=
        Edit_At + CoreText.UTF16_Length
                    (Old (Old'First + First - 1 .. Old'First + Last - 1));
      New_Stop : constant Natural := Edit_At + CoreText.UTF16_Length (By);
      Before   : constant Natural := P.Units;
   begin
      P.Body_Text := new String'
        (Old (Old'First .. Old'First + First - 2) & By
         & Old (Old'First + Last .. Old'Last));
      Free (Old);
      P.Units := Before - (Old_Stop - Edit_At) + (New_Stop - Edit_At);

      --  Remember how long the lines' text was before the first edit.
      if not P.Lines.Is_Empty and then not P.Dirty then
         P.Laid_Units := Before;
      end if;
      Changed (Item, Para, Edit_At, Old_Stop, New_Stop);

      if P.Lines.Is_Empty then
         Item.Heights (Para) := Estimate (Item, P.Units);
         Forget_Tops (Item, Para);
      end if;
   end Replace;

   procedure Split
     (Item  : in out Document;
      Para  : Paragraph_Number;
      Index : Positive)
   is
      P    : constant Paragraph_Access := Item.Paragraphs (Para);
      Old  : Text_Access := P.Body_Text;
      Tail : constant Paragraph_Access :=
        New_Paragraph (Old (Old'First + Index - 1 .. Old'Last));
      Head : constant String := Old (Old'First .. Old'First + Index - 2);
   begin
      P.Body_Text := new String'(Head);
      Free (Old);
      P.Units := CoreText.UTF16_Length (Head);
      P.Lines.Clear;
      P.Dirty := False;
      CoreText.Strings.Clear (P.Held);

      Item.Paragraphs.Insert (Para + 1, Tail);
      Item.Heights (Para) := Estimate (Item, P.Units);
      Item.Heights.Insert (Para + 1, Estimate (Item, Tail.Units));
      Item.Tops.Append (0.0);
      Forget_Tops (Item, Para);
   end Split;

   procedure Join (Item : in out Document; Para : Paragraph_Number) is
      P    : constant Paragraph_Access := Item.Paragraphs (Para);
      Next : Paragraph_Access := Item.Paragraphs (Para + 1);
      Old  : Text_Access := P.Body_Text;
   begin
      P.Body_Text := new String'(Old.all & Next.Body_Text.all);
      Free (Old);
      P.Units := P.Units + Next.Units;
      P.Lines.Clear;
      P.Dirty := False;
      CoreText.Strings.Clear (P.Held);

      Item.Paragraphs.Delete (Para + 1);
      Free (Next.Body_Text);
      Free (Next);
      Item.Heights (Para) := Estimate (Item, P.Units);
      Item.Heights.Delete (Para + 1);
      Item.Tops.Delete_Last;
      Forget_Tops (Item, Para);
   end Join;

   --  Metrics

   function Line_Height (Item : Document) return Float is
     (CoreText.Fonts.Line_Height (Item.Font));
   function Ascent (Item : Document) return Float is
     (CoreText.Fonts.Ascent (Item.Font));
   function Font_Size (Item : Document) return Float is
     (CoreText.Fonts.Size (Item.Font));
   function Width (Item : Document) return Float is (Item.Wide);

   --  Layout

   procedure Refine_Estimate (Item : in out Document);
   --  Take the estimate of a line's length from what has been laid out,
   --  if enough has been.

   procedure Refine_Estimate (Item : in out Document) is
      Better : Long_Float;
   begin
      if Item.Lines_Seen < 1.0 then
         return;
      end if;
      --  The last line of a paragraph is part full.
      Better := Long_Float'Max
        (1.0, Item.Units_Seen / Item.Lines_Seen * 1.0);
      if abs (Better - Item.Per_Line) > 0.03 * Item.Per_Line then
         Item.Per_Line := Better;
         Reset_Heights (Item);
      end if;
   end Refine_Estimate;

   procedure Lay_Out (Item : in out Document; Para : Paragraph_Number) is
      P : constant Paragraph_Access := Item.Paragraphs (Para);
   begin
      if Is_Laid_Out (Item, Para) then
         return;
      end if;

      if not CoreText.Strings.Is_Set (P.Held) then
         CoreText.Strings.Set (P.Held, P.Body_Text.all);
      end if;

      declare
         Old_Stop : constant Integer :=
           P.Edit_Stop - (P.Units - P.Laid_Units);
         Lines : constant Span_Vectors.Vector :=
           (if P.Dirty and then Old_Stop >= P.Edit_At
              and then Old_Stop <= P.Laid_Units
              and then P.Edit_Stop <= P.Units
            then Rewrap
                   (Item.Font, P.Lines, P.Held, Item.Wide,
                    P.Edit_At, Old_Stop, P.Edit_Stop)
            else Wrap (Item.Font, P.Held, Item.Wide));
      begin
         P.Lines := Lines;
      end;
      P.Dirty := False;
      Item.Next_Id := Item.Next_Id + 1;
      P.Id := Item.Next_Id;

      Item.Heights (Para) := Laid_Height (Item, Natural (P.Lines.Length));
      Forget_Tops (Item, Para);

      --  Sample paragraphs of several lines: a one-line paragraph says
      --  nothing about how long a line is.
      if Natural (P.Lines.Length) > 1 then
         Item.Units_Seen := Item.Units_Seen + Long_Float (P.Units);
         Item.Lines_Seen :=
           Item.Lines_Seen + Long_Float (P.Lines.Length) - 0.5;
      end if;
      Item.Laid_Out := Item.Laid_Out + 1;
      if Item.Laid_Out >= Item.Next_Sample then
         Item.Next_Sample := 2 * Item.Next_Sample;
         Refine_Estimate (Item);
      end if;
   end Lay_Out;

   function Line_Count
     (Item : Document; Para : Paragraph_Number) return Positive is
     (Positive (Item.Paragraphs (Para).Lines.Length));

   function Line
     (Item : Document; Para : Paragraph_Number; Number : Positive)
      return CoreText.Wrapping.Span is
     (Item.Paragraphs (Para).Lines (Number));

   function Layout_Id
     (Item : Document; Para : Paragraph_Number) return Positive is
     (Item.Paragraphs (Para).Id);

   procedure Shape_Line
     (Item   : in out Document;
      Reg    : in out CoreText.Shaping.Registry;
      Para   : Paragraph_Number;
      Number : Positive;
      Result : out CoreText.Shaping.Shaped)
   is
      P    : constant Paragraph_Access := Item.Paragraphs (Para);
      Range_Of : constant CoreText.Wrapping.Span := P.Lines (Number);
   begin
      CoreText.Shaping.Shape
        (Reg, Item.Font, P.Held, Range_Of.First, Range_Of.Stop, Result);
   end Shape_Line;

   --  Position

   function Top (Item : in out Document; Para : Paragraph_Number)
      return Float is
   begin
      Know_Tops (Item, Para);
      return Float (Item.Tops (Para));
   end Top;

   function Height (Item : Document; Para : Paragraph_Number) return Float is
     (Float (Item.Heights (Para)));

   function Total_Height (Item : in out Document) return Float is
   begin
      Know_Tops (Item, Count (Item) + 1);
      return Float (Item.Tops (Count (Item) + 1));
   end Total_Height;

   function Paragraph_At
     (Item : in out Document; Y : Float) return Paragraph_Number
   is
      At_Y : constant Long_Float := Long_Float (Y);
   begin
      --  Work out tops as far as they take to pass Y.
      while Item.Known <= Count (Item)
        and then Item.Tops (Item.Known) <= At_Y
      loop
         Know_Tops (Item, Item.Known + 1);
      end loop;

      --  Binary search, for the last top at or before Y.
      declare
         Low  : Positive := 1;
         High : Positive := Natural'Min (Item.Known, Count (Item));
      begin
         while Low < High loop
            declare
               Mid : constant Positive := (Low + High + 1) / 2;
            begin
               if Item.Tops (Mid) <= At_Y then
                  Low := Mid;
               else
                  High := Mid - 1;
               end if;
            end;
         end loop;
         return Low;
      end;
   end Paragraph_At;

   procedure Scroll
     (Item   : in out Document;
      Anchor : in out Paragraph_Number;
      Offset : in out Float;
      By     : Float;
      Extent : Float)
   is
      Furthest : constant Float :=
        Float'Max (0.0, Total_Height (Item) - Extent);
      Y : constant Float :=
        Float'Min
          (Furthest, Float'Max (0.0, Top (Item, Anchor) + Offset + By));
   begin
      Anchor := Paragraph_At (Item, Y);
      Offset := Y - Top (Item, Anchor);
   end Scroll;

   procedure Visible
     (Item   : in out Document;
      Anchor : in out Paragraph_Number;
      Offset : in out Float;
      Extent : Float;
      First, Last : out Paragraph_Number)
   is
      Passes : constant := 8;
   begin
      First := Anchor;
      Last := Anchor;

      for Pass in 1 .. Passes loop
         declare
            Y      : constant Float :=
              Float'Max (0.0, Top (Item, Anchor) + Offset);
            P      : Paragraph_Number := Paragraph_At (Item, Y);
         begin
            First := P;
            Anchor := P;
            Offset := Y - Top (Item, P);

            --  Laying a paragraph out changes the tops after it, which
            --  is where the bottom of the view is found.
            loop
               Lay_Out (Item, P);
               Last := P;
               exit when P = Count (Item)
                 or else Top (Item, P + 1) >= Y + Extent;
               P := P + 1;
            end loop;

            --  Steady when laying out moved nothing at the top.
            exit when Pass = Passes or else Paragraph_At (Item, Y) = First;
         end;
      end loop;
      pragma Assert (for all P in First .. Last => Is_Laid_Out (Item, P));
   end Visible;

   overriding procedure Finalize (Item : in out Document) is
   begin
      Clear (Item);
   end Finalize;

end Typeset.Documents;
