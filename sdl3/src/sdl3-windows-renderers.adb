with Interfaces.C;
with SDL3.Errors;
with SDL3.Thin;

package body SDL3.Windows.Renderers is

   use type System.Address;
   use type Interfaces.C.C_float;

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

   procedure Create (Item : in out Renderer; Target : Window) is
   begin
      Finalize (Item);
      Item.Handle := Thin.Create_Renderer (Target.Handle, System.Null_Address);
      if Item.Handle = System.Null_Address then
         Errors.Raise_Last_Error ("SDL_CreateRenderer");
      end if;

      --  Present waits for the display refresh: no tearing, and it paces
      --  the render loop.
      Errors.Check
        (Thin.Set_Render_VSync (Item.Handle, 1), "SDL_SetRenderVSync");
   end Create;

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

   procedure Present (Item : Renderer) is
   begin
      Errors.Check (Thin.Render_Present (Item.Handle), "SDL_RenderPresent");
   end Present;

   overriding procedure Finalize (Item : in out Renderer) is
   begin
      if Item.Handle /= System.Null_Address then
         Thin.Destroy_Renderer (Item.Handle);
         Item.Handle := System.Null_Address;
      end if;
   end Finalize;

end SDL3.Windows.Renderers;
