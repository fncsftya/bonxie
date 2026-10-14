private with Ada.Finalization;
private with System;

generic
   type Context is limited private;
   with procedure Redraw (Item : in out Context);
package SDL3.Events.Redraws is

   type Watch is limited private;
   --  A request that Redraw be called whenever the window needs
   --  repainting, including while a live resize is in progress, when Poll
   --  is not being called because the OS runs its own modal loop. Redraw
   --  runs on the thread pumping events. Ends when it goes out of scope.

   procedure Install (Item : in out Watch; Target : aliased in out Context)
     with Pre => not Is_Installed (Item), Post => Is_Installed (Item);
   --  Have Redraw called with Target. Target must outlive Item.

   function Is_Installed (Item : Watch) return Boolean;

private

   type Watch is new Ada.Finalization.Limited_Controlled with record
      Data : System.Address := System.Null_Address;
   end record;

   overriding procedure Finalize (Item : in out Watch);

end SDL3.Events.Redraws;
