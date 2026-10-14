with CoreText.Thin;

--  Helpers shared by the CoreText child packages. Internal.
private package CoreText.Core is

   function Create_String (Text : String) return Thin.Ref;
   --  A new CFString of the UTF-8 Text; Release it.

   function To_Ada (Item : Thin.Ref) return String;
   --  The UTF-8 contents of the CFString Item, "" if it will not fit.

   procedure Release (Item : in out Thin.Ref);
   --  Release Item, unless it is null, and null it.

end CoreText.Core;
