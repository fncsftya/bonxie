with SDL3.Thin;

package body SDL3.Events is

   use type Thin.Event_Type;

   function Poll (Item : out Event) return Boolean is
      Raw : aliased Thin.Event;
   begin
      Item := (Kind => Other);
      if not Boolean (Thin.Poll_Event (Raw'Access)) then
         return False;
      end if;

      if Raw.Kind = Thin.Event_Quit then
         Item.Kind := Quit;
      elsif Raw.Kind = Thin.Event_Key_Down then
         Item.Kind := Key_Down;
      end if;
      return True;
   end Poll;

end SDL3.Events;
