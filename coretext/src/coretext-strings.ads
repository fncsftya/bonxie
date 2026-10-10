with Ada.Finalization;
with System;

package CoreText.Strings is

   type Text is limited private;
   --  Some text held as a CoreFoundation string, so that lines of it can
   --  be cut out by UTF-16 range without scanning the UTF-8 from its
   --  start. Make one for a paragraph, and keep it while the paragraph's
   --  text is unchanged.

   procedure Set (Item : in out Text; Value : String)
     with Post => Is_Set (Item) and then Length (Item) = UTF16_Length (Value);
   --  Replace Item's text with the UTF-8 Value.

   procedure Clear (Item : in out Text)
     with Post => not Is_Set (Item);

   function Is_Set (Item : Text) return Boolean;

   function Length (Item : Text) return Natural;
   --  In UTF-16 units; 0 if not set.

   function Handle (Item : Text) return System.Address
     with Pre => Is_Set (Item);
   --  The CFStringRef, for CoreText's own packages.

private

   type Text is new Ada.Finalization.Limited_Controlled with record
      Ref   : System.Address := System.Null_Address;
      Units : Natural := 0;
   end record;

   overriding procedure Finalize (Item : in out Text);

end CoreText.Strings;
