with Ada.Command_Line;
with Ada.Float_Text_IO;
with Ada.Real_Time;
with Ada.Text_IO;
with CoreText.Fonts;
with CoreText.Shaping;
with CoreText.Shaping.Glyphs;
with CoreText.Wrapping;
with Interfaces;
with Texts.Documents;
with Typeset.Layouts;
with SDL3;
with SDL3.Windows;
with SDL3.Windows.Renderers;
with Typeset.Samples;
with Typeset.Views;

--  Measures laying out, scrolling and editing a long document, shaping
--  and rasterizing its text, and drawing it: bench [paragraphs]
procedure Bench is
   package Docs renames Texts.Documents;
   package Layouts renames Typeset.Layouts;
   package Renderers renames SDL3.Windows.Renderers;

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

   Doc  : Docs.Document;
   Laid : Layouts.Layout;

   procedure Scroll_Through (Label : String) is
      Anchor : Positive := 1;
      Offset : Float := 0.0;
      First, Last : Positive;
      Step   : constant Float := Layouts.Total_Height (Laid) / Float (Frames);
   begin
      Start;
      for Frame in 1 .. Frames loop
         Layouts.Scroll (Laid, Anchor, Offset, Step, Extent);
         Layouts.Visible (Laid, Doc, Anchor, Offset, Extent, First, Last);
      end loop;
      Report (Label & ", per frame", Millis / Float (Frames), "ms");
   end Scroll_Through;

   Font : CoreText.Fonts.Font;
   Longest, Longest_Length : Natural := 0;
