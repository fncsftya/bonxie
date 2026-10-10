with SDL3.Events;
with SDL3.Windows;

procedure Bonxie is
   use type SDL3.Events.Event_Kind;
begin
   SDL3.Initialize;

   declare
      Win  : SDL3.Windows.Window;
      Ev   : SDL3.Events.Event;
      Done : Boolean := False;
   begin
      SDL3.Windows.Create
        (Win, "Hello, World! - bonxie", 800, 600, Resizable => True);

      while not Done loop
         while SDL3.Events.Poll (Ev) loop
            Done := Done or else Ev.Kind = SDL3.Events.Quit;
         end loop;
         delay 0.016;
      end loop;
   end;  --  Win is destroyed here

   SDL3.Shutdown;
end Bonxie;
