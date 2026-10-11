with CoreText.Wrapping;

package body UI.Text_Areas is

   package Documents renames Typeset.Documents;
   package Views renames Typeset.Views;
   package Events renames SDL3.Events;

   use Ada.Strings.Unbounded;
   use type Events.Key_Code;

   --  In points
   Outline       : constant Float := 1.0;
   Focus_Outline : constant Float := 2.0;
   Padding       : constant Float := 12.0;
   --  From the outside of the outline to the text.
   Caret_Width   : constant Float := 1.5;
   Underline     : constant Float := 1.5;
   Underline_Gap : constant Float := 2.0;  --  below the baseline

   Lines_Per_Notch : constant Float := 3.0;
   Page_Fraction   : constant Float := 0.9;
   --  How much of what is shown Page Up and Page Down move.

   --  Geometry

   function Scale (Item : Text_Area) return Float is
     (Item.Density * Item.Zoom);
   --  Pixels to a layout unit.

   function Inset (Item : Text_Area) return Float is
     (Padding * Item.Density);

   function Text_Top (Item : Text_Area) return Float is
     (Item.Top + Inset (Item));

   function Text_Width (Item : Text_Area) return Float is
     (Float'Max (0.0, Item.Width - 2.0 * Inset (Item)));

   function Text_Height (Item : Text_Area) return Float is
     (Float'Max (0.0, Item.Height - 2.0 * Inset (Item)));

   function Column (Item : Text_Area) return Float is
     (Float'Max
        (1.0, Float'Min (Item.Measure, Text_Width (Item) / Scale (Item))));
   --  How wide its lines may be, in layout units.

   function Column_Left (Item : Text_Area) return Float is
     (Item.Left + Inset (Item)
      + Float'Max
          (0.0, (Text_Width (Item) - Column (Item) * Scale (Item)) / 2.0));
   --  Where its lines start, in pixels.

   function Extent (Item : Text_Area) return Float is
     (Text_Height (Item) / Scale (Item));
   --  How much of the text is shown, in layout units.

   function View_Top (Item : in out Text_Area) return Float is
     (Documents.Top (Item.Doc, Item.Anchor) + Item.Offset);
   --  Of what is shown, down the text, in layout units.

   --  Positions

   function Is_Position (Item : Text_Area; At_Point : Position)
      return Boolean
   is (At_Point.Paragraph <= Documents.Count (Item.Doc)
       and then At_Point.Index
                <= Documents.Byte_Length (Item.Doc, At_Point.Paragraph) + 1
       and then Documents.Is_Boundary
                  (Item.Doc, At_Point.Paragraph, At_Point.Index));

   function Paragraph_End (Item : Text_Area; Para : Positive)
      return Position is
     ((Para, Documents.Byte_Length (Item.Doc, Para) + 1));

   function Text_End (Item : Text_Area) return Position is
     (Paragraph_End (Item, Documents.Count (Item.Doc)));

   function Units (Item : Text_Area; At_Point : Position) return Natural is
     (Documents.Units_Before (Item.Doc, At_Point.Paragraph, At_Point.Index));
   --  Where At_Point is in its paragraph's lines.

   function Line_Of
     (Item : in out Text_Area; At_Point : Position) return Positive;
   --  The line At_Point is on, of its paragraph, laid out.

   function Line_Of
     (Item : in out Text_Area; At_Point : Position) return Positive is
   begin
      Documents.Lay_Out (Item.Doc, At_Point.Paragraph);
      return Documents.Line_At
               (Item.Doc, At_Point.Paragraph, Units (Item, At_Point));
   end Line_Of;

   function End_After (From : Position; Added : String) return Position;
   --  Where Added ends, put at From.

   function End_After (From : Position; Added : String) return Position is
      Result : Position := From;
   begin
      for C of Added loop
         if C = ASCII.LF then
            Result := (Result.Paragraph + 1, 1);
         else
            Result.Index := Result.Index + 1;
         end if;
      end loop;
      return Result;
   end End_After;

   function Between (Item : Text_Area; From, To : Position) return String
     with Pre => not (To < From);
   --  The text from From to To, a line to each paragraph.

   function Between (Item : Text_Area; From, To : Position) return String is
      Result : Unbounded_String;
   begin
      for Para in From.Paragraph .. To.Paragraph loop
         declare
            Whole : constant String := Documents.Text (Item.Doc, Para);
            First : constant Positive :=
              (if Para = From.Paragraph then From.Index else 1);
            Stop  : constant Positive :=
              (if Para = To.Paragraph then To.Index else Whole'Length + 1);
         begin
            if Para > From.Paragraph then
               Append (Result, ASCII.LF);
            end if;
            Append
              (Result,
               Whole (Whole'First + First - 1 .. Whole'First + Stop - 2));
         end;
      end loop;
      return To_String (Result);
   end Between;

   --  Setting up

   procedure Configure
     (Item    : in out Text_Area;
      Family  : String;
      Size    : Float;
      Measure : Float;
      Spacing : Float := 0.0) is
   begin
      Item.Measure := Measure;
      Documents.Configure (Item.Doc, Family, Size, Measure, Spacing);
   end Configure;

   function Is_Configured (Item : Text_Area) return Boolean is
     (Documents.Is_Configured (Item.Doc));

   procedure Restart_Blink (Item : in out Text_Area);
   --  Show the caret, for a period from now.

   procedure Restart_Blink (Item : in out Text_Area) is
   begin
      Item.Since := Item.Now;
      Item.Caret_On := True;
   end Restart_Blink;

   procedure Load (Item : in out Text_Area; Content : String) is
   begin
      Documents.Load (Item.Doc, Content);
      Item.Anchor := 1;
      Item.Offset := 0.0;
      Item.At_Caret := (others => <>);
      Item.At_Mark := (others => <>);
      Item.Has_Goal := False;
      Item.Dragging := False;
      Item.Undos.Clear;
      Item.Redos.Clear;
      Item.Joining := False;
      Item.Composing := False;
      Restart_Blink (Item);
   end Load;

   function Text (Item : Text_Area) return String is
     (Between (Item, (1, 1), Text_End (Item)));

   procedure Place
     (Item    : in out Text_Area;
      Left, Top, Width, Height : Float;
      Density : Float;
      Zoom    : Float := 1.0) is
   begin
      Item.Left := Left;
      Item.Top := Top;
      Item.Width := Width;
      Item.Height := Height;
      Item.Density := Density;
      Item.Zoom := Zoom;
      if Documents.Width (Item.Doc) /= Column (Item) then
         Documents.Set_Width (Item.Doc, Column (Item));
      end if;
   end Place;

   function Contains (Item : Text_Area; X, Y : Float) return Boolean is
     (X >= Item.Left and then X < Item.Left + Item.Width
      and then Y >= Item.Top and then Y < Item.Top + Item.Height);

   function Is_Focused (Item : Text_Area) return Boolean is (Item.Focused);

   function Caret (Item : Text_Area) return Position is (Item.At_Caret);

   function Mark (Item : Text_Area) return Position is (Item.At_Mark);

   function Has_Selection (Item : Text_Area) return Boolean is
     (Item.At_Mark /= Item.At_Caret);

   function Selection_First (Item : Text_Area) return Position is
     (if Item.At_Mark < Item.At_Caret then Item.At_Mark else Item.At_Caret);

   function Selection_Last (Item : Text_Area) return Position is
     (if Item.At_Mark < Item.At_Caret then Item.At_Caret else Item.At_Mark);

   function Selected_Text (Item : Text_Area) return String is
     (Between (Item, Selection_First (Item), Selection_Last (Item)));

   --  Scrolling

   procedure Scroll (Item : in out Text_Area; By : Float) is
   begin
      Documents.Scroll
        (Item.Doc, Item.Anchor, Item.Offset, By, Extent (Item));
   end Scroll;

   procedure Reveal (Item : in out Text_Area);
   --  Scroll as little as brings the caret's line into view.

   procedure Reveal (Item : in out Text_Area) is
      Para     : constant Positive := Item.At_Caret.Paragraph;
      Number   : constant Positive := Line_Of (Item, Item.At_Caret);
      High     : constant Float := Documents.Line_Height (Item.Doc);
      Line_Top : constant Float :=
        Documents.Top (Item.Doc, Para) + Float (Number - 1) * High;
      Shown    : constant Float := View_Top (Item);
   begin
      if Line_Top < Shown or else Extent (Item) < High then
         Scroll (Item, Line_Top - Shown);
      elsif Line_Top + High > Shown + Extent (Item) then
         Scroll (Item, Line_Top + High - (Shown + Extent (Item)));
      end if;
   end Reveal;

   procedure Moved (Item : in out Text_Area);
   --  The caret or the text changed: show the caret, and bring it into
   --  view.

   procedure Moved (Item : in out Text_Area) is
   begin
      pragma Assert (Is_Position (Item, Item.At_Caret));
      pragma Assert (Is_Position (Item, Item.At_Mark));
      Restart_Blink (Item);
      Reveal (Item);
   end Moved;

   --  Changing the text, as the edits that are undone do

   procedure Break_Paragraph (Item : in out Text_Area);
   --  At the caret, which goes to the start of the new paragraph.

   procedure Break_Paragraph (Item : in out Text_Area) is
      Para : constant Positive := Item.At_Caret.Paragraph;
   begin
      Documents.Split (Item.Doc, Para, Item.At_Caret.Index);
      if Para < Item.Anchor then
         Item.Anchor := Item.Anchor + 1;
      end if;
      Item.At_Caret := (Para + 1, 1);
   end Break_Paragraph;

   procedure Join_Paragraphs (Item : in out Text_Area; Para : Positive)
     with Pre => Para < Documents.Count (Item.Doc);
   --  Para and the next, keeping what is shown where it is.

   procedure Join_Paragraphs (Item : in out Text_Area; Para : Positive) is
   begin
      if Item.Anchor = Para + 1 then
         Item.Offset := Item.Offset
           + Documents.Top (Item.Doc, Para + 1)
           - Documents.Top (Item.Doc, Para);
         Item.Anchor := Para;
      elsif Item.Anchor > Para + 1 then
         Item.Anchor := Item.Anchor - 1;
      end if;
      Documents.Join (Item.Doc, Para);
   end Join_Paragraphs;

   procedure Put (Item : in out Text_Area; Piece : String);
   --  Insert Piece, which has no line feeds, at the caret, and move the
   --  caret past it.

   procedure Put (Item : in out Text_Area; Piece : String) is
      At_Caret : Position renames Item.At_Caret;
   begin
      if Piece'Length > 0 then
         Documents.Replace
           (Item.Doc, At_Caret.Paragraph,
            At_Caret.Index, At_Caret.Index - 1, Piece);
         At_Caret.Index := At_Caret.Index + Piece'Length;
      end if;
   end Put;

   procedure Replace_Range
     (Item     : in out Text_Area;
      From, To : Position;
      By       : String)
     with Pre  => Is_Position (Item, From) and then Is_Position (Item, To)
                  and then not (To < From),
          Post => Item.At_Caret = End_After (From, By)
                  and then Item.At_Mark = Item.At_Caret;
   --  Replace the text from From to To with By, which has a line to each
   --  paragraph, and put the caret after it. Not recorded to undo.

   procedure Replace_Range
     (Item     : in out Text_Area;
      From, To : Position;
      By       : String)
   is
      Para : constant Positive := From.Paragraph;
      Line : Unbounded_String;
   begin
      --  Remove what is there.
      if From.Paragraph = To.Paragraph then
         if From.Index < To.Index then
            Documents.Replace (Item.Doc, Para, From.Index, To.Index - 1, "");
         end if;
      else
         Documents.Replace
           (Item.Doc, Para, From.Index,
            Documents.Byte_Length (Item.Doc, Para), "");
         for Middle in From.Paragraph + 1 .. To.Paragraph - 1 loop
            Documents.Replace
              (Item.Doc, Para + 1, 1,
               Documents.Byte_Length (Item.Doc, Para + 1), "");
            Join_Paragraphs (Item, Para);
         end loop;
         Documents.Replace (Item.Doc, Para + 1, 1, To.Index - 1, "");
         Join_Paragraphs (Item, Para);
      end if;

      --  Put By in its place.
      Item.At_Caret := From;
      for C of By loop
         if C = ASCII.LF then
            Put (Item, To_String (Line));
            Line := Null_Unbounded_String;
            Break_Paragraph (Item);
         else
            Append (Line, C);
         end if;
      end loop;
      Put (Item, To_String (Line));
      Item.At_Mark := Item.At_Caret;
   end Replace_Range;

   --  Edits, which are undone

   procedure Record_Edit
     (Item     : in out Text_Area;
      From     : Position;
      Removed  : String;
      Inserted : String;
      Kind     : Edit_Kind);
   --  To undo, or with the last edit, if they go together.

   procedure Record_Edit
     (Item     : in out Text_Area;
      From     : Position;
      Removed  : String;
      Inserted : String;
      Kind     : Edit_Kind)
   is
      Joined : Boolean := False;
   begin
      Item.Last_Id := Item.Last_Id + 1;
      if Item.Joining and then not Item.Undos.Is_Empty
        and then Kind = Item.Undos.Last_Element.Kind
      then
         declare
            Last : Change renames
              Item.Undos.Reference (Item.Undos.Last_Index);
         begin
            case Kind is
               when Typing =>
                  --  Typing on from where it stopped, on one line.
                  Joined := Removed = ""
                    and then End_After (Last.From, To_String (Last.Inserted))
                             = From
                    and then (for all C of Inserted => C /= ASCII.LF);
                  if Joined then
                     Append (Last.Inserted, Inserted);
                  end if;
               when Deleting_Back =>
                  Joined := Inserted = ""
                    and then End_After (From, Removed) = Last.From;
                  if Joined then
                     Last.From := From;
                     Last.Removed := Removed & Last.Removed;
                  end if;
               when Deleting_Forward =>
                  Joined := Inserted = "" and then From = Last.From;
                  if Joined then
                     Append (Last.Removed, Removed);
                  end if;
               when Other =>
                  null;
            end case;
            if Joined then
               Last.Id := Item.Last_Id;
            end if;
         end;
      end if;

      if not Joined then
         Item.Undos.Append
           (Change'(From     => From,
                    Removed  => To_Unbounded_String (Removed),
                    Inserted => To_Unbounded_String (Inserted),
                    Kind     => Kind,
                    Id       => Item.Last_Id));
         if Natural (Item.Undos.Length) > Undo_Depth then
            Item.Undos.Delete_First;
         end if;
      end if;
      Item.Redos.Clear;
      Item.Joining := Kind /= Other;
   end Record_Edit;

   procedure Edit
     (Item     : in out Text_Area;
      From, To : Position;
      By       : String;
      Kind     : Edit_Kind)
     with Pre => Is_Position (Item, From) and then Is_Position (Item, To)
                 and then not (To < From);
   --  Replace the text from From to To with By, to undo, with the caret
   --  after it.

   procedure Edit
     (Item     : in out Text_Area;
      From, To : Position;
      By       : String;
      Kind     : Edit_Kind)
   is
      Removed : constant String := Between (Item, From, To);
   begin
      Item.Has_Goal := False;
      if Removed /= "" or else By /= "" then
         Record_Edit (Item, From, Removed, By, Kind);
         Replace_Range (Item, From, To, By);
      end if;
      Moved (Item);
   end Edit;

   function Without_Returns (Raw : String) return String;
   --  Raw without carriage returns, as from CR LF line ends.

   function Without_Returns (Raw : String) return String is
      Result : String (1 .. Raw'Length);
      Last   : Natural := 0;
   begin
      for C of Raw loop
         if C /= ASCII.CR then
            Last := Last + 1;
            Result (Last) := C;
         end if;
      end loop;
      return Result (1 .. Last);
   end Without_Returns;

   --  Input methods' text

   function Composed_End (Item : Text_Area) return Position is
     ((Item.Composed.Paragraph,
       Item.Composed.Index + Item.Composed_Length));

   function Is_Composing (Item : Text_Area) return Boolean is
     (Item.Composing);

   procedure Drop_Composition (Item : in out Text_Area);
   --  Take the input method's text away, leaving the caret where it was.

   procedure Drop_Composition (Item : in out Text_Area) is
   begin
      if Item.Composing then
         Replace_Range (Item, Item.Composed, Composed_End (Item), "");
         Item.Composing := False;
      end if;
   end Drop_Composition;

   procedure Finish_Composition (Item : in out Text_Area);
   --  Keep the input method's text as if it were typed: before anything
   --  else is done.

   procedure Finish_Composition (Item : in out Text_Area) is
   begin
      if Item.Composing then
         declare
            Composed : constant String :=
              Between (Item, Item.Composed, Composed_End (Item));
         begin
            Drop_Composition (Item);
            Record_Edit (Item, Item.At_Caret, "", Composed, Other);
            Replace_Range (Item, Item.At_Caret, Item.At_Caret, Composed);
         end;
      end if;
   end Finish_Composition;

   procedure Compose
     (Item   : in out Text_Area;
      Shown  : String;
      Cursor : Natural)
   is
      Clean : String := Without_Returns (Shown);
   begin
      for C of Clean loop
         if C = ASCII.LF then
            C := ' ';
         end if;
      end loop;

      if not Item.Composing and then Clean /= "" then
         if Has_Selection (Item) then
            Edit (Item, Selection_First (Item), Selection_Last (Item), "",
                  Other);
         end if;
         Item.Composed := Item.At_Caret;
         Item.Composing := True;
      elsif Item.Composing then
         Drop_Composition (Item);
         Item.Composing := Clean /= "";
      end if;

      if Item.Composing then
         Replace_Range (Item, Item.Composed, Item.Composed, Clean);
         Item.Composed_Length := Clean'Length;

         --  The caret after Cursor characters.
         declare
            Byte : Positive := Item.Composed.Index;
            Seen : Natural := 0;
         begin
            while Seen < Cursor and then Byte < Composed_End (Item).Index
            loop
               Byte := Documents.Next_Character
                 (Item.Doc, Item.Composed.Paragraph, Byte);
               Seen := Seen + 1;
            end loop;
            Item.At_Caret := (Item.Composed.Paragraph, Byte);
            Item.At_Mark := Item.At_Caret;
         end;
      end if;
      Item.Has_Goal := False;
      Moved (Item);
   end Compose;

   --  Focus

   procedure Set_Focus (Item : in out Text_Area; Focused : Boolean) is
   begin
      if not Focused then
         Finish_Composition (Item);
         Item.Dragging := False;
      elsif not Item.Focused then
         Restart_Blink (Item);
      end if;
      Item.Focused := Focused;
   end Set_Focus;

   --  Moving

   procedure Select_Range (Item : in out Text_Area; From, To : Position) is
   begin
      Finish_Composition (Item);
      Item.At_Mark := From;
      Item.At_Caret := To;
      Item.Has_Goal := False;
      Item.Joining := False;
      Moved (Item);
   end Select_Range;

   procedure Select_All (Item : in out Text_Area) is
   begin
      Select_Range (Item, (1, 1), Text_End (Item));
   end Select_All;

   function Step
     (Item : in out Text_Area;
      From : Position;
      By   : Motion) return Position
     with Pre => By not in Previous_Line | Next_Line;
   --  Where the caret goes from From.

   function Step
     (Item : in out Text_Area;
      From : Position;
      By   : Motion) return Position
   is
      Para   : constant Positive := From.Paragraph;
      Byte   : constant Positive := From.Index;
      Length : constant Natural := Documents.Byte_Length (Item.Doc, Para);
      Count  : constant Positive := Documents.Count (Item.Doc);
      At_Start : constant Boolean := Byte = 1;
      At_End   : constant Boolean := Byte > Length;
   begin
      case By is
         when Previous_Character | Previous_Word =>
            if not At_Start then
               return
                 (Para,
                  (if By = Previous_Word
                   then Documents.Previous_Word (Item.Doc, Para, Byte)
                   else Documents.Previous_Character
                          (Item.Doc, Para, Byte)));
            elsif Para > 1 then
               return Paragraph_End (Item, Para - 1);
            end if;

         when Next_Character | Next_Word =>
            if not At_End then
               return
                 (Para,
                  (if By = Next_Word
                   then Documents.Next_Word (Item.Doc, Para, Byte)
                   else Documents.Next_Character (Item.Doc, Para, Byte)));
            elsif Para < Count then
               return (Para + 1, 1);
            end if;

         when Line_Start =>
            declare
               Number : constant Positive := Line_Of (Item, From);
            begin
               return
                 (Para,
                  Documents.Index_Of
                    (Item.Doc, Para,
                     Documents.Line (Item.Doc, Para, Number).First));
            end;

         when Line_End =>
            declare
               Number : constant Positive := Line_Of (Item, From);
            begin
               if Number < Documents.Line_Count (Item.Doc, Para) then
                  --  Before the space the line breaks after.
                  return
                    (Para,
                     Documents.Index_Of
                       (Item.Doc, Para,
                        Documents.Units_At_Offset
                          (Item.Doc, Para, Number, Float'Last)));
               end if;
               return Paragraph_End (Item, Para);
            end;

         when Paragraph_Start =>
            if not At_Start then
               return (Para, 1);
            elsif Para > 1 then
               return (Para - 1, 1);
            end if;

         when Paragraph_End =>
            if not At_End then
               return Paragraph_End (Item, Para);
            elsif Para < Count then
               return Paragraph_End (Item, Para + 1);
            end if;

         when Text_Start =>
            return (1, 1);

         when Text_End =>
            return Text_End (Item);

         when Previous_Line | Next_Line =>
            raise Program_Error;
      end case;
      return From;
   end Step;

   function Line_Position
     (Item   : in out Text_Area;
      Para   : Positive;
      Number : Positive;
      X      : Float) return Position;
   --  The position on line Number of paragraph Para, laid out, nearest X
   --  layout units across.

   function Line_Position
     (Item   : in out Text_Area;
      Para   : Positive;
      Number : Positive;
      X      : Float) return Position is
   begin
      return
        (Para,
         Documents.Index_Of
           (Item.Doc, Para,
            Documents.Units_At_Offset (Item.Doc, Para, Number, X)));
   end Line_Position;

   function Vertical_Step
     (Item : in out Text_Area;
      By   : Motion) return Position
     with Pre => By in Previous_Line | Next_Line;
   --  Where the caret goes a line up or down, as near the goal as can
   --  be.

   function Vertical_Step
     (Item : in out Text_Area;
      By   : Motion) return Position
   is
      Para   : constant Positive := Item.At_Caret.Paragraph;
      Number : constant Positive := Line_Of (Item, Item.At_Caret);
      Lines  : constant Positive := Documents.Line_Count (Item.Doc, Para);
   begin
      if not Item.Has_Goal then
         Item.Goal := Documents.Caret_Offset
           (Item.Doc, Para, Number, Units (Item, Item.At_Caret));
         Item.Has_Goal := True;
      end if;

      if By = Previous_Line then
         if Number > 1 then
            return Line_Position (Item, Para, Number - 1, Item.Goal);
         elsif Para > 1 then
            Documents.Lay_Out (Item.Doc, Para - 1);
            return Line_Position
              (Item, Para - 1, Documents.Line_Count (Item.Doc, Para - 1),
               Item.Goal);
         end if;
         return (1, 1);
      elsif Number < Lines then
         return Line_Position (Item, Para, Number + 1, Item.Goal);
      elsif Para < Documents.Count (Item.Doc) then
         Documents.Lay_Out (Item.Doc, Para + 1);
         return Line_Position (Item, Para + 1, 1, Item.Goal);
      end if;
      return Text_End (Item);
   end Vertical_Step;

   procedure Move
     (Item   : in out Text_Area;
      By     : Motion;
      Extend : Boolean := False) is
   begin
      Finish_Composition (Item);
      Item.Joining := False;
      if By not in Previous_Line | Next_Line then
         Item.Has_Goal := False;
      end if;

      if not Extend and then Has_Selection (Item)
        and then By in Previous_Character | Next_Character
      then
         Item.At_Caret :=
           (if By = Previous_Character then Selection_First (Item)
            else Selection_Last (Item));
      elsif By in Previous_Line | Next_Line then
         Item.At_Caret := Vertical_Step (Item, By);
      else
         Item.At_Caret := Step (Item, Item.At_Caret, By);
      end if;

      if not Extend then
         Item.At_Mark := Item.At_Caret;
      end if;
      Moved (Item);
   end Move;

   --  The mouse

   function Point_At (Item : in out Text_Area; X, Y : Float)
      return Position;
   --  The position nearest pixel X, Y.

   function Point_At (Item : in out Text_Area; X, Y : Float)
      return Position
   is
      High  : constant Float := Documents.Line_Height (Item.Doc);
      Shown : constant Float := View_Top (Item);
      Depth : constant Float := Shown + (Y - Text_Top (Item)) / Scale (Item);
      Para  : constant Positive := Documents.Paragraph_At (Item.Doc, Depth);
   begin
      Documents.Lay_Out (Item.Doc, Para);
      declare
         Lines  : constant Positive := Documents.Line_Count (Item.Doc, Para);
         Within : constant Float :=
           Float'Max (0.0, Depth - Documents.Top (Item.Doc, Para)) / High;
         Number : constant Positive :=
           (if Within >= Float (Lines) then Lines
            else Natural (Float'Floor (Within)) + 1);
      begin
         return Line_Position
           (Item, Para, Number, (X - Column_Left (Item)) / Scale (Item));
      end;
   end Point_At;

   procedure Click
     (Item   : in out Text_Area;
      X, Y   : Float;
      Clicks : Positive := 1;
      Extend : Boolean := False)
   is
      Point : Position;
   begin
      Finish_Composition (Item);
      Point := Point_At (Item, X, Y);
      Item.Focused := True;
      Item.Dragging := True;
      Item.Has_Goal := False;
      Item.Joining := False;

      if Clicks = 1 or else Extend then
         Item.At_Caret := Point;
         if not Extend then
            Item.At_Mark := Point;
         end if;
      elsif Clicks = 2 then
         declare
            First, Stop : Positive;
         begin
            Documents.Word_At
              (Item.Doc, Point.Paragraph, Point.Index, First, Stop);
            --  Not on a word: the character there.
            if First = Stop
              and then Point.Index
                       <= Documents.Byte_Length (Item.Doc, Point.Paragraph)
            then
               Stop := Documents.Next_Character
                 (Item.Doc, Point.Paragraph, Point.Index);
            end if;
            Item.At_Mark := (Point.Paragraph, First);
            Item.At_Caret := (Point.Paragraph, Stop);
         end;
      else
         Item.At_Mark := (Point.Paragraph, 1);
         Item.At_Caret := Paragraph_End (Item, Point.Paragraph);
      end if;
      Moved (Item);
   end Click;

   procedure Drag (Item : in out Text_Area; X, Y : Float) is
   begin
      if Item.Dragging then
         Item.At_Caret := Point_At (Item, X, Y);
         Moved (Item);
      end if;
   end Drag;

   procedure Release (Item : in out Text_Area) is
   begin
      Item.Dragging := False;
   end Release;

   function Is_Dragging (Item : Text_Area) return Boolean is
     (Item.Dragging);

   --  Editing

   procedure Insert (Item : in out Text_Area; Typed : String) is
   begin
      Drop_Composition (Item);  --  Typed is what it became
      Edit (Item, Selection_First (Item), Selection_Last (Item),
            Without_Returns (Typed), Typing);
   end Insert;

   function Deletion_Motion (By : Deletion; Forward : Boolean) return Motion
   is (case By is
          when Character =>
             (if Forward then Next_Character else Previous_Character),
          when Word => (if Forward then Next_Word else Previous_Word),
          when Line_Part => (if Forward then Line_End else Line_Start));

   procedure Delete_Backward
     (Item : in out Text_Area; By : Deletion := Character) is
   begin
      Finish_Composition (Item);
      if Has_Selection (Item) then
         Edit (Item, Selection_First (Item), Selection_Last (Item), "",
               Other);
         return;
      end if;
      declare
         From : Position :=
           Step (Item, Item.At_Caret, Deletion_Motion (By, False));
      begin
         --  At the start of a line, its part is the break before it.
         if From = Item.At_Caret then
            From := Step (Item, Item.At_Caret, Previous_Character);
         end if;
         Edit (Item, From, Item.At_Caret, "", Deleting_Back);
      end;
   end Delete_Backward;

   procedure Delete_Forward
     (Item : in out Text_Area; By : Deletion := Character) is
   begin
      Finish_Composition (Item);
      if Has_Selection (Item) then
         Edit (Item, Selection_First (Item), Selection_Last (Item), "",
               Other);
         return;
      end if;
      declare
         To : Position :=
           Step (Item, Item.At_Caret, Deletion_Motion (By, True));
      begin
         if To = Item.At_Caret then
            To := Step (Item, Item.At_Caret, Next_Character);
         end if;
         Edit (Item, Item.At_Caret, To, "", Deleting_Forward);
      end;
   end Delete_Forward;

   procedure Copy
     (Item  : in out Text_Area;
      Board : in out Clipboards.Clipboard'Class) is
   begin
      Finish_Composition (Item);
      if Has_Selection (Item) then
         Board.Set_Text (Selected_Text (Item));
      end if;
   end Copy;

   procedure Cut
     (Item  : in out Text_Area;
      Board : in out Clipboards.Clipboard'Class) is
   begin
      Copy (Item, Board);
      if Has_Selection (Item) then
         Edit (Item, Selection_First (Item), Selection_Last (Item), "",
               Other);
      end if;
   end Cut;

   procedure Paste
     (Item  : in out Text_Area;
      Board : in out Clipboards.Clipboard'Class) is
   begin
      Finish_Composition (Item);
      Edit (Item, Selection_First (Item), Selection_Last (Item),
            Without_Returns (Board.Text), Other);
   end Paste;

   --  Undoing

   procedure Undo (Item : in out Text_Area) is
   begin
      Finish_Composition (Item);
      if Item.Undos.Is_Empty then
         return;
      end if;
      declare
         Last : constant Change := Item.Undos.Last_Element;
      begin
         Item.Undos.Delete_Last;
         Replace_Range
           (Item, Last.From,
            End_After (Last.From, To_String (Last.Inserted)),
            To_String (Last.Removed));
         Item.At_Mark := Last.From;
         Item.Redos.Append (Change'(Last));
      end;
      Item.Joining := False;
      Item.Has_Goal := False;
      Moved (Item);
   end Undo;

   procedure Redo (Item : in out Text_Area) is
   begin
      Finish_Composition (Item);
      if Item.Redos.Is_Empty then
         return;
      end if;
      declare
         Last : constant Change := Item.Redos.Last_Element;
      begin
         Item.Redos.Delete_Last;
         Replace_Range
           (Item, Last.From,
            End_After (Last.From, To_String (Last.Removed)),
            To_String (Last.Inserted));
         Item.Undos.Append (Change'(Last));
      end;
      Item.Joining := False;
      Item.Has_Goal := False;
      Moved (Item);
   end Redo;

   function Can_Undo (Item : Text_Area) return Boolean is
     (not Item.Undos.Is_Empty);

   function Can_Redo (Item : Text_Area) return Boolean is
     (not Item.Redos.Is_Empty);

   function State (Item : Text_Area) return Natural is
     (if Item.Undos.Is_Empty then 0 else Item.Undos.Last_Element.Id);

   --  Blinking

   procedure Tick
     (Item    : in out Text_Area;
      Now     : SDL3.Events.Milliseconds;
      Changed : out Boolean)
   is
      On : Boolean;
   begin
      Item.Now := SDL3.Events.Milliseconds'Max (Item.Now, Now);
      On := (Item.Now - Item.Since) / Blink_Period mod 2 = 0;
      Changed := Item.Focused and then On /= Item.Caret_On;
      Item.Caret_On := On;
   end Tick;

   function Is_Caret_Shown (Item : Text_Area) return Boolean is
     (Item.Focused and then Item.Caret_On);

   function Until_Blink (Item : Text_Area) return SDL3.Events.Milliseconds
   is (Blink_Period - (Item.Now - Item.Since) mod Blink_Period);

   --  Events

   procedure Handle_Key
     (Item    : in out Text_Area;
      Event   : Events.Event;
      Board   : in out Clipboards.Clipboard'Class;
      Handled : out Boolean);

   procedure Handle_Key
     (Item    : in out Text_Area;
      Event   : Events.Event;
      Board   : in out Clipboards.Clipboard'Class;
      Handled : out Boolean)
   is
      Key     : constant Events.Key_Code := Event.Key;
      Command : constant Boolean := Event.Command;
      Option  : constant Boolean := Event.Option;
      Shift   : constant Boolean := Event.Shift;
      High    : constant Float := Documents.Line_Height (Item.Doc);

      function Deleting return Deletion is
        (if Command then Line_Part elsif Option then Word else Character);
   begin
      Handled := True;
      if not Item.Focused then
         null;
      elsif Command and then Key = Events.Key_A then
         Select_All (Item);
         return;
      elsif Command and then Key = Events.Key_C then
         Copy (Item, Board);
         return;
      elsif Command and then Key = Events.Key_X then
         Cut (Item, Board);
         return;
      elsif Command and then Key = Events.Key_V then
         Paste (Item, Board);
         return;
      elsif Command and then Key = Events.Key_Z then
         if Shift then
            Redo (Item);
         else
            Undo (Item);
         end if;
         return;
      elsif Key = Events.Key_Left_Arrow then
         Move (Item,
               (if Command then Line_Start
                elsif Option then Previous_Word
                else Previous_Character),
               Extend => Shift);
         return;
      elsif Key = Events.Key_Right_Arrow then
         Move (Item,
               (if Command then Line_End
                elsif Option then Next_Word
                else Next_Character),
               Extend => Shift);
         return;
      elsif Key = Events.Key_Up_Arrow then
         Move (Item,
               (if Command then Text_Start
                elsif Option then Paragraph_Start
                else Previous_Line),
               Extend => Shift);
         return;
      elsif Key = Events.Key_Down_Arrow then
         Move (Item,
               (if Command then Text_End
                elsif Option then Paragraph_End
                else Next_Line),
               Extend => Shift);
         return;
      elsif Key = Events.Key_Backspace then
         Delete_Backward (Item, Deleting);
         return;
      elsif Key = Events.Key_Delete then
         Delete_Forward (Item, Deleting);
         return;
      elsif Key = Events.Key_Return then
         Insert (Item, [ASCII.LF]);
         return;
      elsif Key = Events.Key_Escape then
         Set_Focus (Item, False);
         return;
      end if;

      --  Scrolling, focused or not
      if Key = Events.Key_Down_Arrow then
         Scroll (Item, High);
      elsif Key = Events.Key_Up_Arrow then
         Scroll (Item, -High);
      elsif Key = Events.Key_Page_Down then
         Scroll (Item, Page_Fraction * Extent (Item));
      elsif Key = Events.Key_Page_Up then
         Scroll (Item, -Page_Fraction * Extent (Item));
      elsif Key = Events.Key_Home then
         Scroll (Item, -Documents.Total_Height (Item.Doc));
      elsif Key = Events.Key_End then
         Scroll (Item, Documents.Total_Height (Item.Doc));
      else
         Handled := False;
      end if;
   end Handle_Key;

   procedure Handle
     (Item    : in out Text_Area;
      Event   : Events.Event;
      Board   : in out Clipboards.Clipboard'Class;
      Handled : out Boolean)
   is
      X : constant Float := Event.Mouse_X * Item.Density;
      Y : constant Float := Event.Mouse_Y * Item.Density;
   begin
      Item.Now := SDL3.Events.Milliseconds'Max (Item.Now, Event.Time);
      Handled := False;
      case Event.Kind is
         when Events.Mouse_Down =>
            if Event.Button = 1 and then Contains (Item, X, Y) then
               Click (Item, X, Y, Natural'Max (1, Event.Clicks),
                      Extend => Event.Shift);
               Handled := True;
            end if;
         when Events.Mouse_Move =>
            if Item.Dragging and then Event.Left_Held then
               Drag (Item, X, Y);
               Handled := True;
            elsif Item.Dragging then
               Release (Item);  --  let go where it was not seen
            end if;
         when Events.Mouse_Up =>
            if Event.Button = 1 then
               Release (Item);
            end if;
         when Events.Mouse_Wheel =>
            if not Event.Command and then Contains (Item, X, Y) then
               Scroll
                 (Item,
                  -Event.Wheel_Y * Lines_Per_Notch
                   * Documents.Line_Height (Item.Doc));
               Handled := True;
            end if;
         when Events.Text_Input =>
            if Item.Focused then
               Insert (Item, Events.Typed (Event));
               Handled := True;
            end if;
         when Events.Text_Editing =>
            if Item.Focused then
               Compose (Item, Events.Typed (Event), Event.Cursor);
               Handled := True;
            end if;
         when Events.Key_Down =>
            if not Item.Composing then
               Handle_Key (Item, Event, Board, Handled);
            end if;
         when Events.Quit | Events.Redraw | Events.Other =>
            null;
      end case;
   end Handle;

   --  Drawing

   procedure Draw_Range
     (Item        : in out Text_Area;
      Target      : SDL3.Windows.Renderers.Renderer;
      From, To    : Position;
      First, Last : Positive;
      Value       : SDL3.Windows.Renderers.Color;
      Underlined  : Boolean);
   --  Mark the text from From to To, in paragraphs First to Last, which
   --  are laid out: fill behind it, or underline it.

   procedure Draw_Range
     (Item        : in out Text_Area;
      Target      : SDL3.Windows.Renderers.Renderer;
      From, To    : Position;
      First, Last : Positive;
      Value       : SDL3.Windows.Renderers.Color;
      Underlined  : Boolean)
   is
      High  : constant Float := Documents.Line_Height (Item.Doc);
      Shown : constant Float := View_Top (Item);
      Right : constant Float := Column (Item);
   begin
      for Para in Positive'Max (First, From.Paragraph)
                  .. Positive'Min (Last, To.Paragraph)
      loop
         declare
            Range_First : constant Natural :=
              (if Para = From.Paragraph then Units (Item, From) else 0);
            Range_Stop  : constant Natural :=
              (if Para = To.Paragraph then Units (Item, To)
               else Natural'Last);  --  on past the paragraph's end
            Para_Top    : constant Float := Documents.Top (Item.Doc, Para);
            Lines       : constant Positive :=
              Documents.Line_Count (Item.Doc, Para);
         begin
            for Number in 1 .. Lines loop
               declare
                  Line : constant CoreText.Wrapping.Span :=
                    Documents.Line (Item.Doc, Para, Number);
                  A    : constant Natural :=
                    Natural'Max (Range_First, Line.First);
                  B    : constant Natural :=
                    Natural'Min (Range_Stop, Line.Stop);
                  Runs_On : constant Boolean := Range_Stop > Line.Stop;
                  --  On past the line's end: to the column's.
                  Y    : constant Float :=
                    Text_Top (Item)
                    + (Para_Top + Float (Number - 1) * High - Shown)
                      * Scale (Item);
               begin
                  if A <= Line.Stop
                    and then (if Underlined then A < B
                              else A < B or else Runs_On)
                  then
                     declare
                        X_A : constant Float := Documents.Caret_Offset
                          (Item.Doc, Para, Number, A);
                        X_B : constant Float :=
                          (if Runs_On and then not Underlined
                           then Float'Max (Right, X_A)
                           else Documents.Caret_Offset
                                  (Item.Doc, Para, Number, B));
                        Left : constant Float :=
                          Column_Left (Item) + X_A * Scale (Item);
                        Wide : constant Float := (X_B - X_A) * Scale (Item);
                     begin
                        if Underlined then
                           SDL3.Windows.Renderers.Fill_Rect
                             (Target, Value, Left,
                              Y + Documents.Ascent (Item.Doc) * Scale (Item)
                              + Underline_Gap * Item.Density,
                              Wide, Underline * Item.Density);
                        else
                           declare
                              --  Down over the space after the paragraph
                              --  too, if it runs on to the next.
                              Bottom : constant Float :=
                                (if Runs_On and then Number = Lines
                                 then Text_Top (Item)
                                      + (Para_Top
                                         + Documents.Height (Item.Doc, Para)
                                         - Shown) * Scale (Item)
                                 else Y + High * Scale (Item));
                              Row    : constant Float := Float'Floor (Y);
                           begin
                              --  On whole pixels: rows meet, not overlap
                              --  or leave a gap.
                              SDL3.Windows.Renderers.Fill_Rect
                                (Target, Value, Left, Row, Wide,
                                 Float'Floor (Bottom) - Row);
                           end;
                        end if;
                     end;
                  end if;
               end;
            end loop;
         end;
      end loop;
   end Draw_Range;

   procedure Caret_Box
     (Item : in out Text_Area;
      X, Y, Width, Height : out Float)
   is
      Para     : constant Positive := Item.At_Caret.Paragraph;
      Number   : constant Positive := Line_Of (Item, Item.At_Caret);
      High     : constant Float := Documents.Line_Height (Item.Doc);
      Shown    : constant Float := View_Top (Item);
      Line_Top : constant Float :=
        Documents.Top (Item.Doc, Para) + Float (Number - 1) * High;
      Across   : constant Float := Documents.Caret_Offset
        (Item.Doc, Para, Number, Units (Item, Item.At_Caret));
   begin
      Width := Caret_Width * Item.Density;
      X := Column_Left (Item) + Across * Scale (Item) - Width / 2.0;
      Y := Text_Top (Item) + (Line_Top - Shown) * Scale (Item);
      Height := High * Scale (Item);
   end Caret_Box;

   procedure Draw
     (Item    : in out Text_Area;
      Target  : SDL3.Windows.Renderers.Renderer;
      Colors  : Themes.Theme;
      Settled : Boolean := True)
   is
      use SDL3.Windows.Renderers;
      Edge : constant Float :=
        (if Item.Focused then Focus_Outline else Outline) * Item.Density;
      Inner_Left   : constant Integer := Integer (Item.Left + Edge);
      Inner_Top    : constant Integer := Integer (Item.Top + Edge);
      Inner_Right  : constant Integer :=
        Integer (Item.Left + Item.Width - Edge);
      Inner_Bottom : constant Integer :=
        Integer (Item.Top + Item.Height - Edge);
      First, Last  : Documents.Paragraph_Number;
   begin
      Fill_Rect
        (Target, (if Item.Focused then Colors.Accent else Colors.Foreground),
         Item.Left, Item.Top, Item.Width, Item.Height);
      Fill_Rect
        (Target, Colors.Background,
         Float (Inner_Left), Float (Inner_Top),
         Float (Integer'Max (0, Inner_Right - Inner_Left)),
         Float (Integer'Max (0, Inner_Bottom - Inner_Top)));

      --  Lines part in view run into the padding, but not the outline.
      Set_Clip
        (Target, Inner_Left, Inner_Top,
         Integer'Max (0, Inner_Right - Inner_Left),
         Integer'Max (0, Inner_Bottom - Inner_Top));

      --  What is shown, laid out, as the view will draw it.
      Documents.Visible
        (Item.Doc, Item.Anchor, Item.Offset, Extent (Item), First, Last);

      if Has_Selection (Item) then
         Draw_Range
           (Item, Target, Selection_First (Item), Selection_Last (Item),
            First, Last,
            (if Item.Focused then Themes.Selection (Colors)
             else Themes.Inactive_Selection (Colors)),
            Underlined => False);
      end if;

      Views.Draw
        (Item.View, Item.Doc, Target, Colors.Foreground,
         Item.Anchor, Item.Offset,
         Left    => Column_Left (Item),
         Top     => Text_Top (Item),
         Width   => Natural (Float'Floor (Text_Width (Item))),
         Height  => Natural (Float'Floor (Text_Height (Item))),
         Scale   => Scale (Item),
         Settled => Settled);

      if Item.Composing then
         Draw_Range
           (Item, Target, Item.Composed, Composed_End (Item), First, Last,
            Colors.Foreground, Underlined => True);
      end if;

      if Is_Caret_Shown (Item) and then not Has_Selection (Item) then
         declare
            X, Y, Wide, High : Float;
         begin
            Caret_Box (Item, X, Y, Wide, High);
            Fill_Rect (Target, Colors.Accent, X, Y, Wide, High);
         end;
      end if;

      Clear_Clip (Target);
   end Draw;

end UI.Text_Areas;
