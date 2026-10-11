private with Ada.Finalization;

--  Values in a row, and the sums of those before each: a Fenwick tree.
--  Changing a value, and finding a sum or where the sums pass a value,
--  cost the logarithm of how many there are; adding or removing values,
--  and adding them all up again, cost how many there are, in tight
--  loops over arrays.
package Typeset.Sums is

   type Sum_Tree is limited private;

   function Count (Item : Sum_Tree) return Natural;

   procedure Resize (Item : in out Sum_Tree; Size : Natural)
     with Post => Count (Item) = Size;
   --  To Size values, all 0.0.

   function Value (Item : Sum_Tree; Index : Positive) return Long_Float
     with Pre => Index <= Count (Item);

   procedure Set (Item : in out Sum_Tree; Index : Positive; To : Long_Float)
     with Pre  => Index <= Count (Item) and then To >= 0.0,
          Post => Value (Item, Index) = To;

   procedure Splice
     (Item   : in out Sum_Tree;
      From   : Positive;
      Remove : Natural;
      Add    : Natural)
     with Pre  => From <= Count (Item) + 1
                  and then From + Remove <= Count (Item) + 1,
          Post => Count (Item) = Count (Item)'Old - Remove + Add;
   --  Remove values from From on, and put Add of 0.0 in their place; the
   --  sums are wrong until Rebuild.

   procedure Put (Item : in out Sum_Tree; Index : Positive; To : Long_Float)
     with Pre  => Index <= Count (Item) and then To >= 0.0;
   --  Set the value, but not the sums: Rebuild before asking for them.

   procedure Rebuild (Item : in out Sum_Tree);
   --  Make the sums again from the values, as after Splice or Put, or to
   --  shed rounding.

   function Before (Item : Sum_Tree; Index : Positive) return Long_Float
     with Pre => Index <= Count (Item) + 1;
   --  The sum of the values before Index.

   function Total (Item : Sum_Tree) return Long_Float is
     (Before (Item, Count (Item) + 1));

   function Find (Item : Sum_Tree; Sum : Long_Float) return Positive
     with Pre  => Count (Item) > 0,
          Post => Find'Result <= Count (Item);
   --  The last index whose sum before it is at most Sum; the first if
   --  none is.

private

   type Float_Array is array (Positive range <>) of Long_Float;
   type Float_Array_Access is access Float_Array;

   type Sum_Tree is new Ada.Finalization.Limited_Controlled with record
      Values : Float_Array_Access;
      Tree   : Float_Array_Access;
      --  Tree (I): the sum of the values from I - (I and -I) + 1 to I.
      --  Both have room for more than Count.
      Count  : Natural := 0;
   end record;

   overriding procedure Finalize (Item : in out Sum_Tree);

end Typeset.Sums;
