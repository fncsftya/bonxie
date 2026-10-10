with Ada.Command_Line;
with Ada.Float_Text_IO;
with Ada.Real_Time;
with Ada.Text_IO;
with CoreText.Fonts;
with CoreText.Shaping;
with CoreText.Shaping.Glyphs;
with CoreText.Wrapping;
with Typeset.Documents;
with Interfaces;
with Typeset.Samples;

--  Measures laying out, scrolling and editing a long document, and
--  shaping and rasterizing its text: bench [paragraphs]
procedure Bench is
   package Documents renames Typeset.Documents;

   use Ada.Real_Time;
   use Ada.Text_IO;
   use type CoreText.Wrapping.Span;

   Paragraphs : constant Positive :=
     (if Ada.Command_Line.Argument_Count > 0
      then Positive'Value (Ada.Command_Line.Argument (1)) else 5_000);

   Text : constant String := Typeset.Samples.Document (Paragraphs);

   Frames  : constant := 1_000;
   Extent  : constant Float := 800.0;

   Started : Time;

   procedure Start is
   begin
      Started := Clock;
   end Start;

   function Millis return Float is
     (Float (To_Duration (Clock - Started)) * 1000.0);

   procedure Report (What : String; Value : Float; Unit : String := "ms") is
      Shown : String (1 .. 10);
   begin
      Ada.Float_Text_IO.Put (Shown, Value, Aft => 2, Exp => 0);
      Put_Line ("  " & What & ":" & Shown & " " & Unit);
   end Report;

   procedure Scroll_Through
     (Doc : in out Documents.Document; Label : String)
   is
      Anchor : Documents.Paragraph_Number := 1;
      Offset : Float := 0.0;
      First, Last : Documents.Paragraph_Number;
      Step   : constant Float := Documents.Total_Height (Doc) / Float (Frames);
   begin
      Start;
      for Frame in 1 .. Frames loop
         Documents.Scroll (Doc, Anchor, Offset, Step, Extent);
         Documents.Visible (Doc, Anchor, Offset, Extent, First, Last);
      end loop;
      Report (Label & ", per frame", Millis / Float (Frames), "ms");
   end Scroll_Through;

   Doc : Documents.Document;
   Font : CoreText.Fonts.Font;
   Longest, Longest_Length : Natural := 0;
begin
   Put_Line ("bench:" & Paragraphs'Image & " paragraphs,"
             & Natural'Image (Text'Length / 1024) & " KB");

   CoreText.Fonts.Open (Font, "Georgia", 18.0);
   Start;
   Documents.Configure (Doc, "Georgia", 18.0, 640.0, 8.0);
   Documents.Load (Doc, Text);
   Report ("configure and load", Millis);

   Start;
   declare
      Total : constant Float := Documents.Total_Height (Doc);
   begin
      Report ("total height, estimated", Millis);
      Put_Line ("  estimate:" & Natural'Image (Natural (Total)) & " units");
   end;

   Put_Line ("scrolling through the whole document, from cold:");
   Scroll_Through (Doc, "first pass (lays out as it goes)");
   Scroll_Through (Doc, "second pass (laid out)");
   Put_Line ("  total height now:"
             & Natural'Image (Natural (Documents.Total_Height (Doc)))
             & " units");

   --  Edits: in the longest paragraph.
   for P in 1 .. Documents.Count (Doc) loop
      if Documents.Length (Doc, P) > Longest_Length then
         Longest := P;
         Longest_Length := Documents.Length (Doc, P);
      end if;
   end loop;
   Put_Line ("editing the longest paragraph (" & Longest_Length'Image
             & " units):");
   declare
      Middle : constant Positive := Documents.Byte_Length (Doc, Longest) / 2;
      Edits  : constant := 200;
   begin
      Start;
      for K in 1 .. Edits loop
         Documents.Replace (Doc, Longest, Middle, Middle - 1, "x");
         Documents.Lay_Out (Doc, Longest);
      end loop;
      Report ("typing a character and laying out (rewrap), each",
              Millis / Float (Edits));

      Start;
      for K in 1 .. 20 loop
         declare
            Wrapped : constant CoreText.Wrapping.Span_Vectors.Vector :=
              CoreText.Wrapping.Wrap
                (Font, Documents.Text (Doc, Longest), 640.0);
         begin
            pragma Assert (not Wrapped.Is_Empty);
         end;
      end loop;
      Report ("for comparison, wrapping it all again, each", Millis / 20.0);
   end;

   --  The lines after editing must be those of the text laid out afresh.
   declare
      Para    : constant Documents.Paragraph_Number := Longest;
      Mistakes : Natural := 0;
      Filler   : constant String := "quick brown fox quick brown fox";

      function Same return Boolean is
         Fresh : constant CoreText.Wrapping.Span_Vectors.Vector :=
           CoreText.Wrapping.Wrap (Font, Documents.Text (Doc, Para), 640.0);
      begin
         if Natural (Fresh.Length) /= Documents.Line_Count (Doc, Para) then
            return False;
         end if;
         for N in 1 .. Documents.Line_Count (Doc, Para) loop
            if Documents.Line (Doc, Para, N) /= Fresh (N) then
               return False;
            end if;
         end loop;
         return True;
      end Same;
   begin
      Documents.Lay_Out (Doc, Para);
      for K in 1 .. 300 loop
         declare
            Size  : constant Natural := Documents.Byte_Length (Doc, Para);

            --  The next character boundary at or after Index.
            function Aligned (Index : Positive) return Positive is
               At_Index : Positive := Index;
            begin
               while not Documents.Is_Boundary (Doc, Para, At_Index) loop
                  At_Index := At_Index + 1;
               end loop;
               return At_Index;
            end Aligned;

            Where : constant Positive :=
              Aligned (1 + (K * 7919) mod (Size + 1));
            Cut   : constant Natural :=
              Aligned
                (Natural'Min (Size + 1, Where + (K * 31) mod 40)) - Where;
         begin
            Documents.Replace
              (Doc, Para, Where, Where + Cut - 1,
               (if K mod 3 = 0 then "" else Filler (1 .. K mod 17)));
            if K mod 4 = 0 then  --  sometimes two edits before laying out
               Documents.Replace (Doc, Para, 1, 0, "ab ");
            end if;
            Documents.Lay_Out (Doc, Para);
            if not Same then
               Mistakes := Mistakes + 1;
            end if;
         end;
      end loop;
      Put_Line ("rewrapped after 300 edits, wrong:" & Mistakes'Image);

      --  Splitting and joining.
      declare
         Before : constant Natural := Documents.Count (Doc);
      begin
         Documents.Split (Doc, Para, Documents.Byte_Length (Doc, Para) / 2);
         Documents.Join (Doc, Para);
         Documents.Lay_Out (Doc, Para);
         Put_Line ("split and join, same count: "
                   & Boolean'Image (Documents.Count (Doc) = Before)
                   & ", lines right: " & Boolean'Image (Same));
      end;
   end;

   --  Shaping and rasterizing what a screen shows.
   declare
      use CoreText.Shaping;
      Reg    : Registry;
      Line   : CoreText.Shaping.Shaped;
      Image  : Glyphs.Image;
      Lines  : Natural := 0;
      Made   : Natural := 0;
      Anchor : Documents.Paragraph_Number := Documents.Count (Doc) / 2;
      Offset : Float := 0.0;
      First, Last : Documents.Paragraph_Number;
   begin
      Documents.Visible (Doc, Anchor, Offset, Extent, First, Last);
      Start;
      for P in First .. Last loop
         for N in 1 .. Documents.Line_Count (Doc, P) loop
            Documents.Shape_Line (Doc, Reg, P, N, Line);
            Lines := Lines + 1;
         end loop;
      end loop;
      Put_Line ("shaping a screen:");
      Report ("lines" & Lines'Image & ", all", Millis);

      Start;
      for Id in 1 .. 2_000 loop
         Glyphs.Rasterize
           (Reg, 1, Interfaces.Unsigned_16 (Id), 36.0, 0.0, Image);
         Made := Made + 1;
      end loop;
      Report ("rasterizing a glyph at 36 px, each", Millis / Float (Made));
   end;
end Bench;
