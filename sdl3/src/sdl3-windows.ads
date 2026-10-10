private with Ada.Finalization;
private with System;

package SDL3.Windows is

   type Window is limited private;
   --  Destroyed automatically when it goes out of scope.

   procedure Create
     (Item      : in out Window;
      Title     : String;
      Width     : Positive;
      Height    : Positive;
      Resizable : Boolean := False);

   function Is_Open (Item : Window) return Boolean;

private

   type Window is new Ada.Finalization.Limited_Controlled with record
      Handle : System.Address := System.Null_Address;
   end record;

   overriding procedure Finalize (Item : in out Window);

end SDL3.Windows;
