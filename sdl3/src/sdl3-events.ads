package SDL3.Events is

   type Event_Kind is (Quit, Key_Down, Other);

   type Event is record
      Kind : Event_Kind := Other;
   end record;

   function Poll (Item : out Event) return Boolean;
   --  Fetch the next pending event; False if the queue is empty.

   type Redraw_Handler is access procedure;

   procedure Set_Redraw_Handler (Handler : Redraw_Handler);
   --  Call Handler whenever the window needs repainting, including while a
   --  live resize is in progress (when Poll is not being called, because the
   --  OS runs its own modal loop). Handler runs on the thread pumping events.

end SDL3.Events;
