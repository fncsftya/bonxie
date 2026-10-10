with Ada.Unchecked_Conversion;
with Interfaces.C;
with System;
with SDL3.Thin;

package body SDL3.Events is

   use type Thin.Event_Type;
   use type Interfaces.Unsigned_16;

   Current : Redraw_Handler;

   Control_Or_Command : constant Interfaces.Unsigned_16 := 16#0CC0#;
   --  SDL_KMOD_CTRL and SDL_KMOD_GUI

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

   function Decode (Raw : Thin.Event; Item : out Event) return Boolean;
   --  Fill Item from Raw.

   function To_Wheel is new Ada.Unchecked_Conversion
     (Thin.Event, Thin.Wheel_Event);
   function To_Key is new Ada.Unchecked_Conversion
     (Thin.Event, Thin.Key_Event);

   function Decode (Raw : Thin.Event; Item : out Event) return Boolean is
   begin
      Item := (others => <>);
      if Raw.Kind = Thin.Event_Quit then
         Item.Kind := Quit;
      elsif Raw.Kind = Thin.Event_Key_Down then
         declare
            Key : constant Thin.Key_Event := To_Key (Raw);
         begin
            Item.Kind := Key_Down;
            Item.Key := Key.Key;
            Item.Command := (Key.Modifiers and Control_Or_Command) /= 0;
         end;
      elsif Raw.Kind = Thin.Event_Mouse_Wheel then
         declare
            Wheel : constant Thin.Wheel_Event := To_Wheel (Raw);
         begin
            Item.Kind := Mouse_Wheel;
            Item.Wheel_X := Float (Wheel.X);
            Item.Wheel_Y := Float (Wheel.Y);
            Item.Mouse_X := Float (Wheel.Mouse_X);
            Item.Mouse_Y := Float (Wheel.Mouse_Y);
         end;
      elsif Raw.Kind = Thin.Event_Window_Exposed
        or else Raw.Kind = Thin.Event_Window_Resized
        or else Raw.Kind = Thin.Event_Window_Pixel_Size_Changed
      then
         Item.Kind := Redraw;
      end if;
      return True;
   end Decode;

   function Command_Held return Boolean is
     ((Thin.Get_Mod_State and Control_Or_Command) /= 0);

   function Poll (Item : out Event) return Boolean is
      Raw : aliased Thin.Event;
   begin
      Item := (others => <>);
      return Boolean (Thin.Poll_Event (Raw'Access))
        and then Decode (Raw, Item);
   end Poll;

   function Wait (Item : out Event; Timeout_MS : Integer := -1) return Boolean
   is
      Raw : aliased Thin.Event;
   begin
      Item := (others => <>);
      return Boolean
               (Thin.Wait_Event_Timeout
                  (Raw'Access, Interfaces.Integer_32 (Timeout_MS)))
        and then Decode (Raw, Item);
   end Wait;

end SDL3.Events;
