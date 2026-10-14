with CoreText.Wrapping;

package body UI.Text_Areas is

   package Docs renames Texts.Documents;
   package Layouts renames Typeset.Layouts;
   package Views renames Typeset.Views;
   package Events renames SDL3.Events;

   use type Events.Key_Code;
   use type Events.Event_Kind;
   use type Docs.Version;
   use type Texts.Position;
   use type Docs.Document_Access;

   --  In points
   Outline       : constant Float := 1.0;
   Focus_Outline : constant Float := 2.0;
   Padding       : constant Float := 12.0;
   Line_Padding  : constant Float := 6.0;  --  of a field for one line
   --  From the outside of the outline to the text.
   Caret_Width   : constant Float := 1.5;
   Underline     : constant Float := 1.5;
   Underline_Gap : constant Float := 2.0;  --  below the baseline

   Lines_Per_Notch : constant Float := 3.0;
   Page_Fraction   : constant Float := 0.9;
   --  How much of what is shown Page Up and Page Down move.

   Most_Lines : constant := 1_000_000;

   --  Geometry

   function Scale (Item : Text_Area) return Float is
     (Item.Density * Item.Zoom);
   --  Pixels to a layout unit.

   function Inset (Item : Text_Area) return Float is
     ((if Item.Single then Line_Padding else Padding) * Item.Density);

   function Lead_Room (Item : Text_Area) return Float is
     (if Item.Single then Float'Rounding (Item.Lead * Item.Density)
      else 0.0);
   --  Before a single line, in pixels: see Set_Lead.

   function Trail_Room (Item : Text_Area) return Float is
     (if Item.Single then Float'Rounding (Item.Trail * Item.Density)
      else 0.0);
   --  After a single line, in pixels: see Set_Trail.

   function Text_Top (Item : Text_Area) return Float is
     (if Item.Single
      then Item.Top + Float'Max
             (Inset (Item),
              (Item.Height - Layouts.Line_Height (Item.Laid) * Scale (Item))
              / 2.0)
      else Item.Top + Inset (Item));
   --  A line for one line is in the middle of its height.

   function Text_Width (Item : Text_Area) return Float is
     (Float'Max
        (0.0,
         Item.Width - 2.0 * Inset (Item) - Lead_Room (Item)
         - Trail_Room (Item)));

   function Text_Height (Item : Text_Area) return Float is
     (Float'Max (0.0, Item.Height - 2.0 * Inset (Item)));

   function Column (Item : Text_Area) return Float is
     (if Item.Single then Item.Measure
      else Float'Max
        (1.0, Float'Min (Item.Measure, Text_Width (Item) / Scale (Item))));
   --  How wide its lines may be, in layout units.

   function Column_Left (Item : Text_Area) return Float is
     (if Item.Single
      then Item.Left + Inset (Item) + Lead_Room (Item) - Item.Across_Scroll
      else Item.Left + Inset (Item)
      + Float'Max
          (0.0, (Text_Width (Item) - Column (Item) * Scale (Item)) / 2.0));
   --  Where its lines start, in pixels.

   function Extent (Item : Text_Area) return Float is
     (Text_Height (Item) / Scale (Item));
   --  How much of the text is shown, in layout units.

   function View_Top (Item : Text_Area) return Float is
     (Layouts.Top (Item.Laid, Item.Anchor) + Item.Offset);
   --  Of what is shown, down the text, in layout units.

   --  The document

   function Is_Position (Item : Text_Area; At_Point : Position)
      return Boolean is
     (Docs.Is_Position (Item.Doc.all, At_Point));

   function Paragraph_End (Item : Text_Area; Para : Positive)
      return Position is
     (Docs.Paragraph_End (Item.Doc.all, Para));

   function Text_End (Item : Text_Area) return Position is
     (Docs.Text_End (Item.Doc.all));

   function Byte_Length (Item : Text_Area; Para : Positive) return Natural is
     (Docs.Byte_Length (Item.Doc.all, Para));

   function Count (Item : Text_Area) return Positive is
     (Docs.Count (Item.Doc.all));

   function Units (Item : Text_Area; At_Point : Position) return Natural is
     (Docs.Units_Before (Item.Doc.all, At_Point.Paragraph, At_Point.Index));
   --  Where At_Point is in its paragraph's lines.

   function Composed_End (Item : Text_Area) return Position is
     ((Item.Composed.Paragraph,
       Item.Composed.Index + Item.Composed_Length));

   procedure Restart_Blink (Item : in out Text_Area);
   --  Show the caret, for a period from now.

   procedure Restart_Blink (Item : in out Text_Area) is
   begin
      Item.Since := Item.Now;
      Item.Caret_On := True;
   end Restart_Blink;

   procedure Catch_Up (Item : in out Text_Area);
   --  Bring the caret, the selection and what is shown along with the
   --  document's changes since they were last seen, and lay it out.

   procedure Catch_Up (Item : in out Text_Area) is
      Seen : Docs.Version renames Item.Seen;
   begin
      if Item.Serial /= Docs.Serial (Item.Doc.all)
        or else Seen < Docs.Oldest (Item.Doc.all)
      then
         --  Too far behind: from the start.
         Item.Serial := Docs.Serial (Item.Doc.all);
         Item.At_Caret := (1, 1);
         Item.At_Mark := (1, 1);
         Item.Anchor := 1;
         Item.Offset := 0.0;
         Item.Composing := False;
         Item.Has_Goal := False;
         Item.Dragging := False;
      else
         while Seen < Docs.Current (Item.Doc.all) loop
            declare
               Done : constant Docs.Change :=
                 Docs.Change_After (Item.Doc.all, Seen);
               Old_Anchor : constant Position := (Item.Anchor, 1);
               Moved_To   : constant Position :=
                 Docs.Map (Done, Old_Anchor);
            begin
               Seen := Seen + 1;
               Item.At_Caret := Docs.Map (Done, Item.At_Caret);
               Item.At_Mark := Docs.Map (Done, Item.At_Mark);
               if Item.Composing
                 and then not Done.Kind_Only
                 and then Done.From < Composed_End (Item)
                 and then Item.Composed < Done.To
               then
                  --  Changed from elsewhere: it is now just text.
                  Item.Composing := False;
               elsif Item.Composing then
                  Item.Composed := Docs.Map (Done, Item.Composed);
               end if;

               --  What is shown stays where it was: by its paragraph, or
               --  if that went, down the page. The layout is as before
               --  the change, still.
               if Moved_To = Done.From and then Old_Anchor /= Done.From
                 and then Item.Anchor <= Layouts.Count (Item.Laid)
               then
                  Item.Offset := Item.Offset
                    + Layouts.Top (Item.Laid, Item.Anchor)
                    - Layouts.Top (Item.Laid, Done.From.Paragraph);
               end if;
               Item.Anchor := Moved_To.Paragraph;
            end;
         end loop;
      end if;
      Seen := Docs.Current (Item.Doc.all);
      Layouts.Sync (Item.Laid, Item.Doc.all);
      Item.Anchor := Positive'Min (Item.Anchor, Count (Item));
      pragma Assert (Is_Position (Item, Item.At_Caret));
      pragma Assert (Is_Position (Item, Item.At_Mark));
   end Catch_Up;

   function Line_Of
     (Item : in out Text_Area; At_Point : Position) return Positive;
   --  The line At_Point is on, of its paragraph, laid out.

   function Line_Of
     (Item : in out Text_Area; At_Point : Position) return Positive
   is
      At_Units : constant Natural := Units (Item, At_Point);
   begin
      Layouts.Lay_Out_To
        (Item.Laid, Item.Doc.all, At_Point.Paragraph, At_Units);
      return Layouts.Line_At (Item.Laid, At_Point.Paragraph, At_Units);
   end Line_Of;

   --  Setting up

   procedure Configure
     (Item    : in out Text_Area;
      Family  : String;
      Size    : Float;
      Measure : Float;
      Spacing : Float := 0.0) is
   begin
      Item.Measure := Measure;
      Item.Caret_Kept := False;
      Layouts.Configure (Item.Laid, Family, Size, Measure, Spacing);
   end Configure;

   function Is_Configured (Item : Text_Area) return Boolean is
     (Layouts.Is_Configured (Item.Laid));

   procedure Set_Shared
     (Item   : in out Text_Area;
      Shared : not null Shared_Access) is
   begin
      Views.Set_Shared (Item.View, Shared);
   end Set_Shared;

   procedure Set_Single_Line (Item : in out Text_Area; To : Boolean := True)
   is
   begin
      Item.Single := To;
      Item.Across_Scroll := 0.0;
      Item.Returned := False;
      Item.Caret_Kept := False;
   end Set_Single_Line;

   function Is_Single_Line (Item : Text_Area) return Boolean is
     (Item.Single);

   procedure Set_Lead (Item : in out Text_Area; Points : Float) is
   begin
      Item.Lead := Points;
   end Set_Lead;

   procedure Set_Trail (Item : in out Text_Area; Points : Float) is
   begin
      Item.Trail := Points;
   end Set_Trail;

   function Lead_Left (Item : Text_Area) return Float is
     (Item.Left + Inset (Item));

   function Line_Left (Item : Text_Area) return Float is
     (Column_Left (Item));

   function Line_Middle (Item : Text_Area) return Float is
     (Text_Top (Item) + Layouts.Line_Height (Item.Laid) * Scale (Item) / 2.0);

   procedure Set_Grows (Item : in out Text_Area; To : Boolean := True) is
   begin
      Item.Grows := To;
      Item.Anchor := 1;
      Item.Offset := 0.0;
   end Set_Grows;

   function Is_Growing (Item : Text_Area) return Boolean is (Item.Grows);

   function Content_Height (Item : in out Text_Area) return Float is
   begin
      Catch_Up (Item);
      for Para in 1 .. Layouts.Count (Item.Laid) loop
         if not Layouts.Is_Complete (Item.Laid, Para) then
            Layouts.Lay_Out (Item.Laid, Item.Doc.all, Para);
         end if;
      end loop;
      return Layouts.Total_Height (Item.Laid) * Item.Zoom
        + 2.0 * Padding;
   end Content_Height;

   procedure Take_Return (Item : in out Text_Area; Pressed : out Boolean) is
   begin
      Pressed := Item.Returned;
      Item.Returned := False;
   end Take_Return;

   procedure Attach (Item : in out Text_Area; Doc : not null Document_Access)
   is
   begin
      Item.Doc := Doc;
      Item.Serial := 0;  --  start again
      Item.Caret_Kept := False;
      Catch_Up (Item);
      Restart_Blink (Item);
   end Attach;

   function Is_Attached (Item : Text_Area) return Boolean is
     (Item.Doc /= null);

   function Document (Item : Text_Area) return Document_Access is
     (Item.Doc);

   procedure Reveal (Item : in out Text_Area);
   --  Scroll as little as brings the caret's line into view, and, for one
   --  line, across to it.

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
      if Layouts.Width (Item.Laid) /= Column (Item) then
         Layouts.Set_Width (Item.Laid, Column (Item));
      end if;
      if Item.Single and then Item.Doc /= null then
         Catch_Up (Item);
         Reveal (Item);
      end if;
   end Place;

   function Contains (Item : Text_Area; X, Y : Float) return Boolean is
     (X >= Item.Left and then X < Item.Left + Item.Width
      and then Y >= Item.Top and then Y < Item.Top + Item.Height);

   function Is_Focused (Item : Text_Area) return Boolean is (Item.Focused);

   function Updated (Item : Text_Area; At_Point : Position) return Position;
   --  Where At_Point, as the text area last saw the document, is now:
   --  another view may have changed it since.

   function Updated (Item : Text_Area; At_Point : Position) return Position
   is
      Result : Position := At_Point;
   begin
      if Item.Serial /= Docs.Serial (Item.Doc.all)
        or else Item.Seen < Docs.Oldest (Item.Doc.all)
      then
         return (1, 1);  --  as Catch_Up will have it
      end if;
      for Seen in Item.Seen .. Docs.Current (Item.Doc.all) - 1 loop
         Result := Docs.Map (Docs.Change_After (Item.Doc.all, Seen), Result);
      end loop;
      return Result;
   end Updated;

   function Caret (Item : Text_Area) return Position is
     (Updated (Item, Item.At_Caret));

   function Mark (Item : Text_Area) return Position is
     (Updated (Item, Item.At_Mark));

   function Has_Selection (Item : Text_Area) return Boolean is
     (Mark (Item) /= Caret (Item));

   function Selection_First (Item : Text_Area) return Position is
     (if Mark (Item) < Caret (Item) then Mark (Item) else Caret (Item));

   function Selection_Last (Item : Text_Area) return Position is
     (if Mark (Item) < Caret (Item) then Caret (Item) else Mark (Item));

   function Selected_Text (Item : Text_Area) return String is
     (Docs.Between
        (Item.Doc.all, Selection_First (Item), Selection_Last (Item)));

   --  Scrolling

   procedure Scroll (Item : in out Text_Area; By : Float) is
   begin
      Catch_Up (Item);
      if Item.Grows then
         return;  --  its owner scrolls
      end if;
      Layouts.Scroll (Item.Laid, Item.Anchor, Item.Offset, By, Extent (Item));
   end Scroll;

   function Scroll_Top (Item : Text_Area) return Float is (View_Top (Item));

   procedure Scroll_To (Item : in out Text_Area; Top : Float) is
   begin
      Catch_Up (Item);
      if Item.Grows then
         return;
      end if;
      Item.Anchor := 1;
      Item.Offset := 0.0;
      Layouts.Scroll (Item.Laid, Item.Anchor, Item.Offset, Top, Extent (Item));
   end Scroll_To;

   procedure Reveal (Item : in out Text_Area) is
      Para     : constant Positive := Item.At_Caret.Paragraph;
      Number   : constant Positive := Line_Of (Item, Item.At_Caret);
      High     : constant Float := Layouts.Line_Height (Item.Laid);
      Line_Top : constant Float :=
        Layouts.Top (Item.Laid, Para) + Float (Number - 1) * High;
      Shown    : constant Float := View_Top (Item);
   begin
      if Line_Top < Shown or else Extent (Item) < High then
         Scroll (Item, Line_Top - Shown);
      elsif Line_Top + High > Shown + Extent (Item) then
         Scroll (Item, Line_Top + High - (Shown + Extent (Item)));
      end if;

      --  Once it has a place.
      if Item.Single and then Item.Width > 0.0 then
         declare
            X, Y, Wide, Tall : Float;
            Least : constant Float :=
              Item.Left + Inset (Item) + Lead_Room (Item);
            Most  : constant Float :=
              Item.Left + Item.Width - Inset (Item) - Trail_Room (Item);
         begin
            Caret_Box (Item, X, Y, Wide, Tall);
            if X < Least then
               Item.Across_Scroll :=
                 Float'Max (0.0, Item.Across_Scroll - (Least - X));
            elsif X + Wide > Most then
               Item.Across_Scroll := Item.Across_Scroll + (X + Wide - Most);
            end if;
         end;
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

   --  Changing the text

   procedure Change
     (Item     : in out Text_Area;
      From, To : Position;
      By       : String;
      Undo_As  : Docs.Edit_Kind := Docs.Other;
      Recorded : Boolean := True)
     with Pre => Is_Position (Item, From) and then Is_Position (Item, To)
                 and then not (To < From);
   --  Replace the text from From to To with By, and put the caret after
   --  it, with nothing selected.

   procedure Change
     (Item     : in out Text_Area;
      From, To : Position;
      By       : String;
      Undo_As  : Docs.Edit_Kind := Docs.Other;
      Recorded : Boolean := True) is
   begin
      Docs.Replace (Item.Doc.all, From, To, By, Undo_As, Recorded);
      Catch_Up (Item);
      Item.At_Caret := Texts.End_After (From, By);
      Item.At_Mark := Item.At_Caret;
   end Change;

   procedure Edit
     (Item     : in out Text_Area;
      From, To : Position;
      By       : String;
      Undo_As  : Docs.Edit_Kind)
     with Pre => Is_Position (Item, From) and then Is_Position (Item, To)
                 and then not (To < From);
   --  Replace the text from From to To with By, to undo, with the caret
   --  after it, and bring it into view.

   procedure Edit
     (Item     : in out Text_Area;
      From, To : Position;
      By       : String;
      Undo_As  : Docs.Edit_Kind) is
   begin
      Item.Has_Goal := False;
      if From /= To or else By /= "" then
         Change (Item, From, To, By, Undo_As);
      end if;
      Moved (Item);
   end Edit;

   function Without_Returns (Raw : String) return String;
   --  Raw without carriage returns, as from CR LF line ends.

   function Without_Returns (Raw : String) return String is
      Returns : Natural := 0;
   begin
      for C of Raw loop
         if C = ASCII.CR then
            Returns := Returns + 1;
         end if;
      end loop;
      if Returns = 0 then
         return Raw;
      end if;

      --  Made in place as the result, not on the stack: what is pasted
      --  may be megabytes.
      return Result : String (1 .. Raw'Length - Returns) do
         declare
            Last : Natural := 0;
         begin
            for C of Raw loop
               if C /= ASCII.CR then
                  Last := Last + 1;
                  Result (Last) := C;
               end if;
            end loop;
         end;
      end return;
   end Without_Returns;

   --  Input methods' text

   function Is_Composing (Item : Text_Area) return Boolean is
     (Item.Composing);

   procedure Drop_Composition (Item : in out Text_Area);
   --  Take the input method's text away, leaving the caret where it was.

   procedure Drop_Composition (Item : in out Text_Area) is
   begin
      Catch_Up (Item);
      if Item.Composing then
         Item.Composing := False;
         Change (Item, Item.Composed, Composed_End (Item), "",
                 Recorded => False);
      end if;
   end Drop_Composition;

   procedure Finish_Composition (Item : in out Text_Area);
   --  Keep the input method's text as if it were typed: before anything
   --  else is done.

   procedure Finish_Composition (Item : in out Text_Area) is
   begin
      Catch_Up (Item);
      if Item.Composing then
         declare
            Composed : constant String :=
              Docs.Between (Item.Doc.all, Item.Composed, Composed_End (Item));
            From     : constant Position := Item.Composed;
         begin
            Drop_Composition (Item);
            Change (Item, From, From, Composed);
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
      Catch_Up (Item);
      for C of Clean loop
         if C = ASCII.LF then
            C := ' ';
         end if;
      end loop;

      if not Item.Composing and then Clean /= "" then
         if Has_Selection (Item) then
            Edit (Item, Selection_First (Item), Selection_Last (Item), "",
                  Docs.Other);
         end if;
         Item.Composed := Item.At_Caret;
      elsif Item.Composing then
         Drop_Composition (Item);
      end if;

      if Clean /= "" then
         Change (Item, Item.Composed, Item.Composed, Clean,
                 Recorded => False);
         Item.Composing := True;
         Item.Composed_Length := Clean'Length;

         --  The caret after Cursor characters.
         declare
            Byte : Positive := Item.Composed.Index;
            Seen : Natural := 0;
         begin
            while Seen < Cursor and then Byte < Composed_End (Item).Index
            loop
               Byte := Layouts.Next_Character
                 (Item.Doc.all, Item.Composed.Paragraph, Byte);
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
      Docs.Seal (Item.Doc.all);
      Moved (Item);
   end Select_Range;

   procedure Select_All (Item : in out Text_Area) is
   begin
      Catch_Up (Item);
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
      Doc_Of   : Docs.Document renames Item.Doc.all;
      Para     : constant Positive := From.Paragraph;
      Byte     : constant Positive := From.Index;
      At_Start : constant Boolean := Byte = 1;
      At_End   : constant Boolean := Byte > Byte_Length (Item, Para);
   begin
      case By is
         when Previous_Character | Previous_Word =>
            if not At_Start then
               return
                 (Para,
                  (if By = Previous_Word
                   then Layouts.Previous_Word (Doc_Of, Para, Byte)
                   else Layouts.Previous_Character (Doc_Of, Para, Byte)));
            elsif Para > 1 then
               return Paragraph_End (Item, Para - 1);
            end if;

         when Next_Character | Next_Word =>
            if not At_End then
               return
                 (Para,
                  (if By = Next_Word
                   then Layouts.Next_Word (Doc_Of, Para, Byte)
                   else Layouts.Next_Character (Doc_Of, Para, Byte)));
            elsif Para < Count (Item) then
               return (Para + 1, 1);
            end if;

         when Line_Start =>
            declare
               Number : constant Positive := Line_Of (Item, From);
            begin
               return
                 (Para,
                  Docs.Index_Of
                    (Doc_Of, Para,
                     Layouts.Line (Item.Laid, Para, Number).First));
            end;

         when Line_End =>
            declare
               Number : constant Positive := Line_Of (Item, From);
            begin
               if Layouts.Line (Item.Laid, Para, Number).Stop
                 < Docs.Length (Doc_Of, Para)
               then
                  --  Before the space the line breaks after.
                  return
                    (Para,
                     Docs.Index_Of
                       (Doc_Of, Para,
                        Layouts.Units_At_Offset
                          (Item.Laid, Doc_Of, Para, Number, Float'Last)));
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
            elsif Para < Count (Item) then
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
         Docs.Index_Of
           (Item.Doc.all, Para,
            Layouts.Units_At_Offset
              (Item.Laid, Item.Doc.all, Para, Number, X)));
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
   begin
      if not Item.Has_Goal then
         Item.Goal := Layouts.Caret_Offset
           (Item.Laid, Item.Doc.all, Para, Number,
            Units (Item, Item.At_Caret));
         Item.Has_Goal := True;
      end if;

      if By = Previous_Line then
         if Number > 1 then
            return Line_Position (Item, Para, Number - 1, Item.Goal);
         elsif Para > 1 then
            Layouts.Lay_Out (Item.Laid, Item.Doc.all, Para - 1);
            return Line_Position
              (Item, Para - 1, Layouts.Line_Count (Item.Laid, Para - 1),
               Item.Goal);
         end if;
         return (1, 1);
      end if;

      Layouts.Lay_Out (Item.Laid, Item.Doc.all, Para, Number + 1);
      if Number < Layouts.Line_Count (Item.Laid, Para) then
         return Line_Position (Item, Para, Number + 1, Item.Goal);
      elsif Para < Count (Item) then
         Layouts.Lay_Out (Item.Laid, Item.Doc.all, Para + 1, 1);
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
      Docs.Seal (Item.Doc.all);
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
      High  : constant Float := Layouts.Line_Height (Item.Laid);
      Depth : constant Float :=
        View_Top (Item) + (Y - Text_Top (Item)) / Scale (Item);
      Para  : constant Positive := Layouts.Paragraph_At (Item.Laid, Depth);
      Within : constant Float :=
        Float'Max (0.0, Depth - Layouts.Top (Item.Laid, Para)) / High;
      Wanted : constant Positive :=
        (if Within >= Float (Most_Lines) then Most_Lines
         else Natural (Float'Floor (Within)) + 1);
   begin
      Layouts.Lay_Out (Item.Laid, Item.Doc.all, Para, Wanted);
      return Line_Position
        (Item, Para,
         Positive'Min (Wanted, Layouts.Line_Count (Item.Laid, Para)),
         (X - Column_Left (Item)) / Scale (Item));
   end Point_At;

   function Is_Over_Selection
     (Item : in out Text_Area; X, Y : Float) return Boolean is
   begin
      if not Has_Selection (Item) then
         return False;
      end if;
      Catch_Up (Item);
      declare
         Point : constant Position := Point_At (Item, X, Y);
         First : constant Position :=
           (if Item.At_Caret < Item.At_Mark then Item.At_Caret
            else Item.At_Mark);
         Last  : constant Position :=
           (if Item.At_Caret < Item.At_Mark then Item.At_Mark
            else Item.At_Caret);
      begin
         return not (Point < First) and then Point < Last;
      end;
   end Is_Over_Selection;

   procedure Click
     (Item   : in out Text_Area;
      X, Y   : Float;
      Clicks : Positive := 1;
      Extend : Boolean := False)
   is
      Point : Position;
   begin
      Finish_Composition (Item);
      Docs.Seal (Item.Doc.all);
      Point := Point_At (Item, X, Y);
      Item.Focused := True;
      Item.Dragging := True;
      Item.Has_Goal := False;

      if Clicks = 1 or else Extend then
         Item.At_Caret := Point;
         if not Extend then
            Item.At_Mark := Point;
         end if;
      elsif Clicks = 2 then
         declare
            First, Stop : Positive;
         begin
            Layouts.Word_At
              (Item.Doc.all, Point.Paragraph, Point.Index, First, Stop);
            --  Not on a word: the character there.
            if First = Stop
              and then Point.Index <= Byte_Length (Item, Point.Paragraph)
            then
               Stop := Layouts.Next_Character
                 (Item.Doc.all, Point.Paragraph, Point.Index);
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
      Catch_Up (Item);
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

   function Fitted (Item : Text_Area; Raw : String) return String;
   --  What of Raw to put in the text: without carriage returns, and for
   --  one line, with spaces for line feeds.

   function Fitted (Item : Text_Area; Raw : String) return String is
      Result : String := Without_Returns (Raw);
   begin
      if Item.Single then
         for Char of Result loop
            if Char = ASCII.LF then
               Char := ' ';
            end if;
         end loop;
      end if;
      return Result;
   end Fitted;

   procedure Insert (Item : in out Text_Area; Typed : String) is
   begin
      Drop_Composition (Item);  --  Typed is what it became
      Edit (Item, Selection_First (Item), Selection_Last (Item),
            Fitted (Item, Typed), Docs.Typing);
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
               Docs.Other);
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
         Edit (Item, From, Item.At_Caret, "", Docs.Deleting_Back);
      end;
   end Delete_Backward;

   procedure Delete_Forward
     (Item : in out Text_Area; By : Deletion := Character) is
   begin
      Finish_Composition (Item);
      if Has_Selection (Item) then
         Edit (Item, Selection_First (Item), Selection_Last (Item), "",
               Docs.Other);
         return;
      end if;
      declare
         To : Position :=
           Step (Item, Item.At_Caret, Deletion_Motion (By, True));
      begin
         if To = Item.At_Caret then
            To := Step (Item, Item.At_Caret, Next_Character);
         end if;
         Edit (Item, Item.At_Caret, To, "", Docs.Deleting_Forward);
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
               Docs.Other);
      end if;
   end Cut;

   procedure Paste
     (Item  : in out Text_Area;
      Board : in out Clipboards.Clipboard'Class) is
   begin
      Finish_Composition (Item);
      Edit (Item, Selection_First (Item), Selection_Last (Item),
            Fitted (Item, Board.Text), Docs.Other);
   end Paste;

   --  Undoing

   procedure Undo (Item : in out Text_Area) is
      From, To : Position;
   begin
      Finish_Composition (Item);
      if Docs.Can_Undo (Item.Doc.all)
        and then not Docs.In_Step (Item.Doc.all)
      then
         Docs.Undo (Item.Doc.all, From, To);
         Catch_Up (Item);
         Item.At_Mark := From;
         Item.At_Caret := To;
         Item.Has_Goal := False;
         Moved (Item);
      end if;
   end Undo;

   procedure Redo (Item : in out Text_Area) is
      From, To : Position;
   begin
      Finish_Composition (Item);
      if Docs.Can_Redo (Item.Doc.all)
        and then not Docs.In_Step (Item.Doc.all)
      then
         Docs.Redo (Item.Doc.all, From, To);
         Catch_Up (Item);
         Item.At_Mark := To;
         Item.At_Caret := To;
         Item.Has_Goal := False;
         Moved (Item);
      end if;
   end Redo;

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
      High    : constant Float := Layouts.Line_Height (Item.Laid);

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
         if Item.Single then
            Item.Returned := True;
         else
            Insert (Item, [ASCII.LF]);
         end if;
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
         Scroll (Item, -Layouts.Total_Height (Item.Laid));
      elsif Key = Events.Key_End then
         Scroll (Item, Layouts.Total_Height (Item.Laid));
      else
         Handled := False;
      end if;
   end Handle_Key;

   function Bar_Metrics (Item : Text_Area) return Scrollbars.Metrics is
      Edge : constant Float :=
        (if Item.Focused then Focus_Outline else Outline) * Item.Density;
   begin
      return
        (Left    => Float (Integer (Item.Left + Edge)),
         Top     => Float (Integer (Item.Top + Edge)),
         Width   => Float'Max
                      (0.0, Float (Integer (Item.Left + Item.Width - Edge))
                            - Float (Integer (Item.Left + Edge))),
         Height  => Float'Max
                      (0.0, Float (Integer (Item.Top + Item.Height - Edge))
                            - Float (Integer (Item.Top + Edge))),
         Density => Item.Density,
         Start   => View_Top (Item),
         Shown   => Extent (Item),
         Total   => Layouts.Total_Height (Item.Laid),
         Horizontal => False);
   end Bar_Metrics;

   procedure Set_Faint (Item : in out Text_Area; From, To : Position) is
   begin
      Item.Faint_On := From < To;
      Item.Faint_From := From;
      Item.Faint_To := To;
      Item.Faint_Version := Docs.Current (Item.Doc.all);
   end Set_Faint;

   procedure Clear_Faint (Item : in out Text_Area) is
   begin
      Item.Faint_On := False;
   end Clear_Faint;

   procedure Set_Hovered (Item : in out Text_Area; Hovered : Boolean) is
   begin
      Scrollbars.Set_Pane (Item.Bar, Hovered);
   end Set_Hovered;

   procedure Take_Bar_Change
     (Item : in out Text_Area; Changed : out Boolean) is
   begin
      Changed := Item.Bar_Dirty;
      Item.Bar_Dirty := False;
   end Take_Bar_Change;

   procedure Handle
     (Item    : in out Text_Area;
      Event   : Events.Event;
      Board   : in out Clipboards.Clipboard'Class;
      Handled : out Boolean)
   is
      X : constant Float := Event.Mouse_X * Item.Density;
      Y : constant Float := Event.Mouse_Y * Item.Density;
   begin
      Catch_Up (Item);
      Item.Now := SDL3.Events.Milliseconds'Max (Item.Now, Event.Time);
      Handled := False;
      if not Item.Single and then not Item.Grows
        and then Event.Kind in Events.Mouse_Down | Events.Mouse_Move
                             | Events.Mouse_Up
      then
         declare
            Dragged, Changed : Boolean;
            To : Float;
            Before : constant Boolean := Scrollbars.Is_Shown (Item.Bar);
         begin
            if Event.Kind = Events.Mouse_Move then
               Scrollbars.Set_Pane (Item.Bar, Contains (Item, X, Y));
            end if;
            Scrollbars.Handle
              (Item.Bar, Event, Bar_Metrics (Item), Handled, Dragged, To,
               Changed);
            if Dragged then
               Scroll (Item, To - View_Top (Item));
            end if;
            if Changed or else Dragged
              or else Before /= Scrollbars.Is_Shown (Item.Bar)
            then
               Item.Bar_Dirty := True;
            end if;
            if Handled then
               return;
            end if;
         end;
      end if;
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
            if not Item.Grows and then not Event.Command
              and then Contains (Item, X, Y)
            then
               Scroll
                 (Item,
                  -Event.Wheel_Y * Lines_Per_Notch
                   * Layouts.Line_Height (Item.Laid));
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
         when Events.Quit | Events.Pinch | Events.Redraw
            | Events.Theme_Changed | Events.Other =>
            null;
      end case;
   end Handle;

   --  Drawing

   Faint_Alpha : constant SDL3.Windows.Renderers.Color_Component := 150;
   --  How much of the page's colour covers text that is not settled.

   procedure Draw_Range
     (Item        : in out Text_Area;
      Target      : SDL3.Windows.Renderers.Renderer;
      From, To    : Position;
      First, Last : Positive;
      Value       : SDL3.Windows.Renderers.Color;
      Underlined  : Boolean;
      Rows_From, Rows_To : Float);
   --  Mark the text from From to To, in paragraphs First to Last, which
   --  are laid out: fill behind it, or underline it. Lines wholly outside
   --  the rows of the target Rows_From to Rows_To are left.

   procedure Draw_Range
     (Item        : in out Text_Area;
      Target      : SDL3.Windows.Renderers.Renderer;
      From, To    : Position;
      First, Last : Positive;
      Value       : SDL3.Windows.Renderers.Color;
      Underlined  : Boolean;
      Rows_From, Rows_To : Float)
   is
      High  : constant Float := Layouts.Line_Height (Item.Laid);
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
            Para_Top    : constant Float := Layouts.Top (Item.Laid, Para);
            Lines       : constant Positive :=
              Layouts.Line_Count (Item.Laid, Para);
         begin
            for Number in 1 .. Lines loop
               declare
                  Line : constant CoreText.Wrapping.Span :=
                    Layouts.Line (Item.Laid, Para, Number);
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
                  --  Where the line ends, or the space after the
                  --  paragraph that a mark running on fills; a little
                  --  more, for an underline.
                  Line_Bottom : constant Float :=
                    (if Number = Lines
                       and then Layouts.Is_Complete (Item.Laid, Para)
                     then Text_Top (Item)
                          + (Para_Top + Layouts.Height (Item.Laid, Para)
                             - Shown) * Scale (Item)
                     else Y + High * Scale (Item))
                    + Underline_Gap * Item.Density;
               begin
                  if Line_Bottom >= Rows_From and then Y <= Rows_To
                    and then A <= Line.Stop
                    and then (if Underlined then A < B
                              else A < B or else Runs_On)
                  then
                     declare
                        X_A : constant Float := Layouts.Caret_Offset
                          (Item.Laid, Item.Doc.all, Para, Number, A);
                        X_B : constant Float :=
                          (if Runs_On and then not Underlined
                           then Float'Max (Right, X_A)
                           else Layouts.Caret_Offset
                                  (Item.Laid, Item.Doc.all, Para, Number,
                                   B));
                        Left : constant Float :=
                          Column_Left (Item) + X_A * Scale (Item);
                        Wide : constant Float := (X_B - X_A) * Scale (Item);
                     begin
                        if Underlined then
                           SDL3.Windows.Renderers.Fill_Rect
                             (Target, Value, Left,
                              Y + Layouts.Ascent (Item.Laid) * Scale (Item)
                              + Underline_Gap * Item.Density,
                              Wide, Underline * Item.Density);
                        else
                           declare
                              --  Down over the space after the paragraph
                              --  too, if it runs on to the next.
                              Bottom : constant Float :=
                                (if Runs_On and then Number = Lines
                                   and then Layouts.Is_Complete
                                              (Item.Laid, Para)
                                 then Text_Top (Item)
                                      + (Para_Top
                                         + Layouts.Height (Item.Laid, Para)
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
      X, Y, Width, Height : out Float) is
   begin
      Catch_Up (Item);
      if not (Item.Caret_Kept
              and then Item.Caret_For = Item.At_Caret
              and then Item.Caret_Version = Item.Seen
              and then Item.Caret_Serial = Item.Serial
              and then Item.Caret_Width = Layouts.Width (Item.Laid))
      then
         --  Shaping the line to measure it is the cost: not the top of
         --  the paragraph, which moves as others are laid out.
         Item.Caret_Line := Line_Of (Item, Item.At_Caret);
         Item.Caret_Across := Layouts.Caret_Offset
           (Item.Laid, Item.Doc.all, Item.At_Caret.Paragraph,
            Item.Caret_Line, Units (Item, Item.At_Caret));
         Item.Caret_For := Item.At_Caret;
         Item.Caret_Version := Item.Seen;
         Item.Caret_Serial := Item.Serial;
         Item.Caret_Width := Layouts.Width (Item.Laid);
         Item.Caret_Kept := True;
         Item.Caret_Worked := Item.Caret_Worked + 1;
      end if;
      declare
         Para     : constant Positive := Item.At_Caret.Paragraph;
         Number   : constant Positive := Item.Caret_Line;
         High     : constant Float := Layouts.Line_Height (Item.Laid);
         Line_Top : constant Float :=
           Layouts.Top (Item.Laid, Para) + Float (Number - 1) * High;
         Across   : constant Float := Item.Caret_Across;
      begin
         Width := Caret_Width * Item.Density;
         X := Column_Left (Item) + Across * Scale (Item) - Width / 2.0;
         Y := Text_Top (Item) + (Line_Top - View_Top (Item)) * Scale (Item);
         Height := High * Scale (Item);
      end;
   end Caret_Box;

   function Lines_Drawn (Item : Text_Area) return Natural is
     (Views.Lines_Drawn (Item.View));

   function Caret_Measures (Item : Text_Area) return Natural is
     (Item.Caret_Worked);

   procedure Draw
     (Item      : in out Text_Area;
      Target    : SDL3.Windows.Renderers.Renderer;
      Colors    : Themes.Theme;
      Settled   : Boolean := True;
      Rows_From : Float := Float'First;
      Rows_To   : Float := Float'Last)
   is
      use SDL3.Windows.Renderers;
      Edge : constant Float :=
        (if Item.Grows then 0.0
         elsif Item.Focused then Focus_Outline else Outline) * Item.Density;
      --  A page has no outline.
      Inner_Left   : constant Integer := Integer (Item.Left + Edge);
      Inner_Top    : constant Integer := Integer (Item.Top + Edge);
      Inner_Right  : constant Integer :=
        Integer (Item.Left + Item.Width - Edge);
      Inner_Bottom : constant Integer :=
        Integer (Item.Top + Item.Height - Edge);
      Lead         : constant Integer := Integer (Lead_Room (Item));
      Trail        : constant Integer := Integer (Trail_Room (Item));
      First, Last  : Positive;
      Outer_Clip   : constant Clip := Current_Clip (Target);
      --  The owner's, to go back to.
   begin
      Catch_Up (Item);
      Fill_Rect
        (Target, (if Item.Focused then Colors.Focus else Colors.Border),
         Item.Left, Item.Top, Item.Width, Item.Height);
      Fill_Rect
        (Target, Colors.Background,
         Float (Inner_Left), Float (Inner_Top),
         Float (Integer'Max (0, Inner_Right - Inner_Left)),
         Float (Integer'Max (0, Inner_Bottom - Inner_Top)));

      --  Lines part in view run into the padding, but not the outline,
      --  nor what is before a single line.
      Narrow_Clip
        (Target, Inner_Left + Lead, Inner_Top,
         Integer'Max (0, Inner_Right - Inner_Left - Lead - Trail),
         Integer'Max (0, Inner_Bottom - Inner_Top));

      --  What is shown, laid out, as the view will draw it.
      Layouts.Visible
        (Item.Laid, Item.Doc.all, Item.Anchor, Item.Offset, Extent (Item),
         First, Last);

      if Has_Selection (Item) then
         Draw_Range
           (Item, Target, Selection_First (Item), Selection_Last (Item),
            First, Last,
            (if Item.Focused then Themes.Selection (Colors)
             else Themes.Inactive_Selection (Colors)),
            Underlined => False,
            Rows_From => Rows_From, Rows_To => Rows_To);
      end if;

      Views.Draw
        (Item.View, Item.Laid, Item.Doc.all, Target, Colors.Foreground,
         Item.Anchor, Item.Offset,
         Left    => Column_Left (Item),
         Top     => Text_Top (Item),
         Width   => Natural (Float'Floor (Text_Width (Item))),
         Height  => Natural (Float'Floor (Text_Height (Item))),
         Scale   => Scale (Item),
         Settled => Settled,
         Rows_From => Rows_From, Rows_To => Rows_To);

      if Item.Faint_On
        and then Item.Faint_Version = Docs.Current (Item.Doc.all)
      then
         --  Text laid over with the page's own colour, part see-through,
         --  is text part faded.
         Draw_Range
           (Item, Target, Item.Faint_From, Item.Faint_To, First, Last,
            (Colors.Background with delta Alpha => Faint_Alpha),
            Underlined => False,
            Rows_From => Rows_From, Rows_To => Rows_To);
      end if;

      if Item.Composing then
         Draw_Range
           (Item, Target, Item.Composed, Composed_End (Item), First, Last,
            Colors.Foreground, Underlined => True,
            Rows_From => Rows_From, Rows_To => Rows_To);
      end if;

      if Is_Caret_Shown (Item) and then not Has_Selection (Item) then
         declare
            X, Y, Wide, High : Float;
         begin
            Caret_Box (Item, X, Y, Wide, High);
            Fill_Rect (Target, Colors.Accent, X, Y, Wide, High);
         end;
      end if;

      if not Item.Single then
         Scrollbars.Draw (Item.Bar, Target, Colors, Bar_Metrics (Item));
      end if;

      Restore_Clip (Target, Outer_Clip);
   end Draw;

end UI.Text_Areas;
