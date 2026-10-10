with Interfaces.C;
with System;

package body CoreText.Core is

   use type System.Address;

   function Create_String (Text : String) return Thin.Ref is
      Result : constant Thin.Ref :=
        Thin.CF_String_Create_With_Bytes
          (Thin.Null_Ref, Text'Address, Interfaces.C.long (Text'Length),
           Thin.UTF8, Thin.C_False);
   begin
      if Result = Thin.Null_Ref then
         raise Error with "CFStringCreateWithBytes failed";
      end if;
      return Result;
   end Create_String;

   function To_Ada (Item : Thin.Ref) return String is
      Size   : constant := 1024;
      Buffer : aliased Interfaces.C.char_array (1 .. Size);
   begin
      pragma Assert (Item /= Thin.Null_Ref);
      if Thin.CF_String_Get_C_String
           (Item, Buffer'Address, Size, Thin.UTF8)
      then
         return Interfaces.C.To_Ada (Buffer);
      else
         return "";
      end if;
   end To_Ada;

   procedure Release (Item : in out Thin.Ref) is
   begin
      if Item /= Thin.Null_Ref then
         Thin.CF_Release (Item);
         Item := Thin.Null_Ref;
      end if;
   end Release;

end CoreText.Core;
