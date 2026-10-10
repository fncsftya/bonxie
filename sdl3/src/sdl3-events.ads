package SDL3.Events is

   type Event_Kind is (Quit, Key_Down, Other);

   type Event is record
      Kind : Event_Kind := Other;
   end record;

   function Poll (Item : out Event) return Boolean;
   --  Fetch the next pending event; False if the queue is empty.

end SDL3.Events;
