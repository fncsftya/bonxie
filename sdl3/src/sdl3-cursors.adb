with Interfaces.C;
with System;
with SDL3.Errors;
with SDL3.Thin;

package body SDL3.Cursors is

   use type Thin.Cursor;

   Made : array (Kind) of Thin.Cursor :=
     [others => Thin.Cursor (System.Null_Address)];
   --  Each system cursor lives as long as the program.

   function System_Id (Which : Kind) return Interfaces.C.int is
     (case Which is
         when Default => 0,   --  SDL_SYSTEM_CURSOR_DEFAULT
         when Move    => 9,   --  SDL_SYSTEM_CURSOR_MOVE
         when Pointer => 11,  --  SDL_SYSTEM_CURSOR_POINTER
         when Resize  => 5);  --  SDL_SYSTEM_CURSOR_NWSE_RESIZE

   procedure Set (Which : Kind) is
   begin
      if Made (Which) = Thin.Cursor (System.Null_Address) then
         Made (Which) := Thin.Create_System_Cursor (System_Id (Which));
         if Made (Which) = Thin.Cursor (System.Null_Address) then
            Errors.Raise_Last_Error ("SDL_CreateSystemCursor");
         end if;
      end if;
      Errors.Check (Thin.Set_Cursor (Made (Which)), "SDL_SetCursor");
   end Set;

end SDL3.Cursors;
