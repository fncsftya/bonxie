with Interfaces.C;
with Interfaces.C.Strings;
with SDL3.Errors;
with SDL3.Thin;

package body SDL3.Windows.Renderers is

   use type System.Address;
   use type Interfaces.C.C_float;
   use type Thin.Surface_Access;

   function To_C (Value : Float) return Interfaces.C.C_float is
     (Interfaces.C.C_float (Value));

   procedure Set_Color (Item : Renderer; Value : Color) is
   begin
      Errors.Check
        (Thin.Set_Render_Draw_Color
           (Item.Handle,
            Interfaces.Unsigned_8 (Value.Red),
            Interfaces.Unsigned_8 (Value.Green),
            Interfaces.Unsigned_8 (Value.Blue),
            Interfaces.Unsigned_8 (Value.Alpha)),
         "SDL_SetRenderDrawColor");
   end Set_Color;

   procedure Create
     (Item : in out Renderer; Target : Window; VSync : Boolean := True) is
   begin
      Finalize (Item);
      Item.Handle := Thin.Create_Renderer (Target.Handle, System.Null_Address);
      if Item.Handle = System.Null_Address then
         Errors.Raise_Last_Error ("SDL_CreateRenderer");
      end if;

      Errors.Check
        (Thin.Set_Render_VSync (Item.Handle, (if VSync then 1 else 0)),
         "SDL_SetRenderVSync");
   end Create;

   procedure Create_Offscreen
     (Item : in out Renderer; Width, Height : Positive)
   is
      Surface : constant Thin.Surface_Access :=
        Thin.Create_Surface (1, 1, Thin.Pixel_Format_RGBA32);
   begin
      Finalize (Item);
      if Surface = null then
         Errors.Raise_Last_Error ("SDL_CreateSurface");
      end if;
      Item.Surface := Surface.all'Address;
      Item.Handle := Thin.Create_Software_Renderer (Surface);
      if Item.Handle = System.Null_Address then
         Errors.Raise_Last_Error ("SDL_CreateSoftwareRenderer");
      end if;
      Resize (Item, Width, Height);
   end Create_Offscreen;

   function Is_Offscreen (Item : Renderer) return Boolean is
     (Item.Surface /= System.Null_Address);

   procedure Resize (Item : in out Renderer; Width, Height : Positive) is
      Canvas : constant Thin.Texture :=
        Thin.Create_Texture
          (Item.Handle, Thin.Pixel_Format_RGBA32, Thin.Texture_Access_Target,
           Interfaces.C.int (Width), Interfaces.C.int (Height));
   begin
      if Canvas = System.Null_Address then
         Errors.Raise_Last_Error ("SDL_CreateTexture");
      end if;
      Errors.Check
        (Thin.Set_Render_Target (Item.Handle, Canvas), "SDL_SetRenderTarget");
      if Item.Canvas /= System.Null_Address then
         Thin.Destroy_Texture (Item.Canvas);
      end if;
      Item.Canvas := Canvas;
   end Resize;

   procedure Output_Size (Item : Renderer; Width, Height : out Natural) is
      W, H : aliased Interfaces.C.int;
   begin
      Errors.Check
        (Thin.Get_Render_Output_Size (Item.Handle, W'Access, H'Access),
         "SDL_GetRenderOutputSize");
      Width := Natural (W);
      Height := Natural (H);
   end Output_Size;

   procedure Clear (Item : Renderer; Value : Color) is
   begin
      Set_Color (Item, Value);
      Errors.Check (Thin.Render_Clear (Item.Handle), "SDL_RenderClear");
   end Clear;

   procedure Fill_Rect
     (Item : Renderer;
      Value : Color;
      X, Y, Width, Height : Float)
   is
      Rect : aliased constant Thin.FRect :=
        (X => To_C (X), Y => To_C (Y), W => To_C (Width), H => To_C (Height));
   begin
      Set_Color (Item, Value);
      Errors.Check
        (Thin.Render_Fill_Rect (Item.Handle, Rect'Access),
         "SDL_RenderFillRect");
   end Fill_Rect;

   procedure Draw_Text
     (Item  : Renderer;
      Value : Color;
      X, Y  : Float;
      Text  : String;
      Scale : Positive := 1)
   is
      S : constant Interfaces.C.C_float := Interfaces.C.C_float (Scale);
   begin
      Set_Color (Item, Value);
      --  The debug font has a fixed size; scale the renderer instead.
      Errors.Check
        (Thin.Set_Render_Scale (Item.Handle, S, S), "SDL_SetRenderScale");
      Errors.Check
        (Thin.Render_Debug_Text
           (Item.Handle, To_C (X) / S, To_C (Y) / S,
            Interfaces.C.To_C (Text)),
         "SDL_RenderDebugText");
      Errors.Check
        (Thin.Set_Render_Scale (Item.Handle, 1.0, 1.0), "SDL_SetRenderScale");
   end Draw_Text;

   procedure Save_BMP (Item : Renderer; File_Name : String) is
      Surface : constant System.Address :=
        Thin.Render_Read_Pixels (Item.Handle, System.Null_Address);
      Name    : Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.New_String (File_Name);
      Saved   : Interfaces.C.C_bool;
   begin
      if Surface = System.Null_Address then
         Interfaces.C.Strings.Free (Name);
         Errors.Raise_Last_Error ("SDL_RenderReadPixels");
      end if;
      Saved := Thin.Save_BMP (Surface, Name);
      Interfaces.C.Strings.Free (Name);
      Thin.Destroy_Surface (Surface);
      Errors.Check (Saved, "SDL_SaveBMP");
   end Save_BMP;

   procedure Present (Item : Renderer) is
   begin
      Errors.Check (Thin.Render_Present (Item.Handle), "SDL_RenderPresent");
   end Present;

   overriding procedure Finalize (Item : in out Renderer) is
   begin
      if Item.Canvas /= System.Null_Address then
         Errors.Check
           (Thin.Set_Render_Target (Item.Handle, System.Null_Address),
            "SDL_SetRenderTarget");
         Thin.Destroy_Texture (Item.Canvas);
         Item.Canvas := System.Null_Address;
      end if;
      if Item.Handle /= System.Null_Address then
         Thin.Destroy_Renderer (Item.Handle);
         Item.Handle := System.Null_Address;
      end if;
      if Item.Surface /= System.Null_Address then
         Thin.Destroy_Surface (Item.Surface);
         Item.Surface := System.Null_Address;
      end if;
   end Finalize;

end SDL3.Windows.Renderers;
