with Ada.Unchecked_Deallocation;
with Interfaces.C;
with CoreText.Core;
with CoreText.Thin;

package body CoreText.Shaping.Glyphs is

   use type System.Address;
   use type Interfaces.Unsigned_32;

   procedure Free is new Ada.Unchecked_Deallocation (Buffer, Buffer_Access);

   Border : constant := 1;
   --  Transparent pixels around the glyph, so that smoothing it when
   --  scaled does not bleed in its neighbours.

   Scratch_Dim   : constant := 256;
   Scratch_Pitch : constant := 4 * Scratch_Dim;
   subtype Scratch_Buffer is Buffer (0 .. Scratch_Pitch * Scratch_Dim - 1);
   type Scratch_Buffer_Access is access Scratch_Buffer;

   Scratch_Data    : constant Scratch_Buffer_Access :=
     new Scratch_Buffer'(others => 0);
   Scratch_Space   : Thin.Ref := Thin.Null_Ref;
   Scratch_Context : Thin.Ref := Thin.Null_Ref;

   Last_Font_Handle : System.Address := System.Null_Address;
   Last_Font_Size   : Interfaces.C.double := 0.0;
   Cached_Sized     : Thin.Ref := Thin.Null_Ref;

   procedure Ensure_Scratch is
   begin
      if Scratch_Context = Thin.Null_Ref then
         Scratch_Space := Thin.CG_Color_Space_Create (Thin.Color_Space_SRGB);
         Scratch_Context :=
           Thin.CG_Bitmap_Context_Create
             (Scratch_Data.all'Address,
              Scratch_Dim, Scratch_Dim, 8, Scratch_Pitch,
              Scratch_Space,
              Thin.Alpha_Premultiplied_Last or Thin.Byte_Order_32_Big);
         Thin.CG_Context_Set_Should_Smooth_Fonts
           (Scratch_Context, Thin.C_False);
         Thin.CG_Context_Set_Allows_Font_Subpixel_Positioning
           (Scratch_Context, Thin.C_True);
         Thin.CG_Context_Set_Should_Subpixel_Position_Fonts
           (Scratch_Context, Thin.C_True);
         Thin.CG_Context_Set_Should_Subpixel_Quantize_Fonts
           (Scratch_Context, Thin.C_False);
         Thin.CG_Context_Set_Fill_Color
           (Scratch_Context, 1.0, 1.0, 1.0, 1.0);
      end if;
   end Ensure_Scratch;

   function Sized_Font
     (Handle : System.Address; Size : Interfaces.C.double) return Thin.Ref
   is
      use type Interfaces.C.double;
   begin
      if Handle = Last_Font_Handle and then Size = Last_Font_Size then
         return Cached_Sized;
      end if;
      if Cached_Sized /= Thin.Null_Ref then
         Core.Release (Cached_Sized);
      end if;
      Cached_Sized :=
        Thin.CT_Font_Create_Copy_With_Attributes
          (Handle, Size, System.Null_Address, Thin.Null_Ref);
      Last_Font_Handle := Handle;
      Last_Font_Size := Size;
      return Cached_Sized;
   end Sized_Font;

   procedure Straighten (Data : in out Buffer; Color : Boolean);
   --  Make the premultiplied RGBA pixels of Data straight: their colour not
   --  scaled by their alpha. Those of a glyph of one colour, not Color,
   --  are all made white, their alpha saying how much is covered.

   procedure Straighten (Data : in out Buffer; Color : Boolean) is
      use type Interfaces.Unsigned_8;
      Index : Natural := Data'First;
   begin
      while Index + 3 <= Data'Last loop
         declare
            Alpha : constant Interfaces.Unsigned_8 := Data (Index + 3);
         begin
            for Channel in Index .. Index + 2 loop
               Data (Channel) :=
                 (if not Color then 255
                  elsif Alpha = 0 then 0
                  else Interfaces.Unsigned_8
                         (Natural'Min
                            (255,
                             (Natural (Data (Channel)) * 255
                              + Natural (Alpha) / 2) / Natural (Alpha))));
            end loop;
         end;
         Index := Index + 4;
      end loop;
   end Straighten;

   procedure Rasterize
     (Reg      : Registry;
      Item     : Font_Id;
      Id       : Interfaces.Unsigned_16;
      Size     : Float;
      Subpixel : Float;
      Result   : in out Image)
   is
      use type Interfaces.C.double;

      Glyph_Id : aliased Interfaces.Unsigned_16 := Id;
      Sized    : constant Thin.Ref :=
        Sized_Font (Reg.Fonts (Item).Handle, Interfaces.C.double (Size));
   begin
      if Sized = Thin.Null_Ref then
         raise Error with "CTFontCreateCopyWithAttributes failed";
      end if;

      Free (Result.Data);
      Result.Columns := 0;
      Result.Rows := 0;

      declare
         Box : constant Thin.CG_Rect :=
           Thin.CT_Font_Bounding_Rects
             (Sized, 0, Glyph_Id'Address, System.Null_Address, 1);
         Sub : constant Interfaces.C.double :=
           Interfaces.C.double (Subpixel);
      begin
         if Box.Width <= 0.0 or else Box.Height <= 0.0 then
            return;
         end if;

         declare
            Left_Edge  : constant Integer :=
              Integer (Interfaces.C.double'Floor (Box.X)) - Border;
            Right_Edge : constant Integer :=
              Integer (Interfaces.C.double'Ceiling (Box.X + Box.Width + Sub))
              + Border;
            Low_Edge   : constant Integer :=
              Integer (Interfaces.C.double'Floor (Box.Y)) - Border;
            High_Edge  : constant Integer :=
              Integer (Interfaces.C.double'Ceiling (Box.Y + Box.Height))
              + Border;
            Columns    : constant Positive := Right_Edge - Left_Edge;
            Rows       : constant Positive := High_Edge - Low_Edge;
            Row_Bytes  : constant Positive := 4 * Columns;
            Position   : aliased Thin.CG_Point :=
              (X => Interfaces.C.double (-Left_Edge) + Sub,
               Y => Interfaces.C.double (-Low_Edge));
         begin
            if Columns <= Scratch_Dim and then Rows <= Scratch_Dim then
               Ensure_Scratch;
               Thin.CT_Font_Draw_Glyphs
                 (Sized, Glyph_Id'Address, Position'Address, 1,
                  Scratch_Context);
               declare
                  Data : constant Buffer_Access :=
                    new Buffer (0 .. Row_Bytes * Rows - 1);
               begin
                  for R in 0 .. Rows - 1 loop
                     declare
                        Src_Row : constant Natural :=
                          (Scratch_Dim - Rows + R) * Scratch_Pitch;
                        Dst_Row : constant Natural :=
                          R * Row_Bytes;
                     begin
                        Data (Dst_Row .. Dst_Row + Row_Bytes - 1) :=
                          Scratch_Data (Src_Row .. Src_Row + Row_Bytes - 1);
                        Scratch_Data (Src_Row .. Src_Row + Row_Bytes - 1) :=
                          [others => 0];
                     end;
                  end loop;
                  Straighten (Data.all, Reg.Fonts (Item).Color);
                  Result.Data := Data;
                  Result.Columns := Columns;
                  Result.Rows := Rows;
                  Result.Origin_X := Left_Edge;
                  Result.Origin_Y := High_Edge;
               end;
            else
               declare
                  Data    : Buffer_Access :=
                    new Buffer'(0 .. Row_Bytes * Rows - 1 => 0);
                  Space   : constant Thin.Ref :=
                    Thin.CG_Color_Space_Create (Thin.Color_Space_SRGB);
                  Context : constant Thin.Ref :=
                    Thin.CG_Bitmap_Context_Create
                      (Data.all'Address,
                       Interfaces.C.size_t (Columns),
                       Interfaces.C.size_t (Rows),
                       8, Interfaces.C.size_t (Row_Bytes), Space,
                       Thin.Alpha_Premultiplied_Last
                       or Thin.Byte_Order_32_Big);
               begin
                  Thin.CG_Color_Space_Release (Space);
                  if Context = Thin.Null_Ref then
                     Free (Data);
                     raise Error with "CGBitmapContextCreate failed";
                  end if;

                  Thin.CG_Context_Set_Should_Smooth_Fonts
                    (Context, Thin.C_False);
                  Thin.CG_Context_Set_Allows_Font_Subpixel_Positioning
                    (Context, Thin.C_True);
                  Thin.CG_Context_Set_Should_Subpixel_Position_Fonts
                    (Context, Thin.C_True);
                  Thin.CG_Context_Set_Should_Subpixel_Quantize_Fonts
                    (Context, Thin.C_False);
                  Thin.CG_Context_Set_Fill_Color
                    (Context, 1.0, 1.0, 1.0, 1.0);
                  Thin.CT_Font_Draw_Glyphs
                    (Sized, Glyph_Id'Address, Position'Address, 1, Context);
                  Thin.CG_Context_Release (Context);
                  Straighten (Data.all, Reg.Fonts (Item).Color);

                  Result.Data := Data;
                  Result.Columns := Columns;
                  Result.Rows := Rows;
                  Result.Origin_X := Left_Edge;
                  Result.Origin_Y := High_Edge;
               end;
            end if;
         end;
      end;
   end Rasterize;

   function Is_Blank (Item : Image) return Boolean is (Item.Data = null);

   function Pixels (Item : Image) return System.Address is
     (Item.Data.all'Address);
   function Width (Item : Image) return Positive is (Item.Columns);
   function Height (Item : Image) return Positive is (Item.Rows);
   function Pitch (Item : Image) return Positive is (4 * Item.Columns);
   function Left (Item : Image) return Integer is (Item.Origin_X);
   function Top (Item : Image) return Integer is (Item.Origin_Y);

   overriding procedure Finalize (Item : in out Image) is
   begin
      Free (Item.Data);
   end Finalize;

end CoreText.Shaping.Glyphs;
