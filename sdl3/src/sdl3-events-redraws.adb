with Interfaces.C;
with System.Address_To_Access_Conversions;
with SDL3.Thin;

package body SDL3.Events.Redraws is

   use type System.Address;
   use type Thin.Event_Type;

   --  Callback is declared in the instance, which lives as long as the
   --  program, so it can be given to the C side whatever the access type.

   package Contexts is new System.Address_To_Access_Conversions (Context);

   function Callback
     (User_Data : System.Address; E : access Thin.Event)
      return Interfaces.C.C_bool
     with Convention => C;

   function Callback
     (User_Data : System.Address; E : access Thin.Event)
      return Interfaces.C.C_bool is
   begin
      if E.Kind = Thin.Event_Window_Pixel_Size_Changed then
         Redraw (Contexts.To_Pointer (User_Data).all);
      end if;
      return Interfaces.C.C_bool (True);  --  keep the event
   end Callback;

   procedure Install (Item : in out Watch; Target : aliased in out Context) is
   begin
      if not Boolean
               (Thin.Add_Event_Watch
                  (Callback'Unrestricted_Access, Target'Address))
      then
         raise SDL_Error with "SDL_AddEventWatch failed";
      end if;
      Item.Data := Target'Address;
   end Install;

   function Is_Installed (Item : Watch) return Boolean is
     (Item.Data /= System.Null_Address);

   overriding procedure Finalize (Item : in out Watch) is
   begin
      if Item.Data /= System.Null_Address then
         Thin.Remove_Event_Watch (Callback'Unrestricted_Access, Item.Data);
         Item.Data := System.Null_Address;
      end if;
   end Finalize;

end SDL3.Events.Redraws;
