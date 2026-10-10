with Ada.Unchecked_Deallocation;
with Interfaces;
with Interfaces.C;
with SDL3.Errors;
with SDL3.Thin;

package body SDL3.Windows.Renderers.Textures is

   use type System.Address;

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
