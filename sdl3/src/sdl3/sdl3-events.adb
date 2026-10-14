with Ada.Unchecked_Conversion;
with Interfaces.C.Strings;
with SDL3.Thin;

package body SDL3.Events is

   use type Thin.Event_Type;
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_64;
   use type Interfaces.Integer_32;
   use type Interfaces.C.int;
   use type Interfaces.C.Strings.chars_ptr;

   Control_Or_Command : constant Interfaces.Unsigned_16 := 16#0CC0#;
   --  SDL_KMOD_CTRL and SDL_KMOD_GUI
   Alt_Keys   : constant Interfaces.Unsigned_16 := 16#0300#;
   Shift_Keys : constant Interfaces.Unsigned_16 := 16#0003#;

   Left_Button_Mask : constant Interfaces.Unsigned_32 := 1;
   --  SDL_BUTTON_LMASK

   function Decode (Raw : Thin.Event; Item : out Event) return Boolean;
   --  Fill Item from Raw.

   function To_Common is new Ada.Unchecked_Conversion
     (Thin.Event, Thin.Common_Event);
   function To_Wheel is new Ada.Unchecked_Conversion
     (Thin.Event, Thin.Wheel_Event);
   function To_Pinch is new Ada.Unchecked_Conversion
     (Thin.Event, Thin.Pinch_Event);
   function To_Key is new Ada.Unchecked_Conversion
     (Thin.Event, Thin.Key_Event);
   function To_Text is new Ada.Unchecked_Conversion
     (Thin.Event, Thin.Text_Event);
   function To_Editing is new Ada.Unchecked_Conversion
     (Thin.Event, Thin.Editing_Event);
   function To_Button is new Ada.Unchecked_Conversion
     (Thin.Event, Thin.Button_Event);
   function To_Motion is new Ada.Unchecked_Conversion
     (Thin.Event, Thin.Motion_Event);

   procedure Set_Text (Item : in out Event; Text : String);
   --  As much of Text as there is room for, cut at a character.

   procedure Set_Text (Item : in out Event; Text : String) is
      Length : Natural := Natural'Min (Text'Length, Text_Capacity);
   begin
      --  Back off continuation bytes, to the start of a character.
      if Length < Text'Length then
         while Length > 0
           and then Character'Pos (Text (Text'First + Length))
                    in 16#80# .. 16#BF#
         loop
            Length := Length - 1;
         end loop;
      end if;
      Item.Text (1 .. Length) := Text (Text'First .. Text'First + Length - 1);
      Item.Text_Length := Length;
   end Set_Text;

   procedure Set_Text
     (Item : in out Event; Text : Interfaces.C.Strings.chars_ptr);
   --  SDL's text, if there is any.

   procedure Set_Text
     (Item : in out Event; Text : Interfaces.C.Strings.chars_ptr) is
   begin
      if Text /= Interfaces.C.Strings.Null_Ptr then
         Set_Text (Item, Interfaces.C.Strings.Value (Text));
      end if;
   end Set_Text;

   function Text_Event (Text : String) return Event is
      Result : Event := (Kind => Text_Input, others => <>);
   begin
      Set_Text (Result, Text);
      return Result;
   end Text_Event;

   function Editing_Event (Text : String; Cursor : Natural) return Event is
      Result : Event := (Kind => Text_Editing, Cursor => Cursor, others => <>);
   begin
      Set_Text (Result, Text);
      return Result;
   end Editing_Event;

   procedure Set_Modifiers
     (Item : in out Event; Modifiers : Interfaces.Unsigned_16);

   procedure Set_Modifiers
     (Item : in out Event; Modifiers : Interfaces.Unsigned_16) is
   begin
      Item.Command := (Modifiers and Control_Or_Command) /= 0;
      Item.Option := (Modifiers and Alt_Keys) /= 0;
      Item.Shift := (Modifiers and Shift_Keys) /= 0;
   end Set_Modifiers;

   function Decode (Raw : Thin.Event; Item : out Event) return Boolean is
   begin
      Item := (others => <>);
      Item.Time :=
        Milliseconds (To_Common (Raw).Timestamp / 1_000_000);
      --  The mouse's events do not say which keys are held: now, then.
      Set_Modifiers (Item, Thin.Get_Mod_State);

      if Raw.Kind = Thin.Event_Quit then
         Item.Kind := Quit;
      elsif Raw.Kind = Thin.Event_Key_Down then
         declare
            Key : constant Thin.Key_Event := To_Key (Raw);
         begin
            Item.Kind := Key_Down;
            Item.Key := Key.Key;
            Set_Modifiers (Item, Key.Modifiers);
         end;
      elsif Raw.Kind = Thin.Event_Theme_Changed then
         Item.Kind := Theme_Changed;
      elsif Raw.Kind = Thin.Event_Text_Input then
         Item.Kind := Text_Input;
         Set_Text (Item, To_Text (Raw).Text);
      elsif Raw.Kind = Thin.Event_Text_Editing then
         declare
            Editing : constant Thin.Editing_Event := To_Editing (Raw);
         begin
            Item.Kind := Text_Editing;
            Set_Text (Item, Editing.Text);
            Item.Cursor :=
              (if Editing.Start < 0 then Natural'Last
               else Natural (Editing.Start));
         end;
      elsif Raw.Kind = Thin.Event_Mouse_Button_Down
        or else Raw.Kind = Thin.Event_Mouse_Button_Up
      then
         declare
            Button : constant Thin.Button_Event := To_Button (Raw);
         begin
            Item.Kind :=
              (if Raw.Kind = Thin.Event_Mouse_Button_Down then Mouse_Down
               else Mouse_Up);
            Item.Button := Natural (Button.Button);
            Item.Clicks := Natural (Button.Clicks);
            Item.Mouse_X := Float (Button.X);
            Item.Mouse_Y := Float (Button.Y);
         end;
      elsif Raw.Kind = Thin.Event_Mouse_Motion then
         declare
            Motion : constant Thin.Motion_Event := To_Motion (Raw);
         begin
            Item.Kind := Mouse_Move;
            Item.Left_Held := (Motion.State and Left_Button_Mask) /= 0;
            Item.Mouse_X := Float (Motion.X);
            Item.Mouse_Y := Float (Motion.Y);
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
      elsif Raw.Kind = Thin.Event_Pinch_Update then
         declare
            X, Y : aliased Interfaces.C.C_float;
            Buttons : constant Interfaces.Unsigned_32 :=
              Thin.Get_Mouse_State (X'Access, Y'Access);
            pragma Unreferenced (Buttons);
         begin
            --  Where the pointer is, which the event does not say.
            Item.Kind := Pinch;
            Item.Scale := Float (To_Pinch (Raw).Scale);
            Item.Mouse_X := Float (X);
            Item.Mouse_Y := Float (Y);
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

   function Ticks return Milliseconds is (Milliseconds (Thin.Get_Ticks));

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

   function System_Is_Dark return Boolean is
     (Thin.Get_System_Theme = 2);

end SDL3.Events;
