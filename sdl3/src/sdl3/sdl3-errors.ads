with Interfaces.C;

private package SDL3.Errors is

   procedure Raise_Last_Error (Context : String)
     with No_Return;
   --  Raise SDL_Error with Context and SDL's current error string.

   procedure Check (Ok : Interfaces.C.C_bool; Context : String);
   --  Raise SDL_Error via Raise_Last_Error if Ok is false.

end SDL3.Errors;
