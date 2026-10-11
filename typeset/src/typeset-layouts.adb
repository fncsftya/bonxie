with Ada.Unchecked_Deallocation;
with CoreText.Lines;

package body Typeset.Layouts is

   package Docs renames Texts.Documents;

   use CoreText.Wrapping;
   use type Docs.Version;
   use type Texts.Position;

   procedure Free is new Ada.Unchecked_Deallocation
     (Paragraph_Layout, Paragraph_Access);

   Long_Units : constant := 4 * CoreText.Wrapping.Window;
   --  A paragraph longer than this is broken into lines only as far as
   --  is wanted; a shorter one all at once.

   Sample_Doubling : constant := 8;
   --  The estimate of how much a line holds is made again each time the
   --  paragraphs laid out double from this many.

   Initial_Per_Line : constant := 0.5;
   --  How wide a character is to start with, as a fraction of the font's
   --  size.

   Most_Lines : constant := 1_000_000;
   --  More than a view could want of a paragraph at once.

   --  Heights

   function Lines_For (Item : Layout; Units : Natural) return Long_Float is
     (Long_Float'Ceiling (Long_Float (Units) / Item.Per_Line));
   --  Estimated, of text not yet broken.

   function Height_Of (Item : Layout; Para : Positive) return Long_Float is
      P     : constant Paragraph_Access := Item.Paragraphs.Element (Para);
      Units : constant Natural := Item.Lengths.Element (Para);
      Lines : Long_Float;
   begin
      if P = null or else P.Lines.Is_Empty then
         Lines := Long_Float'Max (1.0, Lines_For (Item, Units));
      elsif P.Dirty or else P.Complete then
         Lines := Long_Float (P.Lines.Length);
      else
         Lines := Long_Float (P.Lines.Length)
           + Lines_For
               (Item,
                Natural'Max (0, Units - P.Lines.Last_Element.Stop));
      end if;
      return Lines * Item.Line_High + Long_Float (Item.Gap);
   end Height_Of;

   procedure Update_Height (Item : in out Layout; Para : Positive) is
   begin
      Sums.Set (Item.Heights, Para, Height_Of (Item, Para));
   end Update_Height;

   procedure Reset_Heights (Item : in out Layout);
   --  Work out every height again, as after the estimate changes.

   procedure Reset_Heights (Item : in out Layout) is
   begin
      if Sums.Count (Item.Heights) /= Count (Item) then
         Sums.Resize (Item.Heights, Count (Item));
      end if;
      for P in 1 .. Count (Item) loop
         Sums.Put (Item.Heights, P, Height_Of (Item, P));
      end loop;
      Sums.Rebuild (Item.Heights);
   end Reset_Heights;

   function New_Id (Item : in out Layout) return Positive is
   begin
      Item.Next_Id := Item.Next_Id + 1;
      return Item.Next_Id;
   end New_Id;

   --  Setting up

   procedure Forget_Layout (Item : in out Layout);
   --  Of every paragraph, and what was learnt from it, for lines of
   --  another width or font.

   procedure Forget_Layout (Item : in out Layout) is
   begin
      Item.Per_Line :=
        Long_Float'Max
          (1.0,
           Long_Float
             (Item.Wide
              / (Initial_Per_Line * CoreText.Fonts.Size (Item.Font))));
      Item.Units_Seen := 0.0;
      Item.Lines_Seen := 0.0;
      Item.Laid_Out := 0;
      Item.Next_Sample := Sample_Doubling;
      for P of Item.Paragraphs loop
         if P /= null then
            P.Lines.Clear;
            P.Dirty := False;
            P.Complete := False;
         end if;
      end loop;
      Reset_Heights (Item);
   end Forget_Layout;

   procedure Configure
     (Item       : in out Layout;
      Family     : String;
      Size       : Float;
      Page_Width : Float;
      Spacing    : Float := 0.0) is
   begin
      CoreText.Fonts.Open (Item.Font, Family, Size);
      Item.Line_High := Long_Float (CoreText.Fonts.Line_Height (Item.Font));
      Item.Wide := Page_Width;
      Item.Gap := Spacing;
      Forget_Layout (Item);
   end Configure;

   function Is_Configured (Item : Layout) return Boolean is
     (CoreText.Fonts.Is_Open (Item.Font));

   procedure Set_Width (Item : in out Layout; Page_Width : Float) is
   begin
      Item.Wide := Page_Width;
      Forget_Layout (Item);
   end Set_Width;

   procedure Clear (Item : in out Layout) is
   begin
      for P of Item.Paragraphs loop
         Free (P);
      end loop;
      Item.Paragraphs.Clear;
      Item.Lengths.Clear;
   end Clear;

   overriding procedure Finalize (Item : in out Layout) is
   begin
      Clear (Item);
   end Finalize;

   function Count (Item : Layout) return Natural is
     (Natural (Item.Paragraphs.Length));

   --  Catching up

   procedure Start_Again (Item : in out Layout; Doc : Document);
   --  With Doc as it is, none of it laid out.

   procedure Start_Again (Item : in out Layout; Doc : Document) is
   begin
      Clear (Item);
      Item.Paragraphs.Append
        (null, Ada.Containers.Count_Type (Docs.Count (Doc)));
      Item.Lengths.Reserve_Capacity
        (Ada.Containers.Count_Type (Docs.Count (Doc)));
      for P in 1 .. Docs.Count (Doc) loop
         Item.Lengths.Append (Docs.Byte_Length (Doc, P));
      end loop;
      Item.Serial := Docs.Serial (Doc);
      Item.Seen := Docs.Current (Doc);
      Reset_Heights (Item);
   end Start_Again;

   procedure Truncate (Item : in out Layout; P : Paragraph_Access;
                       Unit : Natural);
   --  Keep only the lines of P that an edit at Unit cannot change: those
   --  before the line before the one it is in.

   procedure Truncate (Item : in out Layout; P : Paragraph_Access;
                       Unit : Natural)
   is
      Keep : Natural := 0;
      Upto : constant Natural :=
        (if P.Dirty then Natural'Min (Unit, P.Edit_At) else Unit);
   begin
      for Number in 1 .. Natural (P.Lines.Length) loop
         exit when P.Lines (Number).Stop >= Upto;
         Keep := Number;
      end loop;
      --  And not the last of them: an edit at a line's start can let its
      --  first word fit on the line above.
      Keep := Natural'Max (0, Keep - 1);
      P.Lines.Set_Length (Ada.Containers.Count_Type (Keep));
      P.Complete := False;
      P.Dirty := False;
      P.Id := New_Id (Item);
   end Truncate;

   procedure Edited
     (Item : in out Layout;
      P    : Paragraph_Access;
      Edit_At, Old_Stop, New_Stop : Natural);
   --  Note that P's UTF-16 range [Edit_At, Old_Stop) was replaced by what
   --  is now [Edit_At, New_Stop), so that its lines can be made again
   --  from there.

   procedure Edited
     (Item : in out Layout;
      P    : Paragraph_Access;
      Edit_At, Old_Stop, New_Stop : Natural) is
   begin
      if P.Lines.Is_Empty then
         null;
      elsif not P.Complete then
         Truncate (Item, P, Edit_At);
      elsif not P.Dirty then
         P.Dirty := True;
         P.Laid_Units := P.Lines.Last_Element.Stop;
         P.Edit_At := Edit_At;
         P.Edit_Stop := New_Stop;
      else
         --  An edit on an edit: the two, as one.
         P.Edit_Stop :=
           (if Old_Stop <= P.Edit_Stop
            then Natural'Max (New_Stop, P.Edit_Stop + New_Stop - Old_Stop)
            else New_Stop);
         P.Edit_At := Natural'Min (P.Edit_At, Edit_At);
      end if;
   end Edited;

   package Index_Vectors is new Ada.Containers.Vectors (Positive, Positive);

   procedure Apply
     (Item       : in out Layout;
      Doc        : Document;
      Done       : Docs.Change;
      Last       : Boolean;
      Structural : in out Boolean;
      Touched    : in out Index_Vectors.Vector);
   --  Catch up with Done, gathering the paragraphs it changed in Touched,
   --  whose numbers it keeps right. Last says it is the document's last
   --  change, so that what it put in is there to read.

   procedure Apply
     (Item       : in out Layout;
      Doc        : Document;
      Done       : Docs.Change;
      Last       : Boolean;
      Structural : in out Boolean;
      Touched    : in out Index_Vectors.Vector)
   is
      Para : constant Positive := Done.From.Paragraph;
      P    : constant Paragraph_Access := Item.Paragraphs (Para);
      Made : constant Natural := Done.Ending.Paragraph - Para;
      Went : constant Natural := Done.To.Paragraph - Para;
   begin
      --  Those after the change move along with it; those it removed go.
      if Made /= Went then
         declare
            Kept : Index_Vectors.Vector;
         begin
            for Index of Touched loop
               if Index > Para + Went then
                  Kept.Append (Index - Went + Made);
               elsif Index <= Para then
                  Kept.Append (Index);
               end if;
            end loop;
            Touched.Move (Kept);
         end;
      end if;
      Touched.Append (Para);

      if Made = 0 and then Went = 0 then
         if P /= null then
            --  The text CoreText has, edited likewise, not made again.
            if Last and then CoreText.Strings.Is_Set (P.Held) then
               CoreText.Strings.Replace
                 (P.Held, Done.From_Units, Done.To_Units,
                  Docs.Slice (Doc, Para, Done.From.Index, Done.Ending.Index));
            else
               CoreText.Strings.Clear (P.Held);
            end if;
            Edited (Item, P, Done.From_Units, Done.To_Units, Done.End_Units);
         end if;
         --  Not known of a paragraph made since the last sync, until the
         --  end of this one, which sets all those touched.
         Item.Lengths (Para) := Natural'Max
           (0, Integer (Item.Lengths (Para)) + Done.End_Units
               - Done.To_Units);
         return;
      end if;

      Structural := True;
      for New_Para in Para + 1 .. Para + Made loop
         Touched.Append (New_Para);
      end loop;
      declare
         --  A paragraph broken in two: the second's lines are the old
         --  ones after the break, shifted, once rewrapped from the start.
         Broken : constant Boolean :=
           Done.From = Done.To and then Made = 1 and then Done.End_Units = 0
           and then P /= null and then P.Complete and then not P.Dirty;
         Added  : Paragraph_Vectors.Vector;
      begin
         if Broken then
            Added.Append
              (new Paragraph_Layout'
                 (Lines      => P.Lines,
                  Complete   => True,
                  Dirty      => True,
                  Laid_Units => Done.Old_Length,
                  Edit_At    => 0,
                  Edit_Stop  => 0,
                  others     => <>));
            if Last and then CoreText.Strings.Is_Set (P.Held) then
               CoreText.Strings.Replace
                 (P.Held, Done.From_Units, Done.Old_Length, "");
            else
               CoreText.Strings.Clear (P.Held);
            end if;
            Edited (Item, P, Done.From_Units, Done.Old_Length,
                    Done.From_Units);
         else
            if P /= null then
               CoreText.Strings.Clear (P.Held);
               Truncate (Item, P, Done.From_Units);
            end if;
            Added.Append (null, Ada.Containers.Count_Type (Made));
         end if;

         for Gone in Para + 1 .. Para + Went loop
            declare
               Going : Paragraph_Access := Item.Paragraphs (Gone);
            begin
               Free (Going);
            end;
         end loop;
         if Went > 0 then
            Item.Paragraphs.Delete
              (Para + 1, Ada.Containers.Count_Type (Went));
            Item.Lengths.Delete (Para + 1, Ada.Containers.Count_Type (Went));
         end if;
         if Made > 0 then
            Item.Paragraphs.Insert (Para + 1, Added);
            Item.Lengths.Insert
              (Para + 1, 0, Ada.Containers.Count_Type (Made));
         end if;
         Sums.Splice (Item.Heights, Para + 1, Went, Made);
      end;
   end Apply;

   procedure Sync (Item : in out Layout; Doc : Document) is
      Structural : Boolean := False;
      Touched    : Index_Vectors.Vector;
   begin
      if Item.Serial /= Docs.Serial (Doc)
        or else Item.Seen < Docs.Oldest (Doc)
        or else Item.Seen > Docs.Current (Doc)
      then
         Start_Again (Item, Doc);
         return;
      end if;

      while Item.Seen < Docs.Current (Doc) loop
         declare
            Done : constant Docs.Change := Docs.Change_After (Doc, Item.Seen);
         begin
            Item.Seen := Item.Seen + 1;
            if not Done.Kind_Only then
               Apply (Item, Doc, Done, Item.Seen = Docs.Current (Doc),
                      Structural, Touched);
            end if;
         end;
      end loop;
      pragma Assert (Count (Item) = Docs.Count (Doc));

      for Para of Touched loop
         Item.Lengths (Para) := Docs.Length (Doc, Para);
         if Structural then
            Sums.Put (Item.Heights, Para, Height_Of (Item, Para));
         else
            Update_Height (Item, Para);
         end if;
      end loop;
      if Structural then
         Sums.Rebuild (Item.Heights);  --  once, however much changed
      end if;
   end Sync;

   function Is_Synced (Item : Layout; Doc : Document) return Boolean is
     (Item.Serial = Docs.Serial (Doc) and then Item.Seen = Docs.Current (Doc)
      and then Count (Item) = Docs.Count (Doc));

   --  Metrics

   function Line_Height (Item : Layout) return Float is
     (CoreText.Fonts.Line_Height (Item.Font));
   function Ascent (Item : Layout) return Float is
     (CoreText.Fonts.Ascent (Item.Font));
   function Font_Size (Item : Layout) return Float is
     (CoreText.Fonts.Size (Item.Font));
   function Width (Item : Layout) return Float is (Item.Wide);

   --  Lines

   function Is_Laid_Out (Item : Layout; Para : Positive) return Boolean is
     (Item.Paragraphs (Para) /= null
      and then not Item.Paragraphs (Para).Lines.Is_Empty
      and then not Item.Paragraphs (Para).Dirty);

   function Is_Complete (Item : Layout; Para : Positive) return Boolean is
     (Is_Laid_Out (Item, Para) and then Item.Paragraphs (Para).Complete);

   function Covers
     (Item : Layout; Para : Positive; Units : Natural) return Boolean is
     (Is_Laid_Out (Item, Para)
      and then (Item.Paragraphs (Para).Complete
                or else Units
                        < Item.Paragraphs (Para).Lines.Last_Element.Stop));

   procedure Hold (Item : Layout; Doc : Document; Para : Positive);
   --  Set the paragraph's text as a CoreFoundation string, unless it is.

   procedure Hold (Item : Layout; Doc : Document; Para : Positive) is
      P : constant Paragraph_Access := Item.Paragraphs (Para);
   begin
      if not CoreText.Strings.Is_Set (P.Held) then
         CoreText.Strings.Set (P.Held, Docs.Text (Doc, Para));
      end if;
      pragma Assert
        (CoreText.Strings.Length (P.Held) = Item.Lengths (Para));
   end Hold;

   procedure Refine_Estimate (Item : in out Layout);
   --  Take the estimate of a line's length from what has been laid out,
   --  if enough has been.

   procedure Refine_Estimate (Item : in out Layout) is
      Better : Long_Float;
   begin
      if Item.Lines_Seen < 1.0 then
         return;
      end if;
      Better := Long_Float'Max (1.0, Item.Units_Seen / Item.Lines_Seen);
      if abs (Better - Item.Per_Line) > 0.03 * Item.Per_Line then
         Item.Per_Line := Better;
         Reset_Heights (Item);
      end if;
   end Refine_Estimate;

   procedure Laid_Out (Item : in out Layout; Para : Positive);
   --  The paragraph has more lines: its height, and what it says of how
   --  much a line holds.

   procedure Laid_Out (Item : in out Layout; Para : Positive) is
      P : constant Paragraph_Access := Item.Paragraphs (Para);
   begin
      P.Complete := P.Lines.Last_Element.Stop = Item.Lengths (Para);
      Update_Height (Item, Para);

      --  Sample paragraphs of several lines: a one-line paragraph says
      --  nothing about how long a line is.
      if P.Complete and then Natural (P.Lines.Length) > 1 then
         Item.Units_Seen :=
           Item.Units_Seen + Long_Float (Item.Lengths (Para));
         Item.Lines_Seen :=
           Item.Lines_Seen + Long_Float (P.Lines.Length) - 0.5;
         Item.Laid_Out := Item.Laid_Out + 1;
         if Item.Laid_Out >= Item.Next_Sample then
            Item.Next_Sample := 2 * Item.Next_Sample;
            Refine_Estimate (Item);
         end if;
      end if;
   end Laid_Out;

   procedure Make_Lines
     (Item  : in out Layout;
      Doc   : Document;
      Para  : Positive;
      Lines : Positive;
      Units : Natural);
   --  Break the paragraph into at least Lines lines, as far as Units, or
   --  all of them.

   procedure Make_Lines
     (Item  : in out Layout;
      Doc   : Document;
      Para  : Positive;
      Lines : Positive;
      Units : Natural)
   is
      P      : Paragraph_Access renames Item.Paragraphs.Reference (Para);
      Length : constant Natural := Docs.Length (Doc, Para);  --  exactly
   begin
      if P = null then
         P := new Paragraph_Layout;
      end if;
      Item.Lengths (Para) := Length;
      Hold (Item, Doc, Para);
      if P.Dirty then
         declare
            Old_Stop : constant Integer :=
              P.Edit_Stop - (Length - P.Laid_Units);
            Fresh : Span_Vectors.Vector :=
              (if Old_Stop >= P.Edit_At and then Old_Stop <= P.Laid_Units
                 and then P.Edit_Stop <= Length
               then Rewrap
                      (Item.Font, P.Lines, P.Held, Item.Wide,
                       P.Edit_At, Old_Stop, P.Edit_Stop)
               else Wrap (Item.Font, P.Held, Item.Wide));
         begin
            P.Lines.Move (Source => Fresh);  --  not copied
         end;
         P.Dirty := False;
         P.Id := New_Id (Item);
      elsif P.Lines.Is_Empty and then Length <= Long_Units then
         P.Lines := Wrap (Item.Font, P.Held, Item.Wide);
         P.Id := New_Id (Item);
      else
         if P.Lines.Is_Empty then
            P.Id := New_Id (Item);
         end if;
         Extend (Item.Font, P.Held, Item.Wide, P.Lines,
                 Until_Count => Lines, Until_Unit => Units);
      end if;
      Laid_Out (Item, Para);
   end Make_Lines;

   procedure Lay_Out
     (Item  : in out Layout;
      Doc   : Document;
      Para  : Positive;
      Lines : Positive := Positive'Last) is
   begin
      if not Is_Laid_Out (Item, Para)
        or else not (Item.Paragraphs (Para).Complete
                     or else Line_Count (Item, Para) >= Lines)
      then
         Make_Lines (Item, Doc, Para, Lines, Units => 0);
      end if;
   end Lay_Out;

   procedure Lay_Out_To
     (Item  : in out Layout;
      Doc   : Document;
      Para  : Positive;
      Units : Natural) is
   begin
      if not Covers (Item, Para, Units) then
         Make_Lines (Item, Doc, Para, Lines => 1, Units => Units);
      end if;
   end Lay_Out_To;

   function Line_Count (Item : Layout; Para : Positive) return Positive is
     (Positive (Item.Paragraphs (Para).Lines.Length));

   function Line
     (Item : Layout; Para : Positive; Number : Positive)
      return CoreText.Wrapping.Span is
     (Item.Paragraphs (Para).Lines (Number));

   function Layout_Id (Item : Layout; Para : Positive) return Positive is
     (Item.Paragraphs (Para).Id);

   procedure Shape_Line
     (Item   : in out Layout;
      Doc    : Document;
      Reg    : in out CoreText.Shaping.Registry;
      Para   : Positive;
      Number : Positive;
      Result : out CoreText.Shaping.Shaped)
   is
      P     : constant Paragraph_Access := Item.Paragraphs (Para);
      Range_Of : constant CoreText.Wrapping.Span := P.Lines (Number);
   begin
      Hold (Item, Doc, Para);
      CoreText.Shaping.Shape
        (Reg, Item.Font, P.Held, Range_Of.First, Range_Of.Stop, Result);
   end Shape_Line;

   --  Where paragraphs are

   function Top (Item : Layout; Para : Positive) return Float is
     (Float (Sums.Before (Item.Heights, Para)));

   function Height (Item : Layout; Para : Positive) return Float is
     (Float (Sums.Value (Item.Heights, Para)));

   function Total_Height (Item : Layout) return Float is
     (Float (Sums.Total (Item.Heights)));

   function Paragraph_At (Item : Layout; Y : Float) return Positive is
     (Sums.Find (Item.Heights, Long_Float (Y)));

   procedure Scroll
     (Item   : Layout;
      Anchor : in out Positive;
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
     (Item   : in out Layout;
      Doc    : Document;
      Anchor : in out Positive;
      Offset : in out Float;
      Extent : Float;
      First, Last : out Positive)
   is
      Passes : constant := 8;
      High   : constant Float := Line_Height (Item);
   begin
      First := Anchor;
      Last := Anchor;

      for Pass in 1 .. Passes loop
         declare
            --  Not past the end: laying out what was estimated may have
            --  made the page shorter than when the view was scrolled.
            Y : constant Float :=
              Float'Max
                (0.0,
                 Float'Min
                   (Top (Item, Anchor) + Offset,
                    Total_Height (Item) - Extent));
            P : Positive := Paragraph_At (Item, Y);
         begin
            First := P;
            Anchor := P;
            Offset := Y - Top (Item, P);

            --  Laying a paragraph out changes the tops after it, which
            --  is where the bottom of the view is found.
            loop
               declare
                  Down   : constant Float := Y + Extent - Top (Item, P);
                  Wanted : constant Positive :=
                    (if Down / High >= Float (Most_Lines) then Most_Lines
                     else Natural (Float'Floor (Float'Max (0.0, Down) / High))
                          + 1);
               begin
                  Lay_Out (Item, Doc, P, Wanted);
               end;
               Last := P;
               exit when P = Count (Item)
                 or else Top (Item, P + 1) >= Y + Extent;
               P := P + 1;
            end loop;

            --  Steady when laying out moved nothing at the top, and the
            --  page still reaches the bottom of the view.
            exit when Pass = Passes
              or else (Paragraph_At (Item, Y) = First
                       and then (Y = 0.0
                                 or else Total_Height (Item) - Extent >= Y));
         end;
      end loop;
   end Visible;

   --  Carets

   function Line_At
     (Item : Layout; Para : Positive; Units : Natural) return Positive
   is
      Lines : Span_Vectors.Vector renames Item.Paragraphs (Para).Lines;
      Low   : Positive := Lines.First_Index;
      High  : Positive := Lines.Last_Index;
   begin
      --  The first line that ends after Units; the last, at the end.
      while Low < High loop
         declare
            Mid : constant Positive := (Low + High) / 2;
         begin
            if Lines (Mid).Stop > Units then
               High := Mid;
            else
               Low := Mid + 1;
            end if;
         end;
      end loop;
      return Low;
   end Line_At;

   procedure Set_Line
     (Item   : Layout;
      Doc    : Document;
      Para   : Positive;
      Number : Positive;
      Result : in out CoreText.Lines.Line);
   --  Make Result line Number of the paragraph, as it is shaped.

   procedure Set_Line
     (Item   : Layout;
      Doc    : Document;
      Para   : Positive;
      Number : Positive;
      Result : in out CoreText.Lines.Line)
   is
      Bounds : constant CoreText.Wrapping.Span := Line (Item, Para, Number);
   begin
      CoreText.Lines.Make
        (Result, Item.Font,
         Docs.Slice
           (Doc, Para,
            Docs.Index_Of (Doc, Para, Bounds.First),
            Docs.Index_Of (Doc, Para, Bounds.Stop)));
      pragma Assert
        (CoreText.Lines.Length (Result) = Bounds.Stop - Bounds.First);
   end Set_Line;

   function Caret_Offset
     (Item   : Layout;
      Doc    : Document;
      Para   : Positive;
      Number : Positive;
      Units  : Natural) return Float
   is
      Set : CoreText.Lines.Line;
   begin
      Set_Line (Item, Doc, Para, Number, Set);
      return CoreText.Lines.Offset_For_Index
               (Set, Units - Line (Item, Para, Number).First);
   end Caret_Offset;

   function Units_At_Offset
     (Item   : Layout;
      Doc    : Document;
      Para   : Positive;
      Number : Positive;
      X      : Float) return Natural
   is
      Bounds : constant CoreText.Wrapping.Span := Line (Item, Para, Number);
      Set    : CoreText.Lines.Line;
      Units  : Natural;
   begin
      Set_Line (Item, Doc, Para, Number, Set);
      Units := Bounds.First + CoreText.Lines.Index_For_Position (Set, X);
      --  The end of a line that breaks is the start of the next: stop
      --  before the character it breaks after.
      if (Number < Line_Count (Item, Para)
          or else not Item.Paragraphs (Para).Complete)
        and then Units >= Bounds.Stop
      then
         Units := Docs.Units_Before
           (Doc, Para,
            Previous_Character
              (Doc, Para, Docs.Index_Of (Doc, Para, Bounds.Stop)));
      end if;
      return Units;
   end Units_At_Offset;

   --  Characters and words

   procedure Look_Around
     (Doc    : Document;
      Para   : Positive;
      Around : Natural;
      Back, On : Natural;
      Held   : in out CoreText.Strings.Text;
      Offset : out Natural);
   --  Set Held to the paragraph's text from Back units before Around to
   --  On after it, as far as there is any, which starts at unit Offset.

   procedure Look_Around
     (Doc    : Document;
      Para   : Positive;
      Around : Natural;
      Back, On : Natural;
      Held   : in out CoreText.Strings.Text;
      Offset : out Natural)
   is
      First : constant Positive :=
        Docs.Index_Of (Doc, Para, Natural'Max (0, Around - Back));
      Stop  : constant Positive :=
        Docs.Index_Of
          (Doc, Para, Natural'Min (Docs.Length (Doc, Para), Around + On));
   begin
      Offset := Docs.Units_Before (Doc, Para, First);
      CoreText.Strings.Set (Held, Docs.Slice (Doc, Para, First, Stop));
   end Look_Around;

   function Next_Character
     (Doc : Document; Para : Positive; Index : Positive) return Positive
   is
      Units  : constant Natural := Docs.Units_Before (Doc, Para, Index);
      Held   : CoreText.Strings.Text;
      Offset : Natural;
      First, Stop : Natural;
   begin
      Look_Around (Doc, Para, Units, 0, Reach, Held, Offset);
      CoreText.Strings.Cluster (Held, Units - Offset, First, Stop);
      return Docs.Index_Of (Doc, Para, Offset + Stop);
   end Next_Character;

   function Previous_Character
     (Doc : Document; Para : Positive; Index : Positive) return Positive
   is
      Units  : constant Natural := Docs.Units_Before (Doc, Para, Index);
      Held   : CoreText.Strings.Text;
      Offset : Natural;
      First, Stop : Natural;
   begin
      Look_Around (Doc, Para, Units, Reach, 0, Held, Offset);
      CoreText.Strings.Cluster (Held, Units - 1 - Offset, First, Stop);
      return Docs.Index_Of (Doc, Para, Offset + First);
   end Previous_Character;

   function Previous_Word
     (Doc : Document; Para : Positive; Index : Positive) return Positive
   is
      Units  : constant Natural := Docs.Units_Before (Doc, Para, Index);
      Held   : CoreText.Strings.Text;
      Offset : Natural;
   begin
      Look_Around (Doc, Para, Units, Reach, 0, Held, Offset);
      return Docs.Index_Of
        (Doc, Para,
         Offset
         + CoreText.Strings.Previous_Word_Start (Held, Units - Offset));
   end Previous_Word;

   function Next_Word
     (Doc : Document; Para : Positive; Index : Positive) return Positive
   is
      Units  : constant Natural := Docs.Units_Before (Doc, Para, Index);
      Held   : CoreText.Strings.Text;
      Offset : Natural;
   begin
      Look_Around (Doc, Para, Units, 0, Reach, Held, Offset);
      return Docs.Index_Of
        (Doc, Para,
         Offset + CoreText.Strings.Next_Word_Stop (Held, Units - Offset));
   end Next_Word;

   procedure Word_At
     (Doc   : Document;
      Para  : Positive;
      Index : Positive;
      First, Stop : out Positive)
   is
      Units  : constant Natural := Docs.Units_Before (Doc, Para, Index);
      Held   : CoreText.Strings.Text;
      Offset : Natural;
      Word_First, Word_Stop : Natural;
   begin
      Look_Around (Doc, Para, Units, Reach, Reach, Held, Offset);
      CoreText.Strings.Word_At
        (Held, Units - Offset, Word_First, Word_Stop);
      First := Docs.Index_Of (Doc, Para, Offset + Word_First);
      Stop := Docs.Index_Of (Doc, Para, Offset + Word_Stop);
   end Word_At;

end Typeset.Layouts;
