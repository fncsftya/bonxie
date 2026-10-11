with Ada.Unchecked_Deallocation;
with Interfaces;

package body Typeset.Sums is

   use Interfaces;

   procedure Free is new Ada.Unchecked_Deallocation
     (Float_Array, Float_Array_Access);

   function Low_Bit (Index : Positive) return Positive is
     (Positive (Unsigned_64 (Index) and (not Unsigned_64 (Index) + 1)));
   --  The lowest set bit of Index.

   function Count (Item : Sum_Tree) return Natural is (Item.Count);

   procedure Add_Up (Values : Float_Array; Tree : in out Float_Array;
                     Size : Natural);
   --  Make the first Size sums of Tree from Values.

   procedure Make_Room (Item : in out Sum_Tree; Size : Natural);
   --  For Size values, keeping those there are.

   procedure Make_Room (Item : in out Sum_Tree; Size : Natural) is
   begin
      if Item.Values = null or else Item.Values'Length < Size then
         declare
            Room   : constant Positive :=
              Positive'Max (64, 2 * Size);
            Values : constant Float_Array_Access :=
              new Float_Array'(1 .. Room => 0.0);
         begin
            if Item.Values /= null then
               Values (1 .. Item.Count) := Item.Values (1 .. Item.Count);
               Free (Item.Values);
               Free (Item.Tree);
            end if;
            Item.Values := Values;
            Item.Tree := new Float_Array'(1 .. Room => 0.0);
         end;
      end if;
   end Make_Room;

   procedure Resize (Item : in out Sum_Tree; Size : Natural) is
   begin
      Make_Room (Item, Size);
      Item.Count := Size;
      Item.Values (1 .. Size) := [others => 0.0];
      Item.Tree (1 .. Size) := [others => 0.0];
   end Resize;

   function Value (Item : Sum_Tree; Index : Positive) return Long_Float is
     (Item.Values (Index));

   procedure Set (Item : in out Sum_Tree; Index : Positive; To : Long_Float)
   is
      Change  : constant Long_Float := To - Item.Values (Index);
      At_Node : Natural := Index;
   begin
      Item.Values (Index) := To;
      while At_Node <= Item.Count loop
         Item.Tree (At_Node) := Item.Tree (At_Node) + Change;
         At_Node := At_Node + Low_Bit (At_Node);
      end loop;
   end Set;

   procedure Splice
     (Item   : in out Sum_Tree;
      From   : Positive;
      Remove : Natural;
      Add    : Natural)
   is
      Old_Count : constant Natural := Item.Count;
      New_Count : constant Natural := Old_Count - Remove + Add;
   begin
      Make_Room (Item, New_Count);
      --  Those after move along, at once.
      Item.Values (From + Add .. New_Count) :=
        Item.Values (From + Remove .. Old_Count);
      Item.Values (From .. From + Add - 1) := [others => 0.0];
      Item.Count := New_Count;
   end Splice;

   procedure Put (Item : in out Sum_Tree; Index : Positive; To : Long_Float)
   is
   begin
      Item.Values (Index) := To;
   end Put;

   procedure Rebuild (Item : in out Sum_Tree) is
   begin
      if Item.Count > 0 then
         Add_Up (Item.Values.all, Item.Tree.all, Item.Count);
      end if;
   end Rebuild;

   procedure Add_Up (Values : Float_Array; Tree : in out Float_Array;
                     Size : Natural) is
   begin
      Tree (1 .. Size) := Values (1 .. Size);
      for I in 1 .. Size loop
         declare
            Parent : constant Positive := I + Low_Bit (I);
         begin
            if Parent <= Size then
               Tree (Parent) := Tree (Parent) + Tree (I);
            end if;
         end;
      end loop;
   end Add_Up;

   function Before (Item : Sum_Tree; Index : Positive) return Long_Float is
      Result  : Long_Float := 0.0;
      At_Node : Natural := Index - 1;
   begin
      while At_Node > 0 loop
         Result := Result + Item.Tree (At_Node);
         At_Node := At_Node - Low_Bit (At_Node);
      end loop;
      return Result;
   end Before;

   function Find (Item : Sum_Tree; Sum : Long_Float) return Positive is
      Found : Natural := 0;  --  the sum of the first Found is <= Sum
      Left  : Long_Float := Sum;
      Step  : Natural := 1;
   begin
      while Step * 2 <= Item.Count loop
         Step := Step * 2;
      end loop;
      while Step > 0 loop
         if Found + Step <= Item.Count
           and then Item.Tree (Found + Step) <= Left
         then
            Found := Found + Step;
            Left := Left - Item.Tree (Found);
         end if;
         Step := Step / 2;
      end loop;
      return Natural'Min (Found + 1, Item.Count);
   end Find;

   overriding procedure Finalize (Item : in out Sum_Tree) is
   begin
      Free (Item.Values);
      Free (Item.Tree);
      Item.Count := 0;
   end Finalize;

end Typeset.Sums;
