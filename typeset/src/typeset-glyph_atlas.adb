with Ada.Numerics.Elementary_Functions;
with Ada.Unchecked_Deallocation;

package body Typeset.Glyph_Atlas is

   use type Interfaces.Unsigned_64;
   package Glyphs renames CoreText.Shaping.Glyphs;

   procedure Free is new Ada.Unchecked_Deallocation
     (Textures.Vertex_Array, Vertex_Access);

   Subpixel_Steps : constant := 4;
   Subpixel_Width : constant Float := 1.0 / Float (Subpixel_Steps);
   --  How many places across a pixel a glyph is rasterized at.

   Steps_Per_Octave : constant := 4;
   --  While not settled, glyph sizes are these many to a doubling.

   Size_Units : constant Float := 8.0;
   --  Sizes are kept to this many to a pixel.

   function Hash (Key : Interfaces.Unsigned_64)
      return Ada.Containers.Hash_Type is
     (Ada.Containers.Hash_Type
        (Interfaces.Shift_Right (Key * 16#9E37_79B9_7F4A_7C15#, 32)));

   function Raster_Size (Size : Float; Settled : Boolean) return Float;
   --  The size to rasterize glyphs at to draw them at Size.

   function Raster_Size (Size : Float; Settled : Boolean) return Float is
      use Ada.Numerics.Elementary_Functions;
      Steps : constant Float := Float (Steps_Per_Octave);
   begin
      return Float'Max
        (1.0,
         (if Settled
          then Float'Rounding (Size * Size_Units) / Size_Units
          else 2.0 ** (Float'Rounding (Log (Size, 2.0) * Steps) / Steps)));
   end Raster_Size;

   function Key_Of
     (Font : CoreText.Shaping.Font_Id;
      Id   : Interfaces.Unsigned_16;
      Size : Float;
      Sub  : Natural) return Interfaces.Unsigned_64
   is
      Sized : constant Interfaces.Unsigned_64 :=
        Interfaces.Unsigned_64 (Float'Rounding (Size * Size_Units));
   begin
      pragma Assert (Positive (Font) < 4096 and then Sized < 2 ** 20);
      return (((Sized * 4096 + Interfaces.Unsigned_64 (Font)) * 65536
               + Interfaces.Unsigned_64 (Id)) * 4)
        + Interfaces.Unsigned_64 (Sub);
   end Key_Of;

   --  Pages

   procedure Flush_Page
     (Item   : in out Atlas;
      Target : Renderer;
      Index  : Positive) is
   begin
      if Item.Pages (Index).Quads > 0 then
         Textures.Draw_Quads
           (Target, Item.Pages (Index).Image,
            Item.Pages (Index).Vertices.all, Item.Pages (Index).Quads);
         Item.Pages (Index).Quads := 0;
      end if;
   end Flush_Page;

   procedure Flush (Item : in out Atlas; Target : Renderer) is
   begin
      for I in 1 .. Item.Count loop
         Flush_Page (Item, Target, I);
      end loop;
   end Flush;

   procedure Empty_Page (Item : in out Atlas; Index : Positive);
   --  Forget the glyphs on a page, to make room.

   procedure Empty_Page (Item : in out Atlas; Index : Positive) is
      Position : Slot_Maps.Cursor := Item.Slots.First;
   begin
      while Slot_Maps.Has_Element (Position) loop
         declare
            Following : constant Slot_Maps.Cursor :=
              Slot_Maps.Next (Position);
         begin
            if Slot_Maps.Element (Position).Page = Index then
               Item.Slots.Delete (Position);
            end if;
            Position := Following;
         end;
      end loop;
      Item.Pages (Index).Cursor_X := 0;
      Item.Pages (Index).Row_Y := 0;
      Item.Pages (Index).Row_H := 0;
      Item.Pages (Index).Quads := 0;
   end Empty_Page;

   function Fits
     (Page : Page_Record; Width, Height : Positive) return Boolean;
   --  Whether a Width x Height image can be put on the page, after
   --  those already, in a row of the same height or a new row.

   function Fits
     (Page : Page_Record; Width, Height : Positive) return Boolean is
   begin
      if Page.Cursor_X + Width <= Page_Size then
         return Page.Row_Y + Natural'Max (Page.Row_H, Height) <= Page_Size;
      else
         return Page.Row_Y + Page.Row_H + Height <= Page_Size;
      end if;
   end Fits;

   procedure Take
     (Page : in out Page_Record;
      Width, Height : Positive;
      X, Y : out Natural)
     with Pre => Fits (Page, Width, Height);
   --  Put an image on the page.

   procedure Take
     (Page : in out Page_Record;
      Width, Height : Positive;
      X, Y : out Natural) is
   begin
      if Page.Cursor_X + Width > Page_Size then
         Page.Row_Y := Page.Row_Y + Page.Row_H;
         Page.Cursor_X := 0;
         Page.Row_H := 0;
      end if;
      X := Page.Cursor_X;
      Y := Page.Row_Y;
      Page.Cursor_X := Page.Cursor_X + Width;
      Page.Row_H := Natural'Max (Page.Row_H, Height);
   end Take;

   procedure Find_Room
     (Item   : in out Atlas;
      Target : Renderer;
      Width, Height : Positive;
      Index  : out Positive;
      X, Y   : out Natural)
     with Pre => Width <= Page_Size and then Height <= Page_Size;
   --  Somewhere to put an image, making room if need be.

   procedure Find_Room
     (Item   : in out Atlas;
      Target : Renderer;
      Width, Height : Positive;
      Index  : out Positive;
      X, Y   : out Natural) is
   begin
      for I in 1 .. Item.Count loop
         if Fits (Item.Pages (I), Width, Height) then
            Index := I;
            Take (Item.Pages (I), Width, Height, X, Y);
            return;
         end if;
      end loop;

      if Item.Count < Max_Pages then
         Item.Count := Item.Count + 1;
         Index := Item.Count;
         Textures.Create_Blank
           (Item.Pages (Index).Image, Target, Page_Size, Page_Size,
            Smooth => True);
         Item.Pages (Index).Vertices :=
           new Textures.Vertex_Array (1 .. 4 * Textures.Max_Quads);
      else
         --  The page drawn from least recently. Better not one drawn
         --  from this frame: its batch refers to what is there.
         Index := 1;
         for I in 2 .. Item.Count loop
            if Item.Pages (I).Used < Item.Pages (Index).Used then
               Index := I;
            end if;
         end loop;
         Flush_Page (Item, Target, Index);
         Empty_Page (Item, Index);
      end if;
      Take (Item.Pages (Index), Width, Height, X, Y);
   end Find_Room;

   --  Glyphs

   function Slot_For
     (Item    : in out Atlas;
      Reg     : CoreText.Shaping.Registry;
      Target  : Renderer;
      Font    : CoreText.Shaping.Font_Id;
      Id      : Interfaces.Unsigned_16;
      Size    : Float;
      Sub     : Natural) return Slot;
   --  Where the glyph is, rasterizing it if it is not on a page.

   function Slot_For
     (Item    : in out Atlas;
      Reg     : CoreText.Shaping.Registry;
      Target  : Renderer;
      Font    : CoreText.Shaping.Font_Id;
      Id      : Interfaces.Unsigned_16;
      Size    : Float;
      Sub     : Natural) return Slot
   is
      Key    : constant Interfaces.Unsigned_64 := Key_Of (Font, Id, Size, Sub);
      Cursor : constant Slot_Maps.Cursor := Item.Slots.Find (Key);
      Result : Slot;
   begin
      if Slot_Maps.Has_Element (Cursor) then
         return Slot_Maps.Element (Cursor);
      end if;

      Glyphs.Rasterize
        (Reg, Font, Id, Size, Float (Sub) * Subpixel_Width,
         Item.Scratch);
      Item.Made := Item.Made + 1;

      if not Glyphs.Is_Blank (Item.Scratch)
        and then Glyphs.Width (Item.Scratch) <= Page_Size
        and then Glyphs.Height (Item.Scratch) <= Page_Size
      then
         declare
            Index : Positive;
         begin
            Result.W := Glyphs.Width (Item.Scratch);
            Result.H := Glyphs.Height (Item.Scratch);
            Find_Room (Item, Target, Result.W, Result.H, Index,
                       Result.X, Result.Y);
            Result.Page := Index;
            Result.Left := Glyphs.Left (Item.Scratch);
            Result.Top := Glyphs.Top (Item.Scratch);
            Result.Color := CoreText.Shaping.Is_Color (Reg, Font);
            Textures.Update_Region
              (Item.Pages (Index).Image, Result.X, Result.Y, Result.W,
               Result.H, Glyphs.Pixels (Item.Scratch),
               Glyphs.Pitch (Item.Scratch));
         end;
      end if;
      Item.Slots.Insert (Key, Result);
      return Result;
   end Slot_For;

   procedure Begin_Frame (Item : in out Atlas) is
   begin
      Item.Frame := Item.Frame + 1;
   end Begin_Frame;

   procedure Draw
     (Item     : in out Atlas;
      Reg      : CoreText.Shaping.Registry;
      Target   : Renderer;
      Line     : CoreText.Shaping.Shaped;
      X        : Float;
      Baseline : Float;
      Scale    : Float;
      Size     : Float;
      Value    : Color;
      Settled  : Boolean)
   is
      Raster : constant Float := Raster_Size (Size, Settled);
      Ratio  : constant Float := Size / Raster;
      Alpha  : constant Float := Float (Value.Alpha) / 255.0;
      Base   : constant Float := Float'Rounding (Baseline);
      Page_F : constant Float := Float (Page_Size);
   begin
      for G of Line.Glyphs loop
         declare
            At_X  : constant Float := X + G.X * Scale;
            Whole : constant Float := Float'Floor (At_X);
            Sub   : constant Natural :=
              Natural'Min
                (Subpixel_Steps - 1,
                 Natural (Float'Floor ((At_X - Whole) / Subpixel_Width)));
            Found : constant Slot :=
              Slot_For (Item, Reg, Target, G.Font, G.Id, Raster, Sub);
         begin
            if Found.Page /= 0 then
               declare
                  Page : Page_Record renames Item.Pages (Found.Page);
                  Left : constant Float := Whole + Float (Found.Left) * Ratio;
                  Top  : constant Float := Base - Float (Found.Top) * Ratio;
                  Right  : constant Float := Left + Float (Found.W) * Ratio;
                  Bottom : constant Float := Top + Float (Found.H) * Ratio;
                  U0 : constant Float := Float (Found.X) / Page_F;
                  V0 : constant Float := Float (Found.Y) / Page_F;
                  U1 : constant Float := Float (Found.X + Found.W) / Page_F;
                  V1 : constant Float := Float (Found.Y + Found.H) / Page_F;

                  --  The glyphs are premultiplied, so is what tints them.
                  R : constant Float :=
                    (if Found.Color then Alpha
                     else Float (Value.Red) / 255.0 * Alpha);
                  Gr : constant Float :=
                    (if Found.Color then Alpha
                     else Float (Value.Green) / 255.0 * Alpha);
                  B : constant Float :=
                    (if Found.Color then Alpha
                     else Float (Value.Blue) / 255.0 * Alpha);
                  First : constant Positive := 4 * Page.Quads + 1;
               begin
                  Page.Used := Item.Frame;
                  Page.Vertices (First) :=
                    (Left, Top, R, Gr, B, Alpha, U0, V0);
                  Page.Vertices (First + 1) :=
                    (Right, Top, R, Gr, B, Alpha, U1, V0);
                  Page.Vertices (First + 2) :=
                    (Left, Bottom, R, Gr, B, Alpha, U0, V1);
                  Page.Vertices (First + 3) :=
                    (Right, Bottom, R, Gr, B, Alpha, U1, V1);
                  Page.Quads := Page.Quads + 1;
                  if Page.Quads = Textures.Max_Quads then
                     Flush_Page (Item, Target, Found.Page);
                  end if;
               end;
            end if;
         end;
      end loop;
   end Draw;

   function Glyphs_Made (Item : Atlas) return Natural is (Item.Made);

   function Pages_Used (Item : Atlas) return Natural is (Item.Count);

   overriding procedure Finalize (Item : in out Atlas) is
   begin
      for I in 1 .. Item.Count loop
         Free (Item.Pages (I).Vertices);
      end loop;
      Item.Slots.Clear;
   end Finalize;

end Typeset.Glyph_Atlas;
