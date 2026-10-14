with Interfaces.C.Strings;
with SDL3.Thin;

package body SDL3.Errors is

   procedure Raise_Last_Error (Context : String) is
   begin
      raise SDL_Error with
        Context & ": " & Interfaces.C.Strings.Value (Thin.Get_Error);
   end Raise_Last_Error;

   procedure Check (Ok : Interfaces.C.C_bool; Context : String) is
   begin
      if not Boolean (Ok) then
         Raise_Last_Error (Context);
      end if;
   end Check;

end SDL3.Errors;
