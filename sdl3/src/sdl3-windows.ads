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
      Resizable : Boolean := False;
      High_Density : Boolean := False;
      Hidden    : Boolean := False);
   --  With High_Density the window's pixels are the display's own, not
   --  scaled up from points: see Pixel_Density. A Hidden window is not
   --  shown, but can be drawn to, as for measuring.

   function Is_Open (Item : Window) return Boolean;

   function Pixel_Density (Item : Window) return Float
     with Pre => Is_Open (Item), Post => Pixel_Density'Result >= 1.0;
   --  How many pixels of the window's drawing area there are to each
   --  point of its size: 2.0 on a Retina display, if High_Density.

private

   type Window is new Ada.Finalization.Limited_Controlled with record
      Handle : System.Address := System.Null_Address;
   end record;

   overriding procedure Finalize (Item : in out Window);

end SDL3.Windows;
