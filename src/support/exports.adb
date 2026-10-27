with Texts;

package body Exports is

   use type Texts.Paragraph_Kind;
   use type Unbounded.Unbounded_String;

   package Docs renames Texts.Documents;

   Bullet_Mark : constant String := [Character'Val (16#E2#), Character'Val (16#80#), Character'Val (16#A2#), ' '];
   --  What the editor puts before an item of a bulleted list.

   package Cut_Vectors is new Ada.Containers.Vectors (Positive, Positive);
   package Cut_Sorting is new Cut_Vectors.Generic_Sorting;

   function Same (Left, Right : Span) return Boolean
   is (Left.Marks = Right.Marks and then Left.Address = Right.Address);

   --  The spans of paragraph Para from byte Start: cut where a format begins or ends.
   function Spans_Of
     (Item : Docs.Document; Para : Positive; Start : Positive; Titled : Boolean) return Span_Vectors.Vector
   is
      Stop   : constant Positive := Docs.Byte_Length (Item, Para) + 1;
      Result : Span_Vectors.Vector;
      Cuts   : Cut_Vectors.Vector;
   begin
      Cuts.Append (Start);
      Cuts.Append (Stop);
      for Index in 1 .. Docs.Run_Count (Item) loop
         declare
            R : constant Docs.Format_Run := Docs.Run (Item, Index);
         begin
            if R.From.Paragraph <= Para and then Para <= R.To.Paragraph then
               Cuts.Append (Natural'Max (Start, (if R.From.Paragraph = Para then R.From.Index else 1)));
               Cuts.Append (Natural'Min (Stop, (if R.To.Paragraph = Para then R.To.Index else Stop)));
            end if;
         end;
      end loop;
      Cut_Sorting.Sort (Cuts);
      for Each in Cuts.First_Index .. Cuts.Last_Index - 1 loop
         declare
            From : constant Positive := Cuts (Each);
            To   : constant Positive := Cuts (Each + 1);
            Part : Span;
         begin
            if From < To then
               Part.Words := Unbounded.To_Unbounded_String (Docs.Slice (Item, Para, From, To));
               for Index in 1 .. Docs.Run_Count (Item) loop
                  declare
                     R      : constant Docs.Format_Run := Docs.Run (Item, Index);
                     Covers : constant Boolean :=
                       R.From.Paragraph <= Para
                       and then Para <= R.To.Paragraph
                       and then (R.From.Paragraph < Para or else R.From.Index <= From)
                       and then (R.To.Paragraph > Para or else To <= R.To.Index);
                  begin
                     if Covers then
                        case R.Style is
                           when Docs.Bold                                             =>
                              Part.Marks (Bold) := not Titled;

                           when Docs.Italic                                           =>
                              Part.Marks (Italic) := True;

                           when Docs.Underline                                        =>
                              Part.Marks (Underlined) := True;

                           when Docs.Strikethrough                                    =>
                              Part.Marks (Struck) := True;

                           when Docs.Linked                                           =>
                              Part.Marks (Linked) := True;
                              Part.Address := R.Name;

                           when Docs.Faded | Docs.Sized | Docs.Faced | Docs.Versioned =>
                              null;
                        end case;
                     end if;
                  end;
               end loop;
               if not Result.Is_Empty and then Same (Result.Last_Element, Part) then
                  Unbounded.Append (Result (Result.Last_Index).Words, Part.Words);
               else
                  Result.Append (Part);
               end if;
            end if;
         end;
      end loop;
      return Result;
   end Spans_Of;

   function Escaped (Words : String) return String is
      Made : Unbounded.Unbounded_String;
   begin
      for C of Words loop
         case C is
            when '&'                                                                            =>
               Unbounded.Append (Made, "&amp;");

            when '<'                                                                            =>
               Unbounded.Append (Made, "&lt;");

            when '>'                                                                            =>
               Unbounded.Append (Made, "&gt;");

            when '"'                                                                            =>
               Unbounded.Append (Made, "&quot;");

            when ASCII.NUL .. ASCII.BS | ASCII.VT | ASCII.FF | ASCII.SO .. ASCII.US | ASCII.DEL =>
               null;

            when others                                                                         =>
               Unbounded.Append (Made, C);
         end case;
      end loop;
      return Unbounded.To_String (Made);
   end Escaped;

   function Words_Of (Item : Block) return String is
      Made : Unbounded.Unbounded_String;
   begin
      for Each of Item.Spans loop
         Unbounded.Append (Made, Each.Words);
      end loop;
      return Unbounded.To_String (Made);
   end Words_Of;

   function Blocks_Of (Item : Docs.Document) return Block_Vectors.Vector is
      Result : Block_Vectors.Vector;
   begin
      for Para in 1 .. Docs.Count (Item) loop
         declare
            Line    : constant String := Docs.Text (Item, Para);
            Kind    : constant Texts.Paragraph_Kind := Docs.Kind (Item, Para);
            Inset   : constant Texts.Paragraph_Inset := Docs.Inset (Item, Para);
            Lead    : Natural := 0;
            Skip    : Natural := 0;
            Which   : Block_Kinds := Paragraph;
            Figures : Natural := 0;
            Figure  : Unbounded.Unbounded_String;
         begin
            if Kind = Texts.Plain or else Kind > Texts.Heading_3 then
               while Lead < Line'Length and then Line (Line'First + Lead) = ' ' loop
                  Lead := Lead + 1;
               end loop;
               declare
                  Rest : constant String := Line (Line'First + Lead .. Line'Last);
               begin
                  if Rest'Length >= Bullet_Mark'Length
                    and then Rest (Rest'First .. Rest'First + Bullet_Mark'Length - 1) = Bullet_Mark
                  then
                     Which := Bullet;
                     Skip := Lead + Bullet_Mark'Length;
                  else
                     while Figures < Rest'Length and then Rest (Rest'First + Figures) in '0' .. '9' loop
                        Figures := Figures + 1;
                     end loop;
                     if Figures > 0
                       and then Rest'Length >= Figures + 2
                       and then Rest (Rest'First + Figures .. Rest'First + Figures + 1) = ". "
                     then
                        Which := Number;
                        Skip := Lead + Figures + 2;
                        Figure := Unbounded.To_Unbounded_String (Rest (Rest'First .. Rest'First + Figures - 1));
                     end if;
                  end if;
               end;
            end if;
            if not Is_Blank (Line (Line'First + Skip .. Line'Last)) then
               declare
                  Titled : constant Boolean := Kind in Texts.Heading_1 .. Texts.Heading_3;
                  Made   : constant Block :=
                    (Kind   => (if Titled then Heading else Which),
                     Level  => (if Titled then Heading_Level (Kind) else 1),
                     Figure => Figure,
                     Indent => Inset.Indent,
                     Quoted => Inset.Quoted,
                     Para   => Para,
                     Spans  => Spans_Of (Item, Para, Skip + 1, Titled));
               begin
                  if not Made.Spans.Is_Empty then
                     Result.Append (Made);
                  end if;
               end;
            end if;
         end;
      end loop;
      return Result;
   end Blocks_Of;

end Exports;
