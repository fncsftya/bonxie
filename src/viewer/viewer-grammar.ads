private package Viewer.Grammar is

   Idle_Delay : constant := 500;
   procedure Build (Item : in out Session);
   procedure Close (Item : in out Session);
   procedure Pressed (Item : in out Session; X, Y : Float);
   procedure Update (Item : in out Session; Now : SDL3.Events.Milliseconds);
   function Until_Update (Item : Session; Now : SDL3.Events.Milliseconds) return Integer;
   procedure Reset (Item : in out Session);

end Viewer.Grammar;
