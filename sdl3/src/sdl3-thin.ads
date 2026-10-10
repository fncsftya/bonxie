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

   type Event_Type is new Interfaces.Unsigned_32;
   Event_Quit        : constant Event_Type := 16#100#;
   Event_Key_Down    : constant Event_Type := 16#300#;
   Event_Window_Exposed           : constant Event_Type := 16#204#;
   Event_Window_Resized           : constant Event_Type := 16#206#;
   Event_Window_Pixel_Size_Changed : constant Event_Type := 16#207#;

   --  SDL_Event is a 128-byte union whose first member is the type.
   type Event is record
      Kind    : Event_Type;
      Padding : Interfaces.C.char_array (1 .. 124);
   end record
     with Convention => C, Size => 128 * 8;

   type FRect is record
      X, Y, W, H : Interfaces.C.C_float;
   end record
     with Convention => C;

   subtype Window is System.Address;
   subtype Renderer is System.Address;
   Null_Window : constant Window := System.Null_Address;

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
