with Items.Models;
with Ada.Calendar;
with Ada.Calendar.Formatting;

package body Viewer.Canvas_Items.Basics is

   package Windows renames Items.Windows;

   package Models renames Items.Models;

   use type Items.Kinds;

   function Epoch_Now (Item : Session) return Projects.Seconds is
     (if Item.Nav.Pinned_Time > 0
      then Item.Nav.Pinned_Time else Projects.Seconds
        (Ada.Calendar."-"
           (Ada.Calendar.Clock,
            Ada.Calendar.Formatting.Time_Of
              (1970, 1, 1, Time_Zone => 0))));

   function Is_Source (Item : Session; Which : Items.Slot) return Boolean is
     (Windows.Is_Assigned (Item.Windows (Which))
      and then Models.Details (Item.Models (Which)).Kind = Items.Source);

   procedure Touch (Item : in out Session) is
   begin
      Projects.Touch (Item.Nav.Store, Open_Key (Item));
   end Touch;

end Viewer.Canvas_Items.Basics;
