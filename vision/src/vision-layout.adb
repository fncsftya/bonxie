with Ada.Containers.Generic_Array_Sort;

package body Vision.Layout is

   Min_Gutter : constant Float := 1.0;
   --  Of the usual height of a word, how wide a gap from top to bottom of
   --  the words being cut is a gutter between columns.

   Min_Gap : constant Float := 0.3;
   --  How tall, likewise, is a gap between bands.

   Min_Split : constant Float := 1.5;
   --  How wide, likewise, is a gap within a line that makes it two.

   type Run is record
      First, Last : Positive;
      --  Its words, in the order they were found.
      Left, Top, Right, Bottom : Float;
      --  Its box, in the units of the picture's width.
   end record;

   type Run_Array is array (Positive range <>) of Run;
   type Index_Array is array (Positive range <>) of Positive;
   type Height_Array is array (Positive range <>) of Float;

   procedure Reading_Order (Item : in out Result; Aspect : Float) is
      Runs   : Run_Array (1 .. Max_Words);
      Order  : Index_Array (1 .. Max_Words);
      Count  : Natural := 0;
      Usual  : Float := 0.0;

      function Left_Of (Index : Positive) return Float is
        (Item.Words (Index).Left);

      function Right_Of (Index : Positive) return Float is
        (Item.Words (Index).Left + Item.Words (Index).Width);

      function High_Of (Index : Positive) return Float is
        (Item.Words (Index).Height * Aspect);

      procedure Find_Usual_Height is
         procedure Sort is new Ada.Containers.Generic_Array_Sort
           (Index_Type => Positive, Element_Type => Float,
            Array_Type => Height_Array);
         Heights : Height_Array (1 .. Item.Count);
      begin
         for Index in Heights'Range loop
            Heights (Index) := High_Of (Index);
         end loop;
         Sort (Heights);
         Usual := Heights (Heights'First + Heights'Length / 2);
      end Find_Usual_Height;

      procedure Make_Runs is
         First : Positive := 1;

         procedure Close (Last : Positive) is
            Made : Run :=
              (First => First, Last => Last,
               Left => Float'Last, Top => Float'Last,
               Right => 0.0, Bottom => 0.0);
         begin
            for Index in First .. Last loop
               Made.Left := Float'Min (Made.Left, Left_Of (Index));
               Made.Right := Float'Max (Made.Right, Right_Of (Index));
               Made.Top :=
                 Float'Min (Made.Top, Item.Words (Index).Top * Aspect);
               Made.Bottom :=
                 Float'Max
                   (Made.Bottom,
                    Item.Words (Index).Top * Aspect + High_Of (Index));
            end loop;
            Count := Count + 1;
            Runs (Count) := Made;
            First := Last + 1;
         end Close;
      begin
         for Index in 1 .. Item.Count loop
            if Index = Item.Count
              or else Item.Words (Index + 1).Line /= Item.Words (Index).Line
              or else Left_Of (Index + 1) - Right_Of (Index)
                      > Min_Split * Usual
            then
               Close (Index);
            end if;
         end loop;
      end Make_Runs;

      function By_Left (A, B : Positive) return Boolean is
        (Runs (A).Left < Runs (B).Left
         or else (Runs (A).Left = Runs (B).Left
                  and then Runs (A).Top < Runs (B).Top));

      function By_Top (A, B : Positive) return Boolean is
        (Runs (A).Top < Runs (B).Top
         or else (Runs (A).Top = Runs (B).Top
                  and then Runs (A).Left < Runs (B).Left));

      procedure Sort_By_Left is new Ada.Containers.Generic_Array_Sort
        (Index_Type => Positive, Element_Type => Positive,
         Array_Type => Index_Array, "<" => By_Left);

      procedure Sort_By_Top is new Ada.Containers.Generic_Array_Sort
        (Index_Type => Positive, Element_Type => Positive,
         Array_Type => Index_Array, "<" => By_Top);

      procedure Cut (Lo, Hi : Natural) is
         Across, Down       : Float := 0.0;
         Across_At, Down_At : Natural := Lo;
         Reach              : Float;
      begin
         if Hi <= Lo then
            return;
         end if;

         --  The widest gap that no run crosses, from left to right...
         Sort_By_Left (Order (Lo .. Hi));
         Reach := Runs (Order (Lo)).Right;
         for K in Lo .. Hi - 1 loop
            Reach := Float'Max (Reach, Runs (Order (K)).Right);
            if Runs (Order (K + 1)).Left - Reach > Across then
               Across := Runs (Order (K + 1)).Left - Reach;
               Across_At := K;
            end if;
         end loop;

         --  ...and from top to bottom.
         Sort_By_Top (Order (Lo .. Hi));
         Reach := Runs (Order (Lo)).Bottom;
         for K in Lo .. Hi - 1 loop
            Reach := Float'Max (Reach, Runs (Order (K)).Bottom);
            if Runs (Order (K + 1)).Top - Reach > Down then
               Down := Runs (Order (K + 1)).Top - Reach;
               Down_At := K;
            end if;
         end loop;

         --  A gutter is cut before a gap, unless the gap is far wider: the
         --  space between paragraphs may be at the same height in both
         --  columns, but a column is not to be read in pieces for that.
         if Across >= Min_Gutter * Usual and then Across * 2.0 >= Down then
            Sort_By_Left (Order (Lo .. Hi));
            Cut (Lo, Across_At);
            Cut (Across_At + 1, Hi);
         elsif Down >= Min_Gap * Usual then
            Cut (Lo, Down_At);
            Cut (Down_At + 1, Hi);
         end if;
         --  Otherwise they are left sorted from top to bottom.
      end Cut;

   begin
      if Item.Count < 2 then
         return;
      end if;
      Find_Usual_Height;
      Make_Runs;
      for K in 1 .. Count loop
         Order (K) := K;
      end loop;
      Cut (1, Count);

      --  Put the words in the order of the runs, and number the lines.
      declare
         Words : constant Word_Array := Item.Words;
         Next  : Natural := 0;
      begin
         for K in 1 .. Count loop
            for Index in Runs (Order (K)).First .. Runs (Order (K)).Last loop
               Next := Next + 1;
               Item.Words (Next) := Words (Index);
               Item.Words (Next).Line := K;
            end loop;
         end loop;
         pragma Assert (Next = Item.Count);
      end;
   end Reading_Order;

end Vision.Layout;
