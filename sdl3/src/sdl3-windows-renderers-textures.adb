with Ada.Unchecked_Deallocation;
with Interfaces;
with Interfaces.C;
with Interfaces.C.Strings;
with SDL3.Errors;
with SDL3.Thin;

package body SDL3.Windows.Renderers.Textures is

   use type System.Address;
   use type Thin.Surface_Access;
   use type Interfaces.Unsigned_32;

   Blend_Premultiplied : constant Interfaces.Unsigned_32 := 16#10#;
   --  SDL_BLENDMODE_BLEND_PREMULTIPLIED: what is under is kept as much as
   --  what is over is transparent. A predefined mode, which the software
   --  renderer has, unlike composed ones.

   Blend_Straight : constant Interfaces.Unsigned_32 := 16#1#;
   --  SDL_BLENDMODE_BLEND: the same, for colours not premultiplied. The
   --  software renderer draws geometry only in this mode.

   procedure Create_Premultiplied_RGBA
     (Item   : in out Texture;
      Target : Renderer;
      Columns, Rows : Positive;
      Pixels : System.Address;
      Pitch  : Positive)
   is
      Handle : constant Thin.Texture :=
        Thin.Create_Texture
          (Target.Handle, Thin.Pixel_Format_RGBA32,
           Thin.Texture_Access_Static,
           Interfaces.C.int (Columns), Interfaces.C.int (Rows));
   begin
      if Handle = System.Null_Address then
         Errors.Raise_Last_Error ("SDL_CreateTexture");
      end if;

      Errors.Check
        (Thin.Update_Texture
           (Handle, System.Null_Address, Pixels, Interfaces.C.int (Pitch)),
         "SDL_UpdateTexture");
      --  Source colour is already scaled by its alpha.
      Errors.Check
        (Thin.Set_Texture_Blend_Mode (Handle, Blend_Premultiplied),
         "SDL_SetTextureBlendMode");
      Errors.Check
        (Thin.Set_Texture_Scale_Mode (Handle, Thin.Scale_Mode_Nearest),
         "SDL_SetTextureScaleMode");

      Finalize (Item);
      Item.Handle := Handle;
      Item.Wide := Columns;
      Item.High := Rows;
   end Create_Premultiplied_RGBA;

   type Index_Array is array (0 .. Max_Quads * 6 - 1) of Interfaces.C.int
     with Convention => C;

   function Quad_Indices return Index_Array;
   --  Two triangles to each four vertices.

   use type Interfaces.C.int;

   function Quad_Indices return Index_Array is
   begin
      return Result : Index_Array do
         for Q in 0 .. Max_Quads - 1 loop
            declare
               V : constant Interfaces.C.int := Interfaces.C.int (4 * Q);
               I : constant Natural := 6 * Q;
            begin
               Result (I .. I + 5) := [V, V + 1, V + 2, V + 2, V + 1, V + 3];
            end;
         end loop;
      end return;
   end Quad_Indices;

   Indices : aliased constant Index_Array := Quad_Indices;

   procedure Create_Blank
     (Item    : in out Texture;
      Target  : Renderer;
      Columns, Rows : Positive;
      Smooth  : Boolean)
   is
      Handle : constant Thin.Texture :=
        Thin.Create_Texture
          (Target.Handle, Thin.Pixel_Format_RGBA32,
           Thin.Texture_Access_Static,
           Interfaces.C.int (Columns), Interfaces.C.int (Rows));
      type Zeros is array (1 .. 4 * Columns * Rows) of Interfaces.Unsigned_8;
      type Zeros_Access is access Zeros;
      procedure Free is new Ada.Unchecked_Deallocation (Zeros, Zeros_Access);
      Blank : Zeros_Access := new Zeros'(others => 0);
   begin
      if Handle = System.Null_Address then
         Free (Blank);
         Errors.Raise_Last_Error ("SDL_CreateTexture");
      end if;

      --  A new texture holds whatever was in the memory.
      Errors.Check
        (Thin.Update_Texture
           (Handle, System.Null_Address, Blank.all'Address,
            Interfaces.C.int (4 * Columns)),
         "SDL_UpdateTexture");
      Free (Blank);
      Errors.Check
        (Thin.Set_Texture_Blend_Mode (Handle, Blend_Straight),
         "SDL_SetTextureBlendMode");
      Errors.Check
        (Thin.Set_Texture_Scale_Mode
           (Handle, (if Smooth then Thin.Scale_Mode_Linear
                     else Thin.Scale_Mode_Nearest)),
         "SDL_SetTextureScaleMode");

      Finalize (Item);
      Item.Handle := Handle;
      Item.Wide := Columns;
      Item.High := Rows;
   end Create_Blank;

   procedure Update_Region
     (Item   : Texture;
      Left, Top, Columns, Rows : Natural;
      Pixels : System.Address;
      Pitch  : Positive)
   is
      Area : aliased constant Thin.IRect :=
        (X => Interfaces.C.int (Left), Y => Interfaces.C.int (Top),
         W => Interfaces.C.int (Columns), H => Interfaces.C.int (Rows));
   begin
      Errors.Check
        (Thin.Update_Texture
           (Item.Handle, Area'Address, Pixels, Interfaces.C.int (Pitch)),
         "SDL_UpdateTexture");
   end Update_Region;

   procedure Draw_Quads
     (Target     : Renderer;
      Item       : Texture;
      Vertices   : Vertex_Array;
      Quad_Count : Natural) is
   begin
      if Quad_Count = 0 then
         return;
      end if;
      Errors.Check
        (Thin.Render_Geometry
           (Target.Handle, Item.Handle, Vertices (Vertices'First)'Address,
            Interfaces.C.int (4 * Quad_Count), Indices'Address,
            Interfaces.C.int (6 * Quad_Count)),
         "SDL_RenderGeometry");
   end Draw_Quads;

   procedure Create_Mask_From_SVG
     (Item      : in out Texture;
      Target    : Renderer;
      File_Name : String;
      Columns, Rows : Positive)
   is
      use Interfaces.C.Strings;
      Name   : chars_ptr := New_String (File_Name);
      Mode   : chars_ptr := New_String ("rb");
      Stream : constant System.Address := Thin.IO_From_File (Name, Mode);
      Loaded : Thin.Surface_Access;
      Plain  : Thin.Surface_Access;
      type Bytes is array (Natural range <>) of Interfaces.Unsigned_8;
      type Bytes_Access is access Bytes;
      procedure Free is new Ada.Unchecked_Deallocation (Bytes, Bytes_Access);
      Mask   : Bytes_Access;
   begin
      Free (Name);
      Free (Mode);
      if Stream = System.Null_Address then
         Errors.Raise_Last_Error ("SDL_IOFromFile " & File_Name);
      end if;
      Loaded :=
        Thin.Load_Sized_SVG_IO
          (Stream, Interfaces.C.int (Columns), Interfaces.C.int (Rows));
      if Loaded = null then
         Errors.Raise_Last_Error ("IMG_LoadSizedSVG_IO " & File_Name);
      end if;
      --  Whatever it gave: as R, G, B, A bytes.
      Plain :=
        (if Loaded.Format = Thin.Pixel_Format_RGBA32 then Loaded
         else Thin.Convert_Surface (Loaded.all'Address,
                                    Thin.Pixel_Format_RGBA32));
      if Plain = null then
         Thin.Destroy_Surface (Loaded.all'Address);
         Errors.Raise_Last_Error ("SDL_ConvertSurface");
      end if;

      Mask := new Bytes (0 .. 4 * Columns * Rows - 1);
      declare
         type Source_Bytes is array (Natural) of Interfaces.Unsigned_8;
         Source : Source_Bytes
           with Import, Address => Plain.Pixels;
      begin
         for Row in 0 .. Rows - 1 loop
            for Column in 0 .. Columns - 1 loop
               declare
                  Out_At : constant Natural := 4 * (Row * Columns + Column);
                  In_At  : constant Natural :=
                    Row * Natural (Plain.Pitch) + 4 * Column;
               begin
                  Mask (Out_At .. Out_At + 2) := [255, 255, 255];
                  Mask (Out_At + 3) := Source (In_At + 3);
               end;
            end loop;
         end loop;
      end;
      Thin.Destroy_Surface (Plain.all'Address);
      if Plain /= Loaded then
         Thin.Destroy_Surface (Loaded.all'Address);
      end if;

      Create_Blank (Item, Target, Columns, Rows, Smooth => True);
      Update_Region
        (Item, 0, 0, Columns, Rows, Mask (0)'Address, 4 * Columns);
      Free (Mask);
   exception
      when others =>
         Free (Mask);
         raise;
   end Create_Mask_From_SVG;

   procedure Draw_Tinted
     (Target : Renderer;
      Item   : Texture;
      X, Y   : Float;
      Value  : Color)
   is
      function Part (Of_Value : Color_Component) return Float is
        (Float (Of_Value) / 255.0);
      Red   : constant Float := Part (Value.Red);
      Green : constant Float := Part (Value.Green);
      Blue  : constant Float := Part (Value.Blue);
      Alpha : constant Float := Part (Value.Alpha);
      Right : constant Float := X + Float (Item.Wide);
      Below : constant Float := Y + Float (Item.High);
   begin
      --  Not premultiplied, as the texture is not.
      Draw_Quads
        (Target, Item,
         [(X, Y, Red, Green, Blue, Alpha, 0.0, 0.0),
          (Right, Y, Red, Green, Blue, Alpha, 1.0, 0.0),
          (X, Below, Red, Green, Blue, Alpha, 0.0, 1.0),
          (Right, Below, Red, Green, Blue, Alpha, 1.0, 1.0)],
         1);
   end Draw_Tinted;

   function Is_Empty (Item : Texture) return Boolean is
     (Item.Handle = System.Null_Address);

   procedure Draw
     (Target : Renderer;
      Item   : Texture;
      X, Y   : Float)
   is
      Dest : aliased constant Thin.FRect :=
        (X => Interfaces.C.C_float (X),
         Y => Interfaces.C.C_float (Y),
         W => Interfaces.C.C_float (Item.Wide),
         H => Interfaces.C.C_float (Item.High));
   begin
      Errors.Check
        (Thin.Render_Texture (Target.Handle, Item.Handle, null, Dest'Access),
         "SDL_RenderTexture");
   end Draw;

   function Width (Item : Texture) return Positive is (Item.Wide);
   function Height (Item : Texture) return Positive is (Item.High);

   overriding procedure Finalize (Item : in out Texture) is
   begin
      if Item.Handle /= System.Null_Address then
         Thin.Destroy_Texture (Item.Handle);
         Item.Handle := System.Null_Address;
      end if;
   end Finalize;

end SDL3.Windows.Renderers.Textures;
