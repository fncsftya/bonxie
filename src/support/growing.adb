with Ada.Unchecked_Deallocation;

package body Growing is

   procedure Free is new Ada.Unchecked_Deallocation (Element_Array, Element_Array_Access);

   First_Room : constant := 8;

   function Get (Self : aliased List; Index : Positive) return Constant_Reference
   is ((Item => Self.Data (Index)'Access));

   function Ref (Self : aliased in out List; Index : Positive) return Reference
   is ((Item => Self.Data (Index)'Access));

   function Get (Self : aliased List; Position : Cursor) return Constant_Reference
   is ((Item => Self.Data (Position.Place)'Access));

   function Ref (Self : aliased in out List; Position : Cursor) return Reference
   is ((Item => Self.Data (Position.Place)'Access));

   function Iterate (Self : List) return Iterators.Forward_Iterator'Class
   is (Walker'(Last => Self.Count));

   overriding
   function First (Self : Walker) return Cursor
   is (if Self.Last = 0 then (Place => 0) else (Place => 1));

   overriding
   function Next (Self : Walker; Position : Cursor) return Cursor
   is (if Position.Place >= Self.Last then (Place => 0) else (Place => Position.Place + 1));

   procedure Clear (Self : in out List) is
   begin
      Self.Count := 0;
   end Clear;

   procedure Append (Self : in out List; Value : Element) is
   begin
      if Self.Data = null then
         Self.Data := new Element_Array (1 .. First_Room);
      elsif Self.Count = Self.Data'Length then
         declare
            Bigger : constant Element_Array_Access := new Element_Array (1 .. 2 * Self.Data'Length);
         begin
            Bigger (1 .. Self.Count) := Self.Data (1 .. Self.Count);
            Free (Self.Data);
            Self.Data := Bigger;
         end;
      end if;
      Self.Count := Self.Count + 1;
      Self.Data (Self.Count) := Value;
   end Append;

   procedure Resize (Self : in out List; To : Natural; Fill : Element) is
   begin
      if Self.Data = null or else To > Self.Data'Length then
         declare
            Room   : constant Positive :=
              Positive'Max (First_Room, Positive'Max (To, (if Self.Data = null then 0 else 2 * Self.Data'Length)));
            Bigger : constant Element_Array_Access := new Element_Array (1 .. Room);
         begin
            if Self.Data /= null then
               Bigger (1 .. Self.Count) := Self.Data (1 .. Self.Count);
               Free (Self.Data);
            end if;
            Self.Data := Bigger;
         end;
      end if;
      for Each in Self.Count + 1 .. To loop
         Self.Data (Each) := Fill;
      end loop;
      Self.Count := To;
   end Resize;

   procedure Delete (Self : in out List; Index : Positive) is
   begin
      Self.Data (Index .. Self.Count - 1) := Self.Data (Index + 1 .. Self.Count);
      Self.Count := Self.Count - 1;
   end Delete;

   overriding
   procedure Adjust (Self : in out List) is
   begin
      if Self.Data /= null then
         Self.Data := new Element_Array'(Self.Data.all);
      end if;
   end Adjust;

   overriding
   procedure Finalize (Self : in out List) is
   begin
      Free (Self.Data);
   end Finalize;

end Growing;
