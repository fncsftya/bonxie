with Interfaces;

package SDL3.Events is

   type Event_Kind is
     (Quit, Key_Down, Text_Input, Text_Editing, Mouse_Down, Mouse_Up,
      Mouse_Move, Mouse_Wheel, Pinch, Redraw, Other);
   --  Text_Input: text typed, once Windows.Start_Text_Input is called;
   --  the keys that typed it come as Key_Down too. Text_Editing: what an
   --  input method has been given so far, to show in place before it
   --  sends it as Text_Input, as when composing Japanese or an accented
   --  letter. Mouse_Down, Mouse_Up: a mouse button pressed or let go.
   --  Mouse_Move: the pointer moved. Pinch: a pinch on a trackpad.
   --  Redraw: the window was exposed or resized, so what it shows is out
   --  of date.

   subtype Key_Code is Interfaces.Unsigned_32;

   Key_Backspace : constant Key_Code := 16#08#;
   Key_Return    : constant Key_Code := 16#0D#;
   Key_Escape    : constant Key_Code := 16#1B#;
   Key_Delete    : constant Key_Code := 16#7F#;
   Key_Minus     : constant Key_Code := 16#2D#;
   Key_Equals    : constant Key_Code := 16#3D#;
   Key_0         : constant Key_Code := 16#30#;
   Key_A         : constant Key_Code := 16#61#;
   Key_C         : constant Key_Code := 16#63#;
   Key_S         : constant Key_Code := 16#73#;
   Key_V         : constant Key_Code := 16#76#;
   Key_X         : constant Key_Code := 16#78#;
   Key_Z         : constant Key_Code := 16#7A#;
   Key_Home      : constant Key_Code := 16#4000_004A#;
   Key_Page_Up   : constant Key_Code := 16#4000_004B#;
   Key_End       : constant Key_Code := 16#4000_004D#;
   Key_Page_Down : constant Key_Code := 16#4000_004E#;
   Key_Right_Arrow : constant Key_Code := 16#4000_004F#;
   Key_Left_Arrow : constant Key_Code := 16#4000_0050#;
   Key_Down_Arrow : constant Key_Code := 16#4000_0051#;
   Key_Up_Arrow  : constant Key_Code := 16#4000_0052#;

   type Milliseconds is range 0 .. 2 ** 62;

   Text_Capacity : constant := 256;
   --  Bytes of text an event holds. More, as an input method may commit,
   --  is cut short at a character.

   type Event is record
      Kind    : Event_Kind := Other;
      Time    : Milliseconds := 0;  --  when, as Ticks
      Key     : Key_Code := 0;      --  of Key_Down
      Command : Boolean := False;   --  Control or Command was held
      Option  : Boolean := False;   --  Option (Alt) was held
      Shift   : Boolean := False;   --  Shift was held
      Text    : String (1 .. Text_Capacity) := [others => ' '];
      Text_Length : Natural range 0 .. Text_Capacity := 0;
      --  Of Text_Input and Text_Editing: Text (1 .. Text_Length), UTF-8.
      Cursor  : Natural := 0;
      --  Of Text_Editing: the characters of the text before its cursor;
      --  Natural'Last if it is at the end.
      Button  : Natural := 0;       --  of Mouse_Down and Mouse_Up:
      Clicks  : Natural := 0;       --  1 left, 3 right; 2 for a double
      Left_Held : Boolean := False; --  of Mouse_Move
      Wheel_X : Float := 0.0;       --  of Mouse_Wheel, in lines
      Wheel_Y : Float := 0.0;
      Scale   : Float := 1.0;       --  of Pinch: the change, over 1 to
                                    --  zoom in, under 1 to zoom out
      Mouse_X : Float := 0.0;       --  where the pointer was, in points
      Mouse_Y : Float := 0.0;       --  from the window's top left
   end record;
   --  Modifiers are of keys and of the mouse.

   function Typed (Item : Event) return String is
     (Item.Text (1 .. Item.Text_Length))
     with Pre => Item.Kind in Text_Input | Text_Editing;

   function Text_Event (Text : String) return Event
     with Pre  => Text'Length in 1 .. Text_Capacity,
          Post => Typed (Text_Event'Result) = Text;
   --  The event of typing Text, as for testing.

   function Editing_Event (Text : String; Cursor : Natural) return Event
     with Pre  => Text'Length <= Text_Capacity,
          Post => Typed (Editing_Event'Result) = Text;
   --  The event of an input method showing Text, with its cursor after
   --  Cursor characters of it, as for testing.

   function Poll (Item : out Event) return Boolean;
   --  Fetch the next pending event; False if the queue is empty.

   function Wait (Item : out Event; Timeout_MS : Integer := -1) return Boolean;
   --  Wait for the next event, without using the processor: for at most
   --  Timeout_MS milliseconds, or as long as it takes if that is
   --  negative. False if none came.

   function Command_Held return Boolean;
   --  Whether Control or Command is held now.

   function Ticks return Milliseconds;
   --  Since SDL was initialized.

end SDL3.Events;
