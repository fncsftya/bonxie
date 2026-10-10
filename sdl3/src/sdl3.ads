--  Ada-style interface to SDL3. The C binding is hidden in SDL3.Thin.
package SDL3 is

   SDL_Error : exception;
   --  Raised when an SDL call fails; the message is SDL's error string.

   procedure Initialize;
   --  Initialize the SDL video subsystem.

   procedure Shutdown;
   --  Shut SDL down. Destroy all windows first.

end SDL3;
