with Ada.Strings.Unbounded;
with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with CoreText.Fonts;
with CoreText.Wrapping;
with Goldens;
with Texts.Documents;
with Typeset.Layouts;
with Typeset.Samples;

package body Document_Tests is

   package Docs renames Texts.Documents;
   package Layouts renames Typeset.Layouts;

   use type Texts.Position;
   use type Texts.Paragraph_Id;
   use type CoreText.Wrapping.Span;
   use type Docs.Version;

   LF : constant Character := ASCII.LF;

   function UTF_8 (Text : Wide_Wide_String) return String is
     (Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode (Text));

   function Image (At_Point : Texts.Position) return String is
     ("(" & At_Point.Paragraph'Image & "," & At_Point.Index'Image & ")");

   procedure Check (Name : String; Doc : Docs.Document; Expected : String)
   is
   begin
      Goldens.Check_Text (Name, Expected, Docs.Whole (Doc));
   end Check;

   procedure Check_Count
     (Name : String; Doc : Docs.Document; Expected : Positive) is
   begin
      Goldens.Check_Text
        (Name, Expected'Image, Positive'(Docs.Count (Doc))'Image);
   end Check_Count;

   procedure Loading is
      Doc : Docs.Document;
   begin
      Check ("document-empty", Doc, "");
      Docs.Load (Doc, "one" & ASCII.CR & LF & "two" & LF & LF & "four");
      Check ("document-loaded", Doc, "one" & LF & "two" & LF & LF & "four");
      Check_Count ("document-loaded-count", Doc, 4);
      Goldens.Check_Text
        ("document-loaded-state", " 0", Docs.State (Doc)'Image);
   end Loading;

   procedure Splicing is
      Doc : Docs.Document;
      Before : Docs.Version;
   begin
      Docs.Load (Doc, "alpha" & LF & "beta" & LF & "gamma" & LF & "delta");

      --  Across three paragraphs, with two in their place: at once.
      Before := Docs.Current (Doc);
      Docs.Replace (Doc, (1, 3), (3, 3), "X" & LF & "Y" & LF & "Z");
      Check ("document-splice", Doc,
             "alX" & LF & "Y" & LF & "Zmma" & LF & "delta");
      Goldens.Check_Text
        ("document-splice-one-change", " 1",
         Docs.Version'Image (Docs.Current (Doc) - Before));
      declare
         Done : constant Docs.Change := Docs.Change_After (Doc, Before);
      begin
         Goldens.Check_Text
           ("document-splice-change", "( 3, 3)( 3, 2) 2 2 1",
            Image (Done.To) & Image (Done.Ending) & Done.From_Units'Image
            & Done.To_Units'Image & Done.End_Units'Image);
      end;

      --  All of it away, and back.
      Docs.Replace (Doc, (1, 1), Docs.Text_End (Doc), "");
      Check ("document-splice-all", Doc, "");
      declare
         From, To : Texts.Position;
      begin
         Docs.Undo (Doc, From, To);
         Check ("document-splice-all-undone", Doc,
                "alX" & LF & "Y" & LF & "Zmma" & LF & "delta");
         Goldens.Check_Text
           ("document-splice-all-undone-range", "TRUE",
            Boolean'Image (From = (1, 1) and then To = (4, 6)));
      end;
   end Splicing;

   procedure Ids is
      Doc : Docs.Document;
      From, To : Texts.Position;
   begin
      Docs.Load (Doc, "one" & LF & "two" & LF & "three");
      declare
         First  : constant Texts.Paragraph_Id := Docs.Id (Doc, 1);
         Second : constant Texts.Paragraph_Id := Docs.Id (Doc, 2);
         Third  : constant Texts.Paragraph_Id := Docs.Id (Doc, 3);
      begin
         --  Joined, the second goes; the first keeps its id.
         Docs.Replace (Doc, (1, 4), (2, 1), "");
         Goldens.Check_Text
           ("document-ids-joined", "TRUE",
            Boolean'Image
              (Docs.Id (Doc, 1) = First and then Docs.Find (Doc, Second) = 0
               and then Docs.Find (Doc, Third) = 2));

         --  Undone, the second is back, with its id.
         Docs.Undo (Doc, From, To);
         Goldens.Check_Text
           ("document-ids-restored", "TRUE",
            Boolean'Image
              (Docs.Find (Doc, Second) = 2
               and then Docs.Find (Doc, Third) = 3));

         --  Broken in two, the first keeps its id, before the break; the
         --  new one is new; redone after undoing, it is the same again.
         Docs.Replace (Doc, (1, 2), (1, 2), [LF]);
         declare
            Made : constant Texts.Paragraph_Id := Docs.Id (Doc, 2);
         begin
            Goldens.Check_Text
              ("document-ids-split", "TRUE",
               Boolean'Image
                 (Docs.Id (Doc, 1) = First and then Made /= Second
                  and then Made /= Third and then Made /= First));
            Docs.Undo (Doc, From, To);
            Docs.Redo (Doc, From, To);
            Goldens.Check_Text
              ("document-ids-split-redone", "TRUE",
               Boolean'Image (Docs.Id (Doc, 2) = Made));
         end;
      end;
   end Ids;

   procedure Kinds is
      Doc : Docs.Document;
      From, To : Texts.Position;
      Heading : constant Texts.Paragraph_Kind := 1;
   begin
      Docs.Load (Doc, "Title" & LF & "Text");
      Docs.Set_Kind (Doc, 1, Heading);
      Docs.Undo (Doc, From, To);
      Goldens.Check_Text
        ("document-kind-undone", Texts.Plain'Image, Docs.Kind (Doc, 1)'Image);
      Docs.Redo (Doc, From, To);
      Goldens.Check_Text
        ("document-kind-redone", Heading'Image, Docs.Kind (Doc, 1)'Image);

      --  A paragraph that goes and comes back keeps its kind.
      Docs.Set_Kind (Doc, 2, Heading);
      Docs.Replace (Doc, (1, 6), (2, 5), "");
      Docs.Undo (Doc, From, To);
      Goldens.Check_Text
        ("document-kind-restored", Heading'Image, Docs.Kind (Doc, 2)'Image);
   end Kinds;

   procedure Steps is
      Doc : Docs.Document;
      From, To : Texts.Position;
   begin
      Docs.Load (Doc, "Skua");

      --  An application's command: several edits, undone as one.
      Docs.Begin_Step (Doc);
      Docs.Replace (Doc, (1, 1), (1, 1), "Great ");
      Docs.Set_Kind (Doc, 1, 3);
      Docs.Begin_Step (Doc);  --  nested: part of the same
      Docs.Replace (Doc, Docs.Text_End (Doc), Docs.Text_End (Doc),
                    LF & "Bonxie");
      Docs.End_Step (Doc);
      Docs.End_Step (Doc);
      Check ("document-step-done", Doc, "Great Skua" & LF & "Bonxie");

      Docs.Undo (Doc, From, To);
      Check ("document-step-undone", Doc, "Skua");
      Goldens.Check_Text
        ("document-step-undone-kind", Texts.Plain'Image,
         Docs.Kind (Doc, 1)'Image);
      Docs.Redo (Doc, From, To);
      Check ("document-step-redone", Doc, "Great Skua" & LF & "Bonxie");

      --  A step with nothing in it is not one.
      Docs.Begin_Step (Doc);
      Docs.End_Step (Doc);
      Docs.Undo (Doc, From, To);
      Check ("document-empty-step", Doc, "Skua");
   end Steps;

   procedure Joining_Edits is
      Doc : Docs.Document;
      From, To : Texts.Position;
   begin
      Docs.Load (Doc, "");
      for C of String'("Bonxie") loop
         Docs.Replace (Doc, Docs.Text_End (Doc), Docs.Text_End (Doc), [C],
                       Undo_As => Docs.Typing);
      end loop;
      Docs.Seal (Doc);  --  as when the caret moves
      Docs.Replace (Doc, Docs.Text_End (Doc), Docs.Text_End (Doc), "s",
                    Undo_As => Docs.Typing);
      Docs.Undo (Doc, From, To);
      Check ("document-sealed", Doc, "Bonxie");
      Docs.Undo (Doc, From, To);
      Check ("document-joined", Doc, "");
   end Joining_Edits;

   procedure Units is
      Doc   : Docs.Document;
      Piece : constant String := UTF_8 ("ab é 日本 🐦 c");
      Text  : String (1 .. 40 * Piece'Length);
      Wrong : Natural := 0;
   begin
      --  Across many of the offsets kept, with characters of every size
      --  falling on them.
      for K in 0 .. 39 loop
         Text (K * Piece'Length + 1 .. (K + 1) * Piece'Length) := Piece;
      end loop;
      Docs.Load (Doc, Text);
      for Index in 1 .. Text'Length + 1 loop
         if Docs.Is_Boundary (Doc, 1, Index) then
            declare
               Expected : constant Natural :=
                 Texts.UTF16_Length (Text (1 .. Index - 1));
            begin
               if Docs.Units_Before (Doc, 1, Index) /= Expected
                 or else Docs.Index_Of (Doc, 1, Expected) /= Index
               then
                  Wrong := Wrong + 1;
               end if;
            end;
         end if;
      end loop;
      Goldens.Check_Text ("document-units", " 0", Wrong'Image);

      --  And again after an edit before the end.
      Docs.Replace
        (Doc, (1, 7 * Piece'Length + 1), (1, 7 * Piece'Length + 1), Piece);
      Goldens.Check_Text
        ("document-units-edited", Natural'Image (Texts.UTF16_Length
                                                   (Docs.Text (Doc, 1))),
         Natural'Image
           (Docs.Units_Before (Doc, 1, Docs.Byte_Length (Doc, 1) + 1)));
   end Units;

   procedure Against_A_String is
      Doc      : Docs.Document;
      Expected : Ada.Strings.Unbounded.Unbounded_String;
      Seed     : Long_Long_Integer := 1;
      Wrong    : Natural := 0;

      function Piece (Which : Natural) return String is
        (case Which is
            when 0 => "",
            when 1 => "x",
            when 2 => "skua ",
            when 3 => UTF_8 ("é日🐦"),
            when 4 => [LF],
            when others => "a" & LF & UTF_8 ("日本") & LF & "b");

      function Next (Below : Positive) return Natural is
      begin
         Seed := (Seed * 1_103_515_245 + 12_345) mod 2 ** 31;
         return Natural (Seed / 7 mod Long_Long_Integer (Below));
      end Next;

      --  The byte of the whole text, a line to each paragraph, that a
      --  position is at.
      function Offset (At_Point : Texts.Position) return Positive is
         Result : Positive := 1;
      begin
         for Para in 1 .. At_Point.Paragraph - 1 loop
            Result := Result + Docs.Byte_Length (Doc, Para) + 1;
         end loop;
         return Result + At_Point.Index - 1;
      end Offset;

      --  A position in the text at a character, near where the last edit
      --  was, usually: as typing goes.
      function Somewhere (Near : Texts.Position) return Texts.Position is
         Para  : constant Positive :=
           (if Next (4) = 0 then 1 + Next (Docs.Count (Doc))
            else Near.Paragraph);
         Index : Positive :=
           (if Para = Near.Paragraph and then Next (3) > 0
            then Positive'Min
                   (Docs.Byte_Length (Doc, Para) + 1,
                    Near.Index + Next (600))
            else 1 + Next (Docs.Byte_Length (Doc, Para) + 1));
      begin
         while not Docs.Is_Boundary (Doc, Para, Index) loop
            Index := Index - 1;
         end loop;
         return (Para, Index);
      end Somewhere;

      Last : Texts.Position := (1, 1);
   begin
      --  Paragraphs long enough for the gap and the offsets kept to
      --  matter, edited in place, back and forth, and broken and joined.
      declare
         Long : String (1 .. 3_000);
      begin
         for I in Long'Range loop
            Long (I) := Character'Val (Character'Pos ('a') + I mod 26);
         end loop;
         Expected := Ada.Strings.Unbounded.To_Unbounded_String
           (Long & LF & Long (1 .. 700) & LF & UTF_8 ("日本語のテキスト"));
         Docs.Load (Doc, Ada.Strings.Unbounded.To_String (Expected));
      end;

      for K in 1 .. 1_000 loop
         declare
            From  : constant Texts.Position := Somewhere (Last);
            To    : Texts.Position := Somewhere (From);
            Added : constant String := Piece (Next (6));
         begin
            if To < From or else Next (3) > 0 then
               To := From;  --  mostly typing
            end if;
            Ada.Strings.Unbounded.Replace_Slice
              (Expected, Offset (From), Offset (To) - 1, Added);
            Docs.Replace (Doc, From, To, Added);
            Last := Texts.End_After (From, Added);

            if Docs.Whole (Doc) /= Ada.Strings.Unbounded.To_String (Expected)
            then
               Wrong := Wrong + 1;
            end if;
            --  The UTF-16 offsets, kept as far as asked for.
            declare
               Para  : constant Positive := Last.Paragraph;
               Text  : constant String := Docs.Text (Doc, Para);
               Other : constant Texts.Position := Somewhere (Last);
            begin
               if Docs.Length (Doc, Para) /= Texts.UTF16_Length (Text)
                 or else Docs.Units_Before (Doc, Para, Last.Index)
                         /= Texts.UTF16_Length
                              (Text (Text'First
                                     .. Text'First + Last.Index - 2))
                 or else Docs.Index_Of
                           (Doc, Other.Paragraph,
                            Docs.Units_Before
                              (Doc, Other.Paragraph, Other.Index))
                         /= Other.Index
               then
                  Wrong := Wrong + 1;
               end if;
            end;
         end;
      end loop;
      Goldens.Check_Text ("document-against-a-string", " 0", Wrong'Image);
   end Against_A_String;

   procedure Mapping is
      Done : constant Docs.Change :=
        (From => (2, 3), To => (4, 5), Ending => (2, 7), others => <>);
      --  Paragraphs 2 to 4 joined, with four bytes in place of what was
      --  between.
   begin
      Goldens.Check_Text
        ("document-map",
         "( 1, 9)( 2, 2)( 2, 3)( 2, 3)( 2, 7)( 2, 9)( 3, 4)",
         Image (Docs.Map (Done, (1, 9))) & Image (Docs.Map (Done, (2, 2)))
         & Image (Docs.Map (Done, (2, 9))) & Image (Docs.Map (Done, (3, 1)))
         & Image (Docs.Map (Done, (4, 5))) & Image (Docs.Map (Done, (4, 7)))
         & Image (Docs.Map (Done, (5, 4))));
   end Mapping;

   procedure Lines_After_Edits is
      Doc    : Docs.Document;
      Laid   : Layouts.Layout;
      Font   : CoreText.Fonts.Font;
      Width  : constant Float := 640.0;
      Wrong  : Natural := 0;
      Filler : constant String := "quick brown fox quick brown fox";

      --  Whether the lines made of every paragraph are those of its text
      --  broken afresh.
      function Right return Boolean is
      begin
         for Para in 1 .. Docs.Count (Doc) loop
            if Layouts.Is_Laid_Out (Laid, Para) then
               declare
                  Fresh : constant CoreText.Wrapping.Span_Vectors.Vector :=
                    CoreText.Wrapping.Wrap
                      (Font, Docs.Text (Doc, Para), Width);
               begin
                  --  All of them, or the first of them, as far as made.
                  if (if Layouts.Is_Complete (Laid, Para)
                      then Natural (Fresh.Length)
                           /= Layouts.Line_Count (Laid, Para)
                      else Natural (Fresh.Length)
                           < Layouts.Line_Count (Laid, Para))
                  then
                     return False;
                  end if;
                  for N in 1 .. Layouts.Line_Count (Laid, Para) loop
                     if Layouts.Line (Laid, Para, N) /= Fresh (N) then
                        return False;
                     end if;
                  end loop;
               end;
            end if;
         end loop;
         return True;
      end Right;
   begin
      CoreText.Fonts.Open (Font, "Georgia", 18.0);
      Docs.Load (Doc, Typeset.Samples.Document (30));
      Layouts.Configure (Laid, "Georgia", 18.0, Width, 8.0);
      Layouts.Sync (Laid, Doc);

      --  Edits of every kind, at pseudo-random places in paragraphs laid
      --  out wholly, partly (as a long one is) or not at all, sometimes
      --  several before the layout catches up.
      for K in 1 .. 300 loop
         declare
            Para : constant Positive := 1 + (K * 7) mod Docs.Count (Doc);
            Size : constant Natural := Docs.Byte_Length (Doc, Para);

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
            Cut   : constant Positive :=
              Aligned (Natural'Min (Size + 1, Where + (K * 31) mod 40));
         begin
            if K mod 5 = 0 then
               Layouts.Sync (Laid, Doc);
               Layouts.Lay_Out (Laid, Doc, Para, Lines => 1 + K mod 4);
            elsif K mod 5 = 1 then
               Layouts.Sync (Laid, Doc);
               Layouts.Lay_Out (Laid, Doc, Para);
            end if;

            case K mod 6 is
               when 0 =>  --  break the paragraph
                  Docs.Replace (Doc, (Para, Where), (Para, Where), [LF]);
               when 1 =>  --  join it to the next
                  if Para < Docs.Count (Doc) then
                     Docs.Replace
                       (Doc, Docs.Paragraph_End (Doc, Para), (Para + 1, 1),
                        "");
                  end if;
               when 2 =>  --  replace across paragraphs
                  if Para + 2 <= Docs.Count (Doc) then
                     Docs.Replace
                       (Doc, (Para, Where), (Para + 2, 1),
                        "one" & LF & "two ");
                  end if;
               when others =>
                  Docs.Replace
                    (Doc, (Para, Where), (Para, Cut),
                     (if K mod 3 = 0 then "" else Filler (1 .. K mod 17)));
            end case;

            if K mod 4 /= 0 then  --  sometimes two edits before syncing
               Layouts.Sync (Laid, Doc);
               if not Right then
                  Wrong := Wrong + 1;
               end if;
            end if;
         end;
      end loop;
      Goldens.Check_Text ("layout-lines-after-edits", " 0", Wrong'Image);

      --  The heights add up.
      declare
         Sum : Float := 0.0;
      begin
         for Para in 1 .. Layouts.Count (Laid) loop
            Sum := Sum + Layouts.Height (Laid, Para);
         end loop;
         Goldens.Check_Text
           ("layout-heights-add-up", "TRUE",
            Boolean'Image
              (abs (Sum - Layouts.Total_Height (Laid)) < 0.01
               and then abs (Layouts.Top (Laid, Layouts.Count (Laid))
                             + Layouts.Height (Laid, Layouts.Count (Laid))
                             - Sum) < 0.01));
      end;
   end Lines_After_Edits;

end Document_Tests;
