with Ada.Numerics.Elementary_Functions;
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

   procedure Make_Canvas (Item : in out Renderer; Width, Height : Positive);
   --  Draw to a new image Width x Height, in place of any there is.

   function Window_Size (Item : Renderer) return Thin.IRect;
   --  Of the window the renderer is for, in pixels, whatever it draws to.

   procedure Create
     (Item       : in out Renderer;
      Target     : Window;
      VSync      : Boolean := True;
      Keep_Frame : Boolean := True) is
   begin
      Finalize (Item);
      Item.Handle := Thin.Create_Renderer (Target.Handle, System.Null_Address);
      if Item.Handle = System.Null_Address then
         Errors.Raise_Last_Error ("SDL_CreateRenderer");
      end if;

      Errors.Check
        (Thin.Set_Render_VSync (Item.Handle, (if VSync then 1 else 0)),
         "SDL_SetRenderVSync");

      if Keep_Frame then
         declare
            Size : constant Thin.IRect := Window_Size (Item);
         begin
            Make_Canvas
              (Item, Positive'Max (1, Integer (Size.W)),
               Positive'Max (1, Integer (Size.H)));
         end;
      end if;
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

   function Keeps_Frame (Item : Renderer) return Boolean is
     (Item.Canvas /= System.Null_Address);

   function Window_Size (Item : Renderer) return Thin.IRect is
      W, H : aliased Interfaces.C.int;
   begin
      Errors.Check
        (Thin.Get_Window_Output_Size (Item.Handle, W'Access, H'Access),
         "SDL_GetRenderOutputSize");
      return (X => 0, Y => 0, W => W, H => H);
   end Window_Size;

   procedure Fit (Item : in out Renderer; Changed : out Boolean) is
   begin
      Changed := False;
      if Item.Canvas /= System.Null_Address
        and then Item.Surface = System.Null_Address
      then
         declare
            Size : constant Thin.IRect := Window_Size (Item);
            Wide : constant Natural := Natural (Size.W);
            High : constant Natural := Natural (Size.H);
         begin
            --  A window with no area, as when it is minimized, is left
            --  as it was.
            if Wide > 0 and then High > 0
              and then (Wide /= Item.Canvas_Width
                        or else High /= Item.Canvas_Height)
            then
               Make_Canvas (Item, Wide, High);
               Changed := True;
            end if;
         end;
      end if;
   end Fit;

   procedure Resize (Item : in out Renderer; Width, Height : Positive) is
   begin
      Make_Canvas (Item, Width, Height);
   end Resize;

   procedure Make_Canvas (Item : in out Renderer; Width, Height : Positive) is
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
      Item.Canvas_Width := Width;
      Item.Canvas_Height := Height;
      if Item.Surface = System.Null_Address then
         --  Drawn to the window as it is, whole.
         Errors.Check
           (Thin.Set_Texture_Blend_Mode (Canvas, 0),
            "SDL_SetTextureBlendMode");
         Errors.Check
           (Thin.Set_Texture_Scale_Mode (Canvas, Thin.Scale_Mode_Nearest),
            "SDL_SetTextureScaleMode");
      end if;
   end Make_Canvas;

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
      --  Blended with what is behind, if it is not opaque: SDL_BLENDMODE_BLEND
      --  is 1, and _NONE 0.
      Errors.Check
        (Thin.Set_Render_Draw_Blend_Mode
           (Item.Handle, (if Value.Alpha < 255 then 1 else 0)),
         "SDL_SetRenderDrawBlendMode");
      Errors.Check
        (Thin.Render_Fill_Rect (Item.Handle, Rect'Access),
         "SDL_RenderFillRect");
   end Fill_Rect;

   procedure Fill_Rect
     (Item : Renderer;
      Value : Color;
      Blend : Blends;
      X, Y, Width, Height : Float)
   is
      Rect : aliased constant Thin.FRect :=
        (X => To_C (X), Y => To_C (Y), W => To_C (Width), H => To_C (Height));
   begin
      Set_Color (Item, Value);
      --  SDL_BLENDMODE_NONE is 0, _BLEND 1, _ADD 2 and _MUL 8.
      Errors.Check
        (Thin.Set_Render_Draw_Blend_Mode
           (Item.Handle,
            (case Blend is
               when Solid    => (if Value.Alpha < 255 then 1 else 0),
               when Multiply => 8,
               when Add      => 2)),
         "SDL_SetRenderDrawBlendMode");
      Errors.Check
        (Thin.Render_Fill_Rect (Item.Handle, Rect'Access),
         "SDL_RenderFillRect");
   end Fill_Rect;

   function Vertex
     (X, Y : Float; Value : Color; Alpha : Float) return Thin.Vertex is
     (X => To_C (X), Y => To_C (Y),
      Red => To_C (Float (Value.Red) / 255.0),
      Green => To_C (Float (Value.Green) / 255.0),
      Blue => To_C (Float (Value.Blue) / 255.0),
      Alpha => To_C (Alpha * Float (Value.Alpha) / 255.0),
      U => 0.0, V => 0.0);
   --  A corner of a shape, Alpha of the colour's own.

   procedure Draw_Triangles
     (Item     : Renderer;
      Vertices : System.Address;
      Count    : Natural;
      Indices  : System.Address;
      Used     : Natural);
   --  Blend the triangles over what is behind: Vertices is the first of
   --  Count, Indices of Used.

   procedure Draw_Triangles
     (Item     : Renderer;
      Vertices : System.Address;
      Count    : Natural;
      Indices  : System.Address;
      Used     : Natural) is
   begin
      Errors.Check
        (Thin.Set_Render_Draw_Blend_Mode (Item.Handle, 1),
         "SDL_SetRenderDrawBlendMode");
      Errors.Check
        (Thin.Render_Geometry
           (Item.Handle, System.Null_Address, Vertices,
            Interfaces.C.int (Count), Indices,
            Interfaces.C.int (Used)),
         "SDL_RenderGeometry");
   end Draw_Triangles;

   procedure Draw_Line
     (Item : Renderer;
      Value : Color;
      From_X, From_Y, To_X, To_Y : Float;
      Width : Float := 1.0)
   is
      Dx      : constant Float := To_X - From_X;
      Dy      : constant Float := To_Y - From_Y;
      Length  : constant Float := Ada.Numerics.Elementary_Functions.Sqrt
                                    (Dx * Dx + Dy * Dy);
      Across_X : constant Float :=
        (if Length > 0.0 then -Dy / Length else 0.0);
      Across_Y : constant Float :=
        (if Length > 0.0 then Dx / Length else 1.0);
      Core    : constant Float := Float'Max (0.0, Width / 2.0 - 0.5);
      Outer   : constant Float := Width / 2.0 + 0.5;
      --  The solid part's half width, and where it has faded out: a pixel
      --  across, so that the edges are smooth.
      Offsets : constant array (1 .. 4) of Float :=
        [-Outer, -Core, Core, Outer];
      Fades   : constant array (1 .. 4) of Float := [0.0, 1.0, 1.0, 0.0];
      Corners : array (1 .. 8) of Thin.Vertex;
      Order   : array (1 .. 18) of Interfaces.C.int;
      Used    : Natural := 0;
   begin
      for Step in 1 .. 4 loop
         Corners (Step) :=
           Vertex (From_X + Offsets (Step) * Across_X,
                   From_Y + Offsets (Step) * Across_Y,
                   Value, Fades (Step));
         Corners (Step + 4) :=
           Vertex (To_X + Offsets (Step) * Across_X,
                   To_Y + Offsets (Step) * Across_Y,
                   Value, Fades (Step));
      end loop;
      for Strip in 0 .. 2 loop
         declare
            Quad : constant array (1 .. 6) of Natural :=
              [Strip, Strip + 1, Strip + 4,
               Strip + 1, Strip + 5, Strip + 4];
         begin
            for Index of Quad loop
               Used := Used + 1;
               Order (Used) := Interfaces.C.int (Index);
            end loop;
         end;
      end loop;
      Draw_Triangles
        (Item, Corners (1)'Address, 8, Order (1)'Address, Used);
   end Draw_Line;

   procedure Fill_Circle
     (Item : Renderer;
      Value : Color;
      Centre_X, Centre_Y, Radius : Float)
   is
      Segments : constant := 48;
      Inner    : constant Float := Float'Max (0.0, Radius - 0.5);
      Outer    : constant Float := Radius + 0.5;
      --  Solid to Inner, faded out by Outer.
      Corners  : array (1 .. 1 + 2 * Segments) of Thin.Vertex;
      Order    : array (1 .. 9 * Segments) of Interfaces.C.int;
      Used     : Natural := 0;

      procedure Triangle (A, B, C : Positive) is
      begin
         Order (Used + 1) := Interfaces.C.int (A - 1);
         Order (Used + 2) := Interfaces.C.int (B - 1);
         Order (Used + 3) := Interfaces.C.int (C - 1);
         Used := Used + 3;
      end Triangle;
   begin
      Corners (1) := Vertex (Centre_X, Centre_Y, Value, 1.0);
      for Step in 0 .. Segments - 1 loop
         declare
            Angle : constant Float :=
              2.0 * Ada.Numerics.Pi * Float (Step) / Float (Segments);
            Cos   : constant Float :=
              Ada.Numerics.Elementary_Functions.Cos (Angle);
            Sin   : constant Float :=
              Ada.Numerics.Elementary_Functions.Sin (Angle);
         begin
            Corners (2 + Step) :=
              Vertex (Centre_X + Inner * Cos, Centre_Y + Inner * Sin,
                      Value, 1.0);
            Corners (2 + Segments + Step) :=
              Vertex (Centre_X + Outer * Cos, Centre_Y + Outer * Sin,
                      Value, 0.0);
         end;
      end loop;
      for Step in 0 .. Segments - 1 loop
         declare
            Next : constant Natural := (Step + 1) mod Segments;
         begin
            Triangle (1, 2 + Step, 2 + Next);
            Triangle (2 + Step, 2 + Segments + Step, 2 + Next);
            Triangle (2 + Next, 2 + Segments + Step, 2 + Segments + Next);
         end;
      end loop;
      Draw_Triangles
        (Item, Corners (1)'Address, Corners'Length, Order (1)'Address,
         Used);
   end Fill_Circle;

   procedure Set_Clip (Item : Renderer; X, Y, Width, Height : Integer) is
      use Interfaces.C;
      Rect : aliased constant Thin.IRect :=
        (X => int (X), Y => int (Y), W => int (Width), H => int (Height));
   begin
      Errors.Check
        (Thin.Set_Render_Clip_Rect (Item.Handle, Rect'Address),
         "SDL_SetRenderClipRect");
   end Set_Clip;

   procedure Clear_Clip (Item : Renderer) is
   begin
      Errors.Check
        (Thin.Set_Render_Clip_Rect (Item.Handle, System.Null_Address),
         "SDL_SetRenderClipRect");
   end Clear_Clip;

   function Current_Clip (Item : Renderer) return Clip is
      Rect : aliased Thin.IRect := (others => 0);
   begin
      if not Boolean (Thin.Render_Clip_Enabled (Item.Handle)) then
         return (Enabled => False, others => 0);
      end if;
      Errors.Check
        (Thin.Get_Render_Clip_Rect (Item.Handle, Rect'Address),
         "SDL_GetRenderClipRect");
      return (Enabled => True, X => Integer (Rect.X), Y => Integer (Rect.Y),
              Width => Integer (Rect.W), Height => Integer (Rect.H));
   end Current_Clip;

   procedure Restore_Clip (Item : Renderer; Value : Clip) is
   begin
      if Value.Enabled then
         Set_Clip (Item, Value.X, Value.Y, Value.Width, Value.Height);
      else
         Clear_Clip (Item);
      end if;
   end Restore_Clip;

   procedure Narrow_Clip (Item : Renderer; X, Y, Width, Height : Integer) is
      Was    : constant Clip := Current_Clip (Item);
      Left   : constant Integer :=
        (if Was.Enabled then Integer'Max (X, Was.X) else X);
      Top    : constant Integer :=
        (if Was.Enabled then Integer'Max (Y, Was.Y) else Y);
      Right  : constant Integer :=
        (if Was.Enabled then Integer'Min (X + Width, Was.X + Was.Width)
         else X + Width);
      Bottom : constant Integer :=
        (if Was.Enabled then Integer'Min (Y + Height, Was.Y + Was.Height)
         else Y + Height);
   begin
      Set_Clip
        (Item, Left, Top,
         Integer'Max (0, Right - Left), Integer'Max (0, Bottom - Top));
   end Narrow_Clip;

   procedure Draw_Text
     (Item  : Renderer;
      Value : Color;
      X, Y  : Float;
      Text  : String;
      Scale : Positive := 1)
   is
      S : constant Interfaces.C.C_float := Interfaces.C.C_float (Scale);
      Was : constant Clip := Current_Clip (Item);
   begin
      Set_Color (Item, Value);
      --  The debug font has a fixed size; scale the renderer instead.
      Errors.Check
        (Thin.Set_Render_Scale (Item.Handle, S, S), "SDL_SetRenderScale");
      if Was.Enabled and then Scale > 1 then
         --  The clip is in the renderer's coordinates, so scaling it
         --  scaled the clip: put it back, to the pixel inside it.
         Set_Clip
           (Item,
            (Was.X + Scale - 1) / Scale,
            (Was.Y + Scale - 1) / Scale,
            Integer'Max
              (0, (Was.X + Was.Width) / Scale - (Was.X + Scale - 1) / Scale),
            Integer'Max
              (0, (Was.Y + Was.Height) / Scale
                  - (Was.Y + Scale - 1) / Scale));
      end if;
      Errors.Check
        (Thin.Render_Debug_Text
           (Item.Handle, To_C (X) / S, To_C (Y) / S,
            Interfaces.C.To_C (Text)),
         "SDL_RenderDebugText");
      Errors.Check
        (Thin.Set_Render_Scale (Item.Handle, 1.0, 1.0), "SDL_SetRenderScale");
      Restore_Clip (Item, Was);
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
      if Item.Canvas /= System.Null_Address
        and then Item.Surface = System.Null_Address
      then
         --  What is drawn is in the image: copy it to the window, and
         --  go on drawing to the image.
         Errors.Check
           (Thin.Set_Render_Target (Item.Handle, System.Null_Address),
            "SDL_SetRenderTarget");
         Errors.Check
           (Thin.Render_Texture (Item.Handle, Item.Canvas, null, null),
            "SDL_RenderTexture");
         Errors.Check
           (Thin.Render_Present (Item.Handle), "SDL_RenderPresent");
         Errors.Check
           (Thin.Set_Render_Target (Item.Handle, Item.Canvas),
            "SDL_SetRenderTarget");
      else
         Errors.Check
           (Thin.Render_Present (Item.Handle), "SDL_RenderPresent");
      end if;
   end Present;

   overriding procedure Finalize (Item : in out Renderer) is
   begin
      if Item.Canvas /= System.Null_Address then
         --  Not checked: this may be after SDL has gone, and what it
         --  cannot do then must not raise.
         if Thin.Set_Render_Target (Item.Handle, System.Null_Address) then
            null;
         end if;
         Thin.Destroy_Texture (Item.Canvas);
         Item.Canvas := System.Null_Address;
         Item.Canvas_Width := 0;
         Item.Canvas_Height := 0;
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
