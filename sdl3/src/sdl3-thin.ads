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

   --  SDL_Event is a 128-byte union whose first member is the type.
   type Event is record
      Kind    : Event_Type;
      Padding : Interfaces.C.char_array (1 .. 124);
   end record
     with Convention => C, Size => 128 * 8;

   subtype Window is System.Address;
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

   function Poll_Event (E : access Event) return Interfaces.C.C_bool
     with Import, Convention => C, External_Name => "SDL_PollEvent";

   procedure Delay_MS (MS : Interfaces.Unsigned_32)
     with Import, Convention => C, External_Name => "SDL_Delay";

   function Get_Error return Interfaces.C.Strings.chars_ptr
     with Import, Convention => C, External_Name => "SDL_GetError";

end SDL3.Thin;
