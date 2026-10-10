with Interfaces.C;
with System;
with CoreText.Core;
with CoreText.Thin;

package body CoreText.Wrapping is

   use type System.Address;

   Margin : constant := 16;
   --  A window's lines must end this far before the window does (unless
   --  it ends the paragraph), so that what follows a line's break was in
   --  view when it was chosen.

   function Typesetter
     (Using : Fonts.Font; Text : Thin.Ref; From, Stop, Length : Natural)
      return Thin.Ref;
   --  A typesetter over the UTF-16 range [From, Stop) of Text, which is
   --  Length units long. Release it.

   function Typesetter
     (Using : Fonts.Font; Text : Thin.Ref; From, Stop, Length : Natural)
      return Thin.Ref
   is
      Sub  : Thin.Ref := Thin.Null_Ref;
      Whole : constant Boolean := From = 0 and then Stop = Length;
      Attr : Thin.Ref;
      Result : Thin.Ref;
   begin
      if not Whole then
         Sub := Thin.CF_String_Create_With_Substring
           (Thin.Null_Ref, Text,
            (Location => Interfaces.C.long (From),
             Length   => Interfaces.C.long (Stop - From)));
      end if;
      Attr := Thin.CF_Attributed_String_Create
        (Thin.Null_Ref, (if Whole then Text else Sub),
         Fonts.Attributes (Using));
      Core.Release (Sub);
      if Attr = Thin.Null_Ref then
         raise Error with "CFAttributedStringCreate failed";
      end if;
      Result := Thin.CT_Typesetter_Create (Attr);
      Core.Release (Attr);
      if Result = Thin.Null_Ref then
         raise Error with "CTTypesetterCreate failed";
      end if;
      return Result;
   end Typesetter;

   function Suggest_Break
     (Setter : Thin.Ref; Start : Natural; Width : Float) return Natural is
     (Start + Natural'Max
        (1, Natural (Thin.CT_Typesetter_Suggest_Line_Break
                       (Setter, Interfaces.C.long (Start),
                        Interfaces.C.double (Width)))));
   --  Where Setter would end a line starting at its index Start. At
   --  least one unit on, so that wrapping always advances.

   procedure Window_Lines
     (Using  : Fonts.Font;
      Text   : Thin.Ref;
      From, Stop, Length : Natural;
      Width  : Float;
      Result : in out Span_Vectors.Vector);
   --  Break the UTF-16 range [From, Stop) of Text into lines from From,
   --  appending them to Result and stopping before any line that reaches
   --  within Margin of Stop (unless Stop is Length, the paragraph's end).

   procedure Window_Lines
     (Using  : Fonts.Font;
      Text   : Thin.Ref;
      From, Stop, Length : Natural;
      Width  : Float;
      Result : in out Span_Vectors.Vector)
   is
      Setter : Thin.Ref := Typesetter (Using, Text, From, Stop, Length);
      Start  : Natural := From;
   begin
      while Start < Stop loop
         declare
            Last : constant Natural :=
              From + Suggest_Break (Setter, Start - From, Width);
         begin
            exit when Stop < Length and then Last > Stop - Margin;
            Result.Append (Span'(First => Start, Stop => Last));
            Start := Last;
         end;
      end loop;
      Core.Release (Setter);
   end Window_Lines;

   generic
      with function Stops (Item : Span) return Boolean;
   procedure Lines_From
     (Using    : Fonts.Font;
      Text     : Thin.Ref;
      From, Length : Natural;
      Width    : Float;
      First_Size : Positive;
      Result   : in out Span_Vectors.Vector;
      Stopped  : out Boolean;
      Stopped_At : out Span);
   --  Append the lines of paragraph Text, Length units long, from the
   --  line start From to its end, a window at a time, the first
   --  First_Size units long. Stops after the first line for which Stops
   --  is true, setting Stopped and Stopped_At to it.

   procedure Lines_From
     (Using    : Fonts.Font;
      Text     : Thin.Ref;
      From, Length : Natural;
      Width    : Float;
      First_Size : Positive;
      Result   : in out Span_Vectors.Vector;
      Stopped  : out Boolean;
      Stopped_At : out Span)
   is
      Start : Natural := From;
      Size  : Positive := First_Size;
   begin
      Stopped := False;
      Stopped_At := (0, 0);
      while Start < Length loop
         declare
            Got  : Span_Vectors.Vector;
            Used : Natural := 0;
         begin
            Window_Lines
              (Using, Text, Start, Natural'Min (Length, Start + Size),
               Length, Width, Got);

            if Got.Is_Empty then
               Size := 2 * Size;  --  a line longer than the window
            else
               for Item of Got loop
                  Used := Used + 1;
                  Result.Append (Item);
                  if Stops (Item) then
                     Stopped := True;
                     Stopped_At := Item;
                     return;
                  end if;
               end loop;
               Start := Got.Last_Element.Stop;
               Size := Window;
            end if;
         end;
      end loop;
   end Lines_From;

   function Never (Item : Span) return Boolean is (Item.First = Natural'Last);
   --  Never true: no line starts at the largest Natural.

   function Wrap
     (Using : Fonts.Font; Text : Strings.Text; Width : Float)
      return Span_Vectors.Vector
   is
      procedure All_Lines is new Lines_From (Never);

      Length  : constant Natural := Strings.Length (Text);
      Result  : Span_Vectors.Vector;
      Stopped : Boolean;
      Where   : Span;
   begin
      if Length = 0 then
         Result.Append (Span'(First => 0, Stop => 0));
      else
         All_Lines
           (Using, Strings.Handle (Text), 0, Length, Width, Window,
            Result, Stopped, Where);
      end if;
      return Result;
   end Wrap;

   function Wrap
     (Using : Fonts.Font; Text : String; Width : Float)
      return Span_Vectors.Vector
   is
      Held : Strings.Text;
   begin
      Strings.Set (Held, Text);
      return Wrap (Using, Held, Width);
   end Wrap;

   function Line_Starting_At
     (Lines : Span_Vectors.Vector; Unit : Natural) return Natural;
   --  The index of the line of Lines (sorted) that starts at Unit, or 0.

   function Line_Starting_At
     (Lines : Span_Vectors.Vector; Unit : Natural) return Natural
   is
      Low  : Natural := Lines.First_Index;
      High : Integer := Lines.Last_Index;
   begin
      while Low <= High loop
         declare
            Mid   : constant Natural := (Low + High) / 2;
            Start : constant Natural := Lines (Mid).First;
         begin
            if Start = Unit then
               return Mid;
            elsif Start < Unit then
               Low := Mid + 1;
            else
               High := Mid - 1;
            end if;
         end;
      end loop;
      return 0;
   end Line_Starting_At;

   function Rewrap
     (Using    : Fonts.Font;
      Old      : Span_Vectors.Vector;
      Text     : Strings.Text;
      Width    : Float;
      Edit_At  : Natural;
      Old_Stop : Natural;
      New_Stop : Natural)
      return Span_Vectors.Vector
   is
      Length : constant Natural := Strings.Length (Text);
      Delta_Units : constant Integer := New_Stop - Old_Stop;

      --  The line holding the edit, and one before: an edit at a line's
      --  start can let its first word fit on the line above.
      Edit_Line : Positive := Old.Last_Index;
   begin
      if Length = 0 or else Old.Last_Element.Stop = 0 then
         return Wrap (Using, Text, Width);
      end if;

      while Edit_Line > Old.First_Index
        and then Old (Edit_Line).First > Edit_At
      loop
         Edit_Line := Edit_Line - 1;
      end loop;

      declare
         Restart : constant Positive :=
           Positive'Max (Old.First_Index, Edit_Line - 1);

         --  Where Old's breaks resume: a line ending at or past the
         --  edit where an old line started has the old text after it.
         function Resumes (Item : Span) return Boolean is
           (Item.Stop >= New_Stop
            and then Item.Stop - Delta_Units >= 0
            and then Line_Starting_At (Old, Item.Stop - Delta_Units) /= 0);

         procedure Fresh_Lines is new Lines_From (Resumes);

         Result  : Span_Vectors.Vector;
         Stopped : Boolean;
         Where   : Span;
      begin
         for Index in Old.First_Index .. Restart - 1 loop
            Result.Append (Old (Index));
         end loop;

         --  Breaks usually resume within a few lines, so start small.
         Fresh_Lines
           (Using, Strings.Handle (Text), Old (Restart).First, Length,
            Width, Window / 4, Result, Stopped, Where);

         if Stopped then
            for Index in
              Line_Starting_At (Old, Where.Stop - Delta_Units)
                .. Old.Last_Index
            loop
               Result.Append
                 (Span'(First => Old (Index).First + Delta_Units,
                        Stop  => Old (Index).Stop + Delta_Units));
            end loop;
         end if;
         return Result;
      end;
   end Rewrap;

end CoreText.Wrapping;
