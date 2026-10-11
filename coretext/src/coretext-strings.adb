with Interfaces.C;
with CoreText.Core;
with CoreText.Thin;

package body CoreText.Strings is

   use type System.Address;
   use type Interfaces.C.long;
   use type Interfaces.C.unsigned_long;

   procedure Set (Item : in out Text; Value : String) is
      Made : constant Thin.Ref := Core.Create_String (Value);
   begin
      Clear (Item);
      Item.Ref := Made;
      Item.Units := UTF16_Length (Value);
      pragma Assert
        (Natural (Thin.CF_String_Get_Length (Made)) = Item.Units);
   end Set;

   procedure Clear (Item : in out Text) is
   begin
      Core.Release (Item.Ref);
      Item.Units := 0;
   end Clear;

   overriding procedure Finalize (Item : in out Text) is
   begin
      Clear (Item);
   end Finalize;

   function Is_Set (Item : Text) return Boolean is
     (Item.Ref /= System.Null_Address);

   function Length (Item : Text) return Natural is (Item.Units);

   procedure Cluster
     (Item : Text; Unit : Natural; First, Stop : out Natural)
   is
      Found : constant Thin.CF_Range :=
        Thin.CF_String_Composed_Range (Item.Ref, Interfaces.C.long (Unit));
   begin
      First := Natural (Found.Location);
      Stop := First + Natural (Found.Length);
   end Cluster;

   --  Words

   generic
      with procedure Visit (First, Stop : Natural; Done : out Boolean);
   procedure Each_Word (Item : Text);
   --  Visit the text's words in order, until Done.

   procedure Each_Word (Item : Text) is
      Words : Thin.Ref := Thin.CF_String_Tokenizer_Create
        (Thin.Null_Ref, Item.Ref,
         (Location => 0, Length => Interfaces.C.long (Item.Units)),
         Thin.Tokenizer_Unit_Word, Thin.Null_Ref);
      Done  : Boolean := False;
   begin
      if Words = Thin.Null_Ref then
         raise Error with "CFStringTokenizerCreate failed";
      end if;
      while not Done
        and then Thin.CF_String_Tokenizer_Advance (Words) /= Thin.Token_None
      loop
         declare
            Found : constant Thin.CF_Range :=
              Thin.CF_String_Tokenizer_Token_Range (Words);
         begin
            Visit (Natural (Found.Location),
                   Natural (Found.Location + Found.Length), Done);
         end;
      end loop;
      Core.Release (Words);
   exception
      when others =>
         Core.Release (Words);
         raise;
   end Each_Word;

   function Previous_Word_Start (Item : Text; Unit : Natural) return Natural
   is
      Result : Natural := 0;

      procedure Visit (First, Stop : Natural; Done : out Boolean) is
         pragma Unreferenced (Stop);
      begin
         Done := First >= Unit;
         if not Done then
            Result := First;
         end if;
      end Visit;

      procedure Find is new Each_Word (Visit);
   begin
      Find (Item);
      return Result;
   end Previous_Word_Start;

   function Next_Word_Stop (Item : Text; Unit : Natural) return Natural is
      Result : Natural := Item.Units;

      procedure Visit (First, Stop : Natural; Done : out Boolean) is
         pragma Unreferenced (First);
      begin
         Done := Stop > Unit;
         if Done then
            Result := Stop;
         end if;
      end Visit;

      procedure Find is new Each_Word (Visit);
   begin
      Find (Item);
      return Result;
   end Next_Word_Stop;

   procedure Word_At
     (Item : Text; Unit : Natural; First, Stop : out Natural)
   is
      procedure Visit (Word_First, Word_Stop : Natural; Done : out Boolean)
      is
      begin
         Done := Word_Stop >= Unit;
         if Done and then Word_First <= Unit then
            First := Word_First;
            Stop := Word_Stop;
         end if;
      end Visit;

      procedure Find is new Each_Word (Visit);
   begin
      First := Unit;
      Stop := Unit;
      Find (Item);
   end Word_At;

   function Handle (Item : Text) return System.Address is (Item.Ref);

end CoreText.Strings;
