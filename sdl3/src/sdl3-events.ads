with Interfaces;

package SDL3.Events is

   type Event_Kind is (Quit, Key_Down, Mouse_Wheel, Redraw, Other);
   --  Redraw: the window was exposed or resized, so what it shows is out
   --  of date.

   subtype Key_Code is Interfaces.Unsigned_32;

   Key_Minus     : constant Key_Code := 16#2D#;
   Key_Equals    : constant Key_Code := 16#3D#;
   Key_0         : constant Key_Code := 16#30#;
   Key_Home      : constant Key_Code := 16#4000_004A#;
   Key_Page_Up   : constant Key_Code := 16#4000_004B#;
   Key_End       : constant Key_Code := 16#4000_004D#;
   Key_Page_Down : constant Key_Code := 16#4000_004E#;
   Key_Down_Arrow : constant Key_Code := 16#4000_0051#;
   Key_Up_Arrow  : constant Key_Code := 16#4000_0052#;

   type Event is record
      Kind    : Event_Kind := Other;
      Key     : Key_Code := 0;      --  of Key_Down
      Command : Boolean := False;   --  Control or Command was held
      Wheel_X : Float := 0.0;       --  of Mouse_Wheel, in lines
      Wheel_Y : Float := 0.0;
      Mouse_X : Float := 0.0;       --  where the pointer was
      Mouse_Y : Float := 0.0;
   end record;

   function Poll (Item : out Event) return Boolean;
   --  Fetch the next pending event; False if the queue is empty.

   function Wait (Item : out Event; Timeout_MS : Integer := -1) return Boolean;
   --  Wait for the next event, without using the processor: for at most
   --  Timeout_MS milliseconds, or as long as it takes if that is
   --  negative. False if none came.

   function Command_Held return Boolean;
   --  Whether Control or Command is held now.

   type Redraw_Handler is access procedure;

   procedure Set_Redraw_Handler (Handler : Redraw_Handler);
   --  Call Handler whenever the window needs repainting, including while a
   --  live resize is in progress (when Poll is not being called, because the
   --  OS runs its own modal loop). Handler runs on the thread pumping events.

end SDL3.Events;
