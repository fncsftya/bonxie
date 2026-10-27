package body View_Driver is

   use type Pomarine.Events.Milliseconds;

   overriding
   procedure Take (Self : in out Driver; Event : Pomarine.Events.Event) is
   begin
      View.Handle (Self.App.all, Event);
   end Take;

   overriding
   procedure Settle (Self : in out Driver; Milliseconds : Natural) is
   begin
      Self.Clock := Self.Clock + Pomarine.Events.Milliseconds (Milliseconds);
      View.Tick (Self.App.all, Self.Clock);
      View.Render (Self.App.all, Self.Image);
   end Settle;

end View_Driver;
