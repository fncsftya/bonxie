with Ada.Unchecked_Deallocation;

package body Slot_Tables is

   procedure Free is new Ada.Unchecked_Deallocation (Element, Element_Access);
   procedure Free is new Ada.Unchecked_Deallocation (Pointer_Array, Pointer_Array_Access);

   First_Room : constant := 16;

   function Count (Self : Table) return Natural
   is (Self.Made);

   procedure Grow (Self : in out Table; To : Natural) is
   begin
      if To <= Self.Made then
         return;
      end if;
      if Self.Data = null or else To > Self.Data'Length then
         declare
            Room   : constant Positive := Positive'Max (To, Positive'Max (First_Room, 2 * Self.Made));
            Bigger : constant Pointer_Array_Access := new Pointer_Array (1 .. Room);
         begin
            if Self.Data /= null then
               Bigger (1 .. Self.Made) := Self.Data (1 .. Self.Made);
               Free (Self.Data);
            end if;
            Self.Data := Bigger;
         end;
      end if;
      for Each in Self.Made + 1 .. To loop
         Self.Data (Each) := new Element;
         Self.Made := Each;
      end loop;
   end Grow;

   function Get (Self : aliased Table; Index : Positive) return Constant_Reference
   is ((Item => Self.Data (Index)));

   function Ref (Self : aliased in out Table; Index : Positive) return Reference
   is ((Item => Self.Data (Index)));

   function Get (Self : aliased Table; Position : Cursor) return Constant_Reference
   is ((Item => Self.Data (Position.Place)));

   function Ref (Self : aliased in out Table; Position : Cursor) return Reference
   is ((Item => Self.Data (Position.Place)));

   function Iterate (Self : Table) return Iterators.Forward_Iterator'Class
   is (Walker'(Last => Self.Made));

   overriding
   function First (Self : Walker) return Cursor
   is (if Self.Last = 0 then (Place => 0) else (Place => 1));

   overriding
   function Next (Self : Walker; Position : Cursor) return Cursor
   is (if Position.Place >= Self.Last then (Place => 0) else (Place => Position.Place + 1));

   overriding
   procedure Finalize (Self : in out Table) is
   begin
      if Self.Data /= null then
         for Each in reverse 1 .. Self.Made loop
            Free (Self.Data (Each));
         end loop;
         Free (Self.Data);
      end if;
      Self.Made := 0;
   end Finalize;

end Slot_Tables;
