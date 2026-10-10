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
      Sized : Thin.Ref :=
        Thin.CT_Font_Create_Copy_With_Attributes
          (Reg.Fonts (Item).Handle, Interfaces.C.double (Size),
           System.Null_Address, Thin.Null_Ref);
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
            Core.Release (Sized);
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
            Data       : Buffer_Access :=
              new Buffer'(0 .. Row_Bytes * Rows - 1 => 0);
            Space      : constant Thin.Ref :=
              Thin.CG_Color_Space_Create (Thin.Color_Space_SRGB);
            Context    : constant Thin.Ref :=
              Thin.CG_Bitmap_Context_Create
                (Data.all'Address,
                 Interfaces.C.size_t (Columns), Interfaces.C.size_t (Rows),
                 8, Interfaces.C.size_t (Row_Bytes), Space,
                 Thin.Alpha_Premultiplied_Last or Thin.Byte_Order_32_Big);
            Position   : aliased Thin.CG_Point :=
              (X => Interfaces.C.double (-Left_Edge) + Sub,
               Y => Interfaces.C.double (-Low_Edge));
         begin
            Thin.CG_Color_Space_Release (Space);
            if Context = Thin.Null_Ref then
               Free (Data);
               Core.Release (Sized);
               raise Error with "CGBitmapContextCreate failed";
            end if;

            Thin.CG_Context_Set_Should_Smooth_Fonts (Context, Thin.C_False);
            Thin.CG_Context_Set_Allows_Font_Subpixel_Positioning
              (Context, Thin.C_True);
            Thin.CG_Context_Set_Should_Subpixel_Position_Fonts
              (Context, Thin.C_True);
            Thin.CG_Context_Set_Should_Subpixel_Quantize_Fonts
              (Context, Thin.C_False);
            Thin.CG_Context_Set_Fill_Color (Context, 1.0, 1.0, 1.0, 1.0);
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
      end;
      Core.Release (Sized);
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
