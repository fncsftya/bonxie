with Interfaces.C;
with System;
with SDL3.Thin;

package body SDL3.Events is

   use type Thin.Event_Type;

   Current : Redraw_Handler;

   function Watch
     (User_Data : System.Address; E : access Thin.Event)
      return Interfaces.C.C_bool
     with Convention => C;

   function Watch
     (User_Data : System.Address; E : access Thin.Event)
      return Interfaces.C.C_bool
   is
      pragma Unreferenced (User_Data);
   begin
      if Current /= null
        and then E.Kind = Thin.Event_Window_Pixel_Size_Changed
      then
         Current.all;
      end if;
      return Interfaces.C.C_bool (True);
   end Watch;

   procedure Set_Redraw_Handler (Handler : Redraw_Handler) is
      Installed : Boolean;
   begin
      pragma Assert (Handler /= null);
      Installed := Current /= null;
      Current := Handler;
      if not Installed then
         if not Boolean
                  (Thin.Add_Event_Watch (Watch'Access, System.Null_Address))
         then
            Current := null;
            raise SDL_Error with "SDL_AddEventWatch failed";
         end if;
      end if;
   end Set_Redraw_Handler;

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
