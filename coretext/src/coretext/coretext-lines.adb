with Ada.Unchecked_Deallocation;
with Interfaces.C;
with CoreText.Core;
with CoreText.Thin;

package body CoreText.Lines is

   use type System.Address;
   use type Interfaces.C.long;
   use type Interfaces.Unsigned_32;

   procedure Free is new Ada.Unchecked_Deallocation (Buffer, Buffer_Access);

   procedure Make (Item : in out Line; Using : Fonts.Font; Text : String) is
      Str   : Thin.Ref := Core.Create_String (Text);
      Attr  : Thin.Ref;
      Handle : Thin.Ref;
   begin
      Attr := Thin.CF_Attributed_String_Create
        (Thin.Null_Ref, Str, Fonts.Attributes (Using));
      Core.Release (Str);
      if Attr = Thin.Null_Ref then
         raise Error with "CFAttributedStringCreate failed";
      end if;
      Handle := Thin.CT_Line_Create (Attr);
      Core.Release (Attr);
      if Handle = Thin.Null_Ref then
         raise Error with "CTLineCreateWithAttributedString failed";
      end if;

      Core.Release (Item.Handle);
      Item.Handle := Handle;
      Item.Units := UTF16_Length (Text);
   end Make;

   overriding procedure Finalize (Item : in out Line) is
   begin
      Core.Release (Item.Handle);
   end Finalize;

   function Length (Item : Line) return Natural is (Item.Units);

   function Typographic_Width
     (Item : Line; Ascent, Descent : out Interfaces.C.double)
      return Interfaces.C.double;

   function Typographic_Width
     (Item : Line; Ascent, Descent : out Interfaces.C.double)
      return Interfaces.C.double
   is
      A : aliased Interfaces.C.double;
      D : aliased Interfaces.C.double;
      W : constant Interfaces.C.double :=
        Thin.CT_Line_Typographic_Bounds
          (Item.Handle, A'Address, D'Address, System.Null_Address);
   begin
      Ascent := A;
      Descent := D;
      return W;
   end Typographic_Width;

   function Width (Item : Line) return Float is
      A, D : Interfaces.C.double;
   begin
      if Item.Handle = Thin.Null_Ref then
         return 0.0;
      end if;
      return Float (Typographic_Width (Item, A, D));
   end Width;

   function Offset_For_Index (Item : Line; Index : Natural) return Float is
   begin
      if Item.Handle = Thin.Null_Ref then
         return 0.0;
      end if;
      return Float
        (Thin.CT_Line_Offset_For_Index
           (Item.Handle, Interfaces.C.long (Index), System.Null_Address));
   end Offset_For_Index;

   function Index_For_Position (Item : Line; X : Float) return Natural is
      Found : Interfaces.C.long;
   begin
      if Item.Handle = Thin.Null_Ref then
         return 0;
      end if;
      Found := Thin.CT_Line_Index_For_Position
        (Item.Handle, (X => Interfaces.C.double (X), Y => 0.0));
      if Found < 0 then  --  kCFNotFound
         return 0;
      end if;
      return Natural'Min (Natural (Found), Item.Units);
   end Index_For_Position;

   procedure Rasterize
     (Item   : Line;
      Red, Green, Blue : Channel;
      Result : in out Bitmap'Class)
   is
      use type Interfaces.C.double;

      A, D : Interfaces.C.double;
      Advance : constant Interfaces.C.double := Typographic_Width (Item, A, D);
      Ascent  : constant Natural := Natural (Interfaces.C.double'Ceiling (A));
      Descent : constant Natural := Natural (Interfaces.C.double'Ceiling (D));
      Columns : constant Positive :=
        Natural (Interfaces.C.double'Ceiling (Advance)) + 2 * Pad;
      Rows    : constant Positive := Ascent + Descent + 2 * Pad;
      Row_Bytes : constant Positive := 4 * Columns;

      Data  : Buffer_Access := new Buffer'(0 .. Row_Bytes * Rows - 1 => 0);
      Space : constant Thin.Ref :=
        Thin.CG_Color_Space_Create (Thin.Color_Space_SRGB);
      Context : Thin.Ref;

      function Unit (Value : Channel) return Interfaces.C.double is
        (Interfaces.C.double (Value) / 255.0);
   begin
      pragma Assert (Item.Handle /= Thin.Null_Ref);
      Context := Thin.CG_Bitmap_Context_Create
        (Data.all'Address,
         Interfaces.C.size_t (Columns), Interfaces.C.size_t (Rows),
         8, Interfaces.C.size_t (Row_Bytes), Space,
         Thin.Alpha_Premultiplied_Last or Thin.Byte_Order_32_Big);
      Thin.CG_Color_Space_Release (Space);
      if Context = Thin.Null_Ref then
         Free (Data);
         raise Error with "CGBitmapContextCreate failed";
      end if;

      --  LCD-style smoothing assumes an opaque backdrop; we have none.
      Thin.CG_Context_Set_Should_Smooth_Fonts (Context, Thin.C_False);
      Thin.CG_Context_Set_Fill_Color
        (Context, Unit (Red), Unit (Green), Unit (Blue), 1.0);
      --  CG's origin is bottom-left. A whole-pixel baseline keeps glyphs
      --  crisp.
      Thin.CG_Context_Set_Text_Position
        (Context, Interfaces.C.double (Pad),
         Interfaces.C.double (Pad + Descent));
      Thin.CT_Line_Draw (Item.Handle, Context);
      Thin.CG_Context_Release (Context);

      Free (Result.Data);
      Result.Data := Data;
      Result.Columns := Columns;
      Result.Rows := Rows;
      Result.Base := Pad + Ascent;
   end Rasterize;

   overriding procedure Finalize (Item : in out Bitmap) is
   begin
      Free (Item.Data);
   end Finalize;

   function Is_Empty (Item : Bitmap) return Boolean is (Item.Data = null);

   function Pixels (Item : Bitmap) return System.Address is
     (Item.Data.all'Address);

   function Width (Item : Bitmap) return Positive is (Item.Columns);
   function Height (Item : Bitmap) return Positive is (Item.Rows);
   function Pitch (Item : Bitmap) return Positive is (4 * Item.Columns);
   function Baseline (Item : Bitmap) return Positive is (Item.Base);

end CoreText.Lines;
