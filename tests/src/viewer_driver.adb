package body Viewer_Driver is

   use type Pomarine.Events.Milliseconds;

   overriding procedure Take (Self : in out Driver; Event : Pomarine.Events.Event) is
   begin
      Viewer.Handle (Self.App.all, Event);
   end Take;

   overriding procedure Settle (Self : in out Driver; Milliseconds : Natural) is
   begin
      Self.Clock := Self.Clock + Pomarine.Events.Milliseconds (Milliseconds);
      Viewer.Tick (Self.App.all, Self.Clock);
      Viewer.Render (Self.App.all, Self.Image);
   end Settle;

end Viewer_Driver;