begin
   Put_Line ("bench:" & Paragraphs'Image & " paragraphs,"
             & Natural'Image (Text'Length / 1024) & " KB");

   CoreText.Fonts.Open (Font, "Georgia", 18.0);
   Start;
   Docs.Load (Doc, Text);
   Layouts.Configure (Laid, "Georgia", 18.0, 640.0, 8.0);
   Layouts.Sync (Laid, Doc);
   Report ("configure and load", Millis);

   Start;
   declare
      Total : constant Float := Layouts.Total_Height (Laid);
   begin
      Report ("total height, estimated", Millis);
      Put_Line ("  estimate:" & Natural'Image (Natural (Total)) & " units");
   end;

   Put_Line ("scrolling through the whole document, from cold:");
   Scroll_Through ("first pass (lays out as it goes)");
   Scroll_Through ("second pass (laid out)");
   Put_Line ("  total height now:"
             & Natural'Image (Natural (Layouts.Total_Height (Laid)))
             & " units");

   --  Edits: in the longest paragraph.
   for P in 1 .. Docs.Count (Doc) loop
      if Docs.Length (Doc, P) > Longest_Length then
         Longest := P;
         Longest_Length := Docs.Length (Doc, P);
      end if;
   end loop;
   Put_Line ("editing the longest paragraph (" & Longest_Length'Image
             & " units):");
   declare
      Middle : constant Positive :=
        Docs.Index_Of (Doc, Longest, Longest_Length / 2);
      Edits  : constant := 200;
   begin
      Start;
      for K in 1 .. Edits loop
         Docs.Replace (Doc, (Longest, Middle), (Longest, Middle), "x");
         Layouts.Sync (Laid, Doc);
         Layouts.Lay_Out (Laid, Doc, Longest);
      end loop;
      Report ("typing a character and laying out (rewrap), each",
              Millis / Float (Edits));

      Start;
      for K in 1 .. 20 loop
         declare
            Wrapped : constant CoreText.Wrapping.Span_Vectors.Vector :=
              CoreText.Wrapping.Wrap
                (Font, Docs.Text (Doc, Longest), 640.0);
         begin
            pragma Assert (not Wrapped.Is_Empty);
         end;
      end loop;
      Report ("for comparison, wrapping it all again, each", Millis / 20.0);
   end;

   --  The lines after editing must be those of the text laid out afresh.
   declare
      Para    : constant Positive := Longest;
      Mistakes : Natural := 0;
      Filler   : constant String := "quick brown fox quick brown fox";

      function Same return Boolean is
         Fresh : constant CoreText.Wrapping.Span_Vectors.Vector :=
           CoreText.Wrapping.Wrap (Font, Docs.Text (Doc, Para), 640.0);
      begin
         if Natural (Fresh.Length) /= Layouts.Line_Count (Laid, Para) then
            return False;
         end if;
         for N in 1 .. Layouts.Line_Count (Laid, Para) loop
            if Layouts.Line (Laid, Para, N) /= Fresh (N) then
               return False;
            end if;
         end loop;
         return True;
      end Same;
   begin
      Layouts.Lay_Out (Laid, Doc, Para);
      for K in 1 .. 300 loop
         declare
            Size  : constant Natural := Docs.Byte_Length (Doc, Para);

            --  The next character boundary at or after Index.
            function Aligned (Index : Positive) return Positive is
               At_Index : Positive := Index;
            begin
               while not Docs.Is_Boundary (Doc, Para, At_Index) loop
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
            Docs.Replace
              (Doc, (Para, Where), (Para, Where + Cut),
               (if K mod 3 = 0 then "" else Filler (1 .. K mod 17)));
            if K mod 4 = 0 then  --  sometimes two edits before laying out
               Docs.Replace (Doc, (Para, 1), (Para, 1), "ab ");
            end if;
            Layouts.Sync (Laid, Doc);
            Layouts.Lay_Out (Laid, Doc, Para);
            if not Same then
               Mistakes := Mistakes + 1;
            end if;
         end;
      end loop;
      Put_Line ("rewrapped after 300 edits, wrong:" & Mistakes'Image);

      --  Splitting and joining.
      declare
         Before : constant Natural := Docs.Count (Doc);
         Half   : constant Positive :=
           Docs.Index_Of (Doc, Para, Docs.Length (Doc, Para) / 2);
      begin
         Docs.Replace (Doc, (Para, Half), (Para, Half), [ASCII.LF]);
         Docs.Replace (Doc, Docs.Paragraph_End (Doc, Para), (Para + 1, 1), "");
         Layouts.Sync (Laid, Doc);
         Layouts.Lay_Out (Laid, Doc, Para);
         Put_Line ("split and join, same count: "
                   & Boolean'Image (Docs.Count (Doc) = Before)
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
      Anchor : Positive := Docs.Count (Doc) / 2;
      Offset : Float := 0.0;
      First, Last : Positive;
   begin
      Layouts.Visible (Laid, Doc, Anchor, Offset, Extent, First, Last);
      Start;
      for P in First .. Last loop
         for N in 1 .. Layouts.Line_Count (Laid, P) loop
            Layouts.Shape_Line (Laid, Doc, Reg, P, N, Line);
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

   --  Drawing, as the viewer does, into a hidden window without vsync
   --  so that frames are not paced by the display.
   SDL3.Initialize;
   declare
      Win    : SDL3.Windows.Window;
      Target : Renderers.Renderer;  --  after Win: it is destroyed first
      Viewed : Typeset.Views.View;  --  and after Target
      Ink    : constant Renderers.Color := (230, 230, 235, 255);
      Paper  : constant Renderers.Color := (30, 30, 36, 255);
      Width, Height : Natural;
      Density : Float;
      Drawing : Duration := 0.0;
      --  In Views.Draw: Present waits for the display even without
      --  vsync, so the frames are timed without it.
      Draw_Frames : constant := 300;
      Anchor : Positive := 1;
      Offset : Float := 0.0;

      procedure Frame (Zoom : Float; Settled : Boolean) is
         Scale : constant Float := Density * Zoom;
      begin
         Renderers.Clear (Target, Paper);
         Started := Clock;
         Typeset.Views.Draw
           (Viewed, Laid, Doc, Target, Ink, Anchor, Offset,
            Left    => Float'Max
                         (0.0, (Float (Width) - 640.0 * Scale) / 2.0),
            Top     => 0.0,
            Width   => Width,
            Height  => Height,
            Scale   => Scale,
            Settled => Settled);
         Drawing := Drawing + To_Duration (Clock - Started);
         Renderers.Present (Target);
      end Frame;

      function Drawn (Count : Positive) return Float is
        (Float (Drawing) * 1000.0 / Float (Count));

      procedure Report_Made (Shaped_Before, Made_Before : Natural) is
      begin
         Put_Line ("    lines shaped:"
                   & Natural'Image
                       (Typeset.Views.Lines_Shaped (Viewed) - Shaped_Before)
                   & ", glyphs rasterized:"
                   & Natural'Image
                       (Typeset.Views.Glyphs_Made (Viewed) - Made_Before));
      end Report_Made;
   begin
      SDL3.Windows.Create
        (Win, "bench", 1000, 800, High_Density => True, Hidden => True);
      Density := SDL3.Windows.Pixel_Density (Win);
      Renderers.Create (Target, Win, VSync => False);
      Renderers.Output_Size (Target, Width, Height);
      Put_Line ("drawing" & Width'Image & " x" & Height'Image
                & " pixels:");

      declare
         Step : constant Float :=
           Layouts.Total_Height (Laid) / Float (Draw_Frames);
      begin
         Drawing := 0.0;
         for K in 1 .. Draw_Frames loop
            Frame (1.0, Settled => True);
            Layouts.Scroll
              (Laid, Anchor, Offset, Step, Float (Height) / Density);
         end loop;
         Report ("scrolling through, a new screen each frame, per frame",
                 Drawn (Draw_Frames));
         Report_Made (0, 0);
      end;

      Anchor := Docs.Count (Doc) / 2;
      Offset := 0.0;
      Frame (1.0, Settled => True);
      declare
         Shaped_Before : constant Natural :=
           Typeset.Views.Lines_Shaped (Viewed);
         Made_Before   : constant Natural :=
           Typeset.Views.Glyphs_Made (Viewed);
      begin
         Drawing := 0.0;
         for K in 1 .. Draw_Frames loop
            Frame (1.0, Settled => True);
         end loop;
         Report ("holding still, warm, per frame", Drawn (Draw_Frames));

         Drawing := 0.0;
         for K in 1 .. Draw_Frames loop
            Layouts.Scroll
              (Laid, Anchor, Offset,
               (if (K / 50) mod 2 = 0 then 10.0 else -10.0),
               Float (Height) / Density);
            Frame (1.0, Settled => True);
         end loop;
         Report ("scrolling a little back and forth, per frame",
                 Drawn (Draw_Frames));
         Report_Made (Shaped_Before, Made_Before);
      end;

      declare
         Zooms : constant := 200;
         Shaped_Before : constant Natural :=
           Typeset.Views.Lines_Shaped (Viewed);
         Made_Before   : constant Natural :=
           Typeset.Views.Glyphs_Made (Viewed);
      begin
         Drawing := 0.0;
         for K in 1 .. Zooms loop
            Frame (1.0 + Float (K) / Float (Zooms), Settled => False);
         end loop;
         Report ("zooming in, per frame", Drawn (Zooms));
         Report_Made (Shaped_Before, Made_Before);
      end;
   end;
   SDL3.Shutdown;
end Bench;
