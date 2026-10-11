with Ada.Unchecked_Deallocation;
with Interfaces.C;
with System.Storage_Elements;

package body Texts.Documents is

   package Unbounded renames Ada.Strings.Unbounded;
   use type Unbounded.Unbounded_String;
   use type Named_Vectors.Vector;

   procedure Free is new Ada.Unchecked_Deallocation (String, Text_Access);
   procedure Free is new Ada.Unchecked_Deallocation
     (Mark_Array, Mark_Access);
   procedure Free is new Ada.Unchecked_Deallocation
     (Paragraph, Paragraph_Access);

   Serials : Natural := 0;
   --  Documents made so far.

   --  A paragraph's text, in its buffer with a gap

   function Size (P : Paragraph_Access) return Natural is
     (P.Buffer'Length - P.Gap_Size);
   --  In bytes.

   function Byte (P : Paragraph_Access; Index : Positive) return Character is
     (P.Buffer (if Index < P.Gap_First then Index else Index + P.Gap_Size));
   --  Of the text, past the gap.

   function Slice_Of (P : Paragraph_Access; First, Stop : Positive)
      return String
     with Pre => First <= Stop and then Stop <= Size (P) + 1;
   --  The bytes First .. Stop - 1 of the text.

   function Slice_Of (P : Paragraph_Access; First, Stop : Positive)
      return String
   is
      Buffer : String renames P.Buffer.all;
      Gap    : constant Natural := P.Gap_Size;
   begin
      if Stop <= P.Gap_First then
         return Buffer (First .. Stop - 1);
      elsif First >= P.Gap_First then
         return Buffer (First + Gap .. Stop - 1 + Gap);
      else
         return Buffer (First .. P.Gap_First - 1)
           & Buffer (P.Gap_First + Gap .. Stop - 1 + Gap);
      end if;
   end Slice_Of;

   function Units_In (P : Paragraph_Access; First, Stop : Positive)
      return Natural
     with Pre => First <= Stop and then Stop <= Size (P) + 1;
   --  The UTF-16 units of the bytes First .. Stop - 1, on either side of
   --  the gap.

   function Units_In (P : Paragraph_Access; First, Stop : Positive)
      return Natural
   is
      Buffer : String renames P.Buffer.all;
      Gap    : constant Natural := P.Gap_Size;
      Result : Natural := 0;
   begin
      for I in First .. Natural'Min (Stop, P.Gap_First) - 1 loop
         Result := Result + Units_Of (Buffer (I));
      end loop;
      for I in Natural'Max (First, P.Gap_First) .. Stop - 1 loop
         Result := Result + Units_Of (Buffer (I + Gap));
      end loop;
      return Result;
   end Units_In;

   function Units_Of (P : Paragraph_Access) return Natural;
   --  The UTF-16 length of P's text, counted now if it was not.

   function Units_Of (P : Paragraph_Access) return Natural is
   begin
      if not P.Counted then
         P.Units := Units_In (P, 1, Size (P) + 1);
         P.Counted := True;
      end if;
      return P.Units;
   end Units_Of;

   procedure Set_Text (P : Paragraph_Access; Content : String);
   --  Make Content P's text, with no gap.

   procedure Set_Text (P : Paragraph_Access; Content : String) is
   begin
      Free (P.Buffer);
      P.Buffer := new String (1 .. Content'Length);
      P.Buffer.all := Content;
      P.Gap_First := Content'Length + 1;
      P.Gap_Size := 0;
      P.Marked := 0;
   end Set_Text;

   procedure Move_Gap (P : Paragraph_Access; To : Positive)
     with Pre => To <= Size (P) + 1, Post => P.Gap_First = To;
   --  Put the gap before byte To of the text, moving only what is
   --  between.

   procedure Move_Gap (P : Paragraph_Access; To : Positive) is
      Buffer : String renames P.Buffer.all;
      Gap    : constant Natural := P.Gap_Size;
   begin
      if To < P.Gap_First then
         Buffer (To + Gap .. P.Gap_First - 1 + Gap) :=
           Buffer (To .. P.Gap_First - 1);
      elsif To > P.Gap_First then
         Buffer (P.Gap_First .. To - 1) :=
           Buffer (P.Gap_First + Gap .. To - 1 + Gap);
      end if;
      P.Gap_First := To;
   end Move_Gap;

   procedure Widen_Gap (P : Paragraph_Access; Wanted : Natural)
     with Post => P.Gap_Size >= Wanted;
   --  Make the gap at least Wanted bytes, with room to spare: a quarter
   --  of the text again, so that growing costs little, over many edits.

   procedure Widen_Gap (P : Paragraph_Access; Wanted : Natural) is
   begin
      if P.Gap_Size < Wanted then
         declare
            Old    : Text_Access := P.Buffer;
            Text_Size : constant Natural := Size (P);
            Gap    : constant Natural :=
              Wanted + Natural'Max (16, Text_Size / 4);
            After  : constant Natural := Text_Size - (P.Gap_First - 1);
         begin
            P.Buffer := new String (1 .. Text_Size + Gap);
            P.Buffer (1 .. P.Gap_First - 1) := Old (1 .. P.Gap_First - 1);
            P.Buffer (P.Gap_First + Gap .. P.Buffer'Last) :=
              Old (Old'Last - After + 1 .. Old'Last);
            P.Gap_Size := Gap;
            Free (Old);
         end;
      end if;
   end Widen_Gap;

   procedure Free_Paragraph (P : in out Paragraph_Access) is
   begin
      Free (P.Buffer);
      Free (P.Marks);
      Free (P);
   end Free_Paragraph;

   function New_Paragraph
     (Content : String; Units : Natural; Name : Named)
      return Paragraph_Access
   is
      Result : constant Paragraph_Access :=
        new Paragraph'(Buffer    => new String (1 .. Content'Length),
                       Gap_First => Content'Length + 1,
                       Gap_Size  => 0,
                       Units     => Units,
                       Counted   => True,
                       Id        => Name.Id,
                       Kind      => Name.Kind,
                       Marks     => null,
                       Marked    => 0);
   begin
      Result.Buffer.all := Content;
      return Result;
   end New_Paragraph;

   function Uncounted (Content : String; Name : Named)
      return Paragraph_Access;
   --  A paragraph of Content whose UTF-16 length is not yet counted.

   function Uncounted (Content : String; Name : Named)
      return Paragraph_Access
   is
      Result : constant Paragraph_Access := New_Paragraph (Content, 0, Name);
   begin
      Result.Counted := False;
      return Result;
   end Uncounted;

   function Fresh (Item : in out Document) return Named;
   --  A new id, and Plain.

   function Fresh (Item : in out Document) return Named is
      Result : constant Named := (Id => Item.Next_Id, Kind => Plain);
   begin
      Item.Next_Id := Item.Next_Id + 1;
      return Result;
   end Fresh;

   procedure Clear (Item : in out Document) is
   begin
      for P of Item.Paragraphs loop
         Free_Paragraph (P);
      end loop;
      Item.Paragraphs.Clear;
   end Clear;

   overriding procedure Initialize (Item : in out Document) is
   begin
      Serials := Serials + 1;
      Item.Serial := Serials;
      Item.Paragraphs.Append (New_Paragraph ("", 0, Fresh (Item)));
   end Initialize;

   overriding procedure Finalize (Item : in out Document) is
   begin
      Clear (Item);
   end Finalize;

   procedure Forget_Log (Item : in out Document) is
   begin
      --  Past every version a view has seen, so that all start again.
      Item.Base := Current (Item) + 1;
      Item.Log.Clear;
   end Forget_Log;

   function Find_Byte
     (From : System.Address; Value : Interfaces.C.int;
      Bytes : Interfaces.C.size_t) return System.Address
     with Import, Convention => C, External_Name => "memchr";
   --  The first byte Value in the Bytes bytes at From, or null: as quick
   --  as the machine can look.

   procedure Load (Item : in out Document; Content : String) is
      use type System.Address;
      use type System.Storage_Elements.Storage_Offset;
      Start : Positive := Content'First;
   begin
      Clear (Item);
      Item.Paragraphs.Reserve_Capacity
        (Ada.Containers.Count_Type (Content'Length / 64 + 1));
      while Start <= Content'Last loop
         declare
            Found : constant System.Address :=
              Find_Byte
                (Content (Start)'Address, Character'Pos (ASCII.LF),
                 Interfaces.C.size_t (Content'Last - Start + 1));
            Break : Positive;
         begin
            exit when Found = System.Null_Address;
            Break := Start
              + Integer (Found - Content (Start)'Address);
            Item.Paragraphs.Append
              (Uncounted
                 (Content
                    (Start
                     .. (if Break > Start
                           and then Content (Break - 1) = ASCII.CR
                         then Break - 2 else Break - 1)),
                  Fresh (Item)));
            Start := Break + 1;
         end;
      end loop;
      Item.Paragraphs.Append
        (Uncounted (Content (Start .. Content'Last), Fresh (Item)));

      Item.Undos.Clear;
      Item.Redos.Clear;
      Item.Last_State := 0;
      Item.Depth := 0;
      Item.Joining := False;
      Forget_Log (Item);
   end Load;

   function Count (Item : Document) return Positive is
     (Positive (Item.Paragraphs.Length));

   function Text (Item : Document; Para : Positive) return String is
     (Slice_Of (Item.Paragraphs.Element (Para), 1,
                Size (Item.Paragraphs.Element (Para)) + 1));

   function Slice
     (Item : Document; Para : Positive; First, Stop : Positive)
      return String is
     (Slice_Of (Item.Paragraphs.Element (Para), First, Stop));

   function Byte_Length (Item : Document; Para : Positive) return Natural is
     (Size (Item.Paragraphs.Element (Para)));

   function Length (Item : Document; Para : Positive) return Natural is
     (Units_Of (Item.Paragraphs.Element (Para)));

   function Id (Item : Document; Para : Positive) return Paragraph_Id is
     (Item.Paragraphs.Element (Para).Id);

   function Find (Item : Document; Name : Paragraph_Id) return Natural is
   begin
      for Para in 1 .. Count (Item) loop
         if Item.Paragraphs.Element (Para).Id = Name then
            return Para;
         end if;
      end loop;
      return 0;
   end Find;

   function Kind (Item : Document; Para : Positive) return Paragraph_Kind is
     (Item.Paragraphs.Element (Para).Kind);

   --  Positions

   function Is_Boundary
     (Item : Document; Para : Positive; Index : Positive) return Boolean
   is
      P : constant Paragraph_Access := Item.Paragraphs.Element (Para);
   begin
      return Index > Size (P) or else not Is_Continuation (Byte (P, Index));
   end Is_Boundary;

   function Paragraph_End (Item : Document; Para : Positive) return Position
   is ((Para, Byte_Length (Item, Para) + 1));

   function Text_End (Item : Document) return Position is
     (Paragraph_End (Item, Count (Item)));

   function Between (Item : Document; From, To : Position) return String is
      Result : Unbounded.Unbounded_String;
   begin
      for Para in From.Paragraph .. To.Paragraph loop
         declare
            P     : constant Paragraph_Access :=
              Item.Paragraphs.Element (Para);
            First : constant Positive :=
              (if Para = From.Paragraph then From.Index else 1);
            Stop  : constant Positive :=
              (if Para = To.Paragraph then To.Index else Size (P) + 1);
         begin
            if Para > From.Paragraph then
               Unbounded.Append (Result, ASCII.LF);
            end if;
            Unbounded.Append (Result, Slice_Of (P, First, Stop));
         end;
      end loop;
      return Unbounded.To_String (Result);
   end Between;

   function Whole (Item : Document) return String is
     (Between (Item, (1, 1), Text_End (Item)));

   --  The UTF-16 offsets kept: right as far as Marked; extended when
   --  wanted, so that an edit costs only what lies between it and what is
   --  asked for next, not the whole paragraph.

   function Last_Block (P : Paragraph_Access) return Natural is
     (Size (P) / Mark_Spacing);

   procedure Mark (P : Paragraph_Access; Upto : Natural)
     with Pre  => Upto <= Last_Block (P),
          Post => P.Marked > Upto;
   --  Make P's marks right as far as Marks (Upto).

   procedure Mark (P : Paragraph_Access; Upto : Natural) is
   begin
      if P.Marks = null or else P.Marks'Last < Upto then
         declare
            Old  : Mark_Access := P.Marks;
            Room : constant Natural :=
              Natural'Max (Upto, Last_Block (P)) + 16;
         begin
            P.Marks := new Mark_Array (0 .. Room);
            if Old /= null then
               P.Marks (0 .. P.Marked - 1) := Old (0 .. P.Marked - 1);
               Free (Old);
            end if;
         end;
      end if;
      if P.Marked = 0 then
         P.Marks (0) := 0;
         P.Marked := 1;
      end if;
      for Block in P.Marked .. Upto loop
         P.Marks (Block) := P.Marks (Block - 1)
           + Units_In (P, (Block - 1) * Mark_Spacing + 1,
                       Block * Mark_Spacing + 1);
      end loop;
      P.Marked := Natural'Max (P.Marked, Upto + 1);
   end Mark;

   function Units_Before
     (Item : Document; Para : Positive; Index : Positive) return Natural
   is
      P     : constant Paragraph_Access := Item.Paragraphs.Element (Para);
      Block : constant Natural := (Index - 1) / Mark_Spacing;
   begin
      if Index > Size (P) then
         return Units_Of (P);  --  the end: known
      end if;
      Mark (P, Block);
      return P.Marks (Block)
        + Units_In (P, Block * Mark_Spacing + 1, Index);
   end Units_Before;

   function Index_Of
     (Item : Document; Para : Positive; Units : Natural) return Positive
   is
      P       : constant Paragraph_Access := Item.Paragraphs.Element (Para);
      Low, High : Natural;
      Seen    : Natural;
   begin
      if Units = Units_Of (P) then
         return Size (P) + 1;  --  the end: known
      end if;

      --  Marks as far as past Units.
      Mark (P, 0);
      while P.Marked - 1 < Last_Block (P)
        and then P.Marks (P.Marked - 1) <= Units
      loop
         Mark (P, Natural'Min (Last_Block (P), P.Marked + 15));
      end loop;

      --  The last block that starts at or before Units.
      Low := 0;
      High := P.Marked - 1;
      while Low < High loop
         declare
            Mid : constant Natural := (Low + High + 1) / 2;
         begin
            if P.Marks (Mid) <= Units then
               Low := Mid;
            else
               High := Mid - 1;
            end if;
         end;
      end loop;

      Seen := P.Marks (Low);
      for I in Low * Mark_Spacing + 1 .. Size (P) loop
         declare
            Wide : constant Natural := Units_Of (Byte (P, I));
         begin
            if Wide > 0 then
               --  At, or inside, a character starting here.
               if Seen = Units or else Seen + Wide > Units then
                  return I;
               end if;
               Seen := Seen + Wide;
            end if;
         end;
      end loop;
      return Size (P) + 1;
   end Index_Of;

   --  Changing the text

   procedure Splice
     (Item     : in out Document;
      From, To : Position;
      By       : String;
      Given    : Named_Vectors.Vector;
      Gone     : out Named_Vectors.Vector;
      Made     : out Named_Vectors.Vector)
     with Pre => Is_Position (Item, From) and then Is_Position (Item, To)
                 and then not (To < From);
   --  Replace the text from From to To with By, at once however many
   --  paragraphs it spans, and log the change. The paragraphs By starts
   --  are named from Given, as far as it goes, and are Made; those that
   --  go are Gone.

   procedure Splice
     (Item     : in out Document;
      From, To : Position;
      By       : String;
      Given    : Named_Vectors.Vector;
      Gone     : out Named_Vectors.Vector;
      Made     : out Named_Vectors.Vector)
   is
      Para       : constant Positive := From.Paragraph;
      First_P    : constant Paragraph_Access := Item.Paragraphs.Element (Para);
      Last_P     : constant Paragraph_Access :=
        Item.Paragraphs.Element (To.Paragraph);
      From_Units : constant Natural :=
        Units_Before (Item, Para, From.Index);
      To_Units   : constant Natural :=
        Units_Before (Item, To.Paragraph, To.Index);
      Tail_Units : constant Natural := Units_Of (Last_P) - To_Units;
      Old_Length : constant Natural := Units_Of (First_P);
      Breaks     : Natural := 0;
      Ending     : Position;
      End_Units  : Natural;
   begin
      Gone.Clear;
      Made.Clear;
      for C of By loop
         if C = ASCII.LF then
            Breaks := Breaks + 1;
         end if;
      end loop;

      if Breaks = 0 and then To.Paragraph = Para then
         --  Within a paragraph: in its buffer, at the gap, which is
         --  usually where the last edit left it.
         Move_Gap (First_P, From.Index);
         First_P.Gap_Size := First_P.Gap_Size + (To.Index - From.Index);
         Widen_Gap (First_P, By'Length);
         First_P.Buffer
           (First_P.Gap_First .. First_P.Gap_First + By'Length - 1) := By;
         First_P.Gap_First := First_P.Gap_First + By'Length;
         First_P.Gap_Size := First_P.Gap_Size - By'Length;
         End_Units := From_Units + UTF16_Length (By);
         First_P.Units := End_Units + Tail_Units;
         First_P.Marked :=
           Natural'Min (First_P.Marked, (From.Index - 1) / Mark_Spacing + 1);
         Ending := (Para, From.Index + By'Length);
      else
         declare
            Before : constant String := Slice_Of (First_P, 1, From.Index);
            After  : constant String :=
              Slice_Of (Last_P, To.Index, Size (Last_P) + 1);
            Added  : Paragraph_Vectors.Vector;
            Start  : Positive := By'First;
            Piece  : Natural := 0;
         begin
            --  The paragraphs By makes after the first, with the tail.
            Added.Reserve_Capacity (Ada.Containers.Count_Type (Breaks));
            for I in By'Range loop
               if By (I) = ASCII.LF then
                  declare
                     Line : String renames By (Start .. I - 1);
                  begin
                     if Piece = 0 then
                        --  The first: what was before, and the first line
                        --  of By.
                        Set_Text (First_P, Before & Line);
                        First_P.Units := From_Units + UTF16_Length (Line);
                     else
                        Added.Append
                          (New_Paragraph
                             (Line, UTF16_Length (Line),
                              (if Natural (Given.Length) >= Piece
                               then Given (Piece) else Fresh (Item))));
                     end if;
                  end;
                  Piece := Piece + 1;
                  Start := I + 1;
               end if;
            end loop;

            declare
               Line  : String renames By (Start .. By'Last);
               Units : constant Natural := UTF16_Length (Line);
            begin
               if Breaks = 0 then
                  Set_Text (First_P, Before & Line & After);
                  First_P.Units := From_Units + Units + Tail_Units;
                  Ending := (Para, From.Index + Line'Length);
                  End_Units := From_Units + Units;
               else
                  Added.Append
                    (New_Paragraph
                       (Line & After, Units + Tail_Units,
                        (if Natural (Given.Length) >= Breaks
                         then Given (Breaks) else Fresh (Item))));
                  Ending := (Para + Breaks, Line'Length + 1);
                  End_Units := Units;
               end if;
            end;

            --  Out with those from From to To after the first, at once;
            --  in with the new.
            for P in Para + 1 .. To.Paragraph loop
               declare
                  Going : Paragraph_Access := Item.Paragraphs.Element (P);
               begin
                  Gone.Append (Named'(Going.Id, Going.Kind));
                  Free_Paragraph (Going);
               end;
            end loop;
            if To.Paragraph > Para then
               Item.Paragraphs.Delete
                 (Para + 1, Ada.Containers.Count_Type (To.Paragraph - Para));
            end if;
            for P of Added loop
               Made.Append (Named'(P.Id, P.Kind));
            end loop;
            if not Added.Is_Empty then
               Item.Paragraphs.Insert (Para + 1, Added);
            end if;
         end;
      end if;

      Item.Log.Append
        (Change'(From       => From,
                 To         => To,
                 Ending     => Ending,
                 From_Units => From_Units,
                 To_Units   => To_Units,
                 End_Units  => End_Units,
                 Old_Length => Old_Length,
                 Kind_Only  => False));
      if Natural (Item.Log.Length) > 2 * Log_Length then
         Item.Log.Delete_First (Log_Length);
         Item.Base := Item.Base + Log_Length;
      end if;
      pragma Assert (Ending = End_After (From, By));
      pragma Assert (Units_Before (Item, Ending.Paragraph, Ending.Index)
                     = End_Units);
   end Splice;

   procedure Set_Kind_Unrecorded
     (Item : in out Document; Para : Positive; To : Paragraph_Kind) is
   begin
      Item.Paragraphs.Element (Para).Kind := To;
      Item.Log.Append
        (Change'(From | To | Ending => (Para, 1), Kind_Only => True,
                 others => 0));
   end Set_Kind_Unrecorded;

   --  The history

   procedure Push (Item : in out Document; Done : Edit);
   --  Record Done to undo: in the open step, or joined to the last edit,
   --  or as a step of its own.

   procedure Push (Item : in out Document; Done : Edit) is
      Joined : Boolean := False;
   begin
      Item.Last_State := Item.Last_State + 1;
      if Item.Depth > 0 then
         Item.Undos.Reference (Item.Undos.Last_Index).Edits.Append (Done);
         Item.Undos.Reference (Item.Undos.Last_Index).Id := Item.Last_State;
      else
         if Item.Joining and then not Item.Undos.Is_Empty
           and then Natural (Item.Undos.Last_Element.Edits.Length) = 1
           and then Item.Undos.Last_Element.Edits.First_Element.Kind
                    = Done.Kind
           and then not Done.Kind_Only
         then
            declare
               Into : Step renames
                 Item.Undos.Reference (Item.Undos.Last_Index);
               Last : Edit renames Into.Edits.Reference (1);
            begin
               case Done.Kind is
                  when Typing =>
                     --  Typing on from where it stopped, on one line.
                     Joined := Done.Removed = Unbounded.Null_Unbounded_String
                       and then End_After
                                  (Last.From,
                                   Unbounded.To_String (Last.Inserted))
                                = Done.From
                       and then
                         (for all C of Unbounded.To_String (Done.Inserted)
                          => C /= ASCII.LF);
                     if Joined then
                        Unbounded.Append (Last.Inserted, Done.Inserted);
                     end if;
                  when Deleting_Back =>
                     Joined := Done.Inserted = Unbounded.Null_Unbounded_String
                       and then End_After
                                  (Done.From,
                                   Unbounded.To_String (Done.Removed))
                                = Last.From;
                     if Joined then
                        Last.From := Done.From;
                        Last.Removed := Done.Removed & Last.Removed;
                        Last.Gone := Done.Gone & Last.Gone;
                     end if;
                  when Deleting_Forward =>
                     Joined := Done.Inserted = Unbounded.Null_Unbounded_String
                       and then Done.From = Last.From;
                     if Joined then
                        Unbounded.Append (Last.Removed, Done.Removed);
                        Last.Gone.Append (Done.Gone);
                     end if;
                  when Other =>
                     null;
               end case;
               if Joined then
                  Into.Id := Item.Last_State;
               end if;
            end;
         end if;

         if not Joined then
            declare
               Fresh_Step : Step := (Edits => <>, Id => Item.Last_State);
            begin
               Fresh_Step.Edits.Append (Done);
               Item.Undos.Append (Fresh_Step);
            end;
            if Natural (Item.Undos.Length) > Undo_Depth then
               Item.Undos.Delete_First;
            end if;
         end if;
         Item.Joining := Done.Kind /= Other;
      end if;
      Item.Redos.Clear;
   end Push;

   procedure Replace
     (Item     : in out Document;
      From, To : Position;
      By       : String;
      Undo_As  : Edit_Kind := Other;
      Recorded : Boolean := True)
   is
      Removed    : constant Unbounded.Unbounded_String :=
        (if Recorded
         then Unbounded.To_Unbounded_String (Between (Item, From, To))
         else Unbounded.Null_Unbounded_String);
      Gone, Made : Named_Vectors.Vector;
   begin
      Splice (Item, From, To, By, Named_Vectors.Empty_Vector, Gone, Made);
      if Recorded then
         Push (Item,
               (From      => From,
                Removed   => Removed,
                Inserted  => Unbounded.To_Unbounded_String (By),
                Gone      => Gone,
                Made      => Made,
                Kind      => Undo_As,
                others    => <>));
      end if;
   end Replace;

   procedure Set_Kind
     (Item : in out Document; Para : Positive; To : Paragraph_Kind)
   is
      Old : constant Paragraph_Kind := Item.Paragraphs.Element (Para).Kind;
   begin
      Set_Kind_Unrecorded (Item, Para, To);
      Push (Item,
            (From      => (Para, 1),
             Kind_Only => True,
             Old_Kind  => Old,
             New_Kind  => To,
             others    => <>));
      Item.Joining := False;
   end Set_Kind;

   procedure Begin_Step (Item : in out Document) is
   begin
      if Item.Depth = 0 then
         Item.Undos.Append (Step'(Edits => <>, Id => 1));
         Item.Joining := False;
      end if;
      Item.Depth := Item.Depth + 1;
   end Begin_Step;

   procedure End_Step (Item : in out Document) is
   begin
      Item.Depth := Item.Depth - 1;
      if Item.Depth = 0 then
         if Item.Undos.Last_Element.Edits.Is_Empty then
            Item.Undos.Delete_Last;  --  nothing was done
         elsif Natural (Item.Undos.Length) > Undo_Depth then
            Item.Undos.Delete_First;
         end if;
      end if;
   end End_Step;

   function In_Step (Item : Document) return Boolean is (Item.Depth > 0);

   procedure Seal (Item : in out Document) is
   begin
      Item.Joining := False;
   end Seal;

   procedure Undo
     (Item : in out Document;
      From, To : out Position)
   is
      Taken : constant Step := Item.Undos.Last_Element;
      Gone, Made : Named_Vectors.Vector;
   begin
      Item.Undos.Delete_Last;
      for Done of reverse Taken.Edits loop
         if Done.Kind_Only then
            Set_Kind_Unrecorded (Item, Done.From.Paragraph, Done.Old_Kind);
         else
            Splice
              (Item, Done.From,
               End_After (Done.From, Unbounded.To_String (Done.Inserted)),
               Unbounded.To_String (Done.Removed), Done.Gone, Gone, Made);
         end if;
      end loop;
      declare
         First : Edit renames Taken.Edits.First_Element;
      begin
         From := First.From;
         To := (if First.Kind_Only then First.From
                else End_After
                       (First.From, Unbounded.To_String (First.Removed)));
      end;
      Item.Redos.Append (Taken);
      Item.Joining := False;
   end Undo;

   procedure Redo
     (Item : in out Document;
      From, To : out Position)
   is
      Taken : constant Step := Item.Redos.Last_Element;
      Gone, Made : Named_Vectors.Vector;
   begin
      Item.Redos.Delete_Last;
      for Done of Taken.Edits loop
         if Done.Kind_Only then
            Set_Kind_Unrecorded (Item, Done.From.Paragraph, Done.New_Kind);
         else
            Splice
              (Item, Done.From,
               End_After (Done.From, Unbounded.To_String (Done.Removed)),
               Unbounded.To_String (Done.Inserted), Done.Made, Gone, Made);
         end if;
      end loop;
      declare
         Last : Edit renames Taken.Edits.Last_Element;
      begin
         From := Last.From;
         To := (if Last.Kind_Only then Last.From
                else End_After
                       (Last.From, Unbounded.To_String (Last.Inserted)));
      end;
      Item.Undos.Append (Taken);
      Item.Joining := False;
   end Redo;

   function Can_Undo (Item : Document) return Boolean is
     (not Item.Undos.Is_Empty);

   function Can_Redo (Item : Document) return Boolean is
     (not Item.Redos.Is_Empty);

   function State (Item : Document) return Natural is
     (if Item.Undos.Is_Empty then 0 else Item.Undos.Last_Element.Id);

   --  The log

   function Current (Item : Document) return Version is
     (Item.Base + Version (Item.Log.Length));

   function Oldest (Item : Document) return Version is (Item.Base);

   function Serial (Item : Document) return Positive is (Item.Serial);

   function Change_After (Item : Document; Seen : Version) return Change is
     (Item.Log (Positive (Seen - Item.Base + 1)));

   function Map (Item : Change; At_Point : Position) return Position is
   begin
      if Item.Kind_Only or else At_Point < Item.From then
         return At_Point;
      elsif At_Point < Item.To then
         return Item.From;
      elsif At_Point.Paragraph = Item.To.Paragraph then
         return (Item.Ending.Paragraph,
                 Item.Ending.Index + At_Point.Index - Item.To.Index);
      else
         return (At_Point.Paragraph - Item.To.Paragraph
                   + Item.Ending.Paragraph,
                 At_Point.Index);
      end if;
   end Map;

end Texts.Documents;
