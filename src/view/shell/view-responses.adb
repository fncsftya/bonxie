with View.Navigation;
with View.Updates;

package body View.Responses is

   package Widgets renames Pomarine.Widgets;

   use type Widgets.Event_Kind;

   --  What the menu bar and the keys ask

   procedure Perform (Item : in out Session; Event : Widgets.Widget_Event) is
   begin
      if Event.Tag = Check_Updates_Tag then
         if Event.Kind in Widgets.Click | Widgets.Submit then
            Updates.Check_Now (Item);
         end if;
         return;
      end if;
      if Is_Nav_Tag (Event.Tag) then
         if Event.Kind in Widgets.Click | Widgets.Submit then
            Navigation.Do_Command (Item, Command_Of (Event.Tag), Event.Index);
         end if;
         return;
      end if;
   end Perform;

end View.Responses;
