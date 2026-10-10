with Ada.Characters.Handling;
with Interfaces.C;
with CoreText.Core;
with CoreText.Thin;

package body CoreText.Fonts is

   use type System.Address;
   use type Interfaces.C.long;

   function Text_Attributes (Handle : Thin.Ref) return Thin.Ref;
   --  {kCTFontAttributeName: Handle,
   --   kCTForegroundColorFromContextAttributeName: true}. Text drawn with
   --  these takes its colour from the drawing context.

   function Text_Attributes (Handle : Thin.Ref) return Thin.Ref is
      Keys   : aliased array (1 .. 2) of System.Address :=
        [Thin.Font_Attribute_Name, Thin.Foreground_From_Context];
      Values : aliased array (1 .. 2) of System.Address :=
        [Handle, Thin.Boolean_True];
      Result : constant Thin.Ref :=
        Thin.CF_Dictionary_Create
          (Thin.Null_Ref, Keys'Address, Values'Address, 2,
           Thin.Dictionary_Key_Callbacks'Address,
           Thin.Dictionary_Value_Callbacks'Address);
   begin
      if Result = Thin.Null_Ref then
         raise Error with "CFDictionaryCreate failed";
      end if;
      return Result;
   end Text_Attributes;

   procedure Open (Item : in out Font; Family : String; At_Size : Float) is
      Name   : Thin.Ref := Core.Create_String (Family);
      Handle : constant Thin.Ref :=
        Thin.CT_Font_Create_With_Name
          (Name, Interfaces.C.double (At_Size), System.Null_Address);
      Fam    : Thin.Ref;
   begin
      Core.Release (Name);
      if Handle = Thin.Null_Ref then
         raise Error with "CTFontCreateWithName failed: " & Family;
      end if;

      Close (Item);
      Item.Handle := Handle;
      Item.Attrs := Text_Attributes (Handle);
      Item.Pixels := At_Size;
      Item.Up := Float (Thin.CT_Font_Get_Ascent (Handle));
      Item.Down := Float (Thin.CT_Font_Get_Descent (Handle));
      Item.Gap := Float (Thin.CT_Font_Get_Leading (Handle));

      Fam := Thin.CT_Font_Copy_Family_Name (Handle);
      if Fam /= Thin.Null_Ref then
         Item.Family :=
           Ada.Strings.Unbounded.To_Unbounded_String (Core.To_Ada (Fam));
         Core.Release (Fam);
      end if;
   end Open;

   procedure Close (Item : in out Font) is
   begin
      Core.Release (Item.Attrs);
      Core.Release (Item.Handle);
      Item.Family := Ada.Strings.Unbounded.Null_Unbounded_String;
   end Close;

   overriding procedure Finalize (Item : in out Font) is
   begin
      Close (Item);
   end Finalize;

   function Is_Open (Item : Font) return Boolean is
     (Item.Handle /= System.Null_Address);

   function Family_Name (Item : Font) return String is
     (Ada.Strings.Unbounded.To_String (Item.Family));

   function Size (Item : Font) return Float is (Item.Pixels);
   function Ascent (Item : Font) return Float is (Item.Up);
   function Descent (Item : Font) return Float is (Item.Down);
   function Leading (Item : Font) return Float is (Item.Gap);

   function Line_Height (Item : Font) return Float is
     (Item.Up + Item.Down + Item.Gap);

   function Attributes (Item : Font) return System.Address is (Item.Attrs);

   function Families return Family_Vectors.Vector is
      function Before (Left, Right : String) return Boolean is
        (Ada.Characters.Handling.To_Lower (Left)
         < Ada.Characters.Handling.To_Lower (Right)
         or else (Ada.Characters.Handling.To_Lower (Left)
                  = Ada.Characters.Handling.To_Lower (Right)
                  and then Left < Right));

      package Sorting is new Family_Vectors.Generic_Sorting (Before);

      Names  : Thin.Ref := Thin.CT_Font_Manager_Family_Names;
      Sorted : Family_Vectors.Vector;
      Result : Family_Vectors.Vector;
   begin
      if Names = Thin.Null_Ref then
         raise Error with "CTFontManagerCopyAvailableFontFamilyNames failed";
      end if;

      for I in 0 .. Thin.CF_Array_Get_Count (Names) - 1 loop
         declare
            Name : constant String :=
              Core.To_Ada (Thin.CF_Array_Get_Value_At_Index (Names, I));
         begin
            if Name'Length > 0 and then Name (Name'First) /= '.' then
               Sorted.Append (Name);
            end if;
         end;
      end loop;
      Core.Release (Names);

      Sorting.Sort (Sorted);
      for Name of Sorted loop
         if Result.Is_Empty or else Result.Last_Element /= Name then
            Result.Append (Name);
         end if;
      end loop;
      return Result;
   end Families;

end CoreText.Fonts;
