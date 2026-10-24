with Ada.Finalization;
with Ada.Iterator_Interfaces;

--  What is kept for each of a project's items (a window, a page, a pin...),
--  one to a slot, and as many slots as there are items: it grows when more
--  are wanted and is not moved, so that a widget in it can be in a tree.
--  Elements are made with their defaults and kept until the table goes.
generic
   type Element is limited private;
package Slot_Tables is

   type Element_Access is access Element;

   type Reference (Item : not null access Element) is limited null record
     with Implicit_Dereference => Item;

   type Constant_Reference (Item : not null access constant Element) is limited null record
     with Implicit_Dereference => Item;

   type Cursor is record
      Place : Natural := 0;
   end record;
   --  A place to loop at; not a number, so that an index is not mistaken for it.

   function Has_Element (Position : Cursor) return Boolean is (Position.Place /= 0);

   package Iterators is new Ada.Iterator_Interfaces (Cursor, Has_Element);

   type Table is limited new Ada.Finalization.Limited_Controlled with private
     with Constant_Indexing => Get,
          Variable_Indexing => Ref,
          Default_Iterator  => Iterate,
          Iterator_Element  => Element;

   function Count (Self : Table) return Natural;
   --  How many slots there are, from 1.

   procedure Grow (Self : in out Table; To : Natural)
     with Post => Count (Self) >= To;
   --  Have at least To slots; those there are stay where they are.

   function Get (Self : aliased Table; Index : Positive) return Constant_Reference
     with Pre => Index <= Count (Self);

   function Ref (Self : aliased in out Table; Index : Positive) return Reference
     with Pre => Index <= Count (Self);

   function Get (Self : aliased Table; Position : Cursor) return Constant_Reference
     with Pre => Has_Element (Position) and then Position.Place <= Count (Self);

   function Ref (Self : aliased in out Table; Position : Cursor) return Reference
     with Pre => Has_Element (Position) and then Position.Place <= Count (Self);
   --  For loops over the slots: Position is the slot.

   function Iterate (Self : Table) return Iterators.Forward_Iterator'Class;

   overriding procedure Finalize (Self : in out Table);

private

   type Pointer_Array is array (Positive range <>) of Element_Access;
   type Pointer_Array_Access is access Pointer_Array;

   type Table is limited new Ada.Finalization.Limited_Controlled with record
      Made : Natural := 0;
      Data : Pointer_Array_Access;
   end record;

   type Walker (Last : Natural) is new Iterators.Forward_Iterator with null record;

   overriding function First (Self : Walker) return Cursor;
   overriding function Next (Self : Walker; Position : Cursor) return Cursor;

end Slot_Tables;
