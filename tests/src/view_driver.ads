with Goldens;
with Pomarine.Events;
with Pomarine.Testing;
with View;

--  A viewer session as Pomarine.Testing takes it: events given to it as it
--  handles them, and time passing as it ticks and draws.
package View_Driver is

   type Driver (App : not null access View.Session) is limited new Pomarine.Testing.Application with record
      Clock : Pomarine.Events.Milliseconds := 0;
      Image : Goldens.Images.Image;
   end record;

   overriding procedure Take (Self : in out Driver; Event : Pomarine.Events.Event);

   overriding procedure Settle (Self : in out Driver; Milliseconds : Natural);

end View_Driver;
