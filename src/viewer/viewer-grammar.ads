private package Viewer.Grammar is

   Idle_Delay : constant := 500;
   procedure Build (Item : in out Session);
   procedure Close (Item : in out Session);
   procedure Before_Event (Item : in out Session; Event : SDL3.Events.Event);
   procedure Released (Item : in out Session; Event : SDL3.Events.Event);
   procedure Update_Cursor (Item : in out Session);
   procedure Close_Inline (Item : in out Session);
   procedure Update (Item : in out Session; Now : SDL3.Events.Milliseconds);
   function Until_Update (Item : Session; Now : SDL3.Events.Milliseconds) return Integer;
   procedure Reset (Item : in out Session);

end Viewer.Grammar;
