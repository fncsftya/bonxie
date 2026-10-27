with Ada.Finalization;
with Ada.Iterator_Interfaces;

--  A list that grows to hold what it is given, so that what a person makes
--  (items, links, folders, sections) has no number it stops at. It is read
--  and written as an array, List (1 .. List.Count), and is copied whole.

generic
   type Element is private;
package Growing is

   type Element_Array is array (Positive range <>) of aliased Element;
   type Element_Array_Access is access Element_Array;

   type Reference (Item : not null access Element) is limited null record with Implicit_Dereference => Item;

   type Constant_Reference (Item : not null access constant Element) is limited null record
   with Implicit_Dereference => Item;

   type Cursor is record
      Place : Natural := 0;
   end record;
   --  A place to loop at; not a number, so that an index is not mistaken for it.

   function Has_Element (Position : Cursor) return Boolean
   is (Position.Place /= 0);

   package Iterators is new Ada.Iterator_Interfaces (Cursor, Has_Element);

   type List is new Ada.Finalization.Controlled with record
      Count : Natural := 0;
      --  How many of Data are held; the rest is room for more.
      Data  : Element_Array_Access;
   end record
   with Constant_Indexing => Get, Variable_Indexing => Ref, Default_Iterator => Iterate, Iterator_Element => Element;

   function Get (Self : aliased List; Index : Positive) return Constant_Reference
   with Pre => Index <= Self.Count;

   function Ref (Self : aliased in out List; Index : Positive) return Reference
   with Pre => Index <= Self.Count;

   function Get (Self : aliased List; Position : Cursor) return Constant_Reference
   with Pre => Has_Element (Position) and then Position.Place <= Self.Count;

   function Ref (Self : aliased in out List; Position : Cursor) return Reference
   with Pre => Has_Element (Position) and then Position.Place <= Self.Count;
   --  For loops over the elements held: Position is the place.

   function Iterate (Self : List) return Iterators.Forward_Iterator'Class;

   procedure Clear (Self : in out List)
   with Post => Self.Count = 0;
   --  Hold none; the room is kept.

   procedure Append (Self : in out List; Value : Element)
   with Post => Self.Count = Self.Count'Old + 1;
   --  Hold Value after the others, making room if there is none.

   procedure Resize (Self : in out List; To : Natural; Fill : Element)
   with Post => Self.Count = To;
   --  Hold To elements: those held stay, and any more are Fill.

   procedure Delete (Self : in out List; Index : Positive)
   with Pre => Index <= Self.Count, Post => Self.Count = Self.Count'Old - 1;
   --  Hold none at Index: those after it move up one.

   function Slice (Self : List) return Element_Array
   is (if Self.Count = 0 then Element_Array'(1 .. 0 => <>) else Self.Data (1 .. Self.Count));
   --  The elements held, as an array to take a copy of or to loop over.

   type Walker (Last : Natural) is new Iterators.Forward_Iterator with null record;

   overriding
   function First (Self : Walker) return Cursor;
   overriding
   function Next (Self : Walker; Position : Cursor) return Cursor;

   overriding
   procedure Adjust (Self : in out List);
   overriding
   procedure Finalize (Self : in out List);

end Growing;
