with Interfaces.C.Strings;
with SDL3.Thin;

package body SDL3 is

   procedure Raise_Last_Error (Context : String) is
   begin
      raise SDL_Error with
        Context & ": " & Interfaces.C.Strings.Value (SDL3.Thin.Get_Error);
   end Raise_Last_Error;

   procedure Initialize is
   begin
      if not Boolean (SDL3.Thin.Init (SDL3.Thin.Init_Video)) then
         Raise_Last_Error ("SDL_Init");
      end if;
   end Initialize;

   procedure Shutdown is
   begin
      SDL3.Thin.Quit;
   end Shutdown;

end SDL3;
