with Interfaces.C;
with Interfaces.C.Strings;
with System;

--  Minimal thin C binding to SDL3. Internal: use the SDL3 child packages.
private package SDL3.Thin is

   use Interfaces.C;

   type Init_Flags is new Interfaces.Unsigned_32;
   Init_Video : constant Init_Flags := 16#20#;

   type Window_Flags is new Interfaces.Unsigned_64;
   Window_Resizable : constant Window_Flags := 16#20#;
   Window_High_Pixel_Density : constant Window_Flags := 16#2000#;

   type Event_Type is new Interfaces.Unsigned_32;
   Event_Quit        : constant Event_Type := 16#100#;
   Event_Key_Down    : constant Event_Type := 16#300#;
   Event_Mouse_Wheel : constant Event_Type := 16#403#;
   Event_Window_Exposed           : constant Event_Type := 16#204#;
   Event_Window_Resized           : constant Event_Type := 16#206#;
   Event_Window_Pixel_Size_Changed : constant Event_Type := 16#207#;

   --  SDL_Event is a 128-byte union whose first member is the type.
   type Event is record
      Kind    : Event_Type;
      Padding : Interfaces.C.char_array (1 .. 124);
   end record
     with Convention => C, Size => 128 * 8;

   --  The parts of SDL_Event this binding reads, over the same 128 bytes.
   type Wheel_Event is record
      Kind      : Event_Type;
      Reserved  : Interfaces.Unsigned_32;
      Timestamp : Interfaces.Unsigned_64;
      Window_Id : Interfaces.Unsigned_32;
      Which     : Interfaces.Unsigned_32;
      X, Y      : Interfaces.C.C_float;
      Direction : Interfaces.Unsigned_32;
      Mouse_X, Mouse_Y : Interfaces.C.C_float;
      Padding   : Interfaces.C.char_array (1 .. 84);
   end record
     with Convention => C, Size => 128 * 8;

   type Key_Event is record
      Kind      : Event_Type;
      Reserved  : Interfaces.Unsigned_32;
      Timestamp : Interfaces.Unsigned_64;
      Window_Id : Interfaces.Unsigned_32;
      Which     : Interfaces.Unsigned_32;
      Scancode  : Interfaces.Unsigned_32;
      Key       : Interfaces.Unsigned_32;
      Modifiers : Interfaces.Unsigned_16;
      Raw       : Interfaces.Unsigned_16;
      Down      : Interfaces.C.C_bool;
      Repeated  : Interfaces.C.C_bool;
      Padding   : Interfaces.C.char_array (1 .. 90);
   end record
     with Convention => C, Size => 128 * 8;

   type FRect is record
      X, Y, W, H : Interfaces.C.C_float;
   end record
     with Convention => C;

   subtype Window is System.Address;
   subtype Renderer is System.Address;
   Null_Window : constant Window := System.Null_Address;

   subtype Texture is System.Address;

   Pixel_Format_RGBA32 : constant Interfaces.Unsigned_32 := 16#1676_2004#;
   --  SDL_PIXELFORMAT_RGBA32 on little-endian (ABGR8888): bytes R, G, B, A.
   Texture_Access_Static : constant Interfaces.C.int := 0;
   Scale_Mode_Nearest    : constant Interfaces.C.int := 0;
   Scale_Mode_Linear     : constant Interfaces.C.int := 1;

   function Create_Texture
     (R      : Renderer;
      Format : Interfaces.Unsigned_32;
      Access_Kind : Interfaces.C.int;
      W, H   : Interfaces.C.int) return Texture
     with Import, Convention => C, External_Name => "SDL_CreateTexture";

   procedure Destroy_Texture (T : Texture)
     with Import, Convention => C, External_Name => "SDL_DestroyTexture";

   function Update_Texture
     (T      : Texture;
      Area   : System.Address;
      Pixels : System.Address;
      Pitch  : Interfaces.C.int) return Interfaces.C.C_bool
     with Import, Convention => C, External_Name => "SDL_UpdateTexture";

   function Compose_Custom_Blend_Mode
     (Src_Color, Dst_Color, Color_Op, Src_Alpha, Dst_Alpha, Alpha_Op :
        Interfaces.C.int) return Interfaces.Unsigned_32
     with Import, Convention => C,
          External_Name => "SDL_ComposeCustomBlendMode";

   function Set_Texture_Blend_Mode
     (T : Texture; Mode : Interfaces.Unsigned_32) return Interfaces.C.C_bool
     with Import, Convention => C, External_Name => "SDL_SetTextureBlendMode";

   function Set_Texture_Scale_Mode
     (T : Texture; Mode : Interfaces.C.int) return Interfaces.C.C_bool
     with Import, Convention => C, External_Name => "SDL_SetTextureScaleMode";

   function Render_Texture
     (R    : Renderer;
      T    : Texture;
      Src  : access constant FRect;
      Dest : access constant FRect) return Interfaces.C.C_bool
     with Import, Convention => C, External_Name => "SDL_RenderTexture";

   function Init (Flags : Init_Flags) return Interfaces.C.C_bool
     with Import, Convention => C, External_Name => "SDL_Init";

   procedure Quit
     with Import, Convention => C, External_Name => "SDL_Quit";

   function Create_Window
     (Title : Interfaces.C.Strings.chars_ptr;
      W, H  : int;
      Flags : Window_Flags) return Window
     with Import, Convention => C, External_Name => "SDL_CreateWindow";

   procedure Destroy_Window (Win : Window)
     with Import, Convention => C, External_Name => "SDL_DestroyWindow";

   function Create_Renderer
     (Win : Window; Name : System.Address) return Renderer
     with Import, Convention => C, External_Name => "SDL_CreateRenderer";

   procedure Destroy_Renderer (R : Renderer)
     with Import, Convention => C, External_Name => "SDL_DestroyRenderer";

   function Set_Render_Draw_Color
     (R : Renderer; Red, Green, Blue, Alpha : Interfaces.Unsigned_8)
      return Interfaces.C.C_bool
     with Import, Convention => C, External_Name => "SDL_SetRenderDrawColor";

   function Render_Clear (R : Renderer) return Interfaces.C.C_bool
     with Import, Convention => C, External_Name => "SDL_RenderClear";

   function Render_Fill_Rect
     (R : Renderer; Rect : access constant FRect) return Interfaces.C.C_bool
     with Import, Convention => C, External_Name => "SDL_RenderFillRect";

   function Render_Present (R : Renderer) return Interfaces.C.C_bool
     with Import, Convention => C, External_Name => "SDL_RenderPresent";

   function Set_Render_VSync
     (R : Renderer; VSync : Interfaces.C.int) return Interfaces.C.C_bool
     with Import, Convention => C, External_Name => "SDL_SetRenderVSync";

   function Set_Render_Scale
     (R : Renderer; X, Y : Interfaces.C.C_float) return Interfaces.C.C_bool
     with Import, Convention => C, External_Name => "SDL_SetRenderScale";

   function Render_Debug_Text
     (R    : Renderer;
      X, Y : Interfaces.C.C_float;
      Text : Interfaces.C.char_array) return Interfaces.C.C_bool
     with Import, Convention => C, External_Name => "SDL_RenderDebugText";

   function Get_Render_Output_Size
     (R : Renderer; W, H : access Interfaces.C.int) return Interfaces.C.C_bool
     with Import, Convention => C, External_Name => "SDL_GetRenderOutputSize";

   function Wait_Event_Timeout
     (E : access Event; Timeout_MS : Interfaces.Integer_32)
      return Interfaces.C.C_bool
     with Import, Convention => C, External_Name => "SDL_WaitEventTimeout";

   function Get_Window_Pixel_Density (Win : Window) return Interfaces.C.C_float
     with Import, Convention => C,
          External_Name => "SDL_GetWindowPixelDensity";

   type Vertex is record
      X, Y       : Interfaces.C.C_float;
      Red, Green, Blue, Alpha : Interfaces.C.C_float;
      U, V       : Interfaces.C.C_float;
   end record
     with Convention => C;

   type IRect is record
      X, Y, W, H : Interfaces.C.int;
   end record
     with Convention => C;

   function Render_Geometry
     (R           : Renderer;
      T           : Texture;
      Vertices    : System.Address;
      Vertex_Count : Interfaces.C.int;
      Indices     : System.Address;
      Index_Count : Interfaces.C.int) return Interfaces.C.C_bool
     with Import, Convention => C, External_Name => "SDL_RenderGeometry";

   function Get_Mod_State return Interfaces.Unsigned_16
     with Import, Convention => C, External_Name => "SDL_GetModState";

   function Render_Read_Pixels
     (R : Renderer; Area : System.Address) return System.Address
     with Import, Convention => C, External_Name => "SDL_RenderReadPixels";
   --  A new SDL_Surface of the target's pixels, or null.

   function Save_BMP
     (Surface : System.Address; File : Interfaces.C.Strings.chars_ptr)
      return Interfaces.C.C_bool
     with Import, Convention => C, External_Name => "SDL_SaveBMP";

   procedure Destroy_Surface (Surface : System.Address)
     with Import, Convention => C, External_Name => "SDL_DestroySurface";

   function Poll_Event (E : access Event) return Interfaces.C.C_bool
     with Import, Convention => C, External_Name => "SDL_PollEvent";

   type Event_Filter is access function
     (User_Data : System.Address; E : access Event) return Interfaces.C.C_bool
     with Convention => C;

   function Add_Event_Watch
     (Filter : Event_Filter; User_Data : System.Address)
      return Interfaces.C.C_bool
     with Import, Convention => C, External_Name => "SDL_AddEventWatch";

   procedure Delay_MS (MS : Interfaces.Unsigned_32)
     with Import, Convention => C, External_Name => "SDL_Delay";

   function Get_Error return Interfaces.C.Strings.chars_ptr
     with Import, Convention => C, External_Name => "SDL_GetError";

end SDL3.Thin;
