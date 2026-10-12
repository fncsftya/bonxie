with Interfaces.C;
with Interfaces.C.Strings;
with System;

--  Minimal thin C binding to SDL3. Internal: use the SDL3 child packages.
private package SDL3.Thin is

   use Interfaces.C;

   type Init_Flags is new Interfaces.Unsigned_32;
   Init_Video : constant Init_Flags := 16#20#;

   type Window_Flags is new Interfaces.Unsigned_64;
   Window_Hidden    : constant Window_Flags := 16#8#;
   Window_Resizable : constant Window_Flags := 16#20#;
   Window_High_Pixel_Density : constant Window_Flags := 16#2000#;

   type Event_Type is new Interfaces.Unsigned_32;
   Event_Quit        : constant Event_Type := 16#100#;
   Event_Key_Down    : constant Event_Type := 16#300#;
   Event_Text_Editing : constant Event_Type := 16#302#;
   Event_Text_Input  : constant Event_Type := 16#303#;
   Event_Mouse_Motion : constant Event_Type := 16#400#;
   Event_Mouse_Button_Down : constant Event_Type := 16#401#;
   Event_Mouse_Button_Up : constant Event_Type := 16#402#;
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

   type Common_Event is record
      Kind      : Event_Type;
      Reserved  : Interfaces.Unsigned_32;
      Timestamp : Interfaces.Unsigned_64;  --  nanoseconds, as Get_Ticks
      Padding   : Interfaces.C.char_array (1 .. 112);
   end record
     with Convention => C, Size => 128 * 8;

   type Editing_Event is record
      Kind      : Event_Type;
      Reserved  : Interfaces.Unsigned_32;
      Timestamp : Interfaces.Unsigned_64;
      Window_Id : Interfaces.Unsigned_32;
      Align     : Interfaces.Unsigned_32;
      Text      : Interfaces.C.Strings.chars_ptr;
      Start     : Interfaces.Integer_32;  --  in characters; -1 if none
      Length    : Interfaces.Integer_32;
      Padding   : Interfaces.C.char_array (1 .. 88);
   end record
     with Convention => C, Size => 128 * 8;

   type Motion_Event is record
      Kind      : Event_Type;
      Reserved  : Interfaces.Unsigned_32;
      Timestamp : Interfaces.Unsigned_64;
      Window_Id : Interfaces.Unsigned_32;
      Which     : Interfaces.Unsigned_32;
      State     : Interfaces.Unsigned_32;  --  buttons held, a bit each
      X, Y      : Interfaces.C.C_float;
      X_Rel, Y_Rel : Interfaces.C.C_float;
      Padding   : Interfaces.C.char_array (1 .. 84);
   end record
     with Convention => C, Size => 128 * 8;
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

   type Text_Event is record
      Kind      : Event_Type;
      Reserved  : Interfaces.Unsigned_32;
      Timestamp : Interfaces.Unsigned_64;
      Window_Id : Interfaces.Unsigned_32;
      Align     : Interfaces.Unsigned_32;
      Text      : Interfaces.C.Strings.chars_ptr;  --  UTF-8, SDL's
      Padding   : Interfaces.C.char_array (1 .. 96);
   end record
     with Convention => C, Size => 128 * 8;

   type Button_Event is record
      Kind      : Event_Type;
      Reserved  : Interfaces.Unsigned_32;
      Timestamp : Interfaces.Unsigned_64;
      Window_Id : Interfaces.Unsigned_32;
      Which     : Interfaces.Unsigned_32;
      Button    : Interfaces.Unsigned_8;
      Down      : Interfaces.C.C_bool;
      Clicks    : Interfaces.Unsigned_8;
      Pad       : Interfaces.Unsigned_8;
      X, Y      : Interfaces.C.C_float;
      Padding   : Interfaces.C.char_array (1 .. 92);
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
   Texture_Access_Target : constant Interfaces.C.int := 2;
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

   function Set_Render_Draw_Blend_Mode
     (R : Renderer; Mode : Interfaces.Unsigned_32)
      return Interfaces.C.C_bool
     with Import, Convention => C,
          External_Name => "SDL_SetRenderDrawBlendMode";

   function Render_Clear (R : Renderer) return Interfaces.C.C_bool
     with Import, Convention => C, External_Name => "SDL_RenderClear";

   function Render_Fill_Rect
     (R : Renderer; Rect : access constant FRect) return Interfaces.C.C_bool
     with Import, Convention => C, External_Name => "SDL_RenderFillRect";

   function Set_Render_Clip_Rect
     (R : Renderer; Rect : System.Address) return Interfaces.C.C_bool
     with Import, Convention => C, External_Name => "SDL_SetRenderClipRect";
   --  Of an SDL_Rect; null for none.

   function Get_Render_Clip_Rect
     (R : Renderer; Rect : System.Address) return Interfaces.C.C_bool
     with Import, Convention => C, External_Name => "SDL_GetRenderClipRect";
   --  Fills in an SDL_Rect.

   function Render_Clip_Enabled (R : Renderer) return Interfaces.C.C_bool
     with Import, Convention => C, External_Name => "SDL_RenderClipEnabled";

   function Start_Text_Input (Win : Window) return Interfaces.C.C_bool
     with Import, Convention => C, External_Name => "SDL_StartTextInput";

   function Set_Text_Input_Area
     (Win : Window; Rect : System.Address; Cursor : Interfaces.C.int)
      return Interfaces.C.C_bool
     with Import, Convention => C, External_Name => "SDL_SetTextInputArea";

   function Set_Window_Title
     (Win : Window; Title : Interfaces.C.Strings.chars_ptr)
      return Interfaces.C.C_bool
     with Import, Convention => C, External_Name => "SDL_SetWindowTitle";

   function Set_Window_Size
     (Win : Window; W, H : Interfaces.C.int) return Interfaces.C.C_bool
     with Import, Convention => C, External_Name => "SDL_SetWindowSize";

   function Sync_Window (Win : Window) return Interfaces.C.C_bool
     with Import, Convention => C, External_Name => "SDL_SyncWindow";

   function Set_Clipboard_Text
     (Text : Interfaces.C.Strings.chars_ptr) return Interfaces.C.C_bool
     with Import, Convention => C, External_Name => "SDL_SetClipboardText";

   function Get_Clipboard_Text return Interfaces.C.Strings.chars_ptr
     with Import, Convention => C, External_Name => "SDL_GetClipboardText";
   --  Never null; free it.

   procedure Free (Item : Interfaces.C.Strings.chars_ptr)
     with Import, Convention => C, External_Name => "SDL_free";

   function Get_Ticks return Interfaces.Unsigned_64
     with Import, Convention => C, External_Name => "SDL_GetTicks";
   --  Milliseconds since SDL started.

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
     with Import, Convention => C,
          External_Name => "SDL_GetCurrentRenderOutputSize";
   --  Of the render target, if there is one.

   function Get_Window_Output_Size
     (R : Renderer; W, H : access Interfaces.C.int) return Interfaces.C.C_bool
     with Import, Convention => C, External_Name => "SDL_GetRenderOutputSize";
   --  Of the window, ignoring any render target.

   function Wait_Event_Timeout
     (E : access Event; Timeout_MS : Interfaces.Integer_32)
      return Interfaces.C.C_bool
     with Import, Convention => C, External_Name => "SDL_WaitEventTimeout";

   function Get_Window_Properties (Win : Window) return Interfaces.C.unsigned
     with Import, Convention => C, External_Name => "SDL_GetWindowProperties";

   function Get_Pointer_Property
     (Props   : Interfaces.C.unsigned;
      Name    : Interfaces.C.char_array;
      Default : System.Address) return System.Address
     with Import, Convention => C, External_Name => "SDL_GetPointerProperty";

   --  The Objective-C runtime, to reach a window's NSWindow.
   function Selector (Name : Interfaces.C.char_array) return System.Address
     with Import, Convention => C, External_Name => "sel_registerName";

   function Send_Flag
     (Target : System.Address; Sel : System.Address)
      return Interfaces.Unsigned_64
     with Import, Convention => C, External_Name => "objc_msgSend";

   procedure Send_Unsigned
     (Target : System.Address; Sel : System.Address;
      Value  : Interfaces.Unsigned_64)
     with Import, Convention => C, External_Name => "objc_msgSend";

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

   type Surface_Data is record
      Flags  : Interfaces.Unsigned_32;
      Format : Interfaces.Unsigned_32;
      W, H   : Interfaces.C.int;
      Pitch  : Interfaces.C.int;
      Pixels : System.Address;
      Refcount : Interfaces.C.int;
      Reserved : System.Address;
   end record
     with Convention => C;
   --  SDL_Surface, whose fields are read-only.

   type Surface_Access is access all Surface_Data
     with Convention => C;

   function Create_Surface
     (W, H : Interfaces.C.int; Format : Interfaces.Unsigned_32)
      return Surface_Access
     with Import, Convention => C, External_Name => "SDL_CreateSurface";

   function Convert_Surface
     (From : System.Address; Format : Interfaces.Unsigned_32)
      return Surface_Access
     with Import, Convention => C, External_Name => "SDL_ConvertSurface";

   function IO_From_File
     (File, Mode : Interfaces.C.Strings.chars_ptr) return System.Address
     with Import, Convention => C, External_Name => "SDL_IOFromFile";
   --  An SDL_IOStream, or null.

   function Load_Sized_SVG_IO
     (Source : System.Address; W, H : Interfaces.C.int)
      return Surface_Access
     with Import, Convention => C, External_Name => "IMG_LoadSizedSVG_IO";
   --  SDL3_image: the SVG, rasterized to W x H pixels, or null. It closes
   --  the stream.

   function Load_PNG
     (File : Interfaces.C.Strings.chars_ptr) return Surface_Access
     with Import, Convention => C, External_Name => "SDL_LoadPNG";

   function Save_PNG
     (Item : Surface_Access; File : Interfaces.C.Strings.chars_ptr)
      return Interfaces.C.C_bool
     with Import, Convention => C, External_Name => "SDL_SavePNG";

   function Create_Software_Renderer (Target : Surface_Access) return Renderer
     with Import, Convention => C,
          External_Name => "SDL_CreateSoftwareRenderer";

   function Set_Render_Target
     (R : Renderer; T : Texture) return Interfaces.C.C_bool
     with Import, Convention => C, External_Name => "SDL_SetRenderTarget";

   procedure Destroy_Surface (Surface : System.Address)
     with Import, Convention => C, External_Name => "SDL_DestroySurface";

   function Poll_Event (E : access Event) return Interfaces.C.C_bool
     with Import, Convention => C, External_Name => "SDL_PollEvent";

   type Event_Filter is access function
     (User_Data : System.Address; E : access Event) return Interfaces.C.C_bool
     with Convention => C;

   procedure Remove_Event_Watch
     (Filter : Event_Filter; User_Data : System.Address)
     with Import, Convention => C, External_Name => "SDL_RemoveEventWatch";

   function Add_Event_Watch
     (Filter : Event_Filter; User_Data : System.Address)
      return Interfaces.C.C_bool
     with Import, Convention => C, External_Name => "SDL_AddEventWatch";

   procedure Delay_MS (MS : Interfaces.Unsigned_32)
     with Import, Convention => C, External_Name => "SDL_Delay";

   function Get_Error return Interfaces.C.Strings.chars_ptr
     with Import, Convention => C, External_Name => "SDL_GetError";

end SDL3.Thin;
