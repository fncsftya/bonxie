with CoreText.Core;
with CoreText.Thin;

package body CoreText.Strings is

   use type System.Address;

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

   function Handle (Item : Text) return System.Address is (Item.Ref);

end CoreText.Strings;
